-- Two cartridges, one installation, one box -- against the ENGINE's own
-- SaveData rather than a stand-in for it.
--
-- This is the test that was missing, and its absence had a cost: a player put
-- a POKeMON in the GLOBAL BOX on Wild Green and Wild Crystal's was empty.
-- Every other suite here drives `readAll` through a SaveData double, and a
-- double answers whatever it was written to answer -- so all of them agreed
-- with the code and none of them agreed with the game.
--
-- What the double could not know is that `mod.save:set("globalbox", ...)` does
-- not write at "globalbox".  Inside the Gen1WildUI bundle each vendored mod's
-- save is a facade that prefixes every key with the feature's id
-- (runtime/facade.lua), so the bucket is filed as "box.globalbox" -- which the
-- mod itself never notices, because it reads back through the same proxy, and
-- which made every cross-cart read look in the wrong place.
--
-- So this builds the real thing: a memory filesystem, the engine's real slot
-- registry, two carts registered through SaveData's own calls, and Wild
-- Green's save written by SaveData.writeCartSlot with its bucket where the
-- BUNDLE would put it.  Then it asks, from Wild Crystal, what is in the box.
--
-- Run:  luajit tests/globalcarts_test.lua

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

local ENGINE do
  local candidates = { os.getenv("GEN1RECOMP") }
  for _, prefix in ipairs({ "..", "../../..", "../../../..", "../..",
                            "../../../../.." }) do
    candidates[#candidates + 1] = prefix .. "/bryanthaboi/gen1recomp"
    candidates[#candidates + 1] = prefix .. "/gen1recomp"
  end
  for _, dir in ipairs(candidates) do
    if dir then
      local probe = io.open(dir .. "/src/core/SaveData.lua")
      if probe then probe:close(); ENGINE = dir; break end
    end
  end
end
if not ENGINE then
  io.write("globalcarts: SKIPPED -- no engine tree found "
    .. "(set GEN1RECOMP to a gen1recomp checkout)\n")
  os.exit(0)
end
package.path = ENGINE .. "/?.lua;" .. ENGINE .. "/?/init.lua;" .. package.path

-- The engine's own love stand-in, then a memory filesystem over it: the same
-- arrangement tests/engine/cart_saves.lua uses to drive the slot registry.
_G.love = _G.love or require("tests.love_stub")
local files = {}
love.filesystem = {
  files = files,
  write = function(path, content) files[path] = content return true end,
  read = function(path) return files[path] end,
  remove = function(path) files[path] = nil return true end,
  getInfo = function(path)
    if files[path] then return { type = "file" } end
    return nil
  end,
}

local SaveData = require("src.core.SaveData")
local SaveSerializer = require("src.core.SaveSerializer")
local GameVersion = require("src.core.GameVersion")
SaveData.resetSlotState()

local GlobalBox do
  local handle = assert(io.open("globalbox.lua")
    or io.open("../globalbox.lua") or io.open("../../globalbox.lua"),
    "globalbox.lua is missing")
  local source = handle:read("*a")
  handle:close()
  GlobalBox = assert(load(source, "@globalbox.lua"))()
end

-- The bundle's mod id and the key its facade actually files under.
local MOD_ID = "gen1_wild_ui"
local BUNDLE_KEY = "box." .. GlobalBox.KEY

local function bucketWith(origin, ...)
  local bucket = { format = GlobalBox.FORMAT, origin = origin, seq = 0,
                   mons = {}, claims = {} }
  for _, species in ipairs({ ... }) do
    bucket.seq = bucket.seq + 1
    bucket.mons[#bucket.mons + 1] = {
      species = species, level = 5, stats = { hp = 20 },
      gbId = origin .. "#" .. bucket.seq, gbSent = bucket.seq,
    }
  end
  return bucket
end

local function saveWith(name, version, key, bucket)
  return {
    version = version,
    player = { name = name, map = "PALLET_TOWN", x = 1, y = 1 },
    pokedex = { seen = {}, owned = {} },
    inventory = {},
    playTime = 0,
    modData = key and { [MOD_ID] = { [key] = bucket } } or {},
  }
end

-- ---- Wild Green: a cart with one slot and a POKeMON in its outbox

GameVersion.set("red")
SaveData.setCart("wild_green", "greenhash")
local greenSlot = SaveData.createCartSlot("wild_green")
ok(type(greenSlot) == "string", "Wild Green registers a save slot")
SaveData.setActiveCartSlot("wild_green", greenSlot)
local greenBucket = bucketWith("green", "BULBASAUR")
ok(SaveData.writeCartSlot("wild_green", greenSlot,
     saveWith("GREEN", "red", BUNDLE_KEY, greenBucket)),
  "and its save is written, with the box where the BUNDLE files it")

-- ---- Wild Crystal: a second cart, its own slot, nothing sent yet

GameVersion.set("crystal")
SaveData.setCart("wild_crystal", "crystalhash")
local crystalSlot = SaveData.createCartSlot("wild_crystal")
SaveData.setActiveCartSlot("wild_crystal", crystalSlot)
SaveData.writeCartSlot("wild_crystal", crystalSlot,
  saveWith("CRYS", "crystal", nil, nil))

-- ---- the installation, as SaveData itself reports it
--
-- Asserted because the whole read rests on these three calls being the ones
-- that see another cartridge's saves.  They are the same calls sync makes.

local carts = SaveData.cartsWithSlots()
table.sort(carts)
eq(table.concat(carts, ","), "wild_crystal,wild_green",
  "both cartridges are registered on this installation")
eq(#SaveData.listCartSlots("wild_green"), 1, "Wild Green has its one slot")
ok(SaveData.readCartSlotSource("wild_green", greenSlot) ~= nil,
  "and its save can be read from the cartridge that is not it")

-- ---- and now the question the player asked

local liveKey = GlobalBox.liveKey(SaveData, GameVersion)
eq(liveKey, "cart:wild_crystal/" .. crystalSlot,
  "the save being played is Wild Crystal's")

local sources = GlobalBox.readAll({ modId = MOD_ID, liveKey = liveKey })
local view = GlobalBox.view(sources)
eq(#view, 1, "Wild Crystal's GLOBAL BOX has the POKeMON Wild Green sent")
eq(view[1] and view[1].mon.species, "BULBASAUR", "the right one")
eq(view[1] and view[1].origin, "green", "named as coming from Green's save")
eq(GlobalBox.pages(view), 1, "on GLOBAL 1")

-- ---- and the other direction, through the same door

local crystalBucket = bucketWith("crystal", "TOTODILE")
local both = GlobalBox.readAll({ modId = MOD_ID, liveKey = liveKey,
                                 liveBucket = crystalBucket })
eq(#GlobalBox.view(both), 2, "with Crystal's own deposit beside it")

-- Crystal saves; Green boots and reads it back.  The bucket goes through the
-- BUNDLE's key here too, because that is the only place it is ever written.
SaveData.writeCartSlot("wild_crystal", crystalSlot,
  saveWith("CRYS", "crystal", BUNDLE_KEY, crystalBucket))
GameVersion.set("red")
SaveData.setCart("wild_green", "greenhash")
local fromGreen = GlobalBox.readAll({
  modId = MOD_ID,
  liveKey = GlobalBox.liveKey(SaveData, GameVersion),
  liveBucket = greenBucket,
})
local species = {}
for _, entry in ipairs(GlobalBox.view(fromGreen)) do
  species[#species + 1] = entry.mon.species
end
table.sort(species)
eq(table.concat(species, ","), "BULBASAUR,TOTODILE",
  "and back on Wild Green the box holds both, once each")

-- ---- a save with no box in it is not a box with nothing in it

SaveData.setCart("wild_crystal", "crystalhash")
local empty = SaveData.createCartSlot("wild_crystal")
SaveData.writeCartSlot("wild_crystal", empty,
  saveWith("NEW", "crystal", nil, nil))
local stillTwo = GlobalBox.readAll({ modId = MOD_ID,
  liveKey = GlobalBox.liveKey(SaveData, GameVersion) })
eq(#GlobalBox.view(stillTwo), 2,
  "a save that never used the feature adds nothing and breaks nothing")

io.write(("\nglobalcarts: %d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
