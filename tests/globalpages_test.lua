-- The GLOBAL pages on Red's box screen, and SEND.
--
-- globalbox_test.lua covers the STORE -- ids, claims, the union, what a save
-- holds.  This covers the SCREEN over it: that the header keeps walking past
-- BOX 12, that a POKeMON put onto a global page lands in the box rather than
-- in the cartridge's, that picking one up and pressing B puts it back where
-- it was rather than at the end, and that the two verbs which would have this
-- save reordering or deleting POKeMON in OTHER saves are not offered.
--
-- Run:  luajit tests/globalpages_test.lua

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

-- ------------------------------------------------------------- the harness

local BOX_COUNT, PER_BOX = 12, 20

local Boxes = { COUNT = BOX_COUNT, CAPACITY = PER_BOX }
function Boxes.ensure(save)
  save.boxes = save.boxes or {}
  for i = 1, BOX_COUNT do save.boxes[i] = save.boxes[i] or {} end
  save.currentBox = save.currentBox or 1
  return save.boxes
end
function Boxes.active(save) return Boxes.ensure(save)[save.currentBox] end
package.loaded["src.pokemon.Boxes"] = Boxes

package.loaded["src.pokemon.Party"] = { MAX = 6 }
package.loaded["src.pokemon.Stats"] = { ensure = function() end,
                                        calc = function() return {} end }
package.loaded["src.pokemon.Sprites"] = {}
package.loaded["src.ui.Screens"] = { push = function() end }
package.loaded["src.ui.PartyMenu"] = { drawIcon = function() end }
package.loaded["src.ui.Theme"] = { cursor = 1, cursorHollow = 2 }
package.loaded["src.render.PaletteFX"] = {
  GRAYS = {}, markTrueColor = function() end,
  whole = function() return {} end, zone = function() return {} end,
}

local drawn
package.loaded["src.render.Font"] = {
  draw = function(text, x, y) drawn[#drawn + 1] = { text = tostring(text), x = x, y = y } end,
  drawCode = function() end,
  drawBox = function() end,
  width = function(s) return #tostring(s) * 8 end,
  split = function(s) local out = {} for c in tostring(s):gmatch(".") do out[#out+1] = c end return out end,
}

local said
package.loaded["src.render.TextBox"] = {
  new = function(_, text, _, opts)
    said[#said + 1] = { text = tostring(text), opts = opts }
    return { text = text, opts = opts }
  end,
}

local menus
package.loaded["src.ui.Menu"] = {
  new = function(_, items, opts)
    local menu = { items = items, opts = opts, index = 1,
                   clampScroll = function() end }
    menus[#menus + 1] = menu
    return menu
  end,
}

package.loaded["src.core.Strings"] = setmetatable({
  source = function(s) return s end,
}, { __call = function(_, s, ...)
  if select("#", ...) > 0 then return (tostring(s):format(...)) end
  return s
end })
package.loaded["src.core.Sound"] = { playCry = function() end }

-- Convert, standing in for src/online/Convert.lua on the one path Red uses it:
-- taking out a POKeMON that GOLD put in.  Faithful about its shape -- a fresh
-- table out, a reason string on a refusal -- because that is the contract.
local converted = { toGen1 = 0 }
package.loaded["src.online.Convert"] = {
  toGen1 = function(mon, _, gen1Data)
    if mon.isEgg then return nil, "is_egg" end
    if not (gen1Data and gen1Data.pokemon and gen1Data.pokemon[mon.species]) then
      return nil, "species_too_new"
    end
    for _, mv in ipairs(mon.moves or {}) do
      if not (gen1Data.moves and gen1Data.moves[mv.id]) then
        return nil, "move_too_new"
      end
    end
    converted.toGen1 = converted.toGen1 + 1
    return { species = mon.species, nickname = mon.nickname, level = mon.level,
             shape = "gen1" }
  end,
  toGen2 = function(mon) return { species = mon.species, shape = "gen2" } end,
}
package.loaded["src.core.GameVersion"] = {
  VERSIONS = { red = {}, gold = {} },
  get = function() return "red" end,
  generation = function() return 1 end,
  isYellow = function() return false end,
}

_G.love = _G.love or {}
love.graphics = {
  setColor = function() end, getColor = function() return 1, 1, 1, 1 end,
  rectangle = function() end, push = function() end, pop = function() end,
  translate = function() end, scale = function() end, setShader = function() end,
}

-- ---- the two saves on this installation
--
-- One is the save being played (its bucket lives in memory, through mod.save);
-- the other is a Wild Green save sitting on disk with a POKeMON already in its
-- outbox, which is the whole point of the feature.

local SaveSerializer = { }
do
  -- Round-tripping through the engine's own serializer is globalbox_test's
  -- job.  Here a save on "disk" is just a table, so what is asserted is the
  -- reading of it and not the encoding.
  local store = {}
  local n = 0
  function SaveSerializer.encode(value) n = n + 1; store["s" .. n] = value; return "s" .. n end
  function SaveSerializer.decode(body) return store[body] end
end
package.loaded["src.core.SaveSerializer"] = SaveSerializer

local MOD_ID = "gen1_bills_box"
local disk = {}       -- key -> encoded body
local SaveData = {
  cartsWithSlots = function()
    local out = {}
    for key in pairs(disk) do
      local cart = key:match("^cart:(.-)/")
      if cart then out[#out + 1] = cart end
    end
    table.sort(out)
    return out
  end,
  listCartSlots = function(cartId)
    local out = {}
    for key in pairs(disk) do
      local slot = key:match("^cart:" .. cartId .. "/(.+)$")
      if slot then out[#out + 1] = { id = slot, exists = true } end
    end
    return out
  end,
  readCartSlotSource = function(cartId, slotId)
    return disk[("cart:%s/%s"):format(cartId, slotId)]
  end,
  listSlots = function() return {} end,
  readSlotSource = function() return nil end,
  getCart = function() return "wildgreen" end,
  activeCartSlot = function() return "slot1" end,
  activeSlot = function() return "slot1" end,
}
package.loaded["src.core.SaveData"] = SaveData

-- ---- the mod

local modSaveTable
local mod = { id = MOD_ID, path = "modules/Gen1BillsBox", stored = {} }
mod.options = { define = function() end,
                get = function(_, key) return mod.stored[key] end }
-- mod.save, the way the BUNDLE hands it over.
--
-- Inside Gen1WildUI each vendored mod gets a facade whose save proxy prefixes
-- every key with the feature's id (runtime/facade.lua, keyedProxy/joinKey), so
-- "globalbox" is filed as "box.globalbox".  A harness that skipped the prefix
-- would be testing a shipping path that does not exist -- and did: the bug
-- this suite now covers was a cross-cart read looking for the bare key.
local SAVE_PREFIX = "box."
mod.save = {
  get = function(_, key) return modSaveTable[SAVE_PREFIX .. key] end,
  set = function(_, key, value) modSaveTable[SAVE_PREFIX .. key] = value end,
}
mod.log = {}
for _, level in ipairs({ "info", "warn", "error", "debug" }) do
  mod.log[level] = function() end
end
mod.exports = {}
mod.hooks = { wrap = function() end }
mod.events = { on = function() end, once = function() end }
mod.ui = { Font = package.loaded["src.render.Font"],
           TextBox = package.loaded["src.render.TextBox"],
           push = function() end }
mod.find = function() return nil end
mod.theme = function() return nil end

local GlobalBox = assert(load(slurp("globalbox.lua"), "@globalbox.lua"))()
local Pane = assert(load(slurp("globalpane.lua"), "@globalpane.lua"))()(mod, GlobalBox)
-- `mod.stored.globalBox == false and nil or Pane` is the trap this suite has
-- caught before: `a and nil or b` is always b.  Spelled out.
local Screen = assert(load(slurp("screen.lua"), "@screen.lua"))()(mod, function()
  if mod.stored.globalBox == false then return nil end
  return Pane
end)

ok(type(Screen) == "table" and type(Screen.new) == "function",
  "the Gen 1 box screen builds with a GLOBAL BOX pane behind it")

-- ---- saves and POKeMON

local nextId = 0
local function mon(species, nickname, gen, moves)
  nextId = nextId + 1
  return { id = nextId, species = species or "BULBASAUR", level = 5,
           hp = 20, maxHp = 20, nickname = nickname,
           moves = moves or { { id = "TACKLE" } }, dvs = {},
           gbGen = gen }
end

local function newSave(partyN)
  local save = { party = {}, boxes = {}, currentBox = 1 }
  Boxes.ensure(save)
  for _ = 1, partyN or 0 do save.party[#save.party + 1] = mon() end
  return save
end

-- A second cartridge's save on disk, with one POKeMON already sent.  This is
-- the feature in one line: something another game put in, readable here.
local function otherCartHoldingList(list)
  local bucket = { format = GlobalBox.FORMAT, origin = "crystal", seq = 0,
                   mons = {}, claims = {} }
  for _, each in ipairs(list) do
    bucket.seq = bucket.seq + 1
    each.gbId = "crystal#" .. bucket.seq
    each.gbSent = bucket.seq
    each.gbGen = each.gbGen or 1
    bucket.mons[#bucket.mons + 1] = each
  end
  disk["cart:wildcrystal/slot1"] = SaveSerializer.encode({
    modData = { [MOD_ID] = { [GlobalBox.KEY] = bucket } } })
  return bucket
end

local function otherCartHolding(...) return otherCartHoldingList({ ... }) end

local function reset()
  modSaveTable = {}
  disk = {}
  drawn, said, menus = {}, {}, {}
  mod.stored = {}
  -- the disk table is captured by SaveData's closures, so it is replaced in
  -- place rather than rebound
end

-- `disk` is read through closures, so it has to be the same table throughout.
do
  local shared = disk
  reset = function()
    modSaveTable = {}
    for key in pairs(shared) do shared[key] = nil end
    drawn, said, menus = {}, {}, {}
    mod.stored = {}
  end
  disk = shared
end

local function screenOn(save)
  -- a dataset with the species this suite uses in it: a POKeMON the game has
  -- no entry for is drawn as a question mark and offered no STATS row, which
  -- is a GLOBAL-page case of its own and not what most of these check
  local game = {
    save = save,
    data = { text = {}, moves = { TACKLE = {} }, pokemon = {
      BULBASAUR = {}, CHARMANDER = {}, SQUIRTLE = {}, PIDGEY = {},
      RATTATA = {}, PIKACHU = {},
    } },
    input = { wasPressed = function() return false end,
              isDown = function() return false end },
    stack = { push = function() end, pop = function() end,
              top = function() return nil end },
  }
  return Screen.new(game, {}), game
end

local function idsOnGlobal(screen)
  local out = {}
  for page = 1, screen.global:pages() do
    for cell = 1, GlobalBox.PAGE do
      local each = screen.global:at(page, cell)
      if each then out[#out + 1] = tostring(each.gbId) end
    end
  end
  return table.concat(out, ",")
end

-- --------------------------------------------------- the header keeps walking

do
  io.write("the box list keeps going past BOX 12\n")
  reset()
  local screen = screenOn(newSave(1))
  ok(screen.global ~= nil, "the screen opened a GLOBAL BOX session")
  ok(screen.globalPage == nil, "and opens on a cartridge box, not a shared one")

  screen.game.save.currentBox = BOX_COUNT
  screen:changeBox(1)
  eq(screen.globalPage, 1, "RIGHT off the last box lands on GLOBAL 1")
  eq(screen.game.save.currentBox, BOX_COUNT,
    "and leaves the cartridge's open box where it was")

  -- an empty GLOBAL 1 is the only global page there is, so the ring closes
  screen:changeBox(1)
  ok(screen.globalPage == nil, "and RIGHT again is back on the cartridge")
  eq(screen.game.save.currentBox, 1, "at BOX 1")

  screen:changeBox(-1)
  eq(screen.globalPage, 1, "LEFT off BOX 1 is the last global page")

  -- a page fills and the next one opens: twenty is one page, twenty-one is two
  reset()
  local many = {}
  for i = 1, GlobalBox.PAGE do many[i] = mon("PIDGEY", "P" .. i) end
  otherCartHoldingList(many)
  screen = screenOn(newSave(1))
  eq(screen.global:pages(), 2, "a full GLOBAL 1 opens GLOBAL 2")
  screen.globalPage = 2
  screen:changeBox(1)
  ok(screen.globalPage == nil, "and the ring closes after the last of them")
end

-- ------------------------------------------------- what a global page shows

do
  io.write("another cartridge's POKeMON are on the page\n")
  reset()
  otherCartHolding(mon("CHARMANDER", "EMBER"))
  local screen = screenOn(newSave(1))
  eq(screen.global:pages(), 1, "one page holds it")
  screen.globalPage = 1
  local shown = screen:monDrawnAt("box", 1)
  ok(shown ~= nil and shown.nickname == "EMBER",
    "and the grid draws it in the first cell")
  ok(screen:monDrawnAt("box", 2) == nil, "the cell beside it being empty")

  drawn = {}
  screen:drawHeader()
  local header, count
  for _, entry in ipairs(drawn) do
    if entry.x == 24 then header = entry.text else count = entry.text end
  end
  eq(header, "GLOBAL 1", "the header names the page")
  eq(count, "1/20", "and counts what is on it, not what is in a cart box")
end

-- ------------------------------------------------------------ a deposit

do
  io.write("a POKeMON carried onto a global page leaves this save\n")
  reset()
  local save = newSave(2)
  local screen, game = screenOn(save)
  local leaving = save.party[1]

  screen.pane = "party"
  screen.partySlot = 1
  screen:grab()
  ok(screen.held ~= nil and screen.held.mon == leaving, "picked up out of the party")
  eq(#save.party, 1, "which is one shorter")

  screen.pane = "box"
  screen.globalPage = 1
  screen.boxSlot = 7          -- aimed at an empty cell in the middle
  screen:place()
  ok(screen.held == nil, "and put down on GLOBAL 1")
  eq(screen.boxSlot, 1,
    "in the first free cell, with the cursor following it there")
  eq(screen.global:count(), 1, "the box has it")
  eq(#Boxes.ensure(save)[1], 0, "and no cartridge box does")
  eq(#save.party, 1, "nor the party")

  -- and it is in the SAVE, which is the whole reason the store is shaped the
  -- way it is: a deposit that is not in save.modData is a deposit sync loses
  local bucket = GlobalBox.bucketsIn(modSaveTable)[1]
  ok(bucket ~= nil, "this save grew a bucket")
  eq(#bucket.mons, 1, "with the POKeMON in it")
  ok(bucket.mons[1] ~= leaving,
    "as a copy, so the party POKeMON and the stored one are not one table")
  eq(bucket.mons[1].nickname, leaving.nickname, "of the same POKeMON")
end

-- ------------------------------------------------ picking one back up again

do
  io.write("picking one up and pressing B puts it back where it was\n")
  reset()
  otherCartHolding(mon("CHARMANDER", "A"), mon("SQUIRTLE", "B"))
  local screen = screenOn(newSave(1))
  screen.pane = "box"
  screen.globalPage = 1
  local before = idsOnGlobal(screen)

  screen.boxSlot = 1
  screen:grab()
  ok(screen.held ~= nil, "one of another save's comes out")
  ok(screen.held.global, "flagged as having come from the shared box")
  eq(screen.global:count(), 1, "and the box is one shorter")
  ok(GlobalBox.bucketsIn(modSaveTable)[1].claims["crystal#1"] == true,
    "by a claim in THIS save, the other one being untouched")

  screen:returnHeld()
  eq(idsOnGlobal(screen), before, "B puts it back in the cell it came out of")
  eq(next(GlobalBox.bucketsIn(modSaveTable)[1].claims), nil,
    "with the claim dropped rather than left to reconcile")

  -- the same, but put down with A on a global page rather than cancelled
  screen.boxSlot = 2
  screen:grab()
  screen.boxSlot = 20
  screen:place()
  eq(idsOnGlobal(screen), before,
    "and A on the same pages is the same move, whatever cell it is aimed at")
  ok(screen.held == nil, "with nothing left in hand")
end

-- ------------------------------------------------------------- what it won't do

do
  io.write("a shared page is not this save's to rearrange or empty\n")
  reset()
  otherCartHolding(mon("CHARMANDER", "A"))
  local save = newSave(2)
  local screen = screenOn(save)

  -- A POKeMON carried OUT of a shared page cannot SWAP with one in a cart box
  -- or in the party: the one it displaced would have to go back where the
  -- carried one came from, and that is a cell in somebody else's save.
  screen.pane = "box"
  screen.globalPage = 1
  screen.boxSlot = 1
  screen:grab()
  ok(screen.held ~= nil and screen.held.global, "one comes off the shared page")
  screen.pane = "party"
  screen.partySlot = 1
  said = {}
  screen:place()
  ok(screen.held ~= nil, "dropping it onto an occupied party row moves nothing")
  ok(#said == 1 and said[1].text:find("already"), "and says so")
  eq(#save.party, 2, "the party being exactly as it was")
  screen:returnHeld()
  eq(screen.global:count(), 1, "and B puts it back on the shared page")
  screen.pane = "box"

  -- no SORT
  menus = {}
  screen:openSortMenu()
  eq(#menus, 0, "SELECT opens no sort menu on a global page")
  screen.globalPage = nil
  screen:openSortMenu()
  ok(#menus == 1, "and still does on a cartridge box")

  -- no RELEASE
  screen.globalPage = 1
  screen.boxSlot = 1
  menus = {}
  screen:openActions()
  local labels = {}
  for _, item in ipairs(menus[1] and menus[1].items or {}) do
    labels[#labels + 1] = tostring(item.label)
  end
  eq(table.concat(labels, ","), "STATS,CANCEL",
    "START over a shared POKeMON offers no RELEASE")
  screen.globalPage = nil
  screen.game.save.currentBox = 1
  Boxes.ensure(screen.game.save)[1][1] = mon("RATTATA")
  screen.boxSlot = 1
  menus = {}
  screen:openActions()
  local ownLabels = {}
  for _, item in ipairs(menus[1] and menus[1].items or {}) do
    ownLabels[#ownLabels + 1] = tostring(item.label)
  end
  eq(table.concat(ownLabels, ","), "STATS,SEND,RELEASE,SORT,CANCEL",
    "and over one of this cartridge's it still does, beside SEND and the SORT "
    .. "that moved here off SELECT")
end

do
  io.write("a full GLOBAL BOX refuses, and says so\n")
  reset()
  local many = {}
  for i = 1, GlobalBox.CAPACITY do many[i] = mon("PIDGEY", "P" .. i) end
  otherCartHoldingList(many)
  local save = newSave(2)
  local screen = screenOn(save)
  eq(screen.global:count(), GlobalBox.CAPACITY, "four hundred is the cap")
  ok(screen.global:pages() == GlobalBox.MAX_PAGES,
    "and the last page is the last page: no twenty-first opens")

  screen.pane = "party"
  screen.partySlot = 1
  screen:grab()
  screen.pane = "box"
  screen.globalPage = GlobalBox.MAX_PAGES
  screen.boxSlot = 1
  said = {}
  screen:place()
  ok(screen.held ~= nil, "the POKeMON stays in hand")
  ok(#said == 1 and said[1].text:find("full"), "with the box saying it is full")
  eq(screen.globalPage, GlobalBox.MAX_PAGES,
    "and the page you are on is still a page, not a refusal read as one")
  eq(#save.party, 1, "the party still short of it while it is held")
  screen:returnHeld()
  eq(#save.party, 2, "until B puts it back")
end

do
  io.write("what GOLD sent is on the page, and RED says why it can't have it\n")
  reset()
  -- Three POKeMON GOLD put there: one RED knows, one Johto, one that knows a
  -- move RED never heard of.  All three are IN the box -- the box holds Gold's
  -- shape -- and RED's answer is about taking them OUT.
  otherCartHoldingList({
    mon("BULBASAUR", "FINE", 2),
    mon("CHIKORITA", "JOHTO", 2),
    mon("BULBASAUR", "NEWMOVE", 2, { { id = "CRUNCH" } }),
  })
  local screen = screenOn(newSave(1))
  screen.pane, screen.globalPage = "box", 1
  eq(screen.global:count(), 3, "all three are in the box, whatever RED thinks")

  -- the one it knows comes out, converted
  screen.boxSlot = 1
  screen:grab()
  ok(screen.held ~= nil and screen.held.mon.shape == "gen1",
    "the one RED knows comes out in RED's shape")
  eq(converted.toGen1, 1, "converted on the way out, which is where it belongs")
  screen:returnHeld()

  -- the Johto one does not, and says why
  screen.boxSlot = 2
  said = {}
  screen:grab()
  ok(screen.held == nil, "a Johto POKeMON stays in the box")
  ok(#said == 1 and said[1].text:find("RED"),
    "with RED's name on the refusal, because it is RED's rule")
  eq(screen.global:count(), 3, "and the box is untouched")

  -- so does the one with a move RED never heard of, for its own reason
  screen.boxSlot = 3
  said = {}
  screen:grab()
  ok(screen.held == nil, "nor does one knowing a move RED never heard of")
  ok(#said == 1 and said[1].text:find("move"), "which says so in its own words")

  -- and it is DRAWN rather than left as an empty-looking cell that refuses
  ok(screen:monDrawnAt("box", 2) ~= nil,
    "a POKeMON RED has no entry for is still in the cell")
  drawn = {}
  screen:drawGrid()
  local question = false
  for _, entry in ipairs(drawn) do
    if entry.text == "?" then question = true end
  end
  ok(question, "drawn as a question mark, because RED has no icon for it")

  -- and START over it offers no STATS: the summary draws from a species
  -- record, and there isn't one
  screen.boxSlot = 2
  menus = {}
  screen:openActions()
  local labels = {}
  for _, item in ipairs(menus[1] and menus[1].items or {}) do
    labels[#labels + 1] = tostring(item.label)
  end
  eq(table.concat(labels, ","), "CANCEL",
    "and no STATS row for a POKeMON this game has no entry for")
end

do
  io.write("SELECT marks, and A moves the whole mark\n")
  reset()
  local save = newSave(1)
  local screen = screenOn(save)
  local boxes = Boxes.ensure(save)
  local first = { mon("PIDGEY", "A"), mon("RATTATA", "B"), mon("PIKACHU", "C") }
  for i, each in ipairs(first) do boxes[1][i] = each end
  screen.pane, screen.boxSlot = "box", 1

  -- SORT is off SELECT: it lives in the popup now, and SELECT marks
  menus = {}
  screen:toggleMark()
  eq(#menus, 0, "SELECT opens no menu any more")
  ok(screen:markedAt(1), "it marks the cell the cursor is on")
  screen:toggleMark()
  ok(not screen:markedAt(1), "and marks it again to unmark it")

  screen:toggleMark()
  screen.boxSlot = 2
  screen:toggleMark()
  screen.boxSlot = 3
  screen:toggleMark()
  eq(#screen.picked, 3, "three marked")

  -- the marks survive a box change, which is the whole point
  screen:changeBox(2)
  eq(save.currentBox, 3, "walk to BOX 3")
  eq(#screen.picked, 3, "with the marks still held")
  ok(not screen:markedAt(1), "and nothing on THIS page drawn as marked")

  screen.boxSlot = 1
  ok(screen:placeMarks(), "A puts all three down here")
  eq(#boxes[1], 0, "BOX 1 is empty")
  eq(#boxes[3], 3, "and BOX 3 has them")
  eq(#screen.picked, 0, "with the marks cleared")

  -- every one of them, once, and the same ones
  local seen = {}
  for _, each in ipairs(boxes[3]) do seen[each.nickname] = (seen[each.nickname] or 0) + 1 end
  eq(seen.A .. seen.B .. seen.C, "111", "each exactly once")
end

do
  io.write("a full box takes none of them, and B clears the marks\n")
  reset()
  local save = newSave(1)
  local screen = screenOn(save)
  local boxes = Boxes.ensure(save)
  for i = 1, 3 do boxes[1][i] = mon("PIDGEY", "M" .. i) end
  for i = 1, Boxes.CAPACITY - 1 do boxes[2][i] = mon("RATTATA", "F" .. i) end

  screen.pane = "box"
  for cell = 1, 3 do screen.boxSlot = cell screen:toggleMark() end
  eq(#screen.picked, 3, "three marked in BOX 1")

  screen:changeBox(1)
  said = {}
  ok(not screen:placeMarks(), "BOX 2 has room for one and refuses all three")
  ok(#said == 1 and said[1].text:find("full"), "saying it is full")
  eq(#boxes[1], 3, "BOX 1 keeps all three")
  eq(#boxes[2], Boxes.CAPACITY - 1, "and BOX 2 is untouched -- not one moved")
  eq(#screen.picked, 3, "the marks are still held")

  ok(screen:clearMarks(), "B clears them")
  ok(not screen:clearMarks(), "and says so only while there were any")
end

do
  io.write("SEND is on the box popup, and it is the box's own\n")
  reset()
  local save = newSave(1)
  local screen = screenOn(save)
  local boxes = Boxes.ensure(save)
  local leaving = mon("BULBASAUR", "GOING")
  boxes[1][1] = leaving
  screen.pane, screen.boxSlot = "box", 1

  menus = {}
  screen:openActions()
  local labels = {}
  for _, item in ipairs(menus[1] and menus[1].items or {}) do
    labels[#labels + 1] = tostring(item.label)
  end
  eq(table.concat(labels, ","), "STATS,SEND,RELEASE,SORT,CANCEL",
    "the popup carries SEND and the SORT that came off SELECT")

  -- The party menu's SEND empties save.party.  Handing a BOXED POKeMON to
  -- that would deposit it and leave the original in the box -- one POKeMON in
  -- two places -- so this is the box's own move.
  screen:sendToGlobal(1)
  eq(#boxes[1], 0, "the POKeMON leaves the cartridge box")
  eq(screen.global:count(), 1, "and is in the GLOBAL BOX")
  eq(screen.global:at(1, 1).nickname, "GOING", "as itself, exactly once")

  -- and it is not offered ON a global page, where it already is
  screen.globalPage, screen.boxSlot = 1, 1
  menus = {}
  screen:openActions()
  local onGlobalLabels = {}
  for _, item in ipairs(menus[1] and menus[1].items or {}) do
    onGlobalLabels[#onGlobalLabels + 1] = tostring(item.label)
  end
  eq(table.concat(onGlobalLabels, ","), "STATS,CANCEL",
    "no SEND, no RELEASE and no SORT on a page this save does not own")
end

do
  io.write("nothing a menu covers claims true colour\n")
  -- markTrueColor does not copy anything: it says "this RECTANGLE is true
  -- colour" and the renderer re-blits whatever is in it RAW at composite time,
  -- after the whole frame is drawn.  A menu over the grid is therefore
  -- re-blitted raw wherever it overlaps an icon's claim -- and a Gen 1 menu is
  -- black on WHITE while DARK inverts the page around it, so the overlap came
  -- back as white blocks in a grid, exactly the size of the cells underneath.
  -- Reported as "anything that goes over a POKeMON gets inverted".
  reset()
  local save = newSave(1)
  local screen, game = screenOn(save)
  Boxes.ensure(save)[1][1] = mon("BULBASAUR", "UNDER")

  local states = { screen }
  game.stack.states = states

  ok(not screen:coveredByOverlay(0, 0, 32, 24),
    "with nothing above it, an icon claims its rectangle")

  -- a Menu is a stack state with its own tile geometry (src/ui/Menu.lua:19)
  states[2] = { tx = 9, ty = 10, tw = 11, th = 8 }
  ok(screen:coveredByOverlay(9 * 8, 10 * 8, 32, 24),
    "an icon the menu overlaps does not")
  ok(not screen:coveredByOverlay(0, 0, 16, 16),
    "while one it does not reach still does")

  -- a state above that cannot be measured covers everything: better to lose
  -- the icons' colours for as long as it is open than to leave a white block
  states[2] = { something = true }
  ok(screen:coveredByOverlay(0, 0, 16, 16),
    "and something above that cannot be measured is treated as covering all")

  -- and the icon draw asks: the rectangle it would claim is the one it hands
  -- the matte and the mark, so both agree or neither happens
  screen.artRect = function() return { w = 16, h = 16 } end
  states[2] = nil
  ok(screen:artRectFor({ species = "BULBASAUR" }, 0, 0) ~= nil,
    "with nothing above, the icon claims its art rectangle")
  states[2] = { tx = 0, ty = 0, tw = 20, th = 18 }
  ok(screen:artRectFor({ species = "BULBASAUR" }, 0, 0) == nil,
    "and under a menu it claims nothing -- no white block for the menu to "
    .. "come back as")
end

-- ------------------------------------------------------- the CHANGE BOX list

do
  io.write("CHANGE BOX lists the shared pages after the cartridge's\n")
  reset()
  otherCartHolding(mon("CHARMANDER", "A"))
  local screen = screenOn(newSave(1))
  screen.globalPage = 1
  menus = {}
  screen:openBoxList()
  local items = menus[1] and menus[1].items or {}
  eq(#items, BOX_COUNT + 1, "twelve boxes and the one global page")
  eq(tostring(items[BOX_COUNT + 1].label), "*GLOBAL 1  1/20",
    "the open page starred, and counted")
  eq(tostring(items[1].label):sub(1, 1), " ",
    "with no cartridge box claiming to be open at the same time")
  eq(menus[1].index, BOX_COUNT + 1, "and the list opens on the page you are on")

  -- choosing a cartridge box leaves the global pages
  items[3].onSelect()
  ok(screen.globalPage == nil, "choosing BOX 3 leaves the shared pages")
  eq(screen.game.save.currentBox, 3, "for BOX 3")
end

-- --------------------------------------------------- and it can be turned off

do
  io.write("with the feature off the screen is the one it always was\n")
  reset()
  otherCartHolding(mon("CHARMANDER", "A"))
  mod.stored.globalBox = false
  local screen = screenOn(newSave(1))
  ok(screen.global == nil, "no session is opened")
  screen.game.save.currentBox = BOX_COUNT
  screen:changeBox(1)
  ok(screen.globalPage == nil, "and the box ring is the cartridge's twelve")
  eq(screen.game.save.currentBox, 1, "wrapping from BOX 12 to BOX 1")
  menus = {}
  screen:openBoxList()
  eq(#(menus[1].items or {}), BOX_COUNT, "with twelve rows in CHANGE BOX")
end

-- ------------------------- several out of the GLOBAL BOX, which is a QUEUE
--
-- Reported as "when trying to move multiple mon from global box it says
-- 'that can't be sent'", and the message was the smallest part of it.
--
-- A mark records where the POKeMON is.  For a cartridge box that is enough:
-- Red keeps its arrangement beside the box, so a cell is a place and taking
-- one POKeMON out leaves every other cell where it was.  The GLOBAL BOX is
-- not a box, it is a QUEUE -- `Session:take` withdraws and rebuilds the view,
-- and the view closes up, so cell 2 becomes cell 1 and cell 3 becomes cell 2.
--
-- Taking three marks in a row by their recorded cells therefore took the
-- first one, then whatever had MOVED INTO cell 2, then ran off the end of
-- what was left -- which answers `empty_cell`, which `refusalText` had no
-- sentence for and fell through to "That can't be sent".
--
-- So the wrong POKeMON came out before the message ever appeared, and that is
-- the half worth asserting: the three that arrive are the three that were
-- marked, by name.

do
  io.write("three out of the GLOBAL BOX are the three that were marked\n")
  reset()
  otherCartHoldingList({ mon("CHARMANDER", "ONE"), mon("SQUIRTLE", "TWO"),
                         mon("PIDGEY", "THREE") })
  local save = newSave(1)
  local screen = screenOn(save)
  local boxes = Boxes.ensure(save)

  eq(screen.global:count(), 3, "three are in the GLOBAL BOX")
  screen.pane, screen.globalPage = "box", 1
  for cell = 1, 3 do screen.boxSlot = cell screen:toggleMark() end
  eq(#screen.picked, 3, "and all three are marked")

  screen.globalPage, save.currentBox = nil, 1
  said = {}
  ok(screen:placeMarks(), "they move into BOX 1")
  eq(#said, 0, "with nothing refused")
  eq(#boxes[1], 3, "all three arrive")

  local names = {}
  for _, each in ipairs(boxes[1]) do names[tostring(each.nickname)] = true end
  ok(names.ONE and names.TWO and names.THREE,
    "and they are ONE, TWO and THREE -- not the same one three times, and "
    .. "not whatever the queue closed up into their cells")
  eq(screen.global:count(), 0, "the GLOBAL BOX is empty")
  eq(#screen.picked, 0, "and the marks are spent")
end

do
  io.write("and marking SOME of them leaves the right one behind\n")
  reset()
  otherCartHoldingList({ mon("CHARMANDER", "ONE"), mon("SQUIRTLE", "TWO"),
                         mon("PIDGEY", "THREE") })
  local save = newSave(1)
  local screen = screenOn(save)
  local boxes = Boxes.ensure(save)

  screen.pane, screen.globalPage = "box", 1
  screen.boxSlot = 1 screen:toggleMark()
  screen.boxSlot = 2 screen:toggleMark()
  eq(#screen.picked, 2, "the first two are marked")

  screen.globalPage, save.currentBox = nil, 1
  said = {}
  ok(screen:placeMarks(), "and they move")
  eq(#said, 0, "with nothing refused")
  eq(#boxes[1], 2, "two arrive")

  local names = {}
  for _, each in ipairs(boxes[1]) do names[tostring(each.nickname)] = true end
  ok(names.ONE and names.TWO, "ONE and TWO, the two that were marked")
  eq(screen.global:count(), 1, "one is left in the GLOBAL BOX")
  local left = screen.global:at(1, 1)
  eq(left and tostring(left.nickname), "THREE",
    "and it is THREE -- the one nobody marked")
end

-- ----------------------------- and a cell that really is gone says so plainly
--
-- The fallback that turned an empty cell into "That can't be sent" is a
-- sentence about the POKeMON, and the POKeMON was never the problem.

do
  io.write("an empty cell has a sentence of its own now\n")
  local text = GlobalBox.refusalText("empty_cell")
  ok(text ~= GlobalBox.REFUSALS.not_a_mon,
    "empty_cell no longer falls through to \"That can't be sent\"")
  for line in tostring(text):gmatch("[^\n\f]+") do
    ok(#line <= 18, ("%q fits the text box (%d columns)"):format(line, #line))
  end
end

-- ---------------------------------------------- SEND, on the PARTY half too
--
-- Reported as "when you select a party member in box send isn't an option",
-- and the row was left off on purpose.  The reason was real but was about the
-- party MENU's send, which empties save.party directly and would leave this
-- screen's partyRow list describing a POKeMON that is not in the party -- the
-- bookkeeping that keeps the visual order and the BATTLE order the same list.
--
-- Which is a reason for the party half to have its OWN send, not for it to
-- have none: the cursor already lifts POKeMON out of the party correctly, and
-- `partyTake` is what it calls.  So the row list is asserted here as well as
-- the move, because that list is the whole of what was being protected.

local function labelsOf(menu)
  local out = {}
  for _, item in ipairs(menu and menu.items or {}) do
    out[#out + 1] = tostring(item.label)
  end
  return table.concat(out, ",")
end

local function rowNamed(menu, want)
  for _, item in ipairs(menu and menu.items or {}) do
    if tostring(item.label) == want then return item end
  end
  return nil
end

do
  io.write("SEND is on the party half of the box popup\n")
  reset()
  local save = newSave(0)
  save.party[1] = mon("BULBASAUR", "STAYS")
  save.party[2] = mon("CHARMANDER", "GOING")
  local screen = screenOn(save)
  screen.pane, screen.partySlot = "party", 2

  menus, said = {}, {}
  screen:openActions()
  eq(labelsOf(menus[1]), "STATS,SEND,CANCEL",
    "a party member's popup carries SEND -- RELEASE and SORT are the box's")

  -- It ASKS, where the box's SEND does not.  Inside the box a send is a move
  -- between pages; out of the party it is a POKeMON leaving your team, which
  -- is the same line the party menu's own row draws.
  rowNamed(menus[1], "SEND").onSelect()
  ok(said[1] and said[1].text:find("GLOBAL BOX"), "choosing it asks first")
  ok(said[1] and said[1].opts and said[1].opts.defaultNo,
    "with NO under the cursor")
  eq(#save.party, 2, "and nothing has moved while it is asking")

  said[1].opts.choice(true)
  eq(#save.party, 1, "YES takes it out of the party")
  eq(save.party[1].nickname, "STAYS", "leaving the one that stayed")
  eq(screen.global:count(), 1, "and it is in the GLOBAL BOX")
  eq(screen.global:at(1, 1).nickname, "GOING", "as itself, exactly once")
  ok(screen.partyTouched, "the party is marked changed, so the screen saves it")

  -- the bookkeeping the row was once left off to protect
  eq(#(screen.partyRow or {}), #save.party,
    "and the row list is as long as the party -- not one entry describing a "
    .. "POKeMON that has left")
end

do
  io.write("and NO leaves the party exactly as it was\n")
  reset()
  local save = newSave(0)
  save.party[1] = mon("BULBASAUR", "STAYS")
  save.party[2] = mon("CHARMANDER", "GOING")
  local screen = screenOn(save)
  screen.pane, screen.partySlot = "party", 2

  menus, said = {}, {}
  screen:openActions()
  rowNamed(menus[1], "SEND").onSelect()
  said[1].opts.choice(false)
  eq(#save.party, 2, "both are still in the party")
  eq(screen.global:count(), 0, "and the GLOBAL BOX is empty")
end

do
  io.write("the last POKeMON is refused, in the pick-up's own words\n")
  reset()
  local save = newSave(0)
  save.party[1] = mon("BULBASAUR", "ALONE")
  local screen = screenOn(save)
  screen.pane, screen.partySlot = "party", 1

  menus, said = {}, {}
  screen:openActions()
  ok(rowNamed(menus[1], "SEND") ~= nil,
    "the row is still offered -- the party menu's is too, and refusing on the "
    .. "press is where the sentence can be said")
  rowNamed(menus[1], "SEND").onSelect()
  ok(said[1] and said[1].text:find("last"),
    "and pressing it says you can't deposit the last POKeMON")
  ok(not (said[1].opts and said[1].opts.choice),
    "with no question attached -- it is a refusal, not an offer")
  eq(#save.party, 1, "the party is untouched")
  eq(screen.global:count(), 0, "and nothing reached the GLOBAL BOX")
end

io.write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
