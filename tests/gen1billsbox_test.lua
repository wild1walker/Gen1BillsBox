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

  -- The grid is RULED as a table: six one-pixel verticals 24 apart from
  -- x=32, four one-pixel horizontals 24 apart from y=24.  Twenty cells, but
  -- ten lines rather than twenty frames, so neighbouring cells share one
  -- black line instead of stacking two.
  local lines, missing = {}, {}
  for _, r in ipairs(rects) do
    if r.w == 1 or r.h == 1 then lines[r.x .. "," .. r.y .. "," .. r.w .. "," .. r.h] = true end
  end
  for col = 0, 5 do
    local key = (32 + col * 24) .. ",24,1,96"
    if not lines[key] then missing[#missing + 1] = key end
  end
  for row = 0, 3 do
    local key = "32," .. (24 + row * 24) .. ",121,1"
    if not lines[key] then missing[#missing + 1] = key end
  end
  T.eq(#missing, 0, "the grid is ruled as a table (" ..
    table.concat(missing, " ") .. ")")

  -- every cell edge lands on an 8-pixel tile boundary, which is what lets
  -- each one carry a palette zone of its own
  local unaligned = 0
  for col = 0, 5 do if (32 + col * 24) % 8 ~= 0 then unaligned = unaligned + 1 end end
  for row = 0, 4 do if (24 + row * 24) % 8 ~= 0 then unaligned = unaligned + 1 end end
  for slot = 1, 6 do
    if (24 + (slot - 1) * 16) % 8 ~= 0 then unaligned = unaligned + 1 end
  end
  T.eq(unaligned, 0, "every cell and party row starts on a tile boundary")

  -- the grid's last row ends exactly where the footer box begins
  T.eq(24 + 4 * 24, 120, "four rows of 24 stop at the footer")
  T.eq(32 + 5 * 24, 152, "five columns of 24 leave the last tile as margin")

  -- the hairline between the panes runs the height of the party column
  local rule = nil
  for _, r in ipairs(rects) do
    if r.w == 1 and r.h == 96 and r.x == 28 then rule = r end
  end
  T.check(rule ~= nil and rule.y == 24,
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
  T.eq(at[boxA], "36,31", "the first box icon sits under the cursor band")
  T.eq(at[boxB], "60,31", "and the second is one cell to the right")
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
  T.eq(calls[1].x .. "," .. calls[1].y, "36,31",
    "in the slot, not lifted -- the hollow arrow is what says it is carried")
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


-- ------- colour
--
-- The reported bug: with COLORS on ADVANCED every POKeMON in the box came out
-- of the same salmon ramp and the grid lines came out orange, while the party
-- menu next door showed each POKeMON in its own colours.  Both symptoms are
-- one cause -- a single named zone over the whole screen.  MEWMON paints
-- shade 1 {239,156,107}, so grey grid lines are orange lines and every icon
-- wears one palette.
--
-- The fixture dataset carries no palettes, so one is injected here in the
-- shape PaletteFX.pack reads: {palettes = {NAME = colors}, pokemon = {SPECIES
-- = NAME}}.

do
  local P = require("src.render.PaletteFX")
  local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }
  Data.palettes = {
    palettes = {
      MEWMON = { WHITE, { 239, 156, 107 }, { 115, 33, 165 }, BLACK },
      GREENMON = { WHITE, { 99, 255, 90 }, { 255, 99, 140 }, BLACK },
      BLUEMON = { WHITE, { 99, 123, 156 }, { 41, 66, 140 }, BLACK },
    },
    pokemon = { FIXMON_A = "GREENMON", FIXMON_B = "BLUEMON" },
  }

  local game = fakeGame({ mon("FIXMON_A"), mon("FIXMON_B") }, { mon("FIXMON_B") })
  local screen = factory.new(game)
  local zones = screen:sgbPalettes(game)
  T.check(type(zones) == "table" and zones[1] ~= nil, "the screen owns its palette")

  -- the base is the plain grey ramp, so nothing this screen draws is tinted
  local base = zones[1]
  T.eq(base.x .. "," .. base.y .. "," .. base.w .. "," .. base.h, "0,0,160,144",
    "the first zone covers the whole screen")
  T.same(base.colors, P.GRAYS, "and it is the four DMG greys, not MEWMON")

  -- one zone per POKeMON on screen, each carrying that species' palette
  T.eq(#zones, 4, "plus one zone per POKeMON: two in the box, one in the party")
  local byOrigin = {}
  for i = 2, #zones do byOrigin[zones[i].x .. "," .. zones[i].y] = zones[i] end

  local party = byOrigin["8,24"]
  T.check(party ~= nil, "the first party row has a zone of its own")
  T.eq(party.w .. "," .. party.h, "16,16", "two tiles square, the icon exactly")
  T.same(party.colors, Data.palettes.palettes.BLUEMON,
    "wearing FIXMON_B's palette")

  local first = byOrigin["32,24"]
  T.check(first ~= nil, "and so does the first box cell")
  T.eq(first.w .. "," .. first.h, "24,24", "three tiles square, the whole cell")
  T.same(first.colors, Data.palettes.palettes.GREENMON,
    "wearing FIXMON_A's palette, not one shared ramp")
  T.neq(first.colors, byOrigin["56,24"].colors,
    "two different species do not share a palette any more")

  -- every species palette is white / hue / hue / black, which is what lets
  -- black chrome survive a zone laid over it
  for name, colors in pairs(Data.palettes.palettes) do
    T.same(colors[4], BLACK, name .. "'s shade 3 is black, so lines stay black")
    T.same(colors[1], WHITE, name .. "'s shade 0 is white, so paper stays white")
  end

  -- an empty cell asks for nothing
  local emptyCell = byOrigin["80,24"]
  T.eq(emptyCell, nil, "an empty cell contributes no zone")

  -- a carried POKeMON colours the cell it is riding over, not the one it
  -- came out of: the pixels and the palette have to name the same POKeMON
  drive(game, screen, "right", "a")
  T.eq(screen.held.mon.species, "FIXMON_B", "carrying FIXMON_B")
  local carried = {}
  local after = screen:sgbPalettes(game)
  for i = 2, #after do carried[after[i].x .. "," .. after[i].y] = after[i].colors end
  T.same(carried["56,24"], Data.palettes.palettes.BLUEMON,
    "the cursor's cell wears the carried POKeMON's palette")

  Data.palettes = nil
end

-- ------- the cursor is an arrow, not a box
--
-- Asked for: a selector arrow over the POKeMON's head pointing down, hollow
-- while one is in hand, in place of the square that used to ring the cell.

do
  local game = fakeGame({ mon("FIXMON_A") })
  local screen = factory.new(game)

  local function arrowRows()
    local rects = {}
    local real = love.graphics.rectangle
    love.graphics.rectangle = function(mode, x, y, w, h)
      rects[#rects + 1] = { x = x, y = y, w = w, h = h }
    end
    pcall(function() screen:draw() end)
    love.graphics.rectangle = real
    -- the cursor band is the four rows above the first cell's icon
    local rows = {}
    for _, r in ipairs(rects) do
      if r.y >= 26 and r.y < 30 and r.x >= 32 and r.x < 56 and r.h == 1 then
        rows[#rows + 1] = r
      end
    end
    return rows
  end

  local solid = arrowRows()
  T.eq(#solid, 4, "the solid cursor is four rows")
  table.sort(solid, function(a, b) return a.y < b.y end)
  T.eq(solid[1].w .. "," .. solid[2].w .. "," .. solid[3].w .. "," .. solid[4].w,
    "7,5,3,1", "each row narrower than the last: a triangle pointing down")
  T.eq(solid[1].x, 40, "centred over the cell it points into")

  -- nothing rings the cell any more
  local ringed = false
  local rects = {}
  local real = love.graphics.rectangle
  love.graphics.rectangle = function(mode, x, y, w, h)
    rects[#rects + 1] = { x = x, y = y, w = w, h = h }
  end
  pcall(function() screen:draw() end)
  love.graphics.rectangle = real
  for _, r in ipairs(rects) do
    -- a cell-sized outline edge that is not one of the grid's own rules
    if r.w == 24 and r.h == 1 and r.x == 32 then ringed = true end
  end
  T.check(not ringed, "no square highlight is drawn around the selected cell")

  drive(game, screen, "a")
  T.check(screen.held ~= nil, "with a POKeMON in hand")
  local hollow = arrowRows()
  table.sort(hollow, function(a, b) return a.y < b.y end)
  T.eq(#hollow, 6, "the hollow cursor is the same outline, drawn as edges")
  T.eq(hollow[1].w, 7, "the top row still spans the triangle")
  local interior = 0
  for _, r in ipairs(hollow) do if r.w > 1 and r.y > hollow[1].y then interior = interior + 1 end end
  T.eq(interior, 0, "and every row under it is edge pixels only, so it reads hollow")
end


-- ------- a catch into a full box
--
-- The overflow is the ENGINE's, not this mod's: src/pokemon/Boxes.lua's
-- deposit walks from the open box forward through all twelve and wraps.  It
-- is pinned here anyway, because this mod owns the storage screen and rewrites
-- the very line that catch prints, so a regression in either would show up as
-- "my catch vanished".

do
  local function fullSave(openBox, fullBoxes)
    local boxes = {}
    for i = 1, Boxes.COUNT do
      boxes[i] = {}
      if fullBoxes[i] then
        for j = 1, Boxes.CAPACITY do boxes[i][j] = mon("FIXMON_A") end
      end
    end
    return { boxes = boxes, currentBox = openBox, party = {} }
  end

  -- the open box is full: the catch lands in the next one, not on the floor
  local save = fullSave(1, { [1] = true })
  local caught = mon("FIXMON_B")
  T.eq(Boxes.deposit(save, caught), 2, "a full open box overflows into the next")
  T.eq(save.boxes[2][1], caught, "and the POKeMON really is in it")
  T.eq(#save.boxes[1], Boxes.CAPACITY, "leaving the full one exactly full")

  -- it skips full boxes rather than stopping at the first one
  save = fullSave(1, { [1] = true, [2] = true, [3] = true })
  T.eq(Boxes.deposit(save, mon("FIXMON_B")), 4, "and skips every full box on the way")

  -- and it wraps round the back rather than giving up at box twelve
  local all = {}
  for i = 2, Boxes.COUNT do all[i] = true end
  save = fullSave(5, all)
  T.eq(Boxes.deposit(save, mon("FIXMON_B")), 1,
    "from box 5 with 2..12 full it wraps to box 1")

  -- only when all 240 places are taken does the catch fail
  for i = 1, Boxes.COUNT do all[i] = true end
  save = fullSave(1, all)
  T.eq(Boxes.deposit(save, mon("FIXMON_B")), nil,
    "twelve full boxes is the one case that refuses")
end

-- ------- and it says where the POKeMON went, and opens that box

local exports = run.loader.exports[run.mod.manifest.id]
T.eq(type(exports.overflowTarget), "function", "the overflow lookup is exported")
T.eq(type(exports.overflowNote), "function", "and the note it builds")

do
  local overflowTarget, overflowNote = exports.overflowTarget, exports.overflowNote
  local boxes = {}
  for i = 1, Boxes.COUNT do boxes[i] = {} end
  local save = { boxes = boxes, currentBox = 3, party = {} }

  -- landed in the box you had open: nothing to report, and nothing is
  local quiet = mon("FIXMON_A")
  boxes[3][1] = quiet
  T.eq(overflowTarget(save, quiet), nil,
    "an ordinary catch into the open box stays as quiet as it was")

  -- a POKeMON that is in no box at all (a party catch) asks for nothing
  T.eq(overflowTarget(save, mon("FIXMON_C")), nil,
    "a POKeMON that never reached a box reports nothing")

  -- landed somewhere else: both boxes, because neither is guessable
  local overflowed = mon("FIXMON_B")
  boxes[7][1] = overflowed
  local open, landed = overflowTarget(save, overflowed)
  T.eq(open .. "->" .. landed, "3->7", "an overflow reports the box that was full and the one that took it")
  T.eq(save.currentBox, 3, "and the lookup itself changes nothing")

  -- the note tells the truth about what happened, either way round
  local moved = overflowNote(open, landed, true)
  T.check(moved:find("BOX 3 was full!", 1, true) ~= nil, "naming the box that was full")
  T.check(moved:find("Now using BOX 7.", 1, true) ~= nil,
    "and saying the open box followed it")
  local stayed = overflowNote(open, landed, false)
  T.check(stayed:find("Stored in BOX 7.", 1, true) ~= nil,
    "with SWITCH ON FULL off it says where the POKeMON went instead")
  T.check(stayed:find("Now using", 1, true) == nil,
    "and never claims a switch that did not happen")

  -- both fit the battle's two-line box, at the widest box number
  for _, line in ipairs({ overflowNote(1, 12, true), overflowNote(12, 1, false) }) do
    for chunk in (line .. "\n"):gmatch("([^\n]*)\n") do
      T.check(#chunk <= 18, "fits the battle text box: " .. chunk)
    end
  end
end

-- driven through the real event, with a battle that records what it is told
do
  local said = {}
  local battle = { sayNext = function(_, text) said[#said + 1] = text end }
  local boxes = {}
  for i = 1, Boxes.COUNT do boxes[i] = {} end
  local game = { save = { boxes = boxes, currentBox = 1, party = {} } }

  local overflowed = mon("FIXMON_B")
  boxes[4][1] = overflowed
  Runtime.emit("pokemon.caught",
    { battle = battle, game = game, mon = overflowed, destination = "box" })
  T.eq(#said, 1, "the caught event adds one line")
  T.check(said[1]:find("Now using BOX 4.", 1, true) ~= nil, "naming box 4")
  T.eq(game.save.currentBox, 4, "and the open box follows the catch there")

  -- the next catch therefore starts its walk from a box with room, rather
  -- than from the full one again
  T.eq(Boxes.deposit(game.save, mon("FIXMON_C")), 4,
    "so the next catch lands in that box directly")

  -- a catch into the box you are already on: no line, no move
  said = {}
  local ordinary = mon("FIXMON_A")
  boxes[4][#boxes[4] + 1] = ordinary
  Runtime.emit("pokemon.caught",
    { battle = battle, game = game, mon = ordinary, destination = "box" })
  T.eq(#said, 0, "a catch into the open box says nothing")
  T.eq(game.save.currentBox, 4, "and moves nothing")

  -- a catch that went to the PARTY is not this handler's business
  said = {}
  Runtime.emit("pokemon.caught",
    { battle = battle, game = game, mon = overflowed, destination = "party" })
  T.eq(#said, 0, "a catch into the party says nothing")

  -- the switch does not need a battle to talk through: a payload with no
  -- BattleState still moves the open box, it just cannot narrate it
  said = {}
  game.save.currentBox = 1
  Runtime.emit("pokemon.caught", { game = game, mon = overflowed, destination = "box" })
  T.eq(game.save.currentBox, 4, "the open box follows even with nothing to say it through")
  T.eq(#said, 0, "and nothing is said")

  -- a payload with nothing in it at all is survived rather than thrown on
  Runtime.emit("pokemon.caught", { destination = "box" })
  Runtime.emit("pokemon.caught", nil)
  T.eq(#said, 0, "an empty payload is simply ignored")
end


-- ------- every edge of the cell stays clear
--
-- 1.0.4 centred the icon vertically and drew the cursor's flat top row
-- straight onto the rule above it, where it read as a smear on the grid
-- rather than as a cursor.  The lesson is that the vertical column has no
-- slack to spend: a gap, a 4-pixel arrow, a gap, a 16-pixel icon and a gap,
-- inside the 23 pixels between two rules, is three pixels for three gaps.
-- These assert the CLEARANCES rather than the coordinates, because the
-- clearances are the thing that was wrong and a coordinate test passed it.

do
  local CELL, ICON, ARROW_H, ARROW_W = 24, 16, 4, 7
  local iconDX, iconDY = 4, 7
  local arrowDX, arrowDY = 8, 2
  local interior = CELL - 1        -- the pixels between this rule and the next

  -- the two ends, which are what 1.0.4 got wrong
  T.check(arrowDY - 1 >= 1, "the arrow clears the rule above it")
  T.check(interior - (iconDY + ICON - 1) >= 1, "and the icon clears the rule below it")

  -- the arrow points at the head without overlapping it
  local headGap = iconDY - (arrowDY + ARROW_H)
  T.check(headGap >= 0, "the arrow does not overlap the icon")
  T.check(headGap <= 1, "and does not float away from it either")

  -- there is genuinely no room to do better: the three gaps use every pixel
  T.eq((arrowDY - 1) + ARROW_H + headGap + ICON
       + (interior - (iconDY + ICON - 1)), interior,
    "the column is spent to the pixel, which is why the icon cannot also centre")

  -- horizontally there IS room, and it is used
  local left = iconDX - 1
  local right = interior - (iconDX + ICON - 1)
  T.eq(left .. "," .. right, "3,4", "the icon is centred across the cell, within half a pixel")
  T.check(math.abs((iconDX + ICON / 2) - (arrowDX + ARROW_W / 2)) <= 0.5,
    "and the arrow's centre line is the icon's")
  T.check(arrowDX >= 1 and arrowDX + ARROW_W - 1 <= interior,
    "with the arrow clear of both side rules")
end


-- ------- full-colour icons must sit out the shade remap
--
-- The reported bug, twice over.  The SGB pass remaps four DMG shades to four
-- colours keyed off each pixel's RED channel; run authored full-colour art
-- through it and an orange POKeMON (red near 1.0, so shade 0) is painted the
-- palette's white.  The engine's answer is PaletteFX.markTrueColor, and
-- nothing in PartyMenu.drawIcon calls it -- the screen drawing the art has to.
--
-- Decided per icon by looking at the PIXELS of whatever drawIcon will resolve,
-- because that is the only test a mod cannot route around: the icons registry,
-- a species record's own `icon`, an asset override and the pokemon.icon hook
-- all end in a file, and the file either carries colour or it does not.

do
  local P = require("src.render.PaletteFX")
  local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }

  Data.icons = {
    -- a mod's own image: reaches the screen untouched, and this one is colour
    bySpecies = { FIXMON_A = { image = "mods/pack/vivid_a.png" },
                  -- a built-in icon CLASS: drawIcon bakes it grey through
                  -- obpIcon whatever file it points at, so never full colour
                  FIXMON_B = "MON" },
    icons = { MON = "assets/icons/mon.png" },
    byDex = {},
  }
  Data.palettes = {
    palettes = { MEWMON = { WHITE, { 239, 156, 107 }, { 115, 33, 165 }, BLACK },
                 GREENMON = { WHITE, { 99, 255, 90 }, { 255, 99, 140 }, BLACK } },
    pokemon = { FIXMON_A = "GREENMON", FIXMON_B = "GREENMON" },
  }

  -- a fake decoder: files named "vivid" carry colour, everything else is grey
  local FakeData = {}
  FakeData.__index = FakeData
  function FakeData:getDimensions() return self.w, self.h end
  function FakeData:getPixel()
    if self.colour then return 1, 0.4, 0.1, 1 end
    return 0.5, 0.5, 0.5, 1
  end
  local realNewImageData = love.image.newImageData
  love.image.newImageData = function(a, ...)
    local name = type(a) == "table" and (a.name or a.path) or tostring(a)
    return setmetatable({ w = 16, h = tostring(name):find("tall", 1, true) and 32 or 16,
                          colour = tostring(name):find("vivid", 1, true) ~= nil },
                        FakeData)
  end

  local vivid, plain = mon("FIXMON_A"), mon("FIXMON_B")
  local game = fakeGame({ vivid, plain })
  local screen = factory.new(game)

  -- the palette pass leaves the full-colour one alone and still colours the
  -- ordinary one
  local zones = screen:sgbPalettes(game)
  local byOrigin = {}
  for i = 2, #zones do byOrigin[zones[i].x .. "," .. zones[i].y] = zones[i] end
  T.eq(byOrigin["32,24"], nil,
    "a full-colour icon gets no species zone -- it would be paint nobody sees")
  T.check(byOrigin["56,24"] ~= nil,
    "an ordinary DMG icon still gets one")
  T.same(byOrigin["56,24"].colors, Data.palettes.palettes.GREENMON,
    "carrying that species' palette")

  -- and the draw marks the full-colour one so the pass re-blits it unshaded
  local marks = {}
  local realMark = P.markTrueColor
  P.markTrueColor = function(x, y, w, h)
    marks[#marks + 1] = x .. "," .. y .. "," .. w .. "," .. h
  end
  pcall(function() screen:draw() end)
  P.markTrueColor = realMark

  T.eq(#marks, 1, "exactly one region is claimed as full colour")
  T.eq(marks[1], "36,31,16,16",
    "the full-colour icon's own rect, where drawIcon put it")

  -- a taller sheet is drawn as a 16x16 frame, so only that is claimed
  love.image.newImageData = function(a, ...)
    local name = type(a) == "table" and (a.name or a.path) or tostring(a)
    return setmetatable({ w = 16, h = 32, colour = true }, FakeData)
  end
  Data.icons.bySpecies.FIXMON_C = { image = "mods/pack/vivid_tall.png" }
  local tall = mon("FIXMON_C")
  local game2 = fakeGame({ tall })
  local screen2 = factory.new(game2)
  marks = {}
  P.markTrueColor = function(x, y, w, h)
    marks[#marks + 1] = x .. "," .. y .. "," .. w .. "," .. h
  end
  pcall(function() screen2:draw() end)
  P.markTrueColor = realMark
  T.eq(marks[1], "36,31,16,16",
    "a two-frame sheet claims the frame that was drawn, not the whole file")

  love.image.newImageData = realNewImageData
  Data.icons = nil
  Data.palettes = nil
end

run.release()
T.finish("Gen1BillsBox")
