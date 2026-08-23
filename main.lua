-- Gen1BillsBox
--
-- Gen 1's storage screen is a menu of four verbs over a list of twenty
-- names.  This replaces it -- not adds to it -- with the thing the list was
-- always standing in for: the party down the left, the open box as a grid
-- on the right, and a cursor that picks a POKeMON up and puts it down.
--
-- Two decisions are worth stating up front, because they are the whole
-- brief:
--
--   * It REPLACES the screen.  `mod.content.screens:override("BoxMenu")` is
--     the id BILL'S PC pushes, so there is no second entrance to maintain
--     and no vanilla list left underneath to fall out of step with the save.
--   * It looks like the game it is in.  Four shades, the Game Boy's own
--     font, line art and the standard bordered boxes -- no type colours, no
--     widescreen layout, no card chrome.  The grid is Gen 3's idea; every
--     pixel drawing it is Gen 1's.
--
-- The slots are drawn with `PartyMenu.drawIcon`, the engine's own party-menu
-- icon path, so per-species icons, the `pokemon.icon` hook and any icon
-- replacement mod land in the box exactly as they land in the party.

return function(mod)
  local Strings = require("src.core.Strings")

  mod.options:define({
    -- The cry of whichever POKeMON just landed in a slot.  On by default
    -- because the vanilla PC plays one on every withdraw and deposit; this
    -- is the same sound at the same moment, not a new one.
    { key = "placeCry", label = "PLACE CRY", type = "toggle", default = true },
    -- Hold a direction to keep moving, the way the engine's own list menus
    -- offer it (ui.list_menu keyRepeat).  Twenty slots and six party rows
    -- is a lot of single presses.
    { key = "holdMove", label = "HOLD TO MOVE", type = "toggle", default = true },
    -- Where the cursor is when the screen opens.  BOX is the storage screen
    -- doing its job; PARTY suits a player who mostly deposits.
    { key = "startPane", label = "OPEN ON", type = "choice", default = "box",
      choices = {
        { "BOX", "box" },
        { "PARTY", "party" },
      } },
    -- See "a catch that overflows says so" below.  On by default because it
    -- only ever speaks when a POKeMON went somewhere other than the box you
    -- think you are filling, which is the one time you need telling.
    { key = "fullBoxNote", label = "FULL BOX NOTE", type = "toggle",
      default = true },
  })

  local function option(key, fallback)
    local ok, value = pcall(function() return mod.options:get(key) end)
    if not ok or value == nil then return fallback end
    return value
  end

  -- ------- the screen
  --
  -- Kept in its own file and compiled through the sandbox's own `load`, which
  -- is the multi-file pattern the loader supports (src/mods/Sandbox.lua's
  -- sandboxedLoad): the chunk runs in this mod's globals rather than the real
  -- _G.  A failure here logs and returns, which leaves the builtin BoxMenu in
  -- place -- a broken storage screen must never be the only storage screen.
  local source, readErr = mod:read("screen.lua")
  if not source then
    mod.log:error("screen.lua is missing (%s); reinstall the mod",
      tostring(readErr or "unknown read error"))
    return
  end

  local chunk, compileErr = load(source, "@" .. mod.path .. "/screen.lua")
  if not chunk then
    mod.log:error("screen.lua did not compile: %s", tostring(compileErr))
    return
  end

  local okFactory, factory = pcall(chunk)
  if not okFactory or type(factory) ~= "function" then
    mod.log:error("screen.lua must return a factory function: %s",
      tostring(factory))
    return
  end

  local okScreen, screen = pcall(factory, mod)
  if not okScreen or type(screen) ~= "table"
      or type(screen.new) ~= "function" then
    mod.log:error("the box screen factory failed: %s", tostring(screen))
    return
  end

  -- `override` rather than `register` so this is the only BoxMenu on the
  -- chain: a second UI mod registering the same id composes, and two storage
  -- screens over one save is the failure mode worth spending a line to
  -- avoid.  The id is the builtin's, so nothing else has to be told.
  if mod.content.screens:get("BoxMenu") then
    mod.content.screens:override("BoxMenu", screen)
  else
    mod.content.screens:register("BoxMenu", screen)
  end

  -- ------- BILL'S PC is BILL'S BOX
  --
  -- The Pokemon Center PC's storage row reads "SOMEONE'S PC" until you meet
  -- Bill and "BILL'S PC" after (engine/menus/pokemon_pc.asm gates on
  -- EVENT_MET_BILL, and src/world/OverworldController.lua:openPC follows it),
  -- so both labels are renamed -- anchoring on one alone would silently stop
  -- working halfway through the game.
  --
  -- next() is called FIRST and the result decorated, so another mod's row on
  -- the same menu survives instead of being rebuilt over.
  local PC_ROWS = {
    ["BILL'S PC"] = "BILL'S BOX",
    ["SOMEONE'S PC"] = "SOMEONE'S BOX",
  }

  mod.hooks:wrap("ui.pc.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    for _, entry in ipairs(out) do
      if type(entry) == "table" then
        local renamed = PC_ROWS[entry.label]
        if renamed then entry.label = Strings(renamed) end
      end
    end
    return out
  end)

  -- ------- and so are the lines the PC prints
  --
  -- Three sentences elsewhere call the storage system a PC, and a row that
  -- says BOX opening a screen that says PC is worse than not renaming it at
  -- all.  These are ROM-extracted strings (src/core/RomText.lua reads
  -- data.text by pokered label), so they are rewritten rather than replaced:
  -- one gsub of the machine's name leaves a localized import's own wording
  -- everywhere else in the line, and a translation that does not spell it
  -- "PC" is simply left alone.
  --
  -- Done on game.ready because that is the first moment data.text is the
  -- merged table the game will actually print from; the guard makes a second
  -- firing (dev hot reload) a no-op rather than a second rewrite.
  local PC_TEXT = {
    -- engine/menus/pc.asm BillsPC / the "someone's" arm before Bill
    _AccessedBillsPCText = "Accessed BILL's\nBOX.\fAccessed POKéMON\nStorage System.",
    _AccessedSomeonesPCText =
      "Accessed someone's\nBOX.\fAccessed POKéMON\nStorage System.",
    -- the caught-a-mon-with-a-full-party line (src/battle/BattleState.lua)
    _ItemUseBallText07 = "{RAM:wStringBuffer} was\ntransferred to\nBILL's BOX!",
    _ItemUseBallText08 =
      "{RAM:wStringBuffer} was\ntransferred to\nsomeone's BOX!",
  }

  local renamed = false

  local function renameStorageText(game)
    if renamed then return end
    local text = game and game.data and game.data.text
    if type(text) ~= "table" then return end
    renamed = true
    for label, english in pairs(PC_TEXT) do
      local line = text[label]
      if type(line) == "string" then
        -- the word only ever names the machine in these four lines, and
        -- "POKéMON" carries no "PC" to catch by accident
        text[label] = (line:gsub("PC", "BOX"))
      else
        -- no extracted line for this label (an older cache, or a total
        -- conversion that dropped it): romText would fall back to the
        -- engine's own "PC" wording, so supply the renamed one
        text[label] = english
      end
    end
  end

  mod.events:on("game.ready", function(payload)
    renameStorageText(payload and payload.game)
  end)

  -- ------- a catch that overflows says so
  --
  -- The overflow itself is NOT this mod's: src/pokemon/Boxes.lua's `deposit`
  -- already walks from the open box forward through all twelve and drops the
  -- POKeMON in the first one with room, wrapping, and the catch only fails
  -- ("But every BOX is full!") when all 240 places are taken.  That is a
  -- deliberate engine divergence -- the cart refused the catch outright the
  -- moment the open box was full -- and it is what a player wants.
  --
  -- What it does not do is SAY so.  The line it prints is the cart's own
  -- ("<MON> was transferred to BILL's BOX!") and the cart never needed to
  -- name a box, because on the cart the POKeMON could only ever be in the one
  -- you had open.  Here it can be in any of twelve, and nothing on screen
  -- tells you which -- so a POKeMON caught into a full box is findable only
  -- by opening the PC and walking the boxes.
  --
  -- One extra line closes that, and only in the case that needs it: the
  -- landing box is compared against the open one, so an ordinary catch into
  -- the open box stays exactly as quiet as it was.
  --
  -- The number cannot go into the transfer line itself.  That text is
  -- ROM-extracted and reached through src/core/RomText.lua, which fills its
  -- {} slots from the caller's arguments -- BattleState passes exactly one,
  -- the POKeMON's name, so a second slot makes the arity check fail and the
  -- whole line falls back to the engine's own English (saying "PC" again).
  local Boxes = require("src.pokemon.Boxes")

  local function boxHolding(save, mon)
    local boxes = save and save.boxes
    if not (boxes and mon) then return nil end
    for i = 1, Boxes.COUNT do
      for _, held in ipairs(boxes[i] or {}) do
        if held == mon then return i end
      end
    end
    return nil
  end

  -- The line to add after the transfer message, or nil when there is nothing
  -- worth saying.  Split out from the handler so the suite can ask it
  -- directly rather than having to stage a battle.
  local function overflowLine(save, mon)
    local landed = boxHolding(save, mon)
    if not landed then return nil end
    local open = save.currentBox or 1
    if landed == open then return nil end
    return Strings("BOX %d was full!\nStored in BOX %d.", open, landed)
  end

  -- BattleState:sayNext inserts at the queue's `nextInsert`, which the
  -- transfer message has just advanced, so this lands immediately after it
  -- rather than at the end of the battle's remaining chatter.  The event
  -- fires on the line after the deposit (src/battle/BattleState.lua), which
  -- is why the POKeMON is already in a box to be found by the time we look.
  mod.events:on("pokemon.caught", function(payload)
    if type(payload) ~= "table" or payload.destination ~= "box" then return end
    if not option("fullBoxNote", true) then return end
    local battle, game = payload.battle, payload.game
    if type(battle) ~= "table" or type(battle.sayNext) ~= "function" then return end
    local save = game and game.save
    if type(save) ~= "table" then return end
    local line = overflowLine(save, payload.mon)
    if line then battle:sayNext(line) end
  end)

  -- exported so the suite can drive the rename without a booted game, and so
  -- a companion mod can ask whether the rename has run yet
  mod.exports.renameStorageText = renameStorageText
  mod.exports.pcRowLabels = PC_ROWS
  mod.exports.overflowLine = overflowLine
  mod.exports.boxHolding = boxHolding

  mod.log:info("BILL'S PC is a box")
end
