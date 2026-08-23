-- Bill's Box: the storage screen itself.
--
-- Returns a factory: factory(mod) -> { new = function(game) ... end }, which
-- main.lua installs over the builtin "BoxMenu" id.
--
-- ------- the shape of the screen
--
--   rows 0-2    the box header: BOX n, how full it is, and the two arrows
--   rows 3-14   the party down the left, the open box as a 5x4 grid
--   rows 15-17  one line naming what the cursor is on
--
-- 160x144 and nothing else.  Twenty slots at 26x24 leave a 16x16 icon four
-- pixels of margin on every side, six party rows at 16 fill the same 96
-- pixels exactly, and both land on the 8-pixel tile grid the font boxes are
-- drawn from -- which is why the two panes line up top and bottom without a
-- single fractional coordinate anywhere in this file.
--
-- ------- why the slots hold party icons
--
-- Because that is the seam every icon mod already writes to.
-- `PartyMenu.drawIcon` is the engine's one canonical icon path: it folds the
-- icons registry, a species record's own `icon` field, asset overrides and
-- the `pokemon.icon` hook together, then bakes OBP0 and mirrors the frame
-- the way the hardware's OAM did.  Calling it -- rather than re-resolving
-- art here -- is what makes a menu-icon mod show up in the box for free, and
-- what keeps this screen honest when one changes.
--
-- The animation frame is chosen HERE and passed as `forceAlt` rather than
-- letting drawIcon derive it from the mon: its own speed rule reads
-- mon.stats.hp, and a Gen 1 box mon legitimately has no stat block at all
-- (box_struct stops before MON_STATS -- see Stats.ensure).  One boolean
-- avoids ever handing that path a mon it cannot measure.
--
-- ------- what a slot means
--
-- Gen 1 stores a box as a COMPACT array (src/pokemon/Boxes.lua): box[1..n]
-- with nothing after n.  This screen keeps that shape, because the save
-- format, the vanilla PC and every other mod read it.  So dropping into an
-- empty cell APPENDS rather than leaving a hole, and the cursor snaps to
-- where the POKeMON actually landed instead of sitting on the cell you
-- aimed at.  Ruby's sparse grid is the one thing here that is not copied.

return function(mod)
  local Boxes = require("src.pokemon.Boxes")
  local Font = require("src.render.Font")
  local ListMenu = require("src.ui.ListMenu")
  local Menu = require("src.ui.Menu")
  local Party = require("src.pokemon.Party")
  local PartyMenu = require("src.ui.PartyMenu")
  local Screens = require("src.ui.Screens")
  local Stats = require("src.pokemon.Stats")
  local Strings = require("src.core.Strings")
  local TextBox = require("src.render.TextBox")
  local Theme = require("src.ui.Theme")

  -- ------- geometry

  local COLS, ROWS = 5, 4
  local CELL_W, CELL_H = 26, 24
  local GRID_X, GRID_Y = 30, 24

  local PARTY_ROWS = Party.MAX          -- 6
  local PARTY_H = 16
  local PARTY_X, PARTY_Y = 8, 24        -- the icon column; the cursor sits at 0
  local RULE_X = 26                     -- the hairline between the two panes

  local ICON = 16
  local ICON_DX = math.floor((CELL_W - ICON) / 2)   -- 5
  local ICON_DY = math.floor((CELL_H - ICON) / 2)   -- 4
  -- How far a carried POKeMON rides above its slot.  A grid cell has four
  -- pixels of margin to lift into; a party row, which is exactly one icon
  -- tall, has none, so it gets a token two rather than climbing into the row
  -- above it.
  local LIFT, PARTY_LIFT = 4, 2

  local HEADER_TH = 3                   -- tiles
  local INFO_TY = 15                    -- tiles
  local INFO_TEXT_Y = (INFO_TY + 1) * 8 -- 128
  local TEXT_LEFT, TEXT_RIGHT = 8, 152

  -- The four DMG shades the extracted art is drawn in; shade 1 is the
  -- engine's own grey (src/ui/PartyMenu.lua's OBP bake keys on the same
  -- 170).  Nothing here invents a colour: the SGB pass below paints the
  -- finished frame.
  local GREY = { 170 / 255, 170 / 255, 170 / 255 }
  local BLACK = { 0, 0, 0 }

  -- ui.list_menu's own hold-to-scroll cadence (src/ui/ListMenu.lua), in
  -- fixed steps, so a held direction here moves at the speed a held
  -- direction moves everywhere else in the game.
  local REPEAT_DELAY, REPEAT_RATE = 16, 5

  -- how many steps between the two icon frames; the party menu picks 5, 16
  -- or 32 off the mon's HP bar colour, and a storage grid has no bar to read
  local ANIM_STEPS = 8

  -- ------- options, read live so the manager's rows take effect at once

  local function option(key, fallback)
    local ok, value = pcall(function() return mod.options:get(key) end)
    if not ok or value == nil then return fallback end
    return value
  end

  -- ------- small helpers

  local function ink(shade)
    love.graphics.setColor(shade[1], shade[2], shade[3], 1)
  end

  -- A one-pixel outline as four fills.  `rectangle("line", ...)` lands on
  -- half-pixel boundaries on this canvas; four fills cannot.
  local function frame(x, y, w, h)
    love.graphics.rectangle("fill", x, y, w, 1)
    love.graphics.rectangle("fill", x, y + h - 1, w, 1)
    love.graphics.rectangle("fill", x, y + 1, 1, h - 2)
    love.graphics.rectangle("fill", x + w - 1, y + 1, 1, h - 2)
  end

  -- A 4x7 solid triangle: the box arrows.  dir 1 points right, -1 left.
  local function triangle(x, y, dir)
    for i = 0, 3 do
      local px = dir > 0 and (x + i) or (x + 3 - i)
      love.graphics.rectangle("fill", px, y + i, 1, 7 - i * 2)
    end
  end

  local function play(game, id)
    if not (game and game.data) then return end
    pcall(function() require("src.core.Sound").play(game.data, id) end)
  end

  local function cry(game, species)
    if not (game and game.data and species) then return end
    pcall(function() require("src.core.Sound").playCry(game.data, species) end)
  end

  local function follower()
    local ok, module = pcall(require, "src.world.PikachuFollower")
    if ok and type(module) == "table" then return module end
    return nil
  end

  local function defOf(game, mon)
    local pokemon = game.data and game.data.pokemon
    return mon and pokemon and pokemon[mon.species] or nil
  end

  local function nameOf(game, mon)
    if not mon then return "" end
    local def = defOf(game, mon)
    return mon.nickname or (def and def.name) or tostring(mon.species)
  end

  local function textOf(game)
    return (game.data and game.data.text) or {}
  end

  -- ------- the screen

  local Screen = {}
  Screen.__index = Screen

  -- A full-screen replacement: nothing under it draws, and the PC's own menu
  -- waits underneath for the B that closes this.
  Screen.isOpaque = true

  function Screen.new(game)
    Boxes.ensure(game.save)
    local self = setmetatable({}, Screen)
    self.game = game
    -- "box" | "party" | "header"
    self.pane = option("startPane", "box") == "party" and "party" or "box"
    -- the pane the header came from, so DOWN goes back where you were
    self.lastPane = self.pane
    self.boxSlot = 1                 -- 1..20, the cell the cursor is on
    self.partySlot = 1               -- 1..6
    self.held = nil                  -- { mon, pane, index, box }
    self.blink = 0
    self.holdDir, self.holdFrames = nil, 0
    -- whether the party changed while this screen was open, which is the
    -- only reason to disturb the follower on the way out
    self.partyTouched = false
    return self
  end

  -- The PC's screens colour as one region (src/ui/ListMenu.lua does the same
  -- with the same palette).  Saying so matters more here than it does for a
  -- menu: this screen is opaque, so with no opinion of its own the topmost
  -- state that HAS one is the overworld underneath, and the box would come
  -- out wearing the map's palette.
  function Screen:sgbPalettes(game)
    local ok, zones = pcall(function()
      return require("src.render.PaletteFX").wholeNamed(game.data, "MEWMON")
    end)
    return ok and zones or nil
  end

  -- ------- the lists

  function Screen:listFor(pane)
    if pane == "party" then
      self.game.save.party = self.game.save.party or {}
      return self.game.save.party
    end
    return Boxes.active(self.game.save)
  end

  function Screen:capacityFor(pane)
    return pane == "party" and Party.MAX or Boxes.CAPACITY
  end

  function Screen:slotIndex(pane)
    return pane == "party" and self.partySlot or self.boxSlot
  end

  -- Where a carried POKeMON came from.  A box origin is remembered by NUMBER,
  -- not by reference, because the header can walk to another box while it is
  -- being carried -- B has to put it back in the box it was picked out of.
  function Screen:originList(held)
    if held.pane == "party" then return self:listFor("party") end
    return Boxes.ensure(self.game.save)[held.box] or self:listFor("box")
  end

  function Screen:monAt(pane)
    return self:listFor(pane)[self:slotIndex(pane)]
  end

  -- ------- talking to the player
  --
  -- The refusals are the game's own extracted lines in the game's own text
  -- box, at the coordinates every other refusal uses.  The PC session runs
  -- silent (BIT_NO_MENU_BUTTON_SOUND), so every box here says so.

  function Screen:say(text)
    self.game.stack:push(TextBox.new(self.game, text, nil, { noSound = true }))
  end

  -- ------- movement

  local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
  end

  -- Crossing between the panes lands where the eye already is: the row's
  -- centre line, resolved into the other pane's slot height.
  function Screen:toParty(row)
    local centre = GRID_Y + row * CELL_H + CELL_H / 2
    self.partySlot = clamp(math.floor((centre - PARTY_Y) / PARTY_H) + 1,
                           1, PARTY_ROWS)
    self.pane = "party"
  end

  function Screen:toBox(slot)
    local centre = PARTY_Y + (slot - 1) * PARTY_H + PARTY_H / 2
    local row = clamp(math.floor((centre - GRID_Y) / CELL_H), 0, ROWS - 1)
    self.boxSlot = row * COLS + 1
    self.pane = "box"
  end

  function Screen:moveBox(dir)
    local col = (self.boxSlot - 1) % COLS
    local row = math.floor((self.boxSlot - 1) / COLS)
    if dir == "left" then
      if col == 0 then self:toParty(row) else self.boxSlot = self.boxSlot - 1 end
    elseif dir == "right" then
      -- the party is off the left edge, so the right edge wraps within the
      -- row rather than stepping to the next box: box changes belong to the
      -- header, where they are visible
      self.boxSlot = col == COLS - 1 and (self.boxSlot - col) or (self.boxSlot + 1)
    elseif dir == "up" then
      if row == 0 then
        self.lastPane = "box"
        self.pane = "header"
      else
        self.boxSlot = self.boxSlot - COLS
      end
    elseif dir == "down" then
      self.boxSlot = row == ROWS - 1 and (col + 1) or (self.boxSlot + COLS)
    end
  end

  function Screen:moveParty(dir)
    if dir == "right" then
      self:toBox(self.partySlot)
    elseif dir == "up" then
      if self.partySlot == 1 then
        self.lastPane = "party"
        self.pane = "header"
      else
        self.partySlot = self.partySlot - 1
      end
    elseif dir == "down" then
      self.partySlot = self.partySlot < PARTY_ROWS and (self.partySlot + 1) or 1
    end
    -- LEFT out of the party is the screen edge and does nothing
  end

  function Screen:changeBox(delta)
    local save = self.game.save
    local count = Boxes.COUNT
    save.currentBox = ((save.currentBox - 1 + delta) % count) + 1
  end

  function Screen:moveHeader(dir)
    if dir == "left" then
      self:changeBox(-1)
    elseif dir == "right" then
      self:changeBox(1)
    elseif dir == "down" then
      self.pane = self.lastPane
    elseif dir == "up" then
      -- UP again wraps past the header to the bottom of the pane it came
      -- from, so the header is a stop on the way round rather than a wall
      if self.lastPane == "party" then
        self.partySlot = PARTY_ROWS
        self.pane = "party"
      else
        self.boxSlot = (ROWS - 1) * COLS + ((self.boxSlot - 1) % COLS) + 1
        self.pane = "box"
      end
    end
  end

  function Screen:move(dir)
    if self.pane == "header" then return self:moveHeader(dir) end
    if self.pane == "party" then return self:moveParty(dir) end
    return self:moveBox(dir)
  end

  -- ------- picking up and putting down

  -- The one deposit the game refuses outright: Yellow's sleeping starter
  -- Pikachu (engine/pokemon/bills_pc.asm's _SleepingPikachuText2 arm).  It is
  -- asked about the mon that is actually crossing party -> box, whichever
  -- half of a swap that is.
  function Screen:refusesDeposit(mon)
    local Follower = follower()
    if not (Follower and mon) then return false end
    local ok, disabled = pcall(Follower.isFollowingDisabled, self.game.overworld)
    if not (ok and disabled) then return false end
    local okStarter, starter =
      pcall(Follower.isStarterPikachu, self.game.save, mon)
    if not (okStarter and starter) then return false end
    self:say(textOf(self.game)._SleepingPikachuText2
      or Strings("There isn't any\nresponse..."))
    return true
  end

  -- What a move owes the engine at each end.  Both are the vanilla PC's own
  -- tail work: add_mon.asm's _MoveMon recomputes a box mon's stats on its way
  -- into the party (without which an imported .sav can reach the party menu
  -- with mon.stats nil), and bills_pc.asm bumps PIKAHAPPY_DEPOSITED going the
  -- other way.
  function Screen:transfer(mon, fromPane, toPane)
    if fromPane == toPane then return end
    -- one of the two panes is the party, so any crossing is a party change
    self.partyTouched = true
    if toPane == "party" then
      Stats.ensure(defOf(self.game, mon), mon)
    else
      local Follower = follower()
      if Follower and Follower.modifyHappiness then
        pcall(Follower.modifyHappiness, self.game.save, "DEPOSITED", mon)
      end
    end
  end

  function Screen:grab()
    local pane = self.pane
    local list = self:listFor(pane)
    local index = self:slotIndex(pane)
    local mon = list[index]
    if not mon then return end
    -- The party may not be emptied, exactly as the vanilla PC refuses the
    -- last mon.  Refusing the PICK-UP rather than the drop is what makes the
    -- rule impossible to walk around: with one POKeMON there is nothing to
    -- reorder either.
    if pane == "party" and #list <= 1 then
      self:say(textOf(self.game)._CantDepositLastMonText
        or Strings("You can't deposit\nthe last POKéMON!"))
      return
    end
    table.remove(list, index)
    if pane == "party" then self.partyTouched = true end
    self.held = {
      mon = mon,
      pane = pane,
      index = index,
      box = pane == "box" and self.game.save.currentBox or nil,
    }
  end

  function Screen:place()
    local held = self.held
    if not held then return end
    local pane = self.pane
    local list = self:listFor(pane)
    local index = self:slotIndex(pane)
    local target = list[index]

    -- Ask before anything moves, so a refusal leaves the POKeMON in hand
    -- rather than half-placed.  A swap is a deposit and a withdrawal at once,
    -- and only one of the two halves can be crossing party -> box.
    if pane == "box" and held.pane == "party" then
      if self:refusesDeposit(held.mon) then return end
    elseif target and pane == "party" and held.pane == "box" then
      if self:refusesDeposit(target) then return end
    end

    if target then
      -- SWAP: the carried POKeMON takes the slot, the one that was there goes
      -- back to where the carried one came from.  No count changes, so no
      -- capacity question -- which is why a full party and a full box can
      -- still trade.
      local origin = self:originList(held)
      list[index] = held.mon
      table.insert(origin, math.min(held.index, #origin + 1), target)
      self:transfer(held.mon, held.pane, pane)
      self:transfer(target, pane, held.pane)
    else
      -- Defensive, and deliberately so.  The grid has exactly as many cells
      -- as the list has room (twenty, and six), so a list at capacity has no
      -- empty cell left to aim at and every drop into a full one is the swap
      -- above -- this arm cannot be reached in ordinary play.  It stands for
      -- the save that arrives over capacity anyway (an import, another mod's
      -- deposit) so that the answer there is the game's own refusal rather
      -- than a twenty-first POKeMON the box cannot show.
      if #list >= self:capacityFor(pane) then
        local t = textOf(self.game)
        self:say(pane == "party"
          and (t._CantTakeMonText
            or Strings("You can't take\nany more POKéMON.\fDeposit POKéMON\nfirst."))
          or (t._BoxFullText
            or Strings("Oops! This Box is\nfull of POKéMON.")))
        return
      end
      -- a box is a compact array, so an empty cell means "the end of the
      -- list"; follow the POKeMON to where it really landed
      list[#list + 1] = held.mon
      if pane == "party" then
        self.partySlot = #list
      else
        self.boxSlot = #list
      end
      self:transfer(held.mon, held.pane, pane)
    end

    self.held = nil
    if option("placeCry", true) then cry(self.game, held.mon.species) end
  end

  -- B with something in hand: back where it came from, in the slot it came
  -- from, in the box it came from.  There is no cell on this screen where
  -- the way out disappears, and no way to leave holding a POKeMON.
  function Screen:returnHeld()
    local held = self.held
    if not held then return end
    self.held = nil
    local origin = self:originList(held)
    table.insert(origin, math.min(held.index, #origin + 1), held.mon)
    if held.pane == "party" then self.partyTouched = true end
  end

  -- ------- the submenu, the box list, and RELEASE

  function Screen:openSummary(mon)
    -- status_screen.asm derives a box mon's stats on the way in; do it here
    -- so the summary is handed a mon it can draw either way
    Stats.ensure(defOf(self.game, mon), mon)
    Screens.push(self.game, "SummaryMenu", mon)
  end

  -- bills_pc.asm BillsPCRelease: confirm, then "Bye [MON]!".  Offered in the
  -- box pane only, which is where the vanilla PC offers it -- RELEASE
  -- POKeMON never listed the party.
  function Screen:release()
    local game = self.game
    local box = Boxes.active(game.save)
    local index = self.boxSlot
    local mon = box[index]
    if not mon then return end
    local t = textOf(game)
    local name = nameOf(game, mon)

    local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
    local okYellow, isYellow = false, false
    if okVersion then okYellow, isYellow = pcall(GameVersion.isYellow) end
    local player = game.save.player
    if okYellow and isYellow and player and mon.species == "PIKACHU"
        and mon.otId == player.id and mon.ot == player.name then
      cry(game, mon.species)
      self:say(((t._PikachuUnhappyText
        or Strings("%s looks\nunhappy about it!", name))
        :gsub("{RAM:wNameBuffer}", name)))
      return
    end

    game.stringBuffer = name
    game.stack:push(TextBox.new(game,
      (t._OnceReleasedText
        or Strings("Once released,\n%s is\ngone forever. OK?", name))
        :gsub("{RAM:wStringBuffer}", name), nil, {
      defaultNo = true, noSound = true,
      choice = function(yes)
        if not yes then return end
        -- re-read: the list is live and the confirm ran a frame later
        local list = Boxes.active(game.save)
        if list[index] ~= mon then return end
        table.remove(list, index)
        cry(game, mon.species)
        game.stack:push(TextBox.new(game,
          ((t._MonWasReleasedText
            or Strings("%s was\nreleased outside.\fBye %s!", name, name))
            :gsub("{RAM:wStringBuffer}", name)), nil, { noSound = true }))
      end,
    }))
  end

  -- START over a POKeMON.  The vanilla PC's own per-mon rows
  -- (bills_pc.asm DisplayDepositWithdrawMenu) minus the verbs the cursor has
  -- taken over: WITHDRAW and DEPOSIT are what A already does.
  function Screen:openActions()
    if self.held or self.pane == "header" then return end
    local pane = self.pane
    local mon = self:monAt(pane)
    if not mon then return end
    local items = {
      { label = Strings("STATS"), keepOpen = true,
        onSelect = function() self:openSummary(mon) end },
    }
    if pane == "box" then
      items[#items + 1] = { label = Strings("RELEASE"),
        onSelect = function() self:release() end }
    end
    items[#items + 1] = { label = Strings("CANCEL") }
    self.game.stack:push(Menu.new(self.game, items,
      { tx = 9, ty = 10, tw = 11, th = #items * 2 + 2, noSound = true }))
  end

  -- A on the header.  The vanilla CHANGE BOX list, without its save prompt:
  -- this engine keeps all twelve boxes in one save file (src/pokemon/
  -- Boxes.lua), so the "data will be saved" step the cart needed to swap a
  -- SRAM bank has nothing left to do.
  function Screen:openBoxList()
    local game = self.game
    local boxes = Boxes.ensure(game.save)
    local items = {}
    for i = 1, Boxes.COUNT do
      items[#items + 1] = {
        label = Strings("%sBOX %2d", i == game.save.currentBox and "*" or " ", i),
        right = ("%d/%d"):format(#boxes[i], Boxes.CAPACITY),
        value = i,
      }
    end
    game.stack:push(ListMenu.new(game, Strings("CHANGE BOX"), items, {
      noSound = true,
      kind = "bills_box_change",
      onChoose = function(item, list)
        game.save.currentBox = item.value
        list:close()
      end,
    }))
  end

  -- ------- input

  local DIRECTIONS = { "up", "down", "left", "right" }

  function Screen:direction()
    local input = self.game.input
    for _, dir in ipairs(DIRECTIONS) do
      if input:wasPressed(dir) then
        self.holdDir, self.holdFrames = dir, 0
        return dir
      end
    end
    if not option("holdMove", true) then return nil end
    local dir = self.holdDir
    if not dir then return nil end
    -- the headless harness drives wasPressed only; a missing isDown simply
    -- means no repeat, never an error
    if type(input.isDown) ~= "function" or not input:isDown(dir) then
      self.holdDir, self.holdFrames = nil, 0
      return nil
    end
    self.holdFrames = self.holdFrames + 1
    local after = self.holdFrames - REPEAT_DELAY
    if after >= 0 and after % REPEAT_RATE == 0 then return dir end
    return nil
  end

  function Screen:close()
    self.game.stack:pop()
  end

  -- Buttons are read BEFORE the held direction, not after.  A repeat tick and
  -- a real button press can land on the same step, and the direction is the
  -- one of the two that can be asked for again a frame later.
  function Screen:update()
    self.blink = (self.blink + 1) % (ANIM_STEPS * 2)
    local input = self.game.input

    if input:wasPressed("a") then
      if self.pane == "header" then
        self:openBoxList()
      elseif self.held then
        self:place()
      else
        self:grab()
      end
    elseif input:wasPressed("b") then
      if self.held then
        self:returnHeld()
      else
        play(self.game, "Turn_Off_PC")
        self:close()
      end
    elseif input:wasPressed("start") then
      self:openActions()
    elseif input:wasPressed("select") then
      -- a shortcut across the middle of the screen, for the deposit that
      -- would otherwise walk the cursor back to column one every time.  From
      -- the header it crosses to whichever pane the header was not reached
      -- from, so SELECT always changes which side you are on.
      local target = self.pane == "party" and "box" or "party"
      if self.pane == "header" then
        target = self.lastPane == "party" and "box" or "party"
      end
      self.pane, self.lastPane = target, target
    else
      local dir = self:direction()
      if dir then self:move(dir) end
    end
  end

  -- StateStack calls this on pop and only on pop -- a screen pushed ON TOP
  -- (the summary) does not fire it -- so it is exactly "the player is done".
  function Screen:exit()
    -- belt and braces: B already refuses to leave with a POKeMON in hand,
    -- but a stack teardown from anywhere else must not drop one either
    self:returnHeld()
    if not self.partyTouched then return end
    -- The follower is spawned once and then left alone (it is rebuilt on
    -- PikachuFollower.onMapEntered), so a party changed from inside a menu
    -- leaves the old POKeMON walking behind you until you change maps.
    -- viaMapLoad = false is the mid-map respawn the engine already uses for
    -- a bike dismount: behind the player, not under him.
    local game = self.game
    local ow = game.overworld
    if not ow then return end
    local Follower = follower()
    if Follower and type(Follower.onMapEntered) == "function" then
      pcall(Follower.onMapEntered, game, ow, nil, false)
    end
    -- Wilds of Kanto keeps its own trailing entities rather than riding
    -- PikachuFollower, so the engine call above rebuilds something that was
    -- never on screen.  Reached through mod.find, not a manifest dependency:
    -- with that mod absent this is one nil check.
    local okHandle, handle = pcall(mod.find, "overworld_wild_spawns")
    if not okHandle or not handle or not handle.exports then return end
    if type(handle.exports.syncAll) == "function" then
      pcall(handle.exports.syncAll, game, ow)
    end
  end

  -- ------- drawing

  function Screen:animAlt()
    return math.floor(self.blink / ANIM_STEPS) % 2 == 1
  end

  function Screen:drawIcon(mon, x, y, selected)
    if not mon then return end
    love.graphics.setColor(1, 1, 1, 1)
    pcall(PartyMenu.drawIcon, self.game, mon, x, y, false, 0,
          selected and self:animAlt() or false)
  end

  function Screen:drawHeader()
    local game = self.game
    ink(BLACK)
    Font.drawBox(0, 0, 20, HEADER_TH)
    local focused = self.pane == "header"
    ink(focused and BLACK or GREY)
    triangle(8, 8, -1)
    triangle(148, 8, 1)
    ink(BLACK)
    if focused then Font.drawCode(Theme.cursor, 16, 8) end
    Font.draw(Strings("BOX %d", game.save.currentBox), 24, 8)
    local count = ("%d/%d"):format(#Boxes.active(game.save), Boxes.CAPACITY)
    Font.draw(count, 144 - Font.width(count), 8)
  end

  function Screen:drawParty()
    local party = self:listFor("party")
    for i = 1, PARTY_ROWS do
      local y = PARTY_Y + (i - 1) * PARTY_H
      local selected = self.pane == "party" and self.partySlot == i
      local carried = selected and self.held ~= nil
      -- A carried POKeMON rides the cursor and covers the slot it is over,
      -- rather than being drawn on top of whatever lives there: an icon
      -- lifted a few pixels over another icon is two overlapping blobs, and
      -- which one you are holding is the thing that has to stay readable.
      if carried then
        self:drawIcon(self.held.mon, PARTY_X, y - PARTY_LIFT, true)
      else
        self:drawIcon(party[i], PARTY_X, y, selected)
      end
      if selected then
        -- the party's own cursor, in the column the party menu keeps it in
        -- (PartyMenuInit's wTopMenuItemX = 0)
        ink(BLACK)
        Font.drawCode(Theme.cursor, 0, y + 4)
      end
    end
    ink(GREY)
    love.graphics.rectangle("fill", RULE_X, PARTY_Y, 1, PARTY_ROWS * PARTY_H)
  end

  function Screen:drawGrid()
    local box = self:listFor("box")
    for slot = 1, COLS * ROWS do
      local col = (slot - 1) % COLS
      local row = math.floor((slot - 1) / COLS)
      local x = GRID_X + col * CELL_W
      local y = GRID_Y + row * CELL_H
      local selected = self.pane == "box" and self.boxSlot == slot
      local carried = selected and self.held ~= nil
      -- every cell is drawn, empty or not: twenty visible slots is what
      -- makes this a box rather than a list with pictures
      ink(GREY)
      frame(x, y, CELL_W, CELL_H)
      if carried then
        self:drawIcon(self.held.mon, x + ICON_DX, y + ICON_DY - LIFT, true)
      else
        self:drawIcon(box[slot], x + ICON_DX, y + ICON_DY, selected)
      end
      if selected then
        ink(BLACK)
        frame(x, y, CELL_W, CELL_H)
      end
    end
  end

  -- One line, naming what the cursor is on.  The strings are the game's own:
  -- "Move to where?" is the party menu's swap prompt and "Choose a POKeMON."
  -- its resting one.
  function Screen:drawInfo()
    local game = self.game
    ink(BLACK)
    Font.drawBox(0, INFO_TY, 20, 3)
    ink(BLACK)
    if self.held then
      Font.draw(Strings("Move to where?"), TEXT_LEFT, INFO_TEXT_Y)
      return
    end
    if self.pane == "header" then
      Font.draw(Strings("CHANGE BOX"), TEXT_LEFT, INFO_TEXT_Y)
      return
    end
    local mon = self:monAt(self.pane)
    if not mon then
      Font.draw(textOf(game)._PartyMenuNormalText
        or Strings("Choose a POKéMON."), TEXT_LEFT, INFO_TEXT_Y)
      return
    end
    Font.draw(nameOf(game, mon), TEXT_LEFT, INFO_TEXT_Y)
    local level = Strings(":L%d", mon.level or 0)
    Font.draw(level, TEXT_RIGHT - Font.width(level), INFO_TEXT_Y)
  end

  function Screen:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    self:drawHeader()
    self:drawParty()
    self:drawGrid()
    self:drawInfo()
    love.graphics.setColor(1, 1, 1, 1)
  end

  return { new = Screen.new }
end
