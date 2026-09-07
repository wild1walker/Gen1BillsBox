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
mod.save = {
  get = function(_, key) return modSaveTable[key] end,
  set = function(_, key, value) modSaveTable[key] = value end,
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
local function mon(species, nickname)
  nextId = nextId + 1
  return { id = nextId, species = species or "BULBASAUR", level = 5,
           hp = 20, maxHp = 20, nickname = nickname, moves = {}, dvs = {} }
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
  local game = {
    save = save, data = { pokemon = {}, text = {} },
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
  local bucket = GlobalBox.bucketOf(modSaveTable)
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
  ok(GlobalBox.bucketOf(modSaveTable).claims["crystal#1"] == true,
    "by a claim in THIS save, the other one being untouched")

  screen:returnHeld()
  eq(idsOnGlobal(screen), before, "B puts it back in the cell it came out of")
  eq(next(GlobalBox.bucketOf(modSaveTable).claims), nil,
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
  eq(table.concat(ownLabels, ","), "STATS,RELEASE,CANCEL",
    "and over one of this cartridge's it still does")
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

io.write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
