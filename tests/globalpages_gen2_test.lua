-- The GLOBAL pages on Gold's box screen, and the conversion that lets them
-- hold the same POKeMON Red's box screen shows.
--
-- The Gen 1 half of this is globalpages_test.lua and the store underneath both
-- is globalbox_test.lua.  What is only true HERE is the crossing: the box keeps
-- each POKeMON in its OWN generation's shape, so Gold converts NOTHING on the
-- way in and converts on the way out only for a POKeMON that Red put there.
-- Which is what makes the feature usable in game at all -- the version that
-- kept one shape had to mount a whole Gen 1 dataset behind a keypress, and
-- could not hold a Johto POKeMON for a player who has only Gen 2 games.
--
-- Run:  luajit tests/globalpages_gen2_test.lua

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
--
-- The cart's own storage surface, kept behaviourally identical to
-- src/core/gen2/Boxes.lua the way billsbox2_test.lua keeps it.

local NUM_BOXES, PER_BOX, PARTY_SIZE = 14, 20, 6

local Boxes = { NUM_BOXES = NUM_BOXES, MONS_PER_BOX = PER_BOX,
                PARTY_SIZE = PARTY_SIZE }
function Boxes.box(save, index)
  save.boxes = save.boxes or {}
  save.boxes[index] = save.boxes[index] or {}
  return save.boxes[index]
end
function Boxes.count(save, index) return #Boxes.box(save, index) end
function Boxes.isFull(save, index) return Boxes.count(save, index) >= PER_BOX end
function Boxes.name(save, index) return "BOX" .. index end
function Boxes.enterBox(mon)
  mon.entered = true
  mon.status = nil
  mon.hp = mon.isEgg and 0 or (mon.maxHp or mon.hp)
  return mon
end
function Boxes.release(save, index, slot)
  local box = Boxes.box(save, index)
  if not box[slot] then return false end
  return true, table.remove(box, slot)
end
function Boxes.canUsePc(save) return true end
package.loaded["src.core.gen2.Boxes"] = Boxes

local Mail = { PARTY_LENGTH = 6 }
function Mail.monHoldsMail(mon) return mon and mon.mail == true end
function Mail.removeSlot(save, slot)
  if save.mail then table.remove(save.mail, slot) end
end
function Mail.state(save) save.mailState = save.mailState or { party = {} }
  return save.mailState end
package.loaded["src.core.gen2.Mail"] = Mail

package.loaded["src.ui.gen2.PartyMenu"] = {
  new = function() return { clock = 0, drawIcon = function() end } end,
}

local prints
package.loaded["src.ui.gen2.Chrome"] = {
  DEFAULT_BOX_PALETTE = { { 255, 255, 255 }, { 255, 255, 255 },
                          { 255, 255, 255 }, { 0, 0, 0 } },
  clear = function() end,
  box = function() end,
  textbox = function() end,
  printThrough = function(text, tx, ty)
    prints[#prints + 1] = { text = tostring(text), tx = tx, ty = ty }
  end,
  printRightThrough = function(text, txEnd, ty)
    prints[#prints + 1] = { text = tostring(text), tx = txEnd, ty = ty,
                            right = true }
  end,
  letterbox = function() end,
  fitScale = function() return 1 end,
  fitOrigin = function() return 0, 0 end,
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
  get = function() return "gold" end,
  generation = function() return 2 end,
}

_G.love = _G.love or {}
love.graphics = {
  setColor = function() end, getColor = function() return 1, 1, 1, 1 end,
  rectangle = function() end, push = function() end, pop = function() end,
  translate = function() end, scale = function() end, setShader = function() end,
}

-- ---- Convert, standing in for src/online/Convert.lua
--
-- The real one is the Time Capsule's and is asserted against the engine below;
-- what this double has to be faithful about is its SHAPE -- a fresh table out,
-- a reason string on a refusal -- because that is the contract the pane is
-- built on.

local converted = { toGen1 = 0, toGen2 = 0 }
local Convert = {}
function Convert.refusalFor(mon, gen2Data, gen1Data)
  if type(mon) ~= "table" then return "not_a_mon" end
  if mon.isEgg then return "is_egg" end
  if not (gen1Data and gen1Data.pokemon and gen1Data.pokemon[mon.species]) then
    return "species_too_new"
  end
  if mon.mail then return "has_mail" end
  for _, mv in ipairs(mon.moves or {}) do
    if not (gen1Data.moves and gen1Data.moves[mv.id]) then return "move_too_new" end
  end
  return nil
end
function Convert.toGen1(mon, gen2Data, gen1Data)
  local reason = Convert.refusalFor(mon, gen2Data, gen1Data)
  if reason then return nil, reason end
  converted.toGen1 = converted.toGen1 + 1
  return { species = mon.species, nickname = mon.nickname, level = mon.level,
           hp = mon.hp, maxHp = mon.maxHp, moves = mon.moves, shape = "gen1",
           entered = mon.entered }
end
function Convert.toGen2(mon, gen1Data, gen2Data)
  if type(mon) ~= "table" then return nil, "not_a_mon" end
  converted.toGen2 = converted.toGen2 + 1
  return { species = mon.species, nickname = mon.nickname, level = mon.level,
           hp = mon.hp, maxHp = mon.maxHp, moves = mon.moves, shape = "gen2",
           sawGen1Data = gen1Data ~= nil }
end
package.loaded["src.online.Convert"] = Convert

-- ---- Trade, standing in for the dataset mount
--
-- `mounts` is the number that matters: a Gen 2 cartridge must pay for the Gen
-- 1 dataset ONCE per session and never on a withdrawal.
local mounts = 0
local gen1Tree = {
  pokemon = { BULBASAUR = {}, CHARMANDER = {}, SQUIRTLE = {}, PIDGEY = {} },
  moves = { TACKLE = {} },
  growth_rates = {},
}
package.loaded["src.online.Trade"] = {
  gameIsLive = function() return false end,
  withDataset = function(version, fn)
    if version ~= "red" then return nil, version .. " is not imported" end
    mounts = mounts + 1
    return fn(gen1Tree)
  end,
}

-- ---- the saves on this installation

local SaveSerializer = {}
do
  local store, n = {}, 0
  function SaveSerializer.encode(value) n = n + 1; store["s" .. n] = value; return "s" .. n end
  function SaveSerializer.decode(body) return store[body] end
end
package.loaded["src.core.SaveSerializer"] = SaveSerializer

local MOD_ID = "gen1_bills_box"
local disk = {}
package.loaded["src.core.SaveData"] = {
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
  getCart = function() return "wildcrystal" end,
  activeCartSlot = function() return "slot1" end,
  activeSlot = function() return "slot1" end,
}

-- ---- the mod

local modSaveTable = {}
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
mod.exports, mod.find = {}, function() return nil end
mod.hooks = { wrap = function() end }
mod.events = { on = function() end }
mod.ui = { push = function() end }

local GlobalBox = assert(load(slurp("globalbox.lua"), "@globalbox.lua"))()
local Pane = assert(load(slurp("globalpane.lua"), "@globalpane.lua"))()(mod, GlobalBox)
local Screen = assert(load(slurp("gen2screen.lua"), "@gen2screen.lua"))()(mod,
  function()
    if mod.stored.globalBox == false then return nil end
    return Pane
  end)

ok(type(Screen) == "table" and type(Screen.new) == "function",
  "Gold's box screen builds with a GLOBAL BOX pane behind it")

-- ------------------------------------- the premise the cheap direction rests on

do
  io.write("a withdrawal onto Gold needs no Gen 1 dataset, and the engine says so\n")
  local engine
  for _, prefix in ipairs({ "..", "../..", "../../..", "../../../.." }) do
    local handle = io.open(prefix .. "/gen1recomp/src/online/Convert.lua")
      or io.open(prefix .. "/bryanthaboi/gen1recomp/src/online/Convert.lua")
    if handle then engine = handle:read("*a") handle:close() break end
  end
  if os.getenv("GEN1RECOMP") then
    local handle = io.open(os.getenv("GEN1RECOMP") .. "/src/online/Convert.lua")
    if handle then engine = handle:read("*a") handle:close() end
  end
  if not engine then
    io.write("  (skipped: no engine tree to read Convert.lua from)\n")
  else
    -- toGen2 reads gen1Data ONLY to recompute stats the stored POKeMON does
    -- not carry.  That is what lets Gold withdraw without mounting Red, and
    -- it is why the deposit side runs Stats.ensure.  If this guard ever goes,
    -- every withdrawal starts paying for a dataset mount.
    local body = engine:match("function Convert%.toGen2.-\nend\n")
    ok(body ~= nil, "Convert.toGen2 is where it was")
    ok(body and body:find("if not %(oldStats and oldStats%.hp%) then") ~= nil,
      "and reaches for the Gen 1 dataset only when the stats are missing")
    local one = engine:match("function Convert%.toGen1.-\nend\n")
    ok(one and one:find("gen1Data%.pokemon%[mon%.species%]") ~= nil,
      "while toGen1 needs it outright, which is the direction that pays")
  end
end

-- ---- saves and POKeMON

local nextId = 0
local function mon(species, nickname, extra)
  nextId = nextId + 1
  local out = { id = nextId, species = species or "BULBASAUR", level = 5,
                hp = 20, maxHp = 20, nickname = nickname,
                moves = { { id = "TACKLE" } } }
  for key, value in pairs(extra or {}) do out[key] = value end
  return out
end

local function newSave(partyN)
  local save = { party = {}, boxes = {}, currentBox = 1, mail = {} }
  for i = 1, NUM_BOXES do Boxes.box(save, i) end
  for _ = 1, partyN or 0 do save.party[#save.party + 1] = mon() end
  return save
end

local function greenCartHolding(list)
  local bucket = { format = GlobalBox.FORMAT, origin = "green", seq = 0,
                   mons = {}, claims = {} }
  for _, each in ipairs(list) do
    bucket.seq = bucket.seq + 1
    each.gbId = "green#" .. bucket.seq
    each.gbSent = bucket.seq
    bucket.mons[#bucket.mons + 1] = each
  end
  disk["cart:wildgreen/slot1"] = SaveSerializer.encode({
    modData = { [MOD_ID] = { [GlobalBox.KEY] = bucket } } })
  return bucket
end

local function reset()
  for key in pairs(modSaveTable) do modSaveTable[key] = nil end
  for key in pairs(disk) do disk[key] = nil end
  prints = {}
  mod.stored = {}
  converted.toGen1, converted.toGen2 = 0, 0
end

local function screenOn(save)
  local game = { save = save, data = { pokemon = { BULBASAUR = {},
                                                   CHARMANDER = {},
                                                   SQUIRTLE = {},
                                                   PIDGEY = {},
                                                   CHIKORITA = {} } },
                 input = { wasPressed = function() return false end,
                           isDown = function() return false end },
                 stack = { push = function() end, pop = function() end } }
  return Screen.new(game, { save = save })
end

-- ------------------------------------------------------ the header keeps going

do
  io.write("the box list keeps going past BOX 14\n")
  reset()
  local screen = screenOn(newSave(2))
  ok(screen.global ~= nil, "the screen opened a GLOBAL BOX session")
  screen.boxIndex = NUM_BOXES
  screen:changeBox(1)
  eq(screen.globalPage, 1, "RIGHT off the last box lands on GLOBAL 1")
  eq(screen.boxIndex, NUM_BOXES, "leaving the cart's open box where it was")
  ok(screen.save.currentBox <= NUM_BOXES,
    "and never writing a fourteen-plus-one into the cart's own field")
  screen:changeBox(1)
  ok(screen.globalPage == nil, "and the ring closes back onto BOX 1")
  eq(screen.boxIndex, 1, "there")
end

-- -------------------------------------- Wild Green's POKeMON, seen from Gold

do
  io.write("what Wild Green sent is on the page, in Gold's shape when taken\n")
  reset()
  greenCartHolding({ mon("CHARMANDER", "EMBER") })
  local save = newSave(2)
  local screen = screenOn(save)
  screen.globalPage, screen.pane, screen.boxSlot = 1, "box", 1

  local shown = screen:monDrawnAt("box", 1)
  ok(shown ~= nil and shown.nickname == "EMBER",
    "the grid draws it without converting anything")
  eq(converted.toGen2, 0, "so drawing a page costs no conversion at all")
  eq(mounts, 0, "and no dataset mount")

  prints = {}
  screen:drawHeader()
  local name, count
  for _, entry in ipairs(prints) do
    if entry.right then count = entry.text else name = entry.text end
  end
  eq(name, "GLOBAL 1", "the header names the page")
  eq(count, "1/20", "and counts what is on it")

  -- out of the box and into the party: THIS is where Gold converts
  screen:grab()
  ok(screen.held ~= nil, "it comes out")
  eq(screen.held.mon.shape, "gen2", "in Gold's shape")
  eq(converted.toGen2, 1, "converted once")
  eq(mounts, 0,
    "and STILL with no dataset mount, which is what makes this usable in game")
  ok(screen.held.mon.sawGen1Data == false,
    "Convert being handed no Gen 1 tree, because the stored stats stand in")

  screen.pane, screen.partySlot = "party", 3
  screen:place()
  ok(screen.held == nil, "and lands in the party")
  eq(#save.party, 3, "which is one longer")
  eq(screen.global:count(), 0, "the shared box being one shorter")
  ok(GlobalBox.bucketsIn(modSaveTable)[1].claims["green#1"] == true,
    "by a claim in Gold's own save -- Wild Green's is not Gold's to write")
end

-- --------------------------------------------------- and sending one the other way

do
  io.write("a POKeMON sent FROM Gold is stored in Red's shape\n")
  reset()
  local save = newSave(3)
  local screen = screenOn(save)
  local leaving = save.party[1]
  screen.pane, screen.partySlot = "party", 1
  screen:grab()
  ok(screen.held ~= nil, "picked up out of the party")

  screen.pane, screen.globalPage, screen.boxSlot = "box", 1, 9
  screen:place()
  ok(screen.held == nil, "and put down on GLOBAL 1")
  eq(screen.boxSlot, 1, "in the first free cell, the cursor following it")
  eq(converted.toGen1, 0, "with nothing converted on the way in")
  eq(mounts, 0, "and no dataset mounted -- there is nothing to mount one for")

  local bucket = GlobalBox.bucketsIn(modSaveTable)[1]
  eq(#bucket.mons, 1, "the POKeMON is in this save's own bucket")
  eq(GlobalBox.genOf(bucket.mons[1]), 2, "in Gold's own shape, stamped as such")
  ok(bucket.mons[1].entered,
    "with the cart's into-storage tail run on it before it was copied")
  eq(#save.party, 2, "and out of the party")
  eq(Boxes.count(save, 1), 0, "without touching a cartridge box")

  -- the mount is paid for ONCE
  -- and a deposit aimed at an OCCUPIED cell still lands: the pages have no
  -- gaps, so the first free cell is the only place a deposit can go, and the
  -- cursor moving there is what says so
  -- The row the first one left stays empty for as long as the screen is open,
  -- so the second is picked up out of row 2.
  screen.pane, screen.partySlot = "party", 2
  screen:grab()
  ok(screen.held ~= nil, "a second POKeMON comes out of the party")
  screen.pane, screen.globalPage, screen.boxSlot = "box", 1, 1
  screen:place()
  eq(screen.boxSlot, 2, "and lands in the cell after the first, not on top of it")
  eq(screen.global:count(), 2, "with both of them in the box")
  eq(mounts, 0, "and still nothing mounted")
end

-- ------------------------------------------------------------ the refusals

do
  io.write("Gold puts GOLD's POKeMON in, Johto ones included\n")
  reset()
  local save = newSave(3)
  save.party[1] = mon("CHIKORITA", "JOHTO")
  save.party[2] = mon("BULBASAUR", "MAILED", { mail = true })
  save.party[3] = mon("BULBASAUR", "NEW", { moves = { { id = "CRUNCH" } } })
  local screen = screenOn(save)

  -- The box holds Gold's shape, so there is nothing for the deposit to refuse
  -- for being too new.  A player whose games are ALL Gen 2 could not put a
  -- Johto POKeMON in at all while the box kept one shape, which was most of
  -- what such a player has.
  local reasons = {}
  for row = 1, 3 do
    reasons[#reasons + 1] = tostring(Pane.wouldRefuse(screen.game, save.party[row]))
  end
  eq(table.concat(reasons, ","), "nil,has_mail,nil",
    "a Johto POKeMON and one knowing a Gen 2 move both go in; only MAIL does "
    .. "not, and that is Gold's own storage rule")
  ok(GlobalBox.refusalText("has_mail") ~= GlobalBox.REFUSALS.not_a_mon,
    "has_mail has a line of its own to print")

  screen.pane, screen.partySlot = "party", 1
  screen:grab()
  screen.pane, screen.globalPage, screen.boxSlot = "box", 1, 1
  screen:place()
  ok(screen.held == nil, "the Johto POKeMON goes in")
  eq(screen.global:count(), 1, "and is in the box")
  eq(screen.global:at(1, 1).species, "CHIKORITA", "as itself")
  eq(GlobalBox.genOf(screen.global:at(1, 1)), 2, "in Gold's shape")
  eq(converted.toGen1, 0, "with Convert never called")

  -- and it comes back OUT on Gold unchanged, because it never left Gold's
  -- shape: a POKeMON sent to yourself is not a POKeMON put through a trade
  screen.boxSlot = 1
  screen:grab()
  ok(screen.held ~= nil, "it comes back out")
  eq(screen.held.mon.species, "CHIKORITA", "still a CHIKORITA")
  eq(converted.toGen2, 0, "and with no conversion on the way out either")

  -- what RED will not take is asked when RED takes it, not here
  eq(Pane.refusalForTaking(screen.game, { species = "CHIKORITA", gbGen = 2 }),
     nil, "and Gold has no reason to refuse its own")
end

-- ------------------------------------------------------- what it will not do

do
  io.write("a shared page is not Gold's to rearrange or empty either\n")
  reset()
  greenCartHolding({ mon("CHARMANDER", "A") })
  local save = newSave(3)
  local screen = screenOn(save)

  -- A POKeMON carried out of a shared page cannot SWAP with one in a cart box
  -- or in the party: the one it displaced would have to go back where the
  -- carried one came from, and that is a cell in somebody else's save.
  screen.pane, screen.globalPage, screen.boxSlot = "box", 1, 1
  screen:grab()
  ok(screen.held ~= nil and screen.held.global, "one comes off the shared page")
  screen.pane, screen.partySlot = "party", 1
  screen.message = nil
  screen:place()
  ok(screen.held ~= nil, "dropping it onto an occupied party row moves nothing")
  ok(screen.message and screen.message:find("already"), "and says so")
  eq(#save.party, 3, "the party being exactly as it was")
  screen:returnHeld()
  eq(screen.global:count(), 1, "and B puts it back on the shared page")

  screen.pane, screen.globalPage, screen.boxSlot = "box", 1, 1
  screen:openSort()
  ok(screen.sortMenu == nil, "SELECT opens no sort menu on a global page")
  screen.globalPage = nil
  Boxes.box(save, 1)[1] = mon("PIDGEY")
  Boxes.box(save, 1)[2] = mon("PIDGEY")
  screen.boxIndex = 1
  screen:openSort()
  ok(screen.sortMenu ~= nil, "and still does on a cartridge box")

  -- RELEASE is off the menu, and off the road behind it
  screen.globalPage, screen.pane, screen.boxSlot = 1, "box", 1
  screen.actions = nil
  screen:openActions()
  local labels = {}
  for _, item in ipairs((screen.actions or {}).items or {}) do
    labels[#labels + 1] = tostring(item.label)
  end
  eq(table.concat(labels, ","), "STATS,CANCEL", "no RELEASE row is offered")
  screen:doRelease()
  eq(screen.global:count(), 1, "and calling it anyway releases nothing")
end

do
  io.write("SELECT marks on Gold too, and A moves the whole mark\n")
  reset()
  local save = newSave(1)
  local screen = screenOn(save)
  for i, sp in ipairs({ "PIDGEY", "PIDGEY", "PIDGEY" }) do
    Boxes.box(save, 1)[i] = mon(sp, "M" .. i)
  end
  screen.pane, screen.boxIndex, screen.boxSlot = "box", 1, 1

  screen:toggleMark()
  ok(screen:markedAt(1), "SELECT marks the cell the cursor is on")
  screen:toggleMark()
  ok(not screen:markedAt(1), "and marks it again to unmark it")

  for cell = 1, 3 do screen.boxSlot = cell screen:toggleMark() end
  eq(#screen.picked, 3, "three marked")

  screen.boxIndex = 4
  eq(#screen.picked, 3, "the marks survive a box change")
  screen.boxSlot = 1
  ok(screen:placeMarks(), "A puts all three down here")
  eq(Boxes.count(save, 1), 0, "BOX 1 is empty")
  eq(Boxes.count(save, 4), 3, "and BOX 4 has them")
  eq(#screen.picked, 0, "with the marks cleared")

  -- a full box takes none of them rather than as many as fit
  for cell = 1, 3 do screen.boxSlot = cell screen:toggleMark() end
  for i = 1, PER_BOX - 1 do Boxes.box(save, 6)[i] = mon("RATTATA", "F" .. i) end
  screen.boxIndex = 6
  screen.message = nil
  ok(not screen:placeMarks(), "a box with room for one refuses all three")
  ok(screen.message and screen.message:find("full"), "saying it is full")
  eq(Boxes.count(save, 4), 3, "and not one of them moved")
  ok(screen:clearMarks(), "B clears the marks")
end

do
  io.write("SEND is on Gold's box popup, and it is the box's own\n")
  reset()
  local save = newSave(1)
  local screen = screenOn(save)
  local leaving = mon("BULBASAUR", "GOING")
  Boxes.box(save, 1)[1] = leaving
  screen.pane, screen.boxIndex, screen.boxSlot = "box", 1, 1

  screen.actions = nil
  screen:openActions()
  local labels = {}
  for _, item in ipairs((screen.actions or {}).items or {}) do
    labels[#labels + 1] = tostring(item.label)
  end
  eq(table.concat(labels, ","), "STATS,SEND,RELEASE,SORT,CANCEL",
    "the popup carries SEND and the SORT that came off SELECT")

  -- the party menu's SEND empties save.party; a BOXED POKeMON handed to that
  -- would be deposited AND left where it was
  screen:sendToGlobal(1)
  eq(Boxes.count(save, 1), 0, "the POKeMON leaves the cartridge box")
  eq(screen.global:count(), 1, "and is in the GLOBAL BOX")
  eq(screen.global:at(1, 1).nickname, "GOING", "as itself, exactly once")
end

-- ----------------------------------------------------------- and it can be off

do
  io.write("with the feature off Gold's box is the one it always was\n")
  reset()
  greenCartHolding({ mon("CHARMANDER", "A") })
  mod.stored.globalBox = false
  local screen = screenOn(newSave(2))
  ok(screen.global == nil, "no session is opened")
  screen.boxIndex = NUM_BOXES
  screen:changeBox(1)
  ok(screen.globalPage == nil, "and the ring is the cartridge's fourteen")
  eq(screen.boxIndex, 1, "wrapping from BOX 14 to BOX 1")
end

io.write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
