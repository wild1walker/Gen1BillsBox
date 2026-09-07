-- BILL'S BOX on the menu a Gold player actually presses first.
--
-- Reported as "when I go to the pc bills box isn't replacing bills pc", and
-- the reason is that Gold has TWO PC menus where Red has one:
--
--   src/ui/gen2/CenterPcMenu.lua   "Access whose PC?" -- BILL's PC /
--                                  <PLAYER>'s PC / PROF.OAK's PC
--   src/ui/gen2/PcMenu.lua         the storage verbs behind BILL's PC
--
-- Only the second runs `ui.pc.items`, which is the hook this mod renames
-- through, so the row carrying the words "BILL's PC" had no seam on it and
-- kept its name while every other surface in the mod said BOX.
--
-- This drives the CART's own CenterPcMenu -- not a stand-in -- because the
-- whole bug was a stand-in's worth of distance between what the mod hooked
-- and what the game drew.
--
-- Run:  luajit tests/goldpcname_gen2_test.lua

package.path = "./?.lua;" .. package.path

local passed, failed = 0, 0
local function ok(condition, description)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    io.write("  FAIL  ", description, "\n")
  end
end
local function eq(actual, expected, description)
  if actual ~= expected then
    description = ("%s (got %s, wanted %s)")
      :format(description, tostring(actual), tostring(expected))
  end
  ok(actual == expected, description)
end

local ENGINE do
  local candidates = { os.getenv("GEN1RECOMP") }
  for _, prefix in ipairs({ "..", "../../..", "../../../..", "../..",
                            "../../../../.." }) do
    candidates[#candidates + 1] = prefix .. "/bryanthaboi/gen1recomp"
    candidates[#candidates + 1] = prefix .. "/gen1recomp"
  end
  for _, dir in ipairs(candidates) do
    if dir then
      local probe = io.open(dir .. "/src/ui/gen2/CenterPcMenu.lua")
      if probe then probe:close(); ENGINE = dir; break end
    end
  end
end
if not ENGINE then
  io.write("goldpcname_gen2: SKIPPED -- no engine tree found "
    .. "(set GEN1RECOMP to a gen1recomp checkout)\n")
  os.exit(0)
end
package.path = ENGINE .. "/?.lua;" .. package.path

local noop = function() end
_G.love = {
  timer = { getTime = function() return 0 end },
  audio = {},
  window = { getMode = function() return 160, 144 end },
  filesystem = { getInfo = function() return nil end, read = function() return nil end },
  graphics = setmetatable({}, { __index = function() return noop end }),
}
require("src.core.Logger").warn = noop
require("src.core.GameVersion").set("crystal")

local Center = require("src.ui.gen2.CenterPcMenu")

-- ---- the shipped wrap, read out of main.lua rather than restated here

local function slurp(path)
  local handle = assert(io.open(path), path)
  local text = handle:read("*a")
  handle:close()
  return text
end

-- main.lua by SEARCH, not by a bare name.  The bundle's CI stages each
-- vendored mod at <engine>/mods/<id>/ and runs its suites from the engine
-- root, where "main.lua" is the ENGINE's -- which reads fine and matches
-- nothing, so the assert below would blame this mod for the wrong file.
local MOD do
  for _, candidate in ipairs({ "main.lua", "../main.lua", "../../main.lua" }) do
    local handle = io.open(candidate)
    if handle then
      local text = handle:read("*a")
      handle:close()
      if text:find("renameGoldPcMenu", 1, true) then MOD = candidate break end
    end
  end
end
ok(MOD ~= nil, "this mod's own main.lua is found, so every read below runs")
if not MOD then
  io.write(("goldpcname_gen2: %d passed, %d failed\n"):format(passed, failed))
  os.exit(1)
end

local source = slurp(MOD)
local billsBoxSrc = assert(
  source:match("(  local function billsBox%(text%).-\n  end)\n"),
  "could not find billsBox in main.lua")
local renameSrc = assert(
  source:match("(  local function renameGoldPcMenu%(%).-\n  end)\n"),
  "could not find renameGoldPcMenu in main.lua")

local logged = {}
local chunk = assert(load(
  "local mod, gen2, centerPcWrapped = ...\n"
    .. billsBoxSrc .. "\n" .. renameSrc .. "\nreturn renameGoldPcMenu",
  "@Gen1BillsBox/main.lua"))
local renameGoldPcMenu = chunk(
  { log = { info = function(_, ...) logged[#logged + 1] = { ... } end } },
  true, false)

-- ---- before the wrap: the cart's own words

local function entriesFor(save)
  local screen = setmetatable({ save = save }, { __index = Center })
  screen:buildEntries()
  local byId = {}
  for _, entry in ipairs(screen.entries or {}) do byId[entry.id] = entry.label end
  return byId
end

local SAVE = {
  player = { name = "GOLD" },
  engineFlags = { POKEDEX = true },
  hallOfFame = { count = 0 },
}

local before = entriesFor(SAVE)
ok(before.bills ~= nil, "the cart's PC menu has a row with the id `bills`")
ok(before.bills:find("PC", 1, true) ~= nil,
   "and it says PC before this mod touches it (" .. tostring(before.bills) .. ")")

-- ---- after

renameGoldPcMenu()

local after = entriesFor(SAVE)
eq(after.bills, "BILL's BOX", "BILL's PC is BILL's BOX on Gold's PC menu")
eq(after.players, before.players, "the player's own PC keeps its name")
eq(after.oaks, before.oaks, "and so does PROF.OAK's")

-- Twice is once: the guard makes a second game.ready a no-op rather than a
-- second wrap, which would rename a rename.
renameGoldPcMenu()
eq(entriesFor(SAVE).bills, "BILL's BOX", "a second install does not re-wrap")

-- ---- the page the row opens with
--
-- A row that says BOX opening a page that says PC is worse than not renaming
-- it at all, which is the rule this mod already follows for Red's ROM lines.
-- `say` mutates the pages in place before delegating, so the table is read
-- back after the call however the delegate ends.
local pages = {
  { "BILL's PC", "accessed." },
  { "#MON Storage", "System opened." },
}
pcall(Center.say, setmetatable({ save = SAVE }, { __index = Center }), pages, noop)
eq(pages[1][1], "BILL's BOX", "the access page says BOX too")
eq(pages[2][1], "#MON Storage", "and the lines that name no machine are left alone")

local other = { { "PROF.OAK's PC", "accessed." } }
pcall(Center.say, setmetatable({ save = SAVE }, { __index = Center }), other, noop)
eq(other[1][1], "PROF.OAK's PC", "another trainer's PC is not renamed")

io.write(("goldpcname_gen2: %d passed, %d failed\n"):format(passed, failed))
if failed > 0 then os.exit(1) end
