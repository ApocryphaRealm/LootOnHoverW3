# Loot on Hover (The Witcher 3, 5.0)

The loot window opens by itself when Geralt looks at anything he can loot - chests, barrels, crates, corpses, loot
bags, herbs - with no button press. It works while exploring and swimming, never in combat, and Geralt keeps moving
with it open.

| While the window is up | Controller | Keyboard |
|---|---|---|
| take the highlighted item | A | E |
| take everything | X | Space |
| close it | B | Esc |

Y does nothing while it is up. Outside the window every button is the game's own. Looking away closes it, and so
does a fight starting; closed with B, it stays closed until Geralt looks at something else.

Locked chests, empty containers and corpses under the game's Auto-loot setting behave exactly as before.

## Controller bindings

A, X and B reach the mod through its own three input actions (LohTake, LohTakeAll, LohClose), added beside the
player's own bindings in input.settings' [Exploration] and [Swimming] sections - so they follow the buttons whatever
controller map is installed. `tools/bindings.py <input.settings>` adds them (`--remove` takes them out), with the game
closed; the shipped installer is still to come.

## How it works

`dist/Mods/modLootOnHover/content/scripts/local/LootOnHover.ws`, annotations only - no game script is replaced:

- `CInteractionsManager.OnGuiInteractionChanged` (the game's "what Geralt is looking at" event) opens the window when
  the target is a lootable container: the container's own pre-window steps (quest facts, NG+ schematics), then its
  window - without the press animation, so Geralt never kneels at a corpse he only glanced at.
- `CR4LootPopup.OnConfigUI` gives back what the game's window takes: the input context (EMPTY_CONTEXT freezes
  Geralt), the stick and the cursor.
- While it is up, whatever else the player's map puts on A, X, Y and B (attacks, swords, signs, sprint, jump, diving,
  the container's own A press) is held off - through the game's action locks and by swallowing the press - and the
  game's "You cannot do that now" for those is kept quiet.
- The per-frame check closes the window once the target has stayed gone for a third of a second (running an
  interaction drops the target for a moment).
- A herb emptied one item at a time is marked picked, as its take-everything path does.

Log channel `LootOnHover` (launch with `-debugscripts`). The test probe (`probe/`, never shipped) shows each log
line on screen.

## Building

`python tools/dry_compile.py` compiles the script over the game's own scripts with REDkit's wcc_lite (no launch).

## Compatibility

Not with Auto Take All (or any mod that takes everything on A): hovering would take everything at once.
