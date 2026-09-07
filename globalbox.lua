-- The GLOBAL BOX: one store of POKeMON that every cartridge can reach.
--
-- Deposit a POKeMON on Wild Green, withdraw it on Wild Crystal.  That is the
-- whole feature, and everything below is what it costs.
--
-- ------- where it lives, and why it is the only place it could
--
-- A save is not shared.  `mod.storage` is not shared either: its path is
-- `mod_storage/<gameVersion>/<playthroughId>/<modId>/...`
-- (src/mods/Storage.lua:93), so Red's storage and Crystal's are different
-- directories before the cart is even considered, and two playthroughs of the
-- same game are different again.  Save SLOTS are scoped per cart on top of
-- that (`cart_<id>`, src/core/SaveData.lua:913).  None of those can hold a box
-- two cartridges share.
--
-- `mod.cache` can.  It writes to `mod_cache/<modId>/<file>`
-- (src/mods/ImportAccess.lua:73) with no game version, no playthrough and no
-- cart anywhere in the path -- the engine calls it "installation-scoped
-- generated data, independent from Pokemon save slots" (src/mods/Loader.lua
-- :1463), which is exactly this.  Both carts pin the same bundles, so both
-- run this feature under the same mod id and read the same file.
--
-- Two consequences worth knowing rather than discovering:
--
--   * the id is the BUNDLE's, so the nightly channel (gen1_wild_ui_nightly)
--     keeps a different GLOBAL BOX from the stable one.  Deliberate: a
--     nightly is allowed to break, and a shared store it could corrupt is
--     the one thing that would take a stable save down with it.
--   * it is not a save.  It is not in a save slot, it does not roll back with
--     one, and RESTORE on a cartridge does not restore it.  A POKeMON in here
--     is somewhere else, which is the point.
--
-- ------- what may live in it
--
-- Gen 1 POKeMON, in Gen 1 shape, and nothing else.  Not a rule invented here:
-- it is the Time Capsule's, which the engine already implements and this
-- reuses whole (src/online/Convert.lua).  A Johto species, a Gen 2 move, a
-- held MAIL or an EGG is refused with the cartridge's own reason.
--
-- Storing ONE shape is what makes the box work at all.  A Gen 1 cart deposits
-- and withdraws with no conversion and needs no second dataset.  A Gen 2 cart
-- converts on the way in and on the way out, which needs a Gen 1 dataset
-- mounted -- the same requirement, through the same code, that the Time
-- Capsule already has.

local GlobalBox = {}

-- The cartridge's own box holds twenty, and a page that matched nothing would
-- be a page whose "full" a player has no feel for.
GlobalBox.PAGE = 20

-- Twenty pages is four hundred POKeMON, which is more than the twelve boxes
-- of a Gen 1 cartridge (240) and more than Gold's fourteen (280).  A cap
-- exists because this is one file that is rewritten whole; a box nobody can
-- fill is not worth the risk of a box that cannot be written.
GlobalBox.MAX_PAGES = 20
GlobalBox.CAPACITY = GlobalBox.PAGE * GlobalBox.MAX_PAGES

-- One file, rewritten whole.  Two cartridges cannot run at once, so there is
-- no locking to do -- but there IS a stale-copy hazard, which is why every
-- mutating call below re-reads before it writes rather than trusting a list
-- it was handed earlier.
GlobalBox.FILE = "globalbox"

GlobalBox.FORMAT = 1

-- ------- the rules, borrowed rather than restated

-- The reasons Convert.refusalFor answers with, in the cartridge's own voice.
-- `species_too_new` is the one a player meets: a Johto POKeMON cannot go in a
-- box a Gen 1 cartridge has to be able to open.
GlobalBox.REFUSALS = {
  not_a_mon      = "That can't be sent.",
  is_egg         = "An EGG can't be\nsent.",
  species_too_new = "Only POKeMON RED\nknows can go in\fthe GLOBAL BOX.",
  has_mail       = "Take the MAIL off\nfirst.",
  move_too_new   = "It knows a move\nRED has never\fheard of.",
  full           = "The GLOBAL BOX is\nfull!",
  no_gen1_data   = "RED is not\nimported, so this\fbox can't be read.",
}

function GlobalBox.refusalText(reason)
  return GlobalBox.REFUSALS[reason] or GlobalBox.REFUSALS.not_a_mon
end

-- ------- the file

local function serializer()
  local ok, SaveSerializer = pcall(require, "src.core.SaveSerializer")
  if ok and type(SaveSerializer) == "table" then return SaveSerializer end
  return nil
end

-- An empty box, which is what every failure below answers with: a store that
-- cannot be read is a store with nothing in it, not an error a box screen has
-- to grow a branch for.  Writing is where a failure is reported, because that
-- is where one can lose a POKeMON.
local function emptyList() return {} end

function GlobalBox.load(cache)
  if type(cache) ~= "table" or type(cache.read) ~= "function" then
    return emptyList()
  end
  local ok, body = pcall(cache.read, cache, GlobalBox.FILE)
  if not ok or type(body) ~= "string" or body == "" then return emptyList() end
  local S = serializer()
  if not S then return emptyList() end
  local decoded = S.decode(body)
  if type(decoded) ~= "table" or type(decoded.mons) ~= "table" then
    return emptyList()
  end
  -- Forward-compatible by refusing: a file written by a LATER format is not
  -- one this build can rewrite without dropping whatever it did not
  -- understand, and dropping is how a POKeMON disappears.
  if tonumber(decoded.format) ~= GlobalBox.FORMAT then return emptyList() end
  local out = {}
  for _, mon in ipairs(decoded.mons) do
    if type(mon) == "table" and mon.species then out[#out + 1] = mon end
  end
  return out
end

function GlobalBox.save(cache, list)
  if type(cache) ~= "table" or type(cache.write) ~= "function" then
    return false, "storage_unavailable"
  end
  if type(list) ~= "table" then return false, "not_a_list" end
  local S = serializer()
  if not S then return false, "storage_unavailable" end
  local okEncode, body = pcall(S.encode,
    { format = GlobalBox.FORMAT, mons = list })
  if not okEncode or type(body) ~= "string" then return false, "encode_failed" end
  local ok, written = pcall(cache.write, cache, GlobalBox.FILE, body)
  if not ok or written == nil or written == false then
    return false, "write_failed"
  end
  return true
end

-- ------- pages
--
-- The list is flat and the pages are a VIEW of it, so "it adds another page
-- when it fills" needs no bookkeeping: there is always exactly one page more
-- than the full ones, and it is empty.  A box you cannot see an open slot in
-- is a box you cannot deposit into.

function GlobalBox.pages(list)
  local n = type(list) == "table" and #list or 0
  local pages = math.floor(n / GlobalBox.PAGE) + 1
  if pages > GlobalBox.MAX_PAGES then return GlobalBox.MAX_PAGES end
  return pages
end

function GlobalBox.indexAt(page, slot)
  page, slot = tonumber(page), tonumber(slot)
  if not (page and slot) then return nil end
  if page < 1 or page > GlobalBox.MAX_PAGES then return nil end
  if slot < 1 or slot > GlobalBox.PAGE then return nil end
  return (page - 1) * GlobalBox.PAGE + slot
end

function GlobalBox.at(list, page, slot)
  local index = GlobalBox.indexAt(page, slot)
  if not (index and type(list) == "table") then return nil end
  return list[index]
end

function GlobalBox.count(list)
  return type(list) == "table" and #list or 0
end

function GlobalBox.full(list)
  return GlobalBox.count(list) >= GlobalBox.CAPACITY
end

-- ------- what goes in
--
-- The gate is Convert's, asked of the Gen 1 shape the box stores.  A caller
-- on a Gen 2 cartridge converts FIRST and asks about the result, so a mon
-- that Convert would refuse never reaches here with a reason of its own.
function GlobalBox.accepts(list, mon)
  if type(mon) ~= "table" or mon.species == nil then return nil, "not_a_mon" end
  if mon.isEgg then return nil, "is_egg" end
  if GlobalBox.full(list) then return nil, "full" end
  return true
end

-- Append, because the box is a queue of what you sent rather than a grid you
-- arrange: SEND from a party menu has no cell to aim at.  Putting one in a
-- CHOSEN cell is the box screen's job and goes through `put`.
function GlobalBox.add(list, mon)
  local ok, reason = GlobalBox.accepts(list, mon)
  if not ok then return nil, reason end
  list[#list + 1] = mon
  return #list
end

-- Take the POKeMON at a cell out and close the gap behind it, so the pages
-- stay dense and the last one stays the open one.  The cartridge's own box is
-- a compact array for the same reason (src/pokemon/Boxes.lua).
function GlobalBox.take(list, page, slot)
  local index = GlobalBox.indexAt(page, slot)
  if not (index and type(list) == "table") then return nil end
  local mon = list[index]
  if mon == nil then return nil end
  table.remove(list, index)
  return mon
end

-- Put one in a NAMED cell.  Only into a cell that exists or the first free
-- one after the end: a gap in the middle would be a page that reads as full
-- with a hole in it, and the flat list has no way to say that.
function GlobalBox.put(list, page, slot, mon)
  local ok, reason = GlobalBox.accepts(list, mon)
  if not ok then return nil, reason end
  local index = GlobalBox.indexAt(page, slot)
  if not index then return nil, "no_such_cell" end
  if index > #list + 1 then return nil, "no_such_cell" end
  table.insert(list, index, mon)
  return index
end

return GlobalBox
