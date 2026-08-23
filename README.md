# Gen1BillsBox

A Gen 3-style storage screen for
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) that **replaces**
Bill's PC instead of sitting next to it: your party down the left, the open
box as a grid on the right, and a cursor that picks a POKéMON up and puts it
down.

Gen 1's PC is a menu of four verbs over a list of twenty names, and moving
one POKéMON from box 3 to box 7 costs a withdraw, a box change and a deposit.
This is the box the list was always standing in for — and nothing more than
that. It is drawn in the Game Boy's own font, its four shades and its
standard bordered boxes. No type colours, no card chrome, no widescreen
layout. The grid is Gen 3's idea; every pixel drawing it is Gen 1's.

The slots draw through **the party menu's own icon renderer**, so whatever
menu sprites you already run show up in the box exactly as they show up in
the party.

## Install

Download `Gen1BillsBox-<version>.zip` from [Releases](../../releases), then in
the game:

**Launcher → MODS → Import mod .zip**, or in a running game
**START → MODS → Import mod .zip**.

The manifest declares this repo, so the launcher's **MODS** tab offers a
newer release when one is published, and the mod can be installed from
**Find mods** without touching a file at all.

Requires Gen1Recomp with mod API 2. Red, Blue and Yellow.

## The screen

```
┌──────────────────────────────────────┐
│  ◀    BOX 1                  12/20 ▶ │   the header
└──────────────────────────────────────┘
   ▶ ()  │  [ ][ ][ ][ ][ ]
     ()  │  [ ][ ][ ][ ][ ]              the party, then the open box
     ()  │  [ ][ ][ ][ ][ ]
     ()  │  [ ][ ][ ][ ][ ]
┌──────────────────────────────────────┐
│ NIDORAN♂                        :L17 │   what the cursor is on
└──────────────────────────────────────┘
```

Six party slots and twenty box cells, side by side, on one 160×144 screen.

## Controls

| Action | Control |
| --- | --- |
| Move the cursor | D-pad |
| Cross to the party / back to the box | LEFT out of the first column, RIGHT out of the party — or SELECT from anywhere |
| Pick a POKéMON up, put it down, swap two | A |
| Put a carried POKéMON back where it came from | B |
| Close the box | B, with nothing in hand |
| Focus the box header | UP out of the top row |
| Previous / next box | LEFT and RIGHT on the header |
| Jump to any box | A on the header |
| STATS and RELEASE | START, over a POKéMON |

A carried POKéMON stays with the cursor while you walk the header to another
box, which is what makes a cross-box move one operation. B always means
*back*: it puts a carried POKéMON down in the slot, and the box, it was
picked up from, and only closes the screen when your hands are empty. There
is no way to leave this screen holding a POKéMON, and no cell where the way
out disappears.

Dropping onto an occupied slot **swaps** the two. Because the grid has
exactly as many cells as a box has room, a full box has no empty cell to aim
at — so a full party and a full box can still trade, and nothing is ever
refused for want of space.

## BILL'S PC is BILL'S BOX

The Pokémon Center PC's storage row reads **SOMEONE'S BOX** until you meet
Bill and **BILL'S BOX** after, following the same `EVENT_MET_BILL` gate the
vanilla names follow. The three sentences that name the machine elsewhere
follow it:

- "Accessed BILL's **BOX**. Accessed POKéMON Storage System."
- "Accessed someone's **BOX**. …"
- "*MON* was transferred to BILL's **BOX**!" when you catch one with a full
  party.

Those are re-worded rather than replaced: one substitution of the machine's
name over the extracted line, so a localized import keeps its own wording for
the rest of the sentence, and a translation that does not spell it "PC" is
left alone.

## Settings

In the mod manager's row for this mod:

| Row | Default | What it does |
| --- | --- | --- |
| **PLACE CRY** | on | The cry of whichever POKéMON just landed in a slot. The vanilla PC plays one on every withdraw and deposit; this is the same sound at the same moment. |
| **HOLD TO MOVE** | on | Hold a direction to keep moving, at the cadence the engine's own list menus use. |
| **OPEN ON** | BOX | Which side the cursor starts on. |

## What it keeps from the vanilla PC

- The save format and the 12-boxes-of-20 model are untouched
  (`src/pokemon/Boxes.lua`). Turning the mod off leaves a save reaching its
  storage exactly as before.
- The party may not be emptied — the last POKéMON cannot be picked up, which
  is the vanilla PC's "You can't deposit the last POKéMON!" enforced one step
  earlier so it cannot be walked around.
- A POKéMON withdrawn into the party has its stat block recalculated
  (`add_mon.asm` `_MoveMon`'s tail), so a mon decoded out of an imported
  `.sav` can never reach the party menu without one.
- Depositing bumps Yellow's Pikachu happiness (`PIKAHAPPY_DEPOSITED`), and a
  sleeping starter Pikachu still refuses to be boxed.
- RELEASE keeps its confirmation, its "Bye *MON*!", and Yellow's "looks
  unhappy about it!" refusal. It is offered for boxed POKéMON only, which is
  where the vanilla PC offers it.
- The refusals are the game's own extracted lines, in the game's own text
  box, and the whole screen runs silent the way the PC session does
  (`BIT_NO_MENU_BUTTON_SOUND`).

## Known differences

- **A box stays a compact array.** Gen 1 stores `box[1..n]` with nothing
  after `n`, and the save format and every other mod read that shape. So
  dropping into an empty cell appends to the end rather than leaving a hole,
  and the cursor follows the POKéMON to where it actually landed. Ruby's
  sparse grid is the one thing here that is not reproduced.
- **Changing box no longer saves.** The cart asked "data will be saved. OK?"
  because it was swapping an SRAM bank; this engine keeps all twelve boxes in
  one save file, so the prompt has nothing left to do.
- **No per-move message.** The vanilla PC prints "*MON* is taken out." and
  "*MON* was stored in Box n." for every transfer. A screen where a move is
  one button press cannot also stop for a text box each time; the cry and the
  slot you can see are the confirmation.
- **START is a new binding.** The vanilla PC never watched it. It is where
  STATS and RELEASE went once A became pick-up-and-put-down.
- Boxes have no names or wallpapers. They are numbered, as they are on the
  cart.
- The party is refreshed behind you on the way out, so a follower does not
  keep walking as the POKéMON you just deposited. With
  **Wilds of Kanto** installed its own follower is re-synced too, and may
  reappear standing on the player until your next step.

## Compatibility

Menu icons come from `PartyMenu.drawIcon`, the engine's single canonical icon
path: the icons registry, a species record's own `icon` field, asset
overrides and the `pokemon.icon` hook all resolve there. Anything that
changes your party menu icons changes these slots, with nothing to configure.

STATS opens the game's live `SummaryMenu`, so a mod that owns the summary
screen owns it here too.

The PC menu hook calls the next handler first and decorates the result, so
another mod's row on the same menu survives.

`modern_pc_ui` is declared as a conflict: it replaces the same screen id and
only one of them can. **Gen 3 Box** (`gen3_box`) can be installed alongside
this — it adds a separate screen of its own rather than replacing the PC —
though running both is two storage screens over one save.

## Development

From a Gen1Recomp checkout with this mod at `mods/Gen1BillsBox`:

```sh
python3 tools/modkit.py validate mods/Gen1BillsBox
python3 tools/modkit.py lint mods/Gen1BillsBox
luajit mods/Gen1BillsBox/tests/gen1billsbox_test.lua
```

The suite runs against the engine's ROM-free fixture dataset, so it needs no
ROM. It drives the screen the way a player does — one button press per
update — and asserts on `save.boxes` and `save.party` afterwards, including a
census that no POKéMON is ever created or lost, and a geometry pass that
records every fill the screen draws and measures it against the 160×144
layout this README claims.

This package contains no ROM-derived assets. Pokémon names and imagery are
trademarks of their respective owners; this is an unofficial fan-made mod.
