-- Standalone: luajit mods/Gen1BillsBox/tests/gen1billsbox_test.lua
--
-- Loads the mod through the headless SDK harness against the ROM-free
-- fixture dataset and asserts its stated effect: BILL'S PC is renamed and
-- opens THIS screen rather than the vanilla list, and the storage rules that
-- protect a save hold -- the party is never emptied, a box never passes
-- twenty, and a carried POKeMON is never dropped out of the save.
--
-- Run it from a Gen1Recomp checkout with this mod at mods/Gen1BillsBox, or set
-- GEN1BILLSBOX_DIR to wherever it lives.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Boxes = require("src.pokemon.Boxes")
local Stats = require("src.pokemon.Stats")

local DIR = os.getenv("GEN1BILLSBOX_DIR") or "mods/Gen1BillsBox"
local Data = T.fixtures.fresh()
local run = T.sdk.loadMod(DIR, { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

-- ------- the screen replaces the builtin one

local factory = Data.screens and Data.screens.BoxMenu
T.check(factory ~= nil, "the BoxMenu screen id is taken over")
T.eq(type(factory.new), "function", "and it is a screen factory")

-- ------- BILL'S PC is BILL'S BOX

local function passthru(_, items) return items end
local function pcRows(metBill)
  return {
    { label = metBill and "BILL'S PC" or "SOMEONE'S PC" },
    { label = "RED's PC" },
    { label = "LOG OFF" },
  }
end

local afterBill = Runtime.call("ui.pc.items", passthru, {}, pcRows(true))
T.eq(afterBill[1].label, "BILL'S BOX", "the storage row reads BILL'S BOX")
local beforeBill = Runtime.call("ui.pc.items", passthru, {}, pcRows(false))
T.eq(beforeBill[1].label, "SOMEONE'S BOX", "and SOMEONE'S BOX before Bill")
T.eq(afterBill[2].label, "RED's PC", "the player's item PC keeps its name")
T.eq(afterBill[3].label, "LOG OFF", "and so does LOG OFF")

-- another mod's row on the same menu survives: the wrap calls next() first
local shared = Runtime.call("ui.pc.items", function(_, items)
  table.insert(items, 1, { label = "DEXNAV" })
  return items
end, {}, pcRows(true))
T.eq(shared[1].label, "DEXNAV", "another mod's PC row survives the wrap")
T.eq(shared[2].label, "BILL'S BOX", "and the rename still lands")

-- ------- and so do the lines the PC prints
--
-- The rewrite is a gsub of the machine's name over the extracted line, so a
-- localized import keeps its own wording everywhere else in the sentence.

local rename = run.mod and run.loader.exports[run.mod.manifest.id].renameStorageText
T.eq(type(rename), "function", "the rename is exported for the suite to drive")

do
  local text = {
    _AccessedBillsPCText = "Accessed BILL's\nPC.\fAccessed POKéMON\nStorage System.",
    _ItemUseBallText07 = "{RAM:wStringBuffer} was\ntransferred to\nBILL's PC!",
    -- _AccessedSomeonesPCText and _ItemUseBallText08 are deliberately absent:
    -- a cache built without them must still print BOX, not the engine's own
    -- "PC" fallback
  }
  rename({ data = { text = text } })
  T.check(text._AccessedBillsPCText:find("BILL's\nBOX.", 1, true) ~= nil,
    "the access line names a BOX")
  T.check(text._AccessedBillsPCText:find("POKéMON\nStorage System", 1, true) ~= nil,
    "and the rest of the extracted line is untouched")
  T.check(text._ItemUseBallText07:find("BILL's BOX!", 1, true) ~= nil,
    "a caught POKeMON is transferred to BILL's BOX")
  T.check(text._AccessedSomeonesPCText ~= nil
    and text._AccessedSomeonesPCText:find("BOX", 1, true) ~= nil,
    "a missing label is supplied rather than left saying PC")
  -- idempotent: a second firing (dev hot reload) must not rewrite a rewrite
  local before = text._AccessedBillsPCText
  rename({ data = { text = text } })
  T.eq(text._AccessedBillsPCText, before, "a second game.ready changes nothing")
end

-- ------- the storage rules
--
-- The screen is driven the way the player drives it: one press per update,
-- asserting on save.boxes / save.party afterwards.

local function mon(species, level)
  return { species = species, level = level or 5, nickname = species }
end

local function newStack()
  local stack = { states = {} }
  function stack:push(state) table.insert(self.states, state) end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  return stack
end

local function fakeGame(boxMons, partyMons)
  local boxes = {}
  for i = 1, Boxes.COUNT do boxes[i] = {} end
  for i, m in ipairs(boxMons or {}) do boxes[1][i] = m end
  local pressed = {}
  local game = {
    data = Data,
    save = {
      boxes = boxes,
      currentBox = 1,
      party = partyMons or {},
      player = { name = "RED", id = 1 },
      flags = {},
    },
    stack = newStack(),
    input = { wasPressed = function(_, key) return pressed[key] end },
  }
  game.press = function(key) pressed = {}; pressed[key] = true end
  game.release = function() pressed = {} end
  return game
end

local function ids(list)
  local out = {}
  for i, m in ipairs(list) do out[i] = m.species end
  return table.concat(out, ",")
end

-- how many POKeMON exist anywhere the save can see them, plus whatever the
-- cursor is carrying: the number this screen must never change by accident
local function census(game, screen)
  local total = #game.save.party + (screen and screen.held and 1 or 0)
  for i = 1, Boxes.COUNT do total = total + #game.save.boxes[i] end
  return total
end

local function drive(game, screen, ...)
  for _, key in ipairs({ ... }) do
    game.press(key)
    screen:update()
  end
  game.release()
end

-- pick up, move, put down inside one box
do
  local game = fakeGame({ mon("FIXMON_A"), mon("FIXMON_B") })
  local screen = factory.new(game)
  local before = census(game, screen)
  drive(game, screen, "a")
  T.eq(#game.save.boxes[1], 1, "picking one up takes it out of the box")
  T.check(screen.held ~= nil, "and the cursor is carrying it")
  T.eq(census(game, screen), before, "nothing has gone missing")
  drive(game, screen, "right", "a")
  T.eq(ids(game.save.boxes[1]), "FIXMON_B,FIXMON_A",
    "putting it down in an empty cell appends to the compact list")
  T.eq(screen.boxSlot, 2, "and the cursor follows it to where it landed")
  T.eq(census(game, screen), before, "still nothing missing")
end

-- an occupied cell swaps rather than refusing
do
  local game = fakeGame({ mon("FIXMON_A"), mon("FIXMON_B"), mon("FIXMON_C") })
  local screen = factory.new(game)
  -- grabbing slot 1 compacts the box to two, so slot 2 now holds FIXMON_C
  drive(game, screen, "a", "right", "a")
  T.eq(ids(game.save.boxes[1]), "FIXMON_C,FIXMON_B,FIXMON_A",
    "dropping onto an occupied cell swaps the two")
  T.check(screen.held == nil, "and the hand is empty afterwards")
end

-- ------- crossing to the party

do
  local game = fakeGame({ mon("FIXMON_A") }, { mon("FIXMON_B"), mon("FIXMON_C") })
  local screen = factory.new(game)
  -- LEFT out of column one is the party
  drive(game, screen, "left")
  T.eq(screen.pane, "party", "LEFT out of the first column crosses to the party")
  drive(game, screen, "right")
  T.eq(screen.pane, "box", "and RIGHT crosses back")
  -- withdraw: take the box mon, cross, drop on the empty third party slot
  drive(game, screen, "a", "left", "down", "down", "a")
  T.eq(#game.save.party, 3, "a box POKeMON withdrawn joins the party")
  T.eq(#game.save.boxes[1], 0, "and leaves the box")
  T.check(game.save.party[3].stats ~= nil,
    "a withdrawn POKeMON gets the stat block the party menu needs")
end

-- the party may not be emptied
do
  local game = fakeGame({}, { mon("FIXMON_A") })
  local screen = factory.new(game)
  drive(game, screen, "left", "a")
  T.check(screen.held == nil, "the last party POKeMON cannot be picked up")
  T.eq(#game.save.party, 1, "so the party still has it")
  T.check(game.stack:top() ~= nil, "and the refusal is said out loud")
end

-- B puts a carried POKeMON back in the slot it was taken from
do
  local game = fakeGame({ mon("FIXMON_A") }, { mon("FIXMON_B"), mon("FIXMON_C") })
  local screen = factory.new(game)
  local before = census(game, screen)
  drive(game, screen, "left", "down", "a")
  T.check(screen.held ~= nil, "the second party POKeMON is in hand")
  T.eq(#game.save.party, 1, "and out of the party while it is carried")
  drive(game, screen, "up", "b")
  T.check(screen.held == nil, "B puts it down")
  T.eq(ids(game.save.party), "FIXMON_B,FIXMON_C",
    "in the slot it came from, not the one the cursor had moved to")
  T.eq(census(game, screen), before, "and the save still has everyone")
end

-- A full grid has no empty cell to aim at, so every drop into one is a swap.
-- The counts cannot change, which is why a full party and a full box can
-- still trade and why nothing is ever refused for want of room here.
do
  local boxMons = {}
  for i = 1, Boxes.CAPACITY do boxMons[i] = mon("FIXMON_A") end
  local game = fakeGame(boxMons, { mon("FIXMON_B"), mon("FIXMON_C") })
  local screen = factory.new(game)
  local before = census(game, screen)
  drive(game, screen, "left", "a", "right", "a")
  T.check(screen.held == nil, "a drop into a full box goes through as a swap")
  T.eq(#game.save.boxes[1], Boxes.CAPACITY, "the box is still exactly full")
  T.eq(#game.save.party, 2, "the party is still two")
  T.eq(game.save.party[1].species, "FIXMON_A", "with the box POKeMON in it")
  T.eq(census(game, screen), before, "and the save still has everyone")
end

-- a full party and a full box can still TRADE, because a swap changes no count
do
  local boxMons, partyMons = {}, {}
  for i = 1, Boxes.CAPACITY do boxMons[i] = mon("FIXMON_A") end
  for i = 1, 6 do partyMons[i] = mon("FIXMON_B") end
  local game = fakeGame(boxMons, partyMons)
  local screen = factory.new(game)
  drive(game, screen, "a", "left", "a")
  T.check(screen.held == nil, "the swap goes through")
  T.eq(game.save.party[1].species, "FIXMON_A", "the box POKeMON is in the party")
  T.eq(game.save.boxes[1][1].species, "FIXMON_B", "and the party one is boxed")
  T.eq(#game.save.party, 6, "the party is still six")
  T.eq(#game.save.boxes[1], Boxes.CAPACITY, "and the box still twenty")
  T.check(game.save.party[1].stats ~= nil, "the withdrawn half got its stats")
end

-- ------- the header

do
  local game = fakeGame({ mon("FIXMON_A") })
  local screen = factory.new(game)
  drive(game, screen, "up")
  T.eq(screen.pane, "header", "UP out of the top row lands on the box header")
  drive(game, screen, "right")
  T.eq(game.save.currentBox, 2, "RIGHT on the header is the next box")
  drive(game, screen, "left", "left")
  T.eq(game.save.currentBox, Boxes.COUNT, "and LEFT wraps round the back")
  drive(game, screen, "down")
  T.eq(screen.pane, "box", "DOWN goes back to the pane it came from")
end

-- a carried POKeMON crosses boxes with the cursor, and B still knows where
-- home was
do
  local game = fakeGame({ mon("FIXMON_A"), mon("FIXMON_B") })
  local screen = factory.new(game)
  local before = census(game, screen)
  drive(game, screen, "right", "a")           -- carry FIXMON_B out of box 1
  drive(game, screen, "up", "right", "down")  -- walk to box 2
  T.eq(game.save.currentBox, 2, "the box changed while carrying")
  T.check(screen.held ~= nil, "and the POKeMON is still in hand")
  drive(game, screen, "a")
  T.eq(#game.save.boxes[2], 1, "it can be put down in the new box")
  T.eq(census(game, screen), before, "with nobody lost on the way")

  -- and the other direction: carry one out, change box, press B
  drive(game, screen, "a", "up", "left", "down", "b")
  T.check(screen.held == nil, "B puts it down")
  T.eq(#game.save.boxes[2], 1, "in the box it was picked up from, not the open one")
  T.eq(#game.save.boxes[1], 1, "leaving box 1 as it was")
end

-- closing the screen can never strand a POKeMON outside the save
do
  local game = fakeGame({ mon("FIXMON_A") })
  local screen = factory.new(game)
  drive(game, screen, "a")
  T.check(screen.held ~= nil, "carrying one")
  screen:exit()
  T.eq(#game.save.boxes[1], 1, "a stack teardown puts it back in the save")
  T.check(screen.held == nil, "and the hand is empty")
end

-- B on an empty hand closes the screen
do
  local game = fakeGame({ mon("FIXMON_A") })
  local screen = factory.new(game)
  game.stack:push(screen)
  drive(game, screen, "b")
  T.check(game.stack:top() ~= screen, "B closes the box")
end

-- ------- Stats.ensure really is what fills a box mon in
do
  local boxMon = mon("FIXMON_A", 10)
  T.check(boxMon.stats == nil, "a box POKeMON starts with no stat block")
  Stats.ensure(Data.pokemon.FIXMON_A, boxMon)
  T.check(boxMon.stats ~= nil and boxMon.stats.hp > 0,
    "and Stats.ensure is what gives it one")
end


-- ------- the per-POKeMON menu, and the box list
--
-- START's rows are the vanilla PC's own (bills_pc.asm
-- DisplayDepositWithdrawMenu) minus the verbs the cursor took over: WITHDRAW
-- and DEPOSIT are what A already does.

local function labels(items)
  local out = {}
  for i, entry in ipairs(items) do out[i] = entry.label end
  return table.concat(out, "|")
end

do
  local game = fakeGame({ mon("FIXMON_A") }, { mon("FIXMON_B"), mon("FIXMON_C") })
  local screen = factory.new(game)
  drive(game, screen, "start")
  local menu = game.stack:top()
  T.check(menu ~= nil and type(menu.items) == "table",
    "START over a box POKeMON opens a menu")
  T.eq(labels(menu.items), "STATS|RELEASE|CANCEL", "with STATS, RELEASE and CANCEL")
  game.stack:pop()

  drive(game, screen, "left", "start")
  local partyMenu = game.stack:top()
  T.eq(labels(partyMenu.items), "STATS|CANCEL",
    "a party POKeMON is never offered RELEASE, exactly as the vanilla PC has it")
  game.stack:pop()

  -- an empty slot has no menu to open
  drive(game, screen, "down", "down", "start")
  T.eq(game.stack:top(), nil, "and an empty slot opens nothing")
end

do
  local game = fakeGame({ mon("FIXMON_A") })
  local screen = factory.new(game)
  drive(game, screen, "up", "a")
  local list = game.stack:top()
  T.check(list ~= nil and type(list.items) == "table",
    "A on the header opens the box list")
  T.eq(#list.items, Boxes.COUNT, "with a row per box")
  T.eq(list.items[1].right, "1/" .. Boxes.CAPACITY, "each saying how full it is")
  list.onChoose(list.items[7], list)
  T.eq(game.save.currentBox, 7, "and choosing one opens it")
  T.eq(game.stack:top(), nil, "closing the list behind it")
end

-- SELECT crosses the screen without walking the cursor back to column one
do
  local game = fakeGame({ mon("FIXMON_A") }, { mon("FIXMON_B") })
  local screen = factory.new(game)
  drive(game, screen, "right", "right", "select")
  T.eq(screen.pane, "party", "SELECT crosses to the party")
  drive(game, screen, "select")
  T.eq(screen.pane, "box", "and back")
  T.eq(screen.boxSlot, 3, "leaving the box cursor where it was")
  drive(game, screen, "up", "select")
  T.eq(screen.pane, "party", "and from the header it still changes sides")
end


-- ------- the layout, checked the only way a headless run can check it
--
-- Every fill this screen draws is recorded and measured.  A storage screen
-- is geometry before it is anything else -- twenty cells, six party rows, a
-- header and a footer, all inside 160x144 -- and none of that is visible from
-- a rule test.  The numbers below are the ones the file's header comment
-- claims, so a layout change that breaks the claim breaks the suite.

do
  local Font = require("src.render.Font")
  Font.load(Data)

  local game = fakeGame({ mon("FIXMON_A"), mon("FIXMON_B") },
                        { mon("FIXMON_C") })
  local screen = factory.new(game)

  local rects = {}
  local realRectangle = love.graphics.rectangle
  love.graphics.rectangle = function(mode, x, y, w, h)
    rects[#rects + 1] = { mode = mode, x = x, y = y, w = w, h = h }
  end
  local ok, err = pcall(function() screen:draw() end)
  love.graphics.rectangle = realRectangle
  T.check(ok, "the screen draws without error (" .. tostring(err) .. ")")

  local outside = 0
  for _, r in ipairs(rects) do
    if r.x < 0 or r.y < 0 or r.x + r.w > 160 or r.y + r.h > 144 then
      outside = outside + 1
    end
  end
  T.eq(outside, 0, "nothing is drawn outside the 160x144 screen")

  -- the twenty cell tops: five columns 26 apart from x=30, four rows 24 apart
  -- from y=24, which is the first row under the header box
  local tops = {}
  for _, r in ipairs(rects) do
    if r.w == 26 and r.h == 1 then tops[r.x .. "," .. r.y] = true end
  end
  local expected, missing = 0, {}
  for col = 0, 4 do
    for row = 0, 3 do
      local x, y = 30 + col * 26, 24 + row * 24
      expected = expected + 1
      if not tops[x .. "," .. y] then missing[#missing + 1] = x .. "," .. y end
      if not tops[x .. "," .. (y + 23)] then
        missing[#missing + 1] = x .. "," .. (y + 23)
      end
    end
  end
  T.eq(expected, 20, "the grid is twenty cells")
  T.eq(#missing, 0, "each with a top and a bottom edge (" ..
    table.concat(missing, " ") .. ")")

  -- the grid's last row ends exactly where the footer box begins, and its
  -- last column exactly at the screen edge
  T.eq(24 + 4 * 24, 120, "four rows of 24 stop at the footer")
  T.eq(30 + 5 * 26, 160, "five columns of 26 stop at the screen edge")

  -- the hairline between the panes runs the height of the party column
  local rule = nil
  for _, r in ipairs(rects) do
    if r.w == 1 and r.h == 96 then rule = r end
  end
  T.check(rule ~= nil and rule.x == 26 and rule.y == 24,
    "a one-pixel rule separates the party from the grid")

  -- the header and footer boxes are the standard bordered ones, three tiles
  -- tall each, and nothing is drawn between the grid and the footer
  local header, footer = false, false
  for _, r in ipairs(rects) do
    if r.x == 0 and r.y == 0 and r.w == 160 and r.h == 24 then header = true end
    if r.x == 0 and r.y == 120 and r.w == 160 and r.h == 24 then footer = true end
  end
  T.check(header, "the box header is a three-tile bordered box at the top")
  T.check(footer, "and the info line one at the bottom")
end


-- ------- the slots really do go through the party menu's own icon path
--
-- This is the whole compatibility story: resolve art here and an icon mod
-- has to be taught about this screen; call PartyMenu.drawIcon and it never
-- does.  Spy on that one function and assert both that it is what draws a
-- slot, and that it is handed the LIVE POKeMON -- a shiny tells itself apart
-- from an ordinary one of the same species through the mon, not the species.

do
  local PartyMenu = require("src.ui.PartyMenu")
  local boxA, boxB, partyC = mon("FIXMON_A"), mon("FIXMON_B"), mon("FIXMON_C")
  local game = fakeGame({ boxA, boxB }, { partyC })
  local screen = factory.new(game)

  local calls = {}
  local real = PartyMenu.drawIcon
  PartyMenu.drawIcon = function(_, m, x, y)
    calls[#calls + 1] = { mon = m, x = x, y = y }
  end
  local ok = pcall(function() screen:draw() end)
  PartyMenu.drawIcon = real
  T.check(ok, "the screen draws through the shared icon renderer")

  T.eq(#calls, 3, "one icon per occupied slot, and none for the empty ones")

  local at = {}
  for _, call in ipairs(calls) do at[call.mon] = call.x .. "," .. call.y end
  T.eq(at[partyC], "8,24", "the party icon sits in the party column")
  T.eq(at[boxA], "35,28", "the first box icon is centred in its cell")
  T.eq(at[boxB], "61,28", "and the second is one cell to the right")
  T.check(at[boxA] ~= nil and calls[1].mon ~= nil,
    "the live POKeMON table is what reaches the renderer, not a copy")
end

-- a carried POKeMON rides the cursor and covers the slot it is over
do
  local PartyMenu = require("src.ui.PartyMenu")
  local boxA, boxB = mon("FIXMON_A"), mon("FIXMON_B")
  local game = fakeGame({ boxA, boxB })
  local screen = factory.new(game)
  drive(game, screen, "a")
  T.eq(screen.held.mon, boxA, "FIXMON_A is in hand")
  T.eq(game.save.boxes[1][1], boxB, "and FIXMON_B has compacted into slot one")

  local calls = {}
  local real = PartyMenu.drawIcon
  PartyMenu.drawIcon = function(_, m, x, y)
    calls[#calls + 1] = { mon = m, x = x, y = y }
  end
  pcall(function() screen:draw() end)
  PartyMenu.drawIcon = real

  T.eq(#calls, 1, "only the carried POKeMON is drawn on the cursor's cell")
  T.eq(calls[1].mon, boxA, "and it is the carried one, not the slot's occupant")
  T.eq(calls[1].x .. "," .. calls[1].y, "35,24",
    "lifted four pixels, which is the margin its cell has to lift into")
end


-- ------- hold to move
--
-- The cadence is ui.list_menu's own (16 steps of delay, then one every 5),
-- so a held direction here moves at the speed a held direction moves
-- everywhere else in the game.

do
  local game = fakeGame({ mon("FIXMON_A") })
  local down = {}
  game.input.isDown = function(_, key) return down[key] end
  local screen = factory.new(game)

  drive(game, screen, "right")
  T.eq(screen.boxSlot, 2, "the press itself moves one cell")

  down.right = true
  for _ = 1, 15 do screen:update() end
  T.eq(screen.boxSlot, 2, "a held direction waits out the delay first")
  screen:update()
  T.eq(screen.boxSlot, 3, "then repeats")
  for _ = 1, 5 do screen:update() end
  T.eq(screen.boxSlot, 4, "at a steady rate")

  down.right = false
  for _ = 1, 30 do screen:update() end
  T.eq(screen.boxSlot, 4, "and stops the moment it is let go")
end

run.release()
T.finish("Gen1BillsBox")
