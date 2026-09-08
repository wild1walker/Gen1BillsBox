# Changelog

## 1.11.0

- **SEND is on the party half of the box screen.** Selecting a party member
  there offered STATS and CANCEL and nothing else. The row was left off on
  purpose, and the reason was about the wrong thing: the *party menu's* SEND
  empties `save.party` directly, which from this screen would leave its own row
  bookkeeping — and, on Gold, its mail slots — describing a POKéMON that is no
  longer in the party.

  All true, and a reason for the party half to have **its own** SEND rather
  than none. This screen already lifts POKéMON out of the party correctly every
  time the cursor picks one up. So the row makes that same move: the pick-up's
  own last-POKéMON refusal in the pick-up's own words, the DEPOSITED tail a
  deposit applies, the mail behind it moved up with it on Gold, and back into
  the row it came from if the store turns it away.

  It confirms, where the box's SEND does not — inside the box a send is a move
  between pages, and out of the party it is a POKéMON leaving your team.

## 1.10.1

- **Moving several POKéMON out of the GLOBAL BOX took the wrong ones, then
  said "That can't be sent."** A mark records where a POKéMON is. In a
  cartridge box that is enough — Red and Gold keep their arrangement beside
  the box, so taking one out leaves every other cell where it was. The GLOBAL
  BOX is not a box, it is a **queue**: a withdrawal closes it up and every
  cell after the gap moves down one.

  So the first mark came out correctly, the second took whatever had moved
  into its cell, and the last ran off the end of what was left — which
  answered `empty_cell`, which had no sentence of its own and fell through to
  "That can't be sent". Mark ONE and TWO and you moved ONE and THREE.

  A mark on a global page now records the entry's **id**, and every take
  resolves that id to where it is *now*. `empty_cell` also has its own line:
  "It's not in the GLOBAL BOX now." Both box screens.

## 1.10.0

- **Anything drawn over a POKéMON came back inverted.** Reported with a
  screenshot: the STATS/RELEASE popup with white blocks punched through it, in
  a grid, exactly the size and position of the cells underneath.

  `markTrueColor` does not copy anything. It says *this rectangle is true
  colour*, and the renderer re-blits whatever is in it **raw** at composite
  time — after the whole frame is drawn, popups included. So a menu over the
  grid was re-blitted raw wherever it overlapped an icon's claim, and a Gen 1
  menu is black on **white** while DARK inverts the page around it. An icon a
  menu is covering has no business claiming true colour: nobody can see it. It
  does not claim one now.

- **SELECT marks, and A moves everything marked.** Mark six in BOX 1, walk to
  BOX 3, press A. The marks survive a box change; B clears them. A box with
  room for some but not all of them takes none and says so.

- **SORT moved from SELECT to the popup START opens**, beside the other verbs,
  which is what freed SELECT. UNDO came with it. The popup opens on an empty
  cell now too, because SORT is about the box rather than about what the
  cursor happens to be on.

- **SEND is on the box popup as well as the party menu's.** It was left off on
  the grounds that carrying a POKéMON onto a GLOBAL page is the same action
  with the cursor already in your hand — true, and not a reason to make
  anybody walk there. It is the box's *own* SEND: the party menu's takes a
  POKéMON out of `save.party`, and handing a boxed one to that would have
  deposited it in the GLOBAL BOX and left the original exactly where it was.

All four on both cartridges.

## 1.9.0

- **The GLOBAL BOX keeps each POKéMON in its own generation's shape.** It kept
  one shape, Gen 1's, and that was the wrong trade three ways over.

  A Gen 2 game had to convert on the way *in*, which needs Gen 1's base stats,
  moves and growth rates — so it mounted a whole Gen 1 dataset behind a
  keypress, was unusable for anyone with no Gen 1 game imported, and reported
  every way that could fail as the same *"RED, BLUE or YELLOW must be
  imported"*, including the ways that had nothing to do with an import. And a
  player whose games are all Gen 2 could never put a Johto POKéMON in it,
  which is most of what such a player has.

  Now a **deposit converts nothing**, from either game. A withdrawal converts
  only when the POKéMON is crossing generations — and Convert reaches for the
  far generation's dataset only to recompute what a stored POKéMON is missing
  (`src/online/Convert.lua:126`, `:262`), which a stored POKéMON never is. So
  both conversions run on the live game's own dataset and **this mod never
  mounts anything.**

  What moves is *when* a POKéMON is refused. "RED never heard of that move" is
  a fact about handing it to RED, not about storing it, so the Time Capsule's
  refusals are asked at the withdrawal into a Gen 1 game and nowhere else. A
  Johto POKéMON goes in happily from Gold and simply will not come out on Red
  — where it is drawn as a **?**, because Red has no icon for it, and where
  START offers it no STATS row, because the summary screen draws from a
  species record Red does not have.

  The one thing a deposit still refuses is a POKéMON holding MAIL, and that is
  Gold's own storage rule rather than the Time Capsule's.

  **Boxes written by the old build are read, not discarded** — everything in
  one is a Gen 1 shape by construction, so saying so is the whole migration.
  Your own box is stamped up in place the next time the save writes, with the
  ids and the origin untouched so claims against it still land. Another
  cartridge still running the old build keeps its own format and is read
  exactly as before.

- **A refusal ran off the right edge of Gold's message box.** Reported with a
  screenshot reading "YELLOW must be importe" and no way to see the rest. `\f`
  is the engine's page break and every refusal here is written with it; Red's
  arm gets that for free because it prints through the engine's own TextBox,
  but this screen draws its own box and did not — so it printed the first line
  and then everything else, page breaks and all, straight off the screen. A
  and B turn the page now, and turn past the last one to dismiss it.

## 1.8.3

- **The GLOBAL BOX is a feature of this mod, not of any particular game.** It
  always was in the code — `readAll` walks the plain-playthrough slot registry
  (`saves/<version>/`, through `SaveData.listSlots`/`readSlotSource`) as well
  as the cartridge one (`saves/cart_<id>/`, through
  `listCartSlots`/`readCartSlotSource`) — but nothing proved it and everything
  written about it said "cartridge". Install this on a plain RED and a plain
  GOLD and the box is shared between them with no cartridge anywhere; one of
  each works too. A save is a save.

  `tests/globalcarts_test.lua` covers that now against the engine's real
  `SaveData`: three saves — two cartridges and a plain GOLD — one box, and
  each of the three POKéMON found from the others. Cutting the plain-save walk
  out of `readAll` fails it, which is the evidence that was missing.

- **"RED is not imported" named the wrong game.** Sending *from* a Gen 2 game
  needs a Gen 1 dataset, and any of RED, BLUE or YELLOW will do — the mount
  tries all three. Telling a BLUE player to import RED was telling them to do
  the one thing they did not need to. The line names all three now.

- **A refusal that ran off the end of the text box.** "That can't be sent." is
  nineteen columns in an eighteen-column box, so a player read it with the
  full stop cut off. Every refusal is measured against the box now, page by
  page and line by line, so the next one cannot get through.

## 1.8.2

- **A POKéMON sent from Wild Green is in Wild Crystal's GLOBAL BOX.** Reported
  as exactly that, and it was not: the other cartridge's outbox was invisible,
  so the box read empty on every save but the one you were in.

  `mod.save:set("globalbox", …)` does not write at `globalbox`. Inside the
  Gen1WildUI bundle every vendored mod's save is a facade that **prefixes each
  key with the feature's id** (`runtime/facade.lua`, `keyedProxy`/`joinKey`),
  so what this mod writes as `globalbox` is filed as `box.globalbox`. That is
  invisible to the mod itself — it reads back through the same proxy that
  wrote it — and fatal to the GLOBAL BOX, which reads *other* saves raw off
  disk and was looking for the bare key. The standalone mod, with no facade in
  front of it, writes the bare key, so the two could not see each other
  either.

  A bucket is found by its **shape** now, not by its key: every mod id in a
  save, and every key under each of them, with the format, the origin and the
  two tables as what says "this is a box". That holds for the prefix the
  bundle uses today, for a different one tomorrow, and for the standalone
  mod's bare key, without any of them being named in the store.

  The live save's own bucket is still the one thing skipped, and it is skipped
  by its **origin** rather than by which slot it came from — so a bucket the
  live save carries from a *different* channel is read like anyone else's.

- **The suite drives the engine's real `SaveData` now, not a stand-in for it**
  (`tests/globalcarts_test.lua`). Every existing test of the cross-cart read
  went through a SaveData double, and a double answers what it was written to
  answer — so all of them agreed with the code and none of them agreed with
  the game. The new one builds a two-cartridge installation over a memory
  filesystem through the engine's own slot registry, writes Wild Green's save
  with its box where the *bundle* files it, and asks Wild Crystal what is in
  the box. Against the old code it fails with the reported symptom.

  The three harnesses that stub `mod.save` now prefix keys the way the bundle
  does, for the same reason.

## 1.8.1

- **The GLOBAL BOX reads every channel's bucket, not just this build's.**
  `save.modData` is keyed by mod id, and this feature ships under three of
  them: the stable bundle, the nightly channel's copy of it, and the
  standalone mod. Reading only our own meant a player who moved between
  channels would open the GLOBAL BOX and find it empty, with their POKéMON
  still sitting in the save under the other name.

  Every bucket in a save is read now. A bucket is recognised by its own shape
  — format, origin and the two tables — rather than by whose it is, and the
  origin already in it keeps two channels' entries apart once they are in the
  same box. Writing is unchanged: the only bucket anybody ever writes is their
  own. The live save's own bucket stays the one exception, because the copy in
  memory is ahead of the copy on disk.

## 1.8.0

- **The GLOBAL BOX.** Past the last of your cartridge's boxes the header keeps
  going: **GLOBAL 1**, and one more page every time the last one fills. It is
  one box shared by every save on the installation — deposit a POKéMON on Wild
  Green, withdraw it on Wild Crystal — and there is a **SEND** row on a
  POKéMON's own popup in the party menu, on both games, for the times you do
  not want to open the PC at all.

  **It lives inside the saves**, which is the whole of why it is shaped the way
  it is. Save sync carries exactly two things: save slot sources
  (`PUT /sync/save`) and the mod roster (`PUT /sync/mods`). `mod_storage` and
  `mod_cache` appear nowhere in `src/sync/`, so a shared box kept in either
  would not follow the player to another machine, would not be in a backup of
  their saves, and would not come back with RESTORE.

  So it is not one list. Every save carries its own **outbox** in
  `save.modData[<modId>]` — which both generations back `mod.save` with
  (`src/core/Game.lua:1222`, `src/core/Game2.lua:199`) — and the GLOBAL pages
  are all of them laid end to end. Your own save's outbox is the only thing
  you ever write; every other save is read read-only through the same
  `SaveData` calls sync itself makes; and withdrawing one that came from
  another save writes a **claim** into yours, which every cartridge reads, so
  it leaves the box everywhere at once and the save still holding it lets go
  the next time it boots.

  Two consequences worth stating. A deposit is part of a save, so it is
  written when the game writes — quit without saving after a SEND and the SEND
  goes with everything else you did. And deleting the save a POKéMON was
  withdrawn *into*, before the sender next boots, puts it back in the sender's
  outbox: the failure mode is one coming back, never one going missing.

  What may live in it is the **Time Capsule's** rule, reused rather than
  restated (`src/online/Convert.lua`): a Johto species, a Gen 2 move, a held
  MAIL or an EGG is refused with the cartridge's own reason. Gold converts on
  the way in and on the way out; Red has nothing to convert. Only the Gold
  DEPOSIT needs a Gen 1 dataset — `Convert.toGen2` reads one only as a
  fallback for a POKéMON whose stats are missing, and the deposit side runs
  `Stats.ensure` so they never are — so the direction this was asked for
  (everything out of the Wild Green box and into Wild Crystal) mounts nothing,
  and the other pays for it once per session.

  A shared page has no gaps, no swap, no SORT and no RELEASE, and each of
  those follows from the store being shared rather than being a decision taken
  for its own sake: the cell another cartridge's POKéMON sits in is not this
  save's to record, a sort would be this save deciding the order of POKéMON in
  other people's saves, and "gone forever" is not a thing this save gets to
  decide about one living in another. Picking one up and pressing B puts it
  back in the cell it came out of rather than at the end of the box — a claim
  is dropped, and a POKéMON of your own goes back under the id it already had.

  One switch (**GLOBAL BOX**) turns the pages off and one (**SEND ROW**) turns
  the row off. With the first off the box screen is the twelve — or fourteen —
  it always was.

- **The suite runs in CI now, under both interpreters.** This repo had only a
  release workflow, so none of its suites ran on a push. They do now, under
  LuaJIT *and* Lua 5.4 — the game is LuaJIT and the benches are 5.4, and that
  gap has cost this suite of mods real bugs. It found one immediately: the Gen
  2 bench's `Mail.removeSlot` stand-in used `table.remove`, where the cart
  shifts within a fixed six-slot array — the same shift only while the array
  happens to be dense, and an outright error on 5.4.

## 1.7.2

- **The Gold box walks its POKéMON at the cart's own speed.** The clock handed
  to the borrowed icon renderer was *doubled*, to match the Gen 1 box's
  `ANIM_STEPS = 8`. That number came from the wrong screen: Red's box animates
  by **mirroring** one frame the way the hardware's OAM did, and eight steps of
  a mirror reads as a shuffle — but Gold's icons are a two-pose **walk**, so
  eight steps of that is just the walk at double speed.

  The party list this grid actually sits beside is Gold's, at sixteen steps —
  and this screen draws a party column of its own, so the same POKéMON was
  walking at one speed in the box and another in PARTY MENU. It uses the one
  cadence now. 240 ticks is fifteen whole flips, so the walk still doesn't jump
  when the counter wraps, and the flash reads `ticks` directly and is unchanged.

## 1.7.1

- **BILL'S BOX now reaches Gold's PC menu.** Reported as "when I go to the PC,
  BILL'S BOX isn't replacing BILL'S PC" — and it wasn't, on the one menu a
  player presses first. Gold has *two* PC menus where Red has one: the
  "Access whose PC?" chooser (`src/ui/gen2/CenterPcMenu.lua`) and the storage
  verbs behind it (`src/ui/gen2/PcMenu.lua`). Only the second runs the
  `ui.pc.items` hook this mod renames through, so the row actually carrying
  the words "BILL's PC" had no seam on it and kept its name while every other
  surface said BOX.

  Its two sibling PC screens both call that hook and its own comments describe
  the same contract, so the missing call looks like an oversight in the engine
  rather than a decision — worth raising there. Until it is, the row and the
  page it opens with ("BILL's PC accessed.") are renamed by wrapping the two
  methods that produce them. `<PLAYER>'s PC` and `PROF.OAK's PC` are other
  people's machines and keep their names.

  `tests/goldpcname_gen2_test.lua` drives the cart's own `CenterPcMenu` rather
  than a stand-in, because a stand-in's worth of distance between what the mod
  hooked and what the game drew is the whole bug.

## 1.7.0

- **Runs on Gold, Silver and Crystal.** The manifest declares `gen2`, and the
  same screen is there: the 5x4 grid, the party column, pick up and put down.
  Gold's own storage is a list of names with one picture beside it, and this
  replaces all three of its verbs at once — `WITHDRAW`, `DEPOSIT` and
  `MOVE POKéMON` all land on the grid, because Gold sends them to one place.

- **Free placement and the party's hole, on Gold.** Gold stores a box the way
  Red does — a compact array — and an array cannot hold a gap, so a POKéMON put
  down in cell 12 of an empty box used to appear in cell 1, and lifting the
  second of six let the other four slide up behind it. The arrangement now
  lives beside the box in this mod's save data, one cell per POKéMON,
  reconciled on every read; the cartridge's own list is untouched. The party
  column keeps its hole until the screen closes, by the other mechanism —
  `save.party` stays dense and sorted by row, because party order is battle
  order.

- **The carried POKéMON is drawn once.** It used to be a second pass painted on
  top of the grid while the grid still drew the cursor cell's own occupant
  underneath: two icons in one cell, one blinking through the other. It is
  drawn *by* the grid now, in place of the occupant, so the flash is a skipped
  draw rather than a second sprite.

- **Only the icon under the cursor walks — with no bundle installed.** Gold
  picks every icon's frame off one clock, so all twenty cells flip together
  unless something says otherwise. The rule that says otherwise used to live
  only in Gen1WildUI's icon runtime, which meant a standalone install had
  nothing honouring it and the whole grid flipped at once. The rule is this
  mod's own now, installed once on the class, and the bundle's copy composes
  with it rather than fighting it.

- **`UNDO` on a sort restores the gaps**, not just the order, and releasing a
  POKéMON takes its own entry out of the arrangement rather than the last one,
  so nobody else moves.


## 1.6.0

Gen1WildUI carried this as an overlay while it was ahead of a release here; it
shipped in the bundle's 1.22.0. Same code, in the mod that owns it.

- **A full-colour icon is clamped to its cell on both axes.** The width was
  decided by the height — `w = info.h > ICON and ICON or info.w` — so a sprite
  wider than the 16px cell but no taller kept its full width and drew past its
  square, and a taller-but-narrower one had its width forced up to 16 it never
  asked for. Reported as black boxes around some POKéMON in the box on a dark
  page.
- The page under a full-colour icon is painted before the art goes in.
  `PaletteFX.markTrueColor` blits raw so the icon keeps its own colours, and
  raw means the white page under it stays white when everything around it goes
  black. With no theme provider installed this is inert, so a standalone
  install is unchanged.

The clamp is exported as `iconRect` — it is the whole of what went wrong and
it is pure, where everything around it needs a game, a save and a file on disk.

## 1.5.0

The status tint is removed, at the author's request. Icons are drawn as they
always were, and the palette zone under them is the species colours again.
Nothing else changed -- the source is byte-identical to what it was before the
tint went in.

## 1.4.0

The status tint now reaches **full-colour icon art**.

It rode a palette zone, and a palette zone only reaches art that goes through
the shade-remap pass -- which full-colour art sits out by design, since this
mod marks its rect trueColor precisely so the pass does not repaint it off its
red channel. So the tint coloured nothing at all for anyone running a
full-colour icon pack.

The icon is now drawn in the condition's colour instead: LÖVE multiplies an
image by the current colour, so white is the untouched icon and the tint shifts
its hue while keeping its own light and dark. That reaches both kinds of art.
The palette zone stays as well, for the species colours underneath.

The colour comes from `drawColour` in **STATUS COLOURS**
([Gen1WildQOL](https://github.com/wild1walker/Gen1WildQOL) 1.8.0), so the party,
the box and the world keep agreeing. Without that mod there is no tint, exactly
as before.

## 1.3.0

A POKéMON in the box wears its condition. Poisoned is purple, fainted is grey,
and the rest of the statuses have their own colour -- over the species colours
each cell already wears, so a poisoned CHARMANDER still reads as a CHARMANDER.
It applies to the grid and to the party column beside it.

The colours come from **STATUS COLOURS** in
[Gen1WildQOL](https://github.com/wild1walker/Gen1WildQOL) 1.6.0, which owns one
table of what each condition looks like so the box, the party and the dex agree
instead of drifting apart. Without that mod installed there is no tint and the
cells are the species colours exactly as before.

It rides the per-cell zone this mod already builds, so it costs nothing extra
to draw and full-colour art still sits out the pass untouched.

## 1.2.0

- **The per-POKéMON popup takes rows from other mods.** START over a POKéMON
  has always been this screen's own three verbs; it now asks whoever is
  installed whether they have a fourth. A mod that can do something *to* a
  POKéMON gets the row where the player already goes looking for verbs, and
  the alternative — reaching in and patching this screen's internals from the
  outside — stops being the only way to do it.
- The seam is `mod.find("Gen1BillsBox").exports.actions.provide(fn, mod.id)`,
  the same shape Gen1Dex publishes for its AREA caption: providers are asked
  in the order they registered, every one of them contributes (a popup is a
  list, not a single answer), and the callback is handed the game, the
  POKéMON and which pane it is on so a mod can offer a row on the box side
  and not the party side.
- **Rows land between the screen's own verbs and CANCEL.** CANCEL stays last
  however many arrive: it is where a thumb expects the way out to be, and a
  mod's row must not be able to move it.
- **The popup hangs off the bottom edge now**, the way CHANGE BOX already
  did. The vanilla three rows put its bottom edge exactly on the last tile
  row, so a fourth row would have run off the screen; anchoring it instead
  keeps the POKéMON the popup is about visible above it however tall it gets.
- A provider that throws is dropped and reported rather than taking the box
  down with it, and a second registration from the same owner replaces the
  first — a mod's entry chunk runs again on every hot reload, and a stale
  provider closed over the previous load's tables is the one that would
  otherwise answer.
- Nothing changes with no provider registered: the popup is the same three
  rows, in the same order, and the suite asserts that separately from the
  seam.

## 1.1.1

- **The party menu colours are out again**, and the POKéMON screen is the
  engine's own once more — the same screen 1.0.16 shipped, byte for byte.
  1.1.0 added a species palette per party row and it did not do anything
  visible on the setup it was asked for; that work is being taken up
  elsewhere rather than left half-landed here.
- `PARTY COLOURS` is gone with it, so the mod manager's rows are the six they
  were. Nothing about the box, the START row, the renamed PC lines or the
  save is touched by this — 1.1.0 only ever added to the party menu, and only
  the palette list and a full-colour mark at that.
- The full-colour icon test goes back inside `screen.lua`. It moved out in
  1.1.0 only because two screens were asking it; one screen asks it again.

## 1.1.0

- **The POKéMON screen wears the same colours as the box.** The box gives
  every POKéMON in it its own species palette; the party menu draws the same
  six POKéMON one button press away, and the cart put a single `MEWMON` block
  over its whole icon column — so the two screens disagreed about what colour
  a POKéMON was. There is now one palette zone per party row, two tiles
  square, over the icon.
- Everything else on that screen stays the cart's: the `GREENBAR` base, the
  green / yellow / red HP bar blocks, the layout, the cursor.
- Full-colour icons from an icon mod are **marked** there rather than
  coloured, exactly as they are in the box.
- The engine's party menu is **decorated**, not replaced. A mod that has
  already claimed the party screen keeps it.
- **PARTY COLOURS** turns it off, and off is the engine's screen exactly.

## 1.0.15

- **SORT has a heading now**, the way the box list is headed CHANGE BOX. It
  costs no rows: the widget writes a title into the top border it was going to
  draw anyway. Padded a space each side and drawn a pixel low, for the same two
  reasons the box list's heading is.
- Both pop-ups now go through one decorator instead of the box list carrying
  its own copy: it takes the title and the "more below" glyph off the parent
  draw -- the two things the widget draws *onto* its own frame -- and puts them
  back inside it.

## 1.0.14

- **The CHANGE BOX heading sits a pixel lower.** The bordered widget draws a
  title at the very top of the border tile, so the glyphs' first pixel row
  lands on the single white pixel the frame keeps outside its rule and the
  letters read as touching the edge of the pop-up. The heading is now drawn by
  hand, one pixel down, which leaves that margin intact; the row it gains at
  the bottom is the blank one under the top edge, so nothing else moves.

## 1.0.13

- **The CHANGE BOX heading no longer touches its frame.** The bordered widget
  whites out exactly as many tiles as the title is wide and sits it straight on
  the top rule, so an unpadded heading has the rule running into the C and the
  X. The title is padded a tile on each side; the padding lives at the call
  rather than inside the string, so the translation key stays the two words.
- **The scroll arrow moved off the border and inside it.** The widget's own
  "more below" glyph is drawn on the bottom border row, over the frame's rule
  and a tile from its corner. The box list now hides that one — the draw is
  handed a list that stops at the last visible row, so there is nothing left to
  point at — and draws the mod's own triangle instead, in a spare interior
  column beside the bottom row, clear of every edge. Which also makes it the
  same arrow as the grid cursor and the header's two.
- The pop-up is a tile wider (and starts a tile further left) to buy that
  column: the widget grows a box to fit its widest label and never past what it
  is handed, so the room had to be asked for.

## 1.0.12

- **CHANGE BOX is a bordered pop-up too.** A on the box header used to open a
  full-screen list with no frame around it — the engine's list widget draws its
  default mode as a bare 160×144 fill and only its *item box* mode has a
  border, and that one is the bag's fixed four-row geometry. So the box list is
  now the same bordered widget SORT and the per-POKéMON rows use, hanging from
  the bottom edge with the header naming the open box still visible above it.
- Six of the twelve rows are shown at a time and the rest scroll, because
  twelve rows at the vanilla two tiles each would need 26 of the 18 tile rows
  there are. The list **opens on the box you are already in** rather than on
  BOX 1 — with half of it visible, starting anywhere else hides where you are.
- How full each box is moved into its row's label, right-aligned in fixed
  columns so the counts still line up under each other: the bordered widget
  draws one label per row and has no second column for them.

## 1.0.11

- **The flash is faster** — 16 steps lit, 8 dark, where it was 40 and 20. Still
  lit twice as long as it is dark, because the thing flashing is the thing you
  are trying to look at, but quick enough now to read as a flash rather than as
  something switching on and off.
- **One arrow, three directions.** The grid's cursor, the box header's two
  arrows and the header's own selector are now the same triangle drawn on
  whichever axis is asked for. The selector used to be the font's `$ED` glyph,
  which sits inside an 8×8 cell with its own padding and so could not be lined
  up with a triangle drawn beside it however the coordinates were nudged. All
  three now share a row and a shape by construction.
- **SORT is a bordered pop-up**, not a full screen. It is the same widget with
  the same chrome as the per-POKéMON rows START opens, hanging from the bottom
  edge the way the party menu's own submenu does, so it never covers the header
  naming the box you are sorting.

## 1.0.10

- **SELECT over the box opens SORT.** COLLAPSE, BY DEX, BY LEVEL (strongest
  first), BY NAME, BY TYPE — and **UNDO**, one step, offered only while it
  would actually work.
- Every sort ends the same way, with the box closed up into cells 1..n, so
  **COLLAPSE is just the sort that changes no order** and the rest are that
  plus a reordering. Which is also why COLLAPSE reads the *cells*: the compact
  array's order stopped meaning anything the moment gaps existed, so "keep what
  I can see, just close it up" is a sort like any other.
- Ties keep the order you already had. `table.sort` is not stable, so each
  POKéMON's current cell is carried alongside and used as the last word rather
  than hoped for.
- **SELECT from the party still crosses to the box**, which makes the pair read
  as one key — SELECT gets you there, SELECT again tidies it — and costs
  nothing, because LEFT and RIGHT already cross the panes.
- SORT is refused while a POKéMON is in your hand: a box reordering itself
  around one that is not in it reads as the box shuffling for no reason.
- UNDO checks the box still holds the same POKéMON *by identity*, not by count.
  One released and one caught leaves the count alone, and that is exactly the
  case a count check would wave through — and would have resurrected the
  released one.

## 1.0.9

- **The party takes gaps too, while the box is open.** Pick one out of the
  middle of the party and its row stays empty instead of the rest sliding up,
  and you can put it back down in any empty row. Close the box and the party
  is a list of six again.
- It is deliberately *not* the same mechanism as a box's, and the difference is
  the point. A box's arrangement is saved, because a gap you left in storage is
  a decision. The party's is not: it lives on the screen object and is gone the
  moment you close it. **`save.party` is never sparse** — what is sparse is only
  which row each member is drawn in.
- The party array is kept **sorted by that row** after every change, which is
  the whole safety of it: party order is *battle* order, `party[1]` is who you
  send out, so an arrangement that let the visual order and the array order
  drift apart would quietly change who leads. Sorted, they cannot disagree —
  and closing the screen has nothing to collapse, because the party already was
  the list it looked like.

## 1.0.8

- **A BOX row on the START menu**, opening the same screen the PC opens. It
  sits with POKéMON, which is what it is about, and B brings the START menu
  back the way every other start-menu submenu does (`RedisplayStartMenu`).
- New option **BOX ON START** (on) removes it. It is a real change to where
  storage can be reached from — the cart wanted a PC in front of you — so it
  gets a switch.
- The screen now takes the `onCancel` the engine's own start-menu submenus
  take. Opened from the PC there is none, so B there still just uncovers the
  PC's own menu, which was waiting underneath all along.

## 1.0.7

- **Boxes are a real grid now: gaps stay put.** Picking a POKéMON up used to
  make the one behind it slide into the hole, because a Gen 1 box is a
  *compact* array — `box[1..n]` with nothing after `n` — and taking one out of
  the middle closes it up. The array still is that, because it is the save
  format and what the engine's own deposit appends to. What is new is that the
  **arrangement** is kept beside it, in this mod's own save data: one grid cell
  per POKéMON. A POKéMON picked up leaves its cell empty, one put down lands in
  the cell you aimed at, and nothing else moves. The gaps survive closing the
  box, and the save is untouched — remove this mod and you get the compact box
  back, with the same POKéMON in it.
- The two are reconciled on **every** read, so anything that adds to a box
  behind this screen's back — a catch overflowing into it, another mod, an
  imported `.sav` — is absorbed rather than corrupted: new arrivals take the
  lowest free cell, extra cells are dropped, and a cell out of range or claimed
  twice is thrown away.
- **A POKéMON in your hand slowly flashes.** Four shades cannot dim one, so it
  blinks — but slowly, and lit far longer than dark, because the thing flashing
  is the thing you are trying to look at. Two thirds of a second lit, a third
  dark.
- The **party** still closes up behind a POKéMON taken out of it. A party of
  six with a hole in it is not something the rest of the game would understand.
- The cursor no longer jumps after a drop into an empty box cell, because there
  is nowhere else for the POKéMON to land any more.

## 1.0.6

- **Full-colour menu icons are no longer wrecked by the palette pass.** The
  SGB pass remaps four DMG shades to four colours keyed off each pixel's *red*
  channel. Run authored full-colour art through that and it is not recoloured,
  it is destroyed: BEEDRILL's orange has red near 1.0, lands on shade 0, and is
  painted the palette's white. That is why the box's icons never matched the
  party menu's - and it had been wrong since 1.0.0, through both the `MEWMON`
  ramp and the per-species zones that replaced it.
- The engine's answer is `PaletteFX.markTrueColor`, which appends the region to
  the zone list to be re-blit with no shader over the colourised pass. Nothing
  in `PartyMenu.drawIcon` calls it: the screens that draw full-colour art mark
  it themselves. This screen now does too, and skips the species zone for
  those icons.
- Decided per icon by reading the **pixels** of whatever `drawIcon` resolves,
  which is the only test a mod cannot route around - the icons registry, a
  species record's own `icon`, an asset override and the `pokemon.icon` hook
  all end in a file, and the file either carries colour or it does not. A
  built-in icon *class* is never full colour whatever file it points at,
  because `drawIcon` bakes those to grey through `obpIcon`.
- Vanilla DMG icons are unaffected and still get their species palette.

## 1.0.5

- **Reverts 1.0.3's cell placement.** Centring the icon vertically was paid
  for out of the cursor's clearance, and the cursor's flat top row ended up
  drawn straight onto the rule above the cell, where it read as a smear on the
  grid rather than as an arrow. The POKéMON and the arrow are back where 1.0.2
  had them.
- The cell's vertical column has no slack to spend: a gap, the 4-pixel cursor,
  a gap, the 16-pixel icon and a gap, inside the 23 pixels between two rules,
  is three pixels for three gaps. 1/1/1 is the only split that leaves both
  ends clear, so the icon is centred across the cell and deliberately not down
  it. That is now written down in the source, the README and the card, and
  pinned by assertions on the *clearances* rather than on the coordinates —
  1.0.3's coordinates were perfectly good and the arrow was still in the line.

## 1.0.4

- **The open box now follows a catch that overflowed.** Catch into a full box
  and the PC's open box becomes the one that took it, so the PC stops opening
  on a box with no room in it. It also aims the *next* overflow:
  `Boxes.deposit` starts its walk from the open box, so the following catch
  lands there directly instead of walking past the full one again.
- The note says which happened rather than assuming: *"BOX 1 was full! / Now
  using BOX 7."* when the box moved, *"…/ Stored in BOX 7."* when
  **SWITCH ON FULL** is off.
- New option **SWITCH ON FULL** (on).

Worth recording, since it was asked for as Gen 2 behaviour: Gold does the
opposite. A full party *and* a full current box refuses the throw outright
there (`Ball_BoxIsFullMessage` — "The POKéMON BOX is full. That can't be used
now."), and Bill rings you when a box fills. Advancing to the next box with
room is Gen 3's answer, and it is the right one on this engine, which already
refuses to lose the catch.

## 1.0.3

- **The POKéMON are centred in their cells.** 1.0.2 sat them 6 pixels below
  the rule above and 1 above the rule below — pushed hard against the bottom
  of the cell — because the cursor band was taking its room out of the top.
  Margins are now 3 and 4 on both axes, which is as centred as a 16-pixel icon
  gets inside the 23 pixels between two rules.
- **The cursor hangs from the rule above the cell** instead of floating in the
  middle of the gap, so it costs the icon no room and its tip lands on the row
  directly above the POKéMON's head. Its flat top row is drawn onto that rule,
  which leaves a solid wedge showing when the cursor is resting and two thin
  diagonals when it is carrying — a bigger difference than filling or not
  filling a top edge was.
- The arrow is now centred on the *icon* rather than on the cell, so the two
  stay together if either ever moves.

## 1.0.2

- **A POKéMON caught into a full box now says where it went.** The overflow
  itself was never missing: `src/pokemon/Boxes.lua`'s `deposit` already walks
  from the open box forward through all twelve, wrapping, and drops the
  POKéMON in the first one with room — the catch only fails once all 240
  places are taken. What it never did was *say* so. The line it prints is the
  cart's own, and the cart never needed to name a box because the POKéMON
  could only ever be in the one you had open. One extra line now names the box
  that was full and the box it went to, and only when those differ — an
  ordinary catch into the open box stays exactly as quiet as it was.
- New option **FULL BOX NOTE** (on) turns that line off.

## 1.0.1

Reported against 1.0.0: with COLORS on ADVANCED every POKéMON in the box came
out of one salmon ramp and the grid lines came out orange, while the party
menu next door showed each POKéMON in its own colours.

- **Every POKéMON in the box and the party now wears its own species
  palette.** 1.0.0 asked for one `MEWMON` zone over the whole screen, which is
  what the PC's other screens wear — and `MEWMON` paints shade 1
  `{239,156,107}`, so one ramp reached every icon at once. The screen now
  emits a palette zone per POKéMON, the way the battle and summary screens
  give a mon its species colours. ADVANCED was applying all along; this screen
  was the thing not asking for it.
- **The chrome is black instead of orange.** The orange *was* the grid: 1.0.0
  drew its lines in shade 1, which is exactly the shade `MEWMON` paints
  salmon. Every pixel this screen draws itself is now shade 3, which is
  `{0,0,0}` in the grey ramp and in all 151 species palettes alike — so the
  lines stay black under any zone laid over them, and the base palette is now
  the plain four DMG greys.
- **The square highlight is gone.** The cursor is a solid triangle in the band
  above a POKéMON's head, pointing down at it, and the same triangle hollow
  while that POKéMON is in your hand. The party pane keeps the sideways
  cursor — the party menu's own `$ED` / `$EC` pair, filled and hollow — because
  six rows of sixteen fill that pane exactly and leave no band above a head.
- The grid is ruled as a table rather than as twenty separate frames, so
  neighbouring cells share one black line instead of stacking two.
- Cells are 24×24 at x=32 rather than 26×24 at x=30. Not cosmetic: an SGB
  palette zone is addressed in tiles, and a cell three and a half tiles wide
  cannot carry one. Every cell edge and party row now lands on an 8-pixel
  boundary, which is what makes the per-POKéMON colours possible at all.
- A carried POKéMON no longer rides a few pixels above its slot; the hollow
  arrow is what says it is carried.

## 1.0.0

First release.

- Replaces the `BoxMenu` screen — the one BILL'S PC pushes — with a
  party-and-box workspace: six party slots down the left, the open box as a
  5×4 grid of twenty on the right, a header naming the box and how full it
  is, and one line under the grid naming what the cursor is on.
- A picks a POKéMON up, puts it down, or swaps it with the slot's occupant.
  B puts a carried POKéMON back in the slot, and the box, it came from, and
  closes the screen only with an empty hand.
- LEFT out of the first column crosses to the party, RIGHT crosses back, and
  SELECT does it from anywhere. UP out of the top row focuses the box header,
  where LEFT/RIGHT change box and A opens the twelve-box list. A carried
  POKéMON rides along across a box change.
- START opens STATS and, for a boxed POKéMON, RELEASE — with the vanilla
  confirmation, its "Bye *MON*!" and Yellow's "looks unhappy about it!".
- Renames the PC's storage row to SOMEONE'S BOX / BILL'S BOX on the same
  `EVENT_MET_BILL` gate as the vanilla names, and re-words the three lines
  that name the machine elsewhere by substitution, so a localized import
  keeps its own wording for the rest of each sentence.
- Slots are drawn through `PartyMenu.drawIcon`, so any menu-icon mod reaches
  the box with nothing to configure.
- Keeps the native save format, the last-POKéMON rule, the withdrawal stat
  recalculation, `PIKAHAPPY_DEPOSITED`, the sleeping-Pikachu deposit refusal
  and the PC session's silent menus.
- Options: PLACE CRY, HOLD TO MOVE, OPEN ON.
