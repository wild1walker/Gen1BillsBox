# Changelog

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
