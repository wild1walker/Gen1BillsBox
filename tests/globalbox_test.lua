-- The GLOBAL BOX store: where it lives, what the two cartridges agree on, and
-- what happens when one of them takes a POKeMON the other is holding.
--
-- The store is the half of this feature that can lose a POKeMON, so it is
-- tested on its own, against the CART's serializer rather than a stand-in --
-- a round trip through a fake encoder proves nothing about bytes two
-- cartridges have to agree on.
--
-- The first section is the one that matters most and looks least like a test:
-- it reads the ENGINE to check the premise the whole design rests on.  The
-- box lives in the save because that is what save sync carries; if sync ever
-- stops uploading slot sources, or the engine stops backing mod.save with
-- save.modData, this feature is silently outside the saves again and nothing
-- else in this suite would notice.
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

local function engineSource(rel)
  local handle = io.open(ENGINE .. "/" .. rel, "r")
  if not handle then return nil end
  local body = handle:read("*a")
  handle:close()
  return body
end

-- ------------------------------------------------- the premise, read upstream

do
  io.write("the save is the only thing sync carries, and mod.save is in it\n")

  local engine = engineSource("src/sync/SyncEngine.lua") or ""
  ok(engine:find("readCartSlotSource", 1, true) ~= nil,
    "sync uploads a cart slot's own source bytes")
  ok(engine:find("readSlotSource", 1, true) ~= nil,
    "and a plain slot's")

  local client = engineSource("src/sync/SyncClient.lua") or ""
  ok(client:find("/sync/save", 1, true) ~= nil, "over PUT /sync/save")
  ok(client:find("/sync/mods", 1, true) ~= nil,
    "with only the mod roster beside it")

  -- The reason the cache-file version of this store had to go: neither of the
  -- two out-of-save stores is named anywhere sync can see.
  local synced = ""
  for _, rel in ipairs({ "src/sync/SyncEngine.lua", "src/sync/SyncClient.lua",
                         "src/sync/SyncMods.lua", "src/sync/SyncState.lua",
                         "src/sync/SyncTransport.lua" }) do
    synced = synced .. (engineSource(rel) or "")
  end
  ok(synced:find("mod_cache", 1, true) == nil,
    "mod.cache is not synced, which is why the box is not in it")
  ok(synced:find("mod_storage", 1, true) == nil, "nor is mod.storage")

  -- Both generations bind mod.save to the save blob, so a bucket written on
  -- Wild Green and one written on Wild Crystal are both inside a slot source.
  for _, rel in ipairs({ "src/core/Game.lua", "src/core/Game2.lua" }) do
    local body = engineSource(rel) or ""
    ok(body:find("loader%.modSave%s*=%s*save%.modData") ~= nil,
      rel .. " backs mod.save with save.modData")
  end
end

-- ------------------------------------------- a bucket survives a real save

local SaveSerializer = require("src.core.SaveSerializer")
local MOD_ID = "gen1_wild_ui"

local function roundTrip(save)
  local body = SaveSerializer.encode(save)
  ok(type(body) == "string" and body ~= "", "the save encodes")
  local decoded = SaveSerializer.decode(body)
  ok(type(decoded) == "table", "and decodes")
  return decoded, body
end

-- One save, as the engine shapes it: modData is where mod.save lives.
local function newSave()
  return { modData = { [MOD_ID] = {} } }
end

local function bucketIn(save)
  return GlobalBox.ensureBucket(save.modData[MOD_ID])
end

local function mon(species, name)
  return { species = species, name = name, level = 5 }
end

do
  io.write("a deposit is part of the save file, not a file beside it\n")

  local save = newSave()
  local bucket = bucketIn(save)
  ok(type(bucket) == "table", "the save grows a bucket on first use")
  eq(bucket.format, GlobalBox.FORMAT, "stamped with the format")
  ok(type(bucket.origin) == "string" and bucket.origin ~= "",
    "and with the origin that names this save")

  local id = GlobalBox.deposit(bucket, {}, mon(25, "PIKACHU"))
  ok(type(id) == "string", "a deposit answers with the id it minted")
  eq(#bucket.mons, 1, "and the POKeMON is in the save's own bucket")

  local decoded = roundTrip(save)
  local back = GlobalBox.bucketOf(decoded.modData[MOD_ID])
  ok(back ~= nil, "the bucket comes back out of the encoded save")
  eq(back.mons[1].species, 25, "with the POKeMON in it")
  eq(back.mons[1].gbId, id, "and its id intact, which is what a claim names")
  eq(back.origin, bucket.origin, "the origin surviving too")

  -- The origin is half of every id, so re-minting it would orphan every claim
  -- another save holds.  ensureBucket must never mint a second one.
  local again = GlobalBox.ensureBucket(decoded.modData[MOD_ID])
  eq(again.origin, bucket.origin, "reopening the save keeps the origin")
  eq(again.seq, bucket.seq, "and the counter, so ids are never reused")
end

do
  io.write("a bucket from a newer build is left alone, never rewritten\n")

  local modSave = { [GlobalBox.KEY] = { format = GlobalBox.FORMAT + 1,
                                        origin = "later", mons = { mon(1) } } }
  ok(GlobalBox.bucketOf(modSave) == nil, "it does not read as a bucket")
  local bucket, reason = GlobalBox.ensureBucket(modSave)
  ok(bucket == nil, "and it is not replaced with an empty one")
  eq(reason, "foreign_format", "the refusal says why")
  eq(modSave[GlobalBox.KEY].mons[1].species, 1,
    "what the newer build wrote is still there")
end

-- --------------------------------------- two saves, one box

local function sourcesOf(...)
  local out = {}
  for _, pair in ipairs({ ... }) do
    out[#out + 1] = GlobalBox.sourceFrom(pair[1], pair[2], pair[3])
  end
  return out
end

do
  io.write("the box is the union of every save's outbox\n")

  local green, crystal = newSave(), newSave()
  local gb, cb = bucketIn(green), bucketIn(crystal)
  ok(gb.origin ~= cb.origin, "two saves mint two origins")

  local a = GlobalBox.deposit(gb, {}, mon(1, "BULBASAUR"))
  local b = GlobalBox.deposit(cb, {}, mon(4, "CHARMANDER"))
  ok(a ~= b, "and two ids that cannot collide")

  local sources = sourcesOf({ "cart:green/slot1", gb, true },
                            { "cart:crystal/slot1", cb, false })
  local view = GlobalBox.view(sources)
  eq(#view, 2, "both cartridges' POKeMON are in the one box")

  -- The order has to be the same whichever cartridge asks, because a page and
  -- a slot are how the player points at one.
  local reversed = GlobalBox.view(sourcesOf({ "cart:crystal/slot1", cb, true },
                                            { "cart:green/slot1", gb, false }))
  eq(reversed[1].id, view[1].id, "and in the same order read the other way")
  eq(reversed[2].id, view[2].id, "for every cell")

  -- Where a POKeMON is sitting is carried, because only its own save may
  -- remove it and everyone else has to claim it instead.
  local origins = {}
  for _, entry in ipairs(view) do origins[entry.id] = entry.origin end
  eq(origins[a], gb.origin, "each entry names the save holding it")
  eq(origins[b], cb.origin, "on both sides")
end

do
  io.write("withdrawing your own is a removal; someone else's is a claim\n")

  local green, crystal = newSave(), newSave()
  local gb, cb = bucketIn(green), bucketIn(crystal)
  local mine = GlobalBox.deposit(gb, {}, mon(1, "BULBASAUR"))
  local theirs = GlobalBox.deposit(cb, {}, mon(4, "CHARMANDER"))

  local function greenSources()
    return sourcesOf({ "cart:green/slot1", gb, true },
                     { "cart:crystal/slot1", cb, false })
  end

  -- take the one Crystal is holding, from Green
  local view = GlobalBox.view(greenSources())
  local cell
  for index, entry in ipairs(view) do
    if entry.id == theirs then cell = index end
  end
  ok(cell ~= nil, "Crystal's POKeMON is visible from Green")
  local got, ticket = GlobalBox.withdraw(gb, greenSources(), view, 1, cell)
  ok(type(got) == "table" and got.species == 4, "Green gets the POKeMON")
  eq(type(ticket) == "table" and ticket.how, "claimed",
    "by claiming it, not by reaching into Crystal's save")
  eq(#cb.mons, 1, "Crystal's save is untouched -- it is not Green's to write")
  ok(gb.claims[theirs] == true, "the claim is written into Green's own save")

  -- and it is gone from the box for BOTH, immediately
  eq(#GlobalBox.view(greenSources()), 1, "the box loses it on Green")
  local fromCrystal = GlobalBox.view(sourcesOf({ "cart:crystal/slot1", cb, true },
                                               { "cart:green/slot1", gb, false }))
  eq(#fromCrystal, 1, "and on Crystal, which reads the same claim")
  eq(fromCrystal[1].id, mine, "leaving only the one nobody has taken")

  -- taking your own needs no claim
  local ownView = GlobalBox.view(greenSources())
  local own, ownTicket = GlobalBox.withdraw(gb, greenSources(), ownView, 1, 1)
  ok(type(own) == "table" and own.species == 1, "Green takes back its own")
  eq(type(ownTicket) == "table" and ownTicket.how, "removed",
    "straight out of its own bucket")
  eq(#gb.mons, 0, "which is now empty")
  eq(next(gb.claims), theirs, "and no second claim was written for it")

  -- an empty cell is a refusal, not a crash
  local nothing, why = GlobalBox.withdraw(gb, greenSources(),
                                          GlobalBox.view(greenSources()), 1, 7)
  ok(nothing == nil, "an empty cell hands back nothing")
  eq(why, "empty_cell", "and says so")
end

do
  io.write("reconcile drops what has been taken, and only then the claim\n")

  local green, crystal = newSave(), newSave()
  local gb, cb = bucketIn(green), bucketIn(crystal)
  local sent = GlobalBox.deposit(gb, {}, mon(1, "BULBASAUR"))
  cb.claims[sent] = true          -- Crystal withdrew it while Green was off

  local function all(liveIsGreen)
    return sourcesOf({ "cart:green/slot1", gb, liveIsGreen },
                     { "cart:crystal/slot1", cb, not liveIsGreen })
  end

  -- Crystal boots first: its claim has to survive, because Green still holds
  -- the POKeMON and releasing early would hand the player a second copy.
  local dropped, released = GlobalBox.reconcile(cb, all(false))
  eq(dropped, 0, "Crystal has nothing of its own to drop")
  eq(released, 0, "and keeps the claim while the sender still holds it")
  ok(cb.claims[sent] == true, "so it is still there")

  -- Green boots: the POKeMON leaves its outbox.
  dropped = GlobalBox.reconcile(gb, all(true))
  eq(dropped, 1, "Green drops the one that was claimed")
  eq(#gb.mons, 0, "its outbox is empty")

  -- now the claim has nothing left to hide
  local _, freed = GlobalBox.reconcile(cb, all(false))
  eq(freed, 1, "and Crystal's claim is released once nothing holds it")
  eq(next(cb.claims), nil, "leaving no bookkeeping behind")

  -- a POKeMON with no id is not a POKeMON this store can track, so it goes
  gb.mons[#gb.mons + 1] = mon(7, "SQUIRTLE")
  local strays = GlobalBox.reconcile(gb, all(true))
  eq(strays, 1, "an entry with no id is dropped rather than shown forever")
end

do
  io.write("a withdrawal can be put back exactly where it was\n")

  local green, crystal = newSave(), newSave()
  local gb, cb = bucketIn(green), bucketIn(crystal)
  GlobalBox.deposit(gb, {}, mon(1, "BULBASAUR"))
  local mine = GlobalBox.deposit(gb, {}, mon(7, "SQUIRTLE"))
  local theirs = GlobalBox.deposit(cb, {}, mon(4, "CHARMANDER"))

  local function sources()
    return sourcesOf({ "cart:green/slot1", gb, true },
                     { "cart:crystal/slot1", cb, false })
  end
  local function idsInOrder()
    local out = {}
    for _, entry in ipairs(GlobalBox.view(sources())) do out[#out + 1] = entry.id end
    return table.concat(out, ",")
  end

  local before = idsInOrder()

  -- picking one of your own up and putting it back down again -- B on a box
  -- screen -- must not read as a second deposit at the end of the box
  local view = sources()
  local cell
  for index, entry in ipairs(GlobalBox.view(view)) do
    if entry.id == mine then cell = index end
  end
  local got, ticket = GlobalBox.withdraw(gb, view, GlobalBox.view(view), 1, cell)
  ok(got ~= nil, "one of your own comes out")
  ok(GlobalBox.restore(gb, ticket), "and goes back")
  eq(idsInOrder(), before, "into the same cell, with the same id")
  eq(bucketIn(green).seq, 2, "and no new id was minted")

  -- and so must putting back one that was CLAIMED: the claim is dropped, so
  -- the POKeMON was never moved at all
  local claimView = GlobalBox.view(sources())
  local theirCell
  for index, entry in ipairs(claimView) do
    if entry.id == theirs then theirCell = index end
  end
  local _, claimTicket = GlobalBox.withdraw(gb, sources(), claimView, 1, theirCell)
  eq(claimTicket.how, "claimed", "someone else's is claimed")
  eq(#GlobalBox.view(sources()), 2, "and leaves the box")
  ok(GlobalBox.restore(gb, claimTicket), "restoring drops the claim")
  eq(idsInOrder(), before, "and the box is exactly as it was")
  eq(next(gb.claims), nil, "with no claim left behind to reconcile later")

  ok(GlobalBox.restore(gb, { how = "removed", id = mine, mon = mon(7) }) == false,
    "a restore of one already in the outbox is refused, not duplicated")
  ok(GlobalBox.restore(gb, nil) == false, "and a restore of nothing is refused")
end

-- ------------------------------------------------------- pages and the gate

do
  io.write("pages are a view of the union, and there is always an open one\n")

  eq(GlobalBox.PAGE, 20, "a page is a cartridge box")
  eq(GlobalBox.CAPACITY, GlobalBox.PAGE * GlobalBox.MAX_PAGES,
    "and the cap is every page full")

  eq(GlobalBox.pages({}), 1, "an empty box still has GLOBAL 1")
  local view = {}
  for index = 1, GlobalBox.PAGE do view[index] = { id = tostring(index) } end
  eq(GlobalBox.pages(view), 2, "filling GLOBAL 1 opens GLOBAL 2")
  view[#view + 1] = { id = "x" }
  eq(GlobalBox.pages(view), 2, "which stays open while it fills")

  eq(GlobalBox.indexAt(2, 1), GlobalBox.PAGE + 1, "a cell maps into the list")
  ok(GlobalBox.indexAt(0, 1) == nil, "page zero is not a cell")
  ok(GlobalBox.indexAt(GlobalBox.MAX_PAGES + 1, 1) == nil,
    "and neither is one past the last page")
  ok(GlobalBox.indexAt(1, GlobalBox.PAGE + 1) == nil, "nor a slot past a page")

  local full = {}
  for index = 1, GlobalBox.CAPACITY do full[index] = { id = tostring(index) } end
  ok(GlobalBox.full(full), "a full box says so")
  eq(GlobalBox.pages(full), GlobalBox.MAX_PAGES,
    "and stops at the last page rather than opening one that cannot exist")

  local save = newSave()
  local bucket = bucketIn(save)
  local id, reason = GlobalBox.deposit(bucket, full, mon(1))
  ok(id == nil, "a full box takes nothing more")
  eq(reason, "full", "and says which refusal it is")
  ok(GlobalBox.refusalText("full"):find("full", 1, true) ~= nil,
    "which has a line the cartridge can print")
end

do
  io.write("only a Gen 1 POKeMON, and only a POKeMON\n")

  local bucket = bucketIn(newSave())
  local _, notMon = GlobalBox.deposit(bucket, {}, { name = "NOTHING" })
  eq(notMon, "not_a_mon", "a table with no species is refused")
  local _, egg = GlobalBox.deposit(bucket, {}, { species = 1, isEgg = true })
  eq(egg, "is_egg", "and an EGG, which no Gen 1 cartridge can hold")
  eq(#bucket.mons, 0, "neither reached the save")

  -- The Johto and Gen 2 move refusals are Convert's, asked before this store
  -- ever sees the POKeMON -- so what is checked here is that the store can
  -- SAY them in the cartridge's own voice.
  for _, reason in ipairs({ "species_too_new", "move_too_new", "has_mail",
                            "no_gen1_data", "no_save" }) do
    ok(type(GlobalBox.REFUSALS[reason]) == "string",
      reason .. " has a line to print")
  end
  eq(GlobalBox.refusalText("nonsense"), GlobalBox.REFUSALS.not_a_mon,
    "and an unknown reason falls back rather than printing nil")

  local none, why = GlobalBox.deposit(nil, {}, mon(1))
  ok(none == nil, "with no save there is nowhere to deposit")
  eq(why, "no_save", "which is its own refusal")
end

-- --------------------------------- reading every save on the installation

do
  io.write("readAll walks the slots sync itself uploads\n")

  local function bucketWith(origin, species)
    return { format = GlobalBox.FORMAT, origin = origin, seq = 1,
             mons = { { species = species, gbId = origin .. "#1", gbSent = 1 } },
             claims = {} }
  end

  local function encodeSave(bucket)
    return SaveSerializer.encode({ modData = { [MOD_ID] = {
      [GlobalBox.KEY] = bucket } } })
  end

  local function encodeSaveUnder(id, bucket)
    return SaveSerializer.encode({ modData = { [id] = {
      [GlobalBox.KEY] = bucket } } })
  end

  local disk = {
    ["cart:wildgreen/slot1"] = encodeSave(bucketWith("green", 1)),
    ["cart:wildcrystal/slot1"] = encodeSave(bucketWith("crystal", 4)),
    ["game:red/slot1"] = encodeSave(bucketWith("red", 7)),
    -- a slot with no bucket at all, which is every save that has never used
    -- the feature: it must be skipped, not counted as an empty box
    ["game:blue/slot1"] = SaveSerializer.encode({ modData = {} }),
  }

  local SaveData = {
    cartsWithSlots = function() return { "wildcrystal", "wildgreen" } end,
    listCartSlots = function(cartId)
      local out = {}
      for key in pairs(disk) do
        local slot = key:match("^cart:" .. cartId .. "/(.+)$")
        if slot then out[#out + 1] = { id = slot, exists = true } end
      end
      table.sort(out, function(a, b) return a.id < b.id end)
      return out
    end,
    readCartSlotSource = function(cartId, slotId)
      return disk[("cart:%s/%s"):format(cartId, slotId)]
    end,
    listSlots = function(version)
      return { { id = "slot1", exists = disk["game:" .. version .. "/slot1"] ~= nil } }
    end,
    readSlotSource = function(version, slotId)
      return disk[("game:%s/%s"):format(version, slotId)]
    end,
  }
  local GameVersion = { VERSIONS = { red = {}, blue = {}, gold = {} } }

  local live = bucketWith("live", 25)
  local sources = GlobalBox.readAll({
    SaveData = SaveData, Serializer = SaveSerializer, GameVersion = GameVersion,
    modId = MOD_ID,
    liveKey = "cart:wildcrystal/slot1", liveBucket = live,
  })

  local keys = {}
  for _, source in ipairs(sources) do keys[#keys + 1] = source.key end
  table.sort(keys)
  eq(table.concat(keys, ","),
     "cart:wildcrystal/slot1,cart:wildgreen/slot1,game:red/slot1",
    "every save with a bucket is read, and the one without is skipped")

  local liveCount = 0
  for _, source in ipairs(sources) do
    if source.key == "cart:wildcrystal/slot1" then
      liveCount = liveCount + 1
      eq(source.origin, "live",
        "the save being played is read from memory, not from its last write")
      ok(source.live, "and is flagged as the one that may be written")
    end
  end
  eq(liveCount, 1, "and it is read exactly once")

  eq(#GlobalBox.view(sources), 3, "the box shows one POKeMON from each")



  -- With no live save -- a launcher screen -- there is still a box to look at,
  -- there is just nowhere to deposit into.
  local readOnly = GlobalBox.readAll({
    SaveData = SaveData, Serializer = SaveSerializer, GameVersion = GameVersion,
    modId = MOD_ID,
  })
  eq(#GlobalBox.view(readOnly), 3, "with no save loaded the box still reads")

  -- A missing engine is an empty box, not a crash: the box screen has no
  -- branch for a store that failed to load and should not need one.
  eq(#GlobalBox.readAll({ modId = MOD_ID, SaveData = false }), 0,
    "and no SaveData at all reads as nothing rather than raising")

  -- ---- the same feature under a different mod id
  --
  -- save.modData is keyed by mod id, and this ships under three: the stable
  -- bundle, the nightly channel's copy, and the standalone mod.  A player who
  -- moved between them would open the box and find it empty, with their
  -- POKeMON still in the save under the other name -- so every bucket in a
  -- save is read, recognised by its shape rather than by whose it is.
  disk["cart:wildgreen/slot2"] =
    encodeSaveUnder(MOD_ID .. "_nightly", bucketWith("nightly", 10))
  local mixed = GlobalBox.readAll({
    SaveData = SaveData, Serializer = SaveSerializer, GameVersion = GameVersion,
    modId = MOD_ID, liveKey = "cart:wildcrystal/slot1", liveBucket = live,
  })
  eq(#GlobalBox.view(mixed), 4,
    "a bucket the nightly channel wrote is in the same box as the stable one")
  local origins = {}
  for _, entry in ipairs(GlobalBox.view(mixed)) do
    origins[#origins + 1] = entry.origin
  end
  table.sort(origins)
  eq(table.concat(origins, ","), "green,live,nightly,red",
    "each keeping the origin that says which save it came out of")

  -- but never the live save's OWN bucket off disk: the copy in memory is
  -- ahead of it, and reading both would show every unsaved deposit twice
  disk["cart:wildcrystal/slot1"] = encodeSave(bucketWith("stale", 99))
  local again = GlobalBox.readAll({
    SaveData = SaveData, Serializer = SaveSerializer, GameVersion = GameVersion,
    modId = MOD_ID, liveKey = "cart:wildcrystal/slot1", liveBucket = live,
  })
  local stale = 0
  for _, source in ipairs(again) do
    if source.origin == "stale" then stale = stale + 1 end
  end
  eq(stale, 0, "the live save's last write is not read back over its memory")
end

do
  io.write("liveKey names the save the player is in\n")

  local cartSaveData = {
    getCart = function() return "wildcrystal" end,
    activeCartSlot = function(cartId) return cartId == "wildcrystal" and "slot2" or nil end,
    activeSlot = function() return "slot1" end,
  }
  eq(GlobalBox.liveKey(cartSaveData, { get = function() return "gold" end }),
     "cart:wildcrystal/slot2", "a cartridge is named by cart and slot")

  local plainSaveData = {
    getCart = function() return nil end,
    activeSlot = function(version) return version == "red" and "slot3" or nil end,
  }
  eq(GlobalBox.liveKey(plainSaveData, { get = function() return "red" end }),
     "game:red/slot3", "and a plain game by version and slot")

  local noSlot = {
    getCart = function() return nil end,
    activeSlot = function() return nil end,
  }
  ok(GlobalBox.liveKey(noSlot, { get = function() return "red" end }) == nil,
    "with no slot chosen there is no live save, and that is not an error")
  ok(GlobalBox.liveKey(nil, nil) == nil, "nor is having no SaveData at all")
end

io.write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
