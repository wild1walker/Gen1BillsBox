# Changelog

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
