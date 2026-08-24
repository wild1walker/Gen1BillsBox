# Gen1BillsBox

A Gen 3-style storage screen for
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) that **replaces**
Bill's PC instead of sitting next to it: your party down the left, the open
box as a grid on the right, and a cursor that picks a POKéMON up and puts it
down.

Gen 1's PC is a menu of four verbs over a list of twenty names, and moving
one POKéMON from box 3 to box 7 costs a withdraw, a box change and a deposit.
This is the box the list was always standing in for — and nothing more than
that. It is drawn in the Game Boy's own font, black line art and its standard
bordered boxes. No type colours, no card chrome, no widescreen layout. The
grid is Gen 3's idea; every pixel drawing it is Gen 1's.

The slots draw through **the party menu's own icon renderer**, so whatever
menu sprites you already run show up in the box exactly as they show up in
the party — and each one gets **its own species palette**, so a box shows
twenty sets of colours where the Game Boy could show four.

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
                     ▼
   ▶ ()  │  [()][  ][  ][  ][  ]
     ()  │  [  ][  ][  ][  ][  ]         the party, then the open box
     ()  │  [  ][  ][  ][  ][  ]
     ()  │  [  ][  ][  ][  ][  ]
┌──────────────────────────────────────┐
│ NIDORAN♂                        :L17 │   what the cursor is on
└──────────────────────────────────────┘
```

Six party slots and twenty box cells, side by side, on one 160×144 screen.
Every cell is 24×24 and every party row 16 tall, which is three tiles and two
— and that is a requirement rather than a preference. See **Colour** below.

## Colour

Two rules, and the screen falls out of them.

**The chrome is black.** Every pixel this screen draws itself — the boxes, the
grid, the arrows, the text — is shade 3, the darkest of the four Game Boy
shades. Shade 3 is `{0,0,0}` in the grey ramp, in `MEWMON`, and in all 151
species palettes alike, so the lines stay black whatever is laid over them.
Shade 1 is the opposite: `MEWMON`, the palette the PC's other screens wear,
paints it `{239,156,107}`, which is how a grey grid line comes out orange.

**Each POKéMON gets its own palette.** The screen emits one SGB zone per
POKéMON on it, carrying that species' palette, the same way the battle screen
and the summary screen colour a mon. A species palette is white / hue / hue /
black, so a zone laid over a cell recolours the POKéMON in it and cannot touch
the black lines around it. This is what forces the tile-aligned layout: a zone
is addressed in *tiles*, so a cell three and a half tiles wide cannot carry
one at all.

**Except art that is already in colour.** If your icons come from a mod that
draws them full-colour rather than in the Game Boy's four shades, a palette
zone would not recolour them - it would destroy them, because the pass keys
each pixel off its *red* channel and an orange pixel lands on the palette's
white. Those icons are marked so the pass re-blits them untouched, and get no
species zone at all. Which icons those are is decided by reading the pixels of
whatever the icon path actually resolves to, so it works the same whether the
art arrived through the icons registry, a species record's own `icon`, an
asset override or the `pokemon.icon` hook.

Your COLORS setting still decides what those palettes are — ADVANCED resolves
per-species pokered-gbc colours, SGB the Super Game Boy ones, CLASSIC and the
OG modes replace the lot. The screen asks; the mode answers.

## Controls

| Action | Control |
| --- | --- |
| Move the cursor | D-pad |
| Cross to the party / back to the box | LEFT out of the first column, RIGHT out of the party — or SELECT from the party |
| Sort or tidy the open box | SELECT, on the box side |
| Pick a POKéMON up, put it down, swap two | A |
| Put a carried POKéMON back where it came from | B |
| Close the box | B, with nothing in hand |
| Focus the box header | UP out of the top row |
| Previous / next box | LEFT and RIGHT on the header |
| Jump to any box | A on the header |
| STATS and RELEASE | START, over a POKéMON |
| Open the box without a PC | **BOX** on the START menu |

The cursor in the grid is an arrow in the band above a POKéMON's head,
pointing down at it, and the same arrow **hollow** while that POKéMON is in
your hand. The box header's two arrows and its own selector are that same
triangle drawn on another axis — one shape, one row, aligned by construction
rather than by nudging coordinates until a font glyph looked close.

Across the cell the icon is centred, 3 in from one side and 4 from the other,
which is as centred as 16 pixels get inside the 23 between two rules. Down the
cell it deliberately is not. That column holds a gap, the 4-pixel cursor, a
gap, the 16-pixel icon and a gap in those same 23 pixels — three pixels of
slack for three gaps — so any split but 1/1/1 takes one to zero, and the two
that must not go to zero are the ends: an arrow with no gap above it is drawn
*on* the rule and reads as a smear on the grid, and an icon with no gap below
it sits on the next rule. So the POKéMON sits one pixel off the bottom rule
with the cursor's band above it, which is the only arrangement that leaves
every edge clear.

The party pane keeps the sideways cursor instead — the party
menu's own filled and hollow glyphs — because six rows of sixteen fill that
pane exactly and leave no band above a head to put an arrow in.

A on the header opens the twelve-box list: a bordered pop-up like SORT,
hanging from the bottom edge so the header naming the open box stays visible
above it, showing six rows at a time and scrolling the rest — twelve rows at
the vanilla two tiles each would need 26 of the 18 tile rows there are. It
opens on the box you are already in rather than on BOX 1, and each row carries
how full that box is, right-aligned in fixed columns so the counts line up.

Its heading is padded a tile on each side, because the widget whites out
exactly as many tiles as the title is wide and sits it on the top rule, and
drawn a pixel lower than the widget puts it, because at the top of the border
tile the letters' first pixel row lands on the single white pixel the frame
keeps outside its rule. Its scroll arrow is drawn *inside* the frame rather
than on the bottom border where the widget's own would go — which makes it the
same triangle as the grid cursor and the header's two.

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

A POKéMON in your hand **flashes**. Four shades cannot dim one, so it blinks —
16 steps lit, 8 dark, so it stays lit twice as long as it is dark, because the
thing flashing is the thing you are trying to look at.

## Sorting

**SELECT** over the box opens SORT:

| Row | What it does |
| --- | --- |
| **COLLAPSE** | Closes the gaps up, keeping the order you can see. |
| **BY DEX** | Pokédex number. |
| **BY LEVEL** | Strongest first. |
| **BY NAME** | Alphabetical, by nickname where there is one. |
| **BY TYPE** | Grouped by primary type, alphabetically — the data carries type *names* rather than the cart's numbering, so there is no other order to honour. |
| **UNDO** | One step, and only while it would still work. |

It is a bordered pop-up, not a screen: the same widget with the same chrome as
the per-POKéMON rows START opens, hanging from the bottom edge the way the
party menu's own submenu does, so it never covers the header naming the box you
are sorting. It is headed **SORT**, which costs no rows — the widget writes a
title into the top border it was going to draw anyway.

Every sort ends the same way — the box closed up into cells 1..n — so COLLAPSE
is simply the sort that changes no order, and the rest are that plus a
reordering. Ties keep the order you already had.

SORT is refused while a POKéMON is in your hand, and UNDO is offered only when
the box still holds exactly the POKéMON the snapshot was taken of — checked by
identity, not by count, because one released and one caught leaves the count
alone and would otherwise let UNDO resurrect the released one.

SELECT from the *party* still crosses to the box, so the pair reads as one key:
SELECT gets you there, SELECT again tidies it. Nothing is lost, because LEFT
and RIGHT already cross the panes.

## Gaps

A POKéMON picked up **leaves its cell empty**, and one put down lands in the
cell you aimed at. Nothing slides up behind anything, and the gaps are still
there next time you open the box.

That takes some doing, because a Gen 1 box is a *compact* array — `box[1..n]`
with nothing after `n` — so taking one out of the middle closes it up. The
array still is exactly that: it is the save format, it is what the engine's own
deposit appends to, and it is what is left behind if you remove this mod. What
this mod adds is the **arrangement**, kept beside the box in its own save data:
one grid cell per POKéMON.

The two are reconciled on every read, which is what makes it safe to bolt onto
a shared save. Anything may add to a box behind this screen's back — a catch
overflowing into it, another mod, an imported `.sav` — and the arrangement just
grows to meet it: new arrivals take the lowest free cell, spare cells are
dropped, and a cell that is out of range or claimed twice is thrown away. The
worst case is that a box goes back to the compact order nobody could see a gap
in anyway. No POKéMON is ever anywhere but in the box the save says it is in.

### The party takes gaps too — while you are looking at it

Pick one out of the middle of the party and its row stays empty; put it back
down in any empty row. Close the box and the party is a list of six again.

That is deliberately *not* the box's mechanism, and the difference is the
point. A box's arrangement is **saved**, because a gap you left in storage is a
decision. The party's is not — it lives on the screen and is gone when you
close it. `save.party` is **never** sparse: what is sparse is only which row
each member is drawn in.

The party array is kept **sorted by that row** after every change, and that is
the whole safety of it. Party order is *battle* order — `party[1]` is who you
send out — so an arrangement that let the visual order and the array order
drift apart would quietly change who leads. Sorted, the two cannot disagree,
and closing the screen has nothing to collapse: the party already was the list
it looked like.

## Opening it from the START menu

A **BOX** row sits on the START menu next to POKéMON, opening the same screen
BILL'S BOX opens — no PC in front of you required. B brings the START menu back
the way it does from POKéDEX, POKéMON, ITEM and the trainer card, because the
screen takes the same `onCancel` those do.

This is the one thing here that is a genuine reach beyond the cart, which
wanted you standing at a PC, so **BOX ON START** turns it off. Note that the
party can still never be emptied from it — the last POKéMON cannot be picked
up at all — so there is no way to strand yourself in tall grass with nothing to
send out.

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
| **FULL BOX NOTE** | on | One line after a catch that overflowed, naming the box it actually went to. See below. |
| **SWITCH ON FULL** | on | The open box follows a catch that overflowed, instead of staying on the full one. |
| **BOX ON START** | on | A BOX row on the START menu, opening the same screen the PC opens. |

## Catching into a full box

It already works, and it is not this mod's doing: the engine's own
`Boxes.deposit` walks from the box you have open forward through all twelve,
wrapping, and drops the POKéMON in the first one with room. A catch only fails
once all 240 places are taken — that is when you get *"But every BOX is
full!"*. The cart refused the catch the moment the open box was full; this
engine deliberately does not.

What it never did was *tell* you. The line it prints is the cart's own —
*"MON was transferred to BILL's BOX!"* — and the cart never needed to name a
box, because there the POKéMON could only ever be in the one you had open.
Here it can be in any of twelve, so a POKéMON caught into a full box was
findable only by opening the PC and walking the boxes.

So this mod adds one line after it, and moves the open box to match:

```
BOX 1 was full!
Now using BOX 7.
```

Only when the two differ. An ordinary catch into the box you have open is
exactly as quiet as it always was.

Moving the open box is the half that matters most. Left behind, the PC keeps
opening on a box with no room in it, and because `Boxes.deposit` starts its
walk from the open box, *every* later catch walks past the full one again.
Following the overflow means the next catch lands directly in a box with
space. Turn it off with **SWITCH ON FULL** and the note says
*"Stored in BOX 7."* instead — it never claims a switch that did not happen.

This was asked for as Gen 2 behaviour, and it is worth recording that Gold
does the opposite: there a full party *and* a full current box refuses the
throw outright (`Ball_BoxIsFullMessage` — *"The POKéMON BOX is full. That
can't be used now."*), and Bill rings you when a box fills. Advancing to the
next box with room is Gen 3's answer. It is the right one on this engine
either way, which already refuses to lose the catch.

Changing box here does not save the game, for the same reason the box screen's
own box changes do not: all twelve boxes are one save file on this engine, so
the cart's "data will be saved" step has nothing left to do.

The number cannot go into the transfer line itself, for what it's worth: that
text is ROM-extracted and filled from the caller's arguments, and the battle
passes exactly one — the POKéMON's name — so a second slot fails the arity
check and drops the whole line back to the engine's English (which says "PC"
again).

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
