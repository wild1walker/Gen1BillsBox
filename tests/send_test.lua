-- SEND, on a POKeMON's own popup, on both cartridges.
--
-- The box screen is where you ARRANGE the GLOBAL BOX; SEND is the one-press
-- way in from the menu you are already in when you decide a POKeMON should go.
-- `ui.party.submenu` is the same hook name and arity on Red and on Gold, so
-- this drives the mod's ENTRY -- main.lua, whole -- twice, once per
-- generation, rather than the row in isolation: the whole point of the row is
-- that one of it serves both games.
--
-- Run:  luajit tests/send_test.lua

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
  local same = actual == expected
  if not same then
    description = ("%s (got %s, wanted %s)")
      :format(description, tostring(actual), tostring(expected))
  end
  ok(same, description)
end

local function slurp(path)
  local handle = assert(io.open(path, "r"), path .. " is missing")
  local body = handle:read("*a")
  handle:close()
  return body
end

-- ------------------------------------------------------------- the engine

-- Both generations' surfaces are registered at once; which one the mod uses is
-- decided by GameVersion.generation, which is the switch main.lua itself reads.
local GENERATION = 1
package.loaded["src.core.GameVersion"] = {
  VERSIONS = { red = {}, gold = {} },
  get = function() return GENERATION == 2 and "gold" or "red" end,
  generation = function() return GENERATION end,
  isYellow = function() return false end,
}

local Boxes1 = { COUNT = 12, CAPACITY = 20 }
function Boxes1.ensure(save)
  save.boxes = save.boxes or {}
  for i = 1, 12 do save.boxes[i] = save.boxes[i] or {} end
  save.currentBox = save.currentBox or 1
  return save.boxes
end
function Boxes1.active(save) return Boxes1.ensure(save)[save.currentBox] end
package.loaded["src.pokemon.Boxes"] = Boxes1

local Boxes2 = { NUM_BOXES = 14, MONS_PER_BOX = 20, PARTY_SIZE = 6 }
function Boxes2.box(save, index)
  save.boxes = save.boxes or {}
  save.boxes[index] = save.boxes[index] or {}
  return save.boxes[index]
end
function Boxes2.count(save, index) return #Boxes2.box(save, index) end
function Boxes2.isFull(save, index) return Boxes2.count(save, index) >= 20 end
function Boxes2.name(save, index) return "BOX" .. index end
local entered = {}
function Boxes2.enterBox(mon) entered[mon] = true return mon end
function Boxes2.release() return false end
function Boxes2.canUsePc() return true end
package.loaded["src.core.gen2.Boxes"] = Boxes2

local mailRemoved
local Mail = { PARTY_LENGTH = 6 }
function Mail.monHoldsMail(mon) return mon and mon.mail == true end
function Mail.removeSlot(save, slot) mailRemoved[#mailRemoved + 1] = slot end
function Mail.state(save) save.mailState = save.mailState or { party = {} }
  return save.mailState end
package.loaded["src.core.gen2.Mail"] = Mail

local happiness
package.loaded["src.world.PikachuFollower"] = {
  isFollowingDisabled = function() return false end,
  isStarterPikachu = function() return false end,
  modifyHappiness = function(_, what, mon)
    happiness[#happiness + 1] = { what = what, mon = mon }
  end,
}

package.loaded["src.pokemon.Party"] = { MAX = 6 }
package.loaded["src.pokemon.Stats"] = { ensure = function() end,
                                        calc = function() return {} end }
package.loaded["src.pokemon.Sprites"] = {}
package.loaded["src.ui.Screens"] = { push = function() end }
package.loaded["src.ui.PartyMenu"] = { drawIcon = function() end }
package.loaded["src.ui.gen2.PartyMenu"] = {
  new = function() return { clock = 0, drawIcon = function() end } end }
package.loaded["src.ui.Theme"] = { cursor = 1, cursorHollow = 2 }
package.loaded["src.render.PaletteFX"] = {
  GRAYS = {}, markTrueColor = function() end,
  whole = function() return {} end, zone = function() return {} end }
package.loaded["src.render.Font"] = {
  draw = function() end, drawCode = function() end, drawBox = function() end,
  width = function(s) return #tostring(s) * 8 end,
  split = function(s)
    local out = {} for c in tostring(s):gmatch(".") do out[#out + 1] = c end
    return out
  end }
package.loaded["src.ui.gen2.Chrome"] = setmetatable({
  DEFAULT_BOX_PALETTE = { { 255, 255, 255 }, { 255, 255, 255 },
                          { 255, 255, 255 }, { 0, 0, 0 } },
  fitScale = function() return 1 end,
  fitOrigin = function() return 0, 0 end,
}, { __index = function() return function() end end })
package.loaded["src.ui.Menu"] = {
  new = function(_, items, opts) return { items = items, opts = opts,
                                          index = 1,
                                          clampScroll = function() end } end }
package.loaded["src.core.Sound"] = { play = function() end,
                                     playCry = function() end }
package.loaded["src.core.Strings"] = setmetatable({
  source = function(s) return s end,
}, { __call = function(_, s, ...)
  if select("#", ...) > 0 then return (tostring(s):format(...)) end
  return s
end })

local said
package.loaded["src.render.TextBox"] = {
  new = function(_, text, _, opts)
    local page = { text = tostring(text), opts = opts }
    said[#said + 1] = page
    return page
  end }

-- The conversion.  On Red the mod does not call it at all; on Gold it is the
-- gate, so the double refuses for the same reasons the cart's own does.
local Convert = {}
function Convert.refusalFor(mon, _, gen1Data)
  if type(mon) ~= "table" then return "not_a_mon" end
  if mon.isEgg then return "is_egg" end
  if not (gen1Data and gen1Data.pokemon and gen1Data.pokemon[mon.species]) then
    return "species_too_new"
  end
  if mon.mail then return "has_mail" end
  return nil
end
function Convert.toGen1(mon, data, gen1Data)
  local reason = Convert.refusalFor(mon, data, gen1Data)
  if reason then return nil, reason end
  return { species = mon.species, nickname = mon.nickname, level = mon.level,
           shape = "gen1" }
end
function Convert.toGen2(mon)
  return { species = mon.species, nickname = mon.nickname, shape = "gen2" }
end
package.loaded["src.online.Convert"] = Convert
package.loaded["src.online.Trade"] = {
  gameIsLive = function() return false end,
  withDataset = function(version, fn)
    if version ~= "red" then return nil, "not imported" end
    return fn({ pokemon = { BULBASAUR = {}, CHARMANDER = {} }, moves = {},
                growth_rates = {} })
  end,
}

local SaveSerializer = {}
do
  local store, n = {}, 0
  function SaveSerializer.encode(v) n = n + 1 store["s" .. n] = v return "s" .. n end
  function SaveSerializer.decode(b) return store[b] end
end
package.loaded["src.core.SaveSerializer"] = SaveSerializer
package.loaded["src.core.SaveData"] = {
  cartsWithSlots = function() return {} end,
  listCartSlots = function() return {} end,
  readCartSlotSource = function() return nil end,
  listSlots = function() return {} end,
  readSlotSource = function() return nil end,
  getCart = function() return "wildcart" end,
  activeCartSlot = function() return "slot1" end,
  activeSlot = function() return "slot1" end,
}

_G.love = _G.love or {}
love.graphics = setmetatable({
  getColor = function() return 1, 1, 1, 1 end,
}, { __index = function() return function() end end })

-- ------------------------------------------------------- the mod, as loaded

-- main.lua by SEARCH: the bundle's CI stages this mod at <engine>/mods/<id>/
-- and runs its suites from the engine root, where "main.lua" is the ENGINE's.
local MOD do
  for _, candidate in ipairs({ "main.lua", "../main.lua", "../../main.lua" }) do
    local handle = io.open(candidate)
    if handle then
      local text = handle:read("*a")
      handle:close()
      if text:find("sendToGlobal", 1, true) then MOD = candidate break end
    end
  end
end
ok(MOD ~= nil, "this mod's own main.lua is found, so every check below runs")
if not MOD then
  io.write(("send: %d passed, %d failed\n"):format(passed, failed))
  os.exit(1)
end
local HERE = MOD:match("^(.*)main%.lua$") or ""

local submenu, modSaveTable, options

local function loadMod(generation)
  GENERATION = generation
  modSaveTable, options = {}, {}
  said, happiness, mailRemoved = {}, {}, {}
  submenu = nil
  local mod = { id = "gen1_bills_box", path = "modules/Gen1BillsBox" }
  mod.options = { define = function(_, rows)
                    for _, row in ipairs(rows) do
                      if options[row.key] == nil then options[row.key] = row.default end
                    end
                  end,
                  get = function(_, key) return options[key] end }
  mod.log = {}
  for _, level in ipairs({ "info", "warn", "error", "debug" }) do
    mod.log[level] = function() end
  end
  mod.read = function(_, name)
    local handle = io.open(HERE .. name)
    if not handle then return nil, "missing" end
    local body = handle:read("*a")
    handle:close()
    return body
  end
  mod.content = { screens = { get = function() return nil end,
                              register = function() end,
                              override = function() end } }
  mod.hooks = { wrap = function(_, name, fn)
    if name == "ui.party.submenu" then submenu = fn end
  end }
  mod.events = { on = function() end }
  mod.exports = {}
  mod.ui = { push = function() end,
             TextBox = package.loaded["src.render.TextBox"],
             Font = package.loaded["src.render.Font"],
             Menu = package.loaded["src.ui.Menu"] }
  -- prefixed, the way the bundle's facade hands it over (runtime/facade.lua):
  -- a harness with a bare key is a harness for a path that does not ship
  mod.save = { get = function(_, key) return modSaveTable["box." .. key] end,
               set = function(_, key, value) modSaveTable["box." .. key] = value end }
  mod.find = function() return nil end
  mod.theme = function() return nil end
  mod.world = {}
  assert(load(slurp(MOD), "@" .. MOD))()(mod)
  return mod
end

local nextId = 0
local function mon(species, nickname, extra)
  nextId = nextId + 1
  local out = { id = nextId, species = species or "BULBASAUR", level = 5,
                hp = 20, maxHp = 20, nickname = nickname, moves = {} }
  for key, value in pairs(extra or {}) do out[key] = value end
  return out
end

local function gameWith(partyN)
  local save = { party = {}, boxes = {}, currentBox = 1, mail = {} }
  for _ = 1, partyN do save.party[#save.party + 1] = mon() end
  return { save = save, data = { pokemon = { BULBASAUR = {}, CHARMANDER = {},
                                             CHIKORITA = {} }, text = {} },
           stack = { push = function() end, pop = function() end } }
end

-- The vanilla rows the hook is handed, so what is asserted is what the mod
-- ADDED and not what it replaced.
local function rowsFor(game, mon_, ctx)
  local base = { { label = "STATS" }, { label = "SWITCH" } }
  return submenu(function(_, items) return items end, game, base, mon_, ctx)
end

local function labels(rows)
  local out = {}
  for _, row in ipairs(rows or {}) do out[#out + 1] = tostring(row.label) end
  return table.concat(out, ",")
end

local function rowNamed(rows, name)
  for _, row in ipairs(rows or {}) do
    if tostring(row.label) == name then return row end
  end
  return nil
end

-- ------------------------------------------------------------------- Red

do
  io.write("SEND is on the party popup, on Red\n")
  loadMod(1)
  ok(type(submenu) == "function", "the mod wraps ui.party.submenu")

  local game = gameWith(2)
  local rows = rowsFor(game, game.save.party[1])
  eq(labels(rows), "STATS,SWITCH,SEND",
    "the row lands after the vanilla ones, which are index-sensitive")

  -- and it does the thing
  local leaving = game.save.party[1]
  said = {}
  rowNamed(rows, "SEND").onSelect()
  eq(#said, 1, "it asks first")
  ok(said[1].text:find("GLOBAL BOX%?") ~= nil, "naming where it is going")
  ok(said[1].opts and said[1].opts.defaultNo,
    "with the cursor on NO, because this one leaves the save")
  eq(#game.save.party, 2, "and nothing has moved yet")

  said[1].opts.choice(false)
  eq(#game.save.party, 2, "NO moves nothing")

  said[1].opts.choice(true)
  eq(#game.save.party, 1, "YES takes it out of the party")
  local GlobalBox = assert(load(slurp(HERE .. "globalbox.lua")))()
  local bucket = GlobalBox.bucketsIn(modSaveTable)[1]
  ok(bucket ~= nil and #bucket.mons == 1, "and puts it in this save's bucket")
  ok(bucket.mons[1] ~= leaving,
    "as a copy, so the box and the party never share a table")
  ok(#happiness == 1 and happiness[1].what == "DEPOSITED",
    "with the cart's own into-storage tail run on it")
  ok(said[#said].text:find("^Sent"), "and says so afterwards")
end

do
  io.write("and it will not empty the party\n")
  loadMod(1)
  local game = gameWith(1)
  local rows = rowsFor(game, game.save.party[1])
  said = {}
  rowNamed(rows, "SEND").onSelect()
  eq(#said, 1, "the last POKeMON is refused")
  ok(said[1].text:find("last"), "with the cart's own line")
  ok(said[1].opts == nil or said[1].opts.choice == nil,
    "and no confirm to press through")
  eq(#game.save.party, 1, "the party keeping it")
end

do
  io.write("mid-battle it is not offered at all\n")
  loadMod(1)
  local game = gameWith(2)
  eq(labels(rowsFor(game, game.save.party[1], { battle = {} })), "STATS,SWITCH",
    "SWITCH / STATS / CANCEL in a battle is not a place to empty the party")
end

do
  io.write("and the switch turns it off\n")
  local mod = loadMod(1)
  options.sendRow = false
  local game = gameWith(2)
  eq(labels(rowsFor(game, game.save.party[1])), "STATS,SWITCH",
    "SEND ROW off takes the row away")
  options.sendRow = true
  options.globalBox = false
  eq(labels(rowsFor(game, game.save.party[1])), "STATS,SWITCH",
    "and so does turning the whole GLOBAL BOX off")
end

-- ------------------------------------------------------------------ Gold

do
  io.write("SEND is the same row on Gold, over the Time Capsule's rules\n")
  loadMod(2)
  ok(type(submenu) == "function", "the mod wraps the same hook on Gold")

  local game = gameWith(3)
  game.save.party[2] = mon("CHIKORITA", "JOHTO")
  game.save.party[3] = mon("BULBASAUR", "MAILED", { mail = true })

  eq(labels(rowsFor(game, game.save.party[1])), "STATS,SWITCH,SEND",
    "a POKeMON RED knows carries the row")
  -- A Johto POKeMON carries it too now: the box holds Gold's shape, so there
  -- is nothing to refuse on the way IN.  It is RED that will not take it out.
  eq(labels(rowsFor(game, game.save.party[2])), "STATS,SWITCH,SEND",
    "and so does a Johto POKeMON, which the box holds perfectly well")
  -- MAIL is the one thing still refused at the deposit, and it is the CART's
  -- rule rather than the Time Capsule's: sPartyMail is keyed by party slot, so
  -- Gold will not put a POKeMON holding a letter into storage at all.
  eq(labels(rowsFor(game, game.save.party[3])), "STATS,SWITCH",
    "one holding MAIL does not, which is Gold's own storage rule")

  said = {}
  rowNamed(rowsFor(game, game.save.party[1]), "SEND").onSelect()
  said[1].opts.choice(true)
  eq(#game.save.party, 2, "sending takes it out of the party")
  local GlobalBox = assert(load(slurp(HERE .. "globalbox.lua")))()
  local bucket = GlobalBox.bucketsIn(modSaveTable)[1]
  ok(bucket ~= nil and #bucket.mons == 1, "and into this save's bucket")
  eq(bucket.mons[1].shape, nil, "with nothing converted on the way in")
  eq(GlobalBox.genOf(bucket.mons[1]), 2, "stamped as the Gold shape it is")
  ok(#mailRemoved == 1 and mailRemoved[1] == 1,
    "with the letters behind it moved up, which are indexed by party slot")
end

do
  io.write("and on Gold it will not leave you unable to fight\n")
  loadMod(2)
  local game = gameWith(2)
  game.save.party[2].hp = 0
  said = {}
  rowNamed(rowsFor(game, game.save.party[1]), "SEND").onSelect()
  eq(#said, 1, "sending your last healthy POKeMON is refused")
  ok(said[1].text:find("last"), "with a line that says so")
  eq(#game.save.party, 2, "and the party is untouched")
end

io.write(("\nsend: %d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
