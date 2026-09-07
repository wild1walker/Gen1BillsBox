-- The GLOBAL BOX store: pages, capacity, and what may live in it.
--
-- The store is the half of this feature that can lose a POKeMON, so it is
-- tested on its own, against the CART's serializer rather than a stand-in --
-- a round trip through a fake encoder proves nothing about a file two
-- cartridges have to agree on.
--
-- Run:  luajit tests/globalbox_test.lua

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
      local probe = io.open(dir .. "/src/core/SaveSerializer.lua")
      if probe then probe:close(); ENGINE = dir; break end
    end
  end
end
if not ENGINE then
  io.write("globalbox: SKIPPED -- no engine tree found "
    .. "(set GEN1RECOMP to a gen1recomp checkout)\n")
  os.exit(0)
end
package.path = ENGINE .. "/?.lua;" .. package.path
ok(ENGINE ~= nil, "an engine tree is found, so every check below really runs")

local GlobalBox = assert(loadfile("globalbox.lua"))()

-- ---- a cache that is a table, so the file is inspectable

local function fakeCache()
  local files = {}
  return {
    files = files,
    read = function(_, name) return files[name] end,
    write = function(_, name, bytes) files[name] = bytes return true end,
  }, files
end

local function mon(name, species)
  return { species = species or "PIKACHU", nickname = name, level = 12,
           moves = { { id = "THUNDERSHOCK", pp = 30 } } }
end

-- ------------------------------------------------------------------ pages

do
  io.write("an empty box is one empty page, not none\n")
  local list = {}
  eq(GlobalBox.pages(list), 1, "there is always a page to put one on")
  eq(GlobalBox.at(list, 1, 1), nil, "and nothing on it")
end

do
  io.write("a page fills at twenty and the next one appears\n")
  local list = {}
  for i = 1, GlobalBox.PAGE do GlobalBox.add(list, mon("M" .. i)) end
  eq(#list, 20, "twenty in")
  eq(GlobalBox.pages(list), 2, "GLOBAL 1 is full, so GLOBAL 2 exists")
  eq(GlobalBox.at(list, 1, 20).nickname, "M20", "the twentieth is the last cell of page 1")
  eq(GlobalBox.at(list, 2, 1), nil, "and page 2 is empty")

  GlobalBox.add(list, mon("M21"))
  eq(GlobalBox.pages(list), 2, "the twenty-first does not add a third page")
  eq(GlobalBox.at(list, 2, 1).nickname, "M21", "it lands on page 2's first cell")
end

do
  io.write("cells outside a page do not resolve\n")
  eq(GlobalBox.indexAt(1, 0), nil, "slot 0 is not a cell")
  eq(GlobalBox.indexAt(1, 21), nil, "nor is slot 21")
  eq(GlobalBox.indexAt(0, 1), nil, "nor is page 0")
  eq(GlobalBox.indexAt(GlobalBox.MAX_PAGES + 1, 1), nil,
     "nor a page past the cap")
  eq(GlobalBox.indexAt(2, 1), 21, "page 2 slot 1 is the twenty-first")
end

-- ------------------------------------------------------------- taking out

do
  io.write("taking one out closes the gap behind it\n")
  local list = {}
  for i = 1, 5 do GlobalBox.add(list, mon("M" .. i)) end
  local taken = GlobalBox.take(list, 1, 2)
  eq(taken.nickname, "M2", "the one aimed at comes out")
  eq(#list, 4, "and the box is one shorter")
  eq(GlobalBox.at(list, 1, 2).nickname, "M3", "the rest close up behind it")
  eq(GlobalBox.take(list, 1, 20), nil, "an empty cell yields nothing")
end

do
  io.write("putting one in a named cell inserts rather than overwrites\n")
  local list = {}
  for i = 1, 3 do GlobalBox.add(list, mon("M" .. i)) end
  GlobalBox.put(list, 1, 2, mon("NEW"))
  eq(#list, 4, "nothing was displaced out of the box")
  eq(GlobalBox.at(list, 1, 2).nickname, "NEW", "it went where it was aimed")
  eq(GlobalBox.at(list, 1, 3).nickname, "M2", "and the one there moved along")

  local index, reason = GlobalBox.put(list, 1, 20, mon("FAR"))
  eq(index, nil, "a cell past the end of the list is refused")
  eq(reason, "no_such_cell", "and says why -- a gap is not a thing this can hold")
end

-- --------------------------------------------------------------- the gate

do
  io.write("only a POKeMON goes in, and never an EGG\n")
  local list = {}
  local index, reason = GlobalBox.add(list, { isEgg = true, species = "PIKACHU" })
  eq(index, nil, "an EGG is refused")
  eq(reason, "is_egg", "with the Time Capsule's own reason")
  eq(select(2, GlobalBox.add(list, {})), "not_a_mon", "so is a table with no species")
  eq(#list, 0, "and nothing was added")
end

do
  io.write("the box has a bottom\n")
  local list = {}
  for i = 1, GlobalBox.CAPACITY do list[i] = mon("M" .. i) end
  eq(GlobalBox.full(list), true, "four hundred is full")
  eq(GlobalBox.pages(list), GlobalBox.MAX_PAGES,
     "and the page count stops at the cap rather than growing past it")
  local index, reason = GlobalBox.add(list, mon("ONE MORE"))
  eq(index, nil, "one more is refused")
  eq(reason, "full", "and says so")
  ok(GlobalBox.refusalText("full"):find("full", 1, true) ~= nil,
     "which has words a text box can print")
end

-- ------------------------------------------------- the file, round-tripped

do
  io.write("what one cartridge writes, the other reads\n")
  local cache = fakeCache()

  local out = GlobalBox.load(cache)
  eq(#out, 0, "an unwritten box reads as empty rather than failing")

  GlobalBox.add(out, mon("SPARK", "PIKACHU"))
  GlobalBox.add(out, mon("LEAF", "BULBASAUR"))
  eq(GlobalBox.save(cache, out), true, "it writes")

  -- A SECOND reader, with no memory of the first: this is the whole point of
  -- the store, so it is read back through a fresh load rather than reused.
  local back = GlobalBox.load(cache)
  eq(#back, 2, "the other cartridge sees both")
  eq(back[1].nickname, "SPARK", "in order")
  eq(back[2].species, "BULBASAUR", "with their species intact")
  eq(back[1].moves[1].id, "THUNDERSHOCK", "and their moves")
end

do
  io.write("a file this build cannot rewrite safely is not rewritten\n")
  local cache, files = fakeCache()
  local S = require("src.core.SaveSerializer")
  files[GlobalBox.FILE] = S.encode({ format = GlobalBox.FORMAT + 1,
                                     mons = { mon("FUTURE") } })
  local out = GlobalBox.load(cache)
  eq(#out, 0,
     "a later format reads as empty rather than as a box to overwrite -- "
     .. "dropping what it did not understand is how a POKeMON disappears")
end

do
  io.write("a corrupt or missing store is an empty box, not a crash\n")
  local cache, files = fakeCache()
  files[GlobalBox.FILE] = "not a serialized table at all"
  eq(#GlobalBox.load(cache), 0, "garbage reads as empty")
  eq(#GlobalBox.load(nil), 0, "so does no cache at all")
  eq(#GlobalBox.load({}), 0, "so does a cache with no read")
  eq(GlobalBox.save({}, {}), false, "and a cache with no write says it failed")
end

io.write(("\nglobalbox: %d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
