# Changelog

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
