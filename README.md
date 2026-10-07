# Loot on Hover (The Witcher 3, 5.0)

The loot window opens by itself when Geralt looks at something he can loot - a chest, a barrel, a corpse - with
no button press. It works while exploring and swimming, never in combat.

| While the window is up | Controller | Keyboard |
|---|---|---|
| take the highlighted item | A | E |
| take everything | X | Space |
| open the window normally (Geralt stands still, the stick browses) | Y | - |
| close it | B | Esc |

Looking away closes it, and so does a fight starting. Close it with B and it stays closed until Geralt looks at
something else.

Nothing it doesn't already show: herbs, locked chests, empty containers and anything the game loots without its
window (Ciri, the Auto-loot corpses setting) behave exactly as before.

## How it works

`dist/Mods/modLootOnHover/content/scripts/local/LootOnHover.ws`, annotations only - no game script is replaced:

- `CInteractionsManager.OnGuiInteractionChanged` (the game's "what Geralt is looking at" event) runs the
  container's own A press when the new target is a lootable container, marking the window it opens as a preview.
- `CR4LootPopup.OnConfigUI`, for a preview, gives back what the game's window takes: the game's input context
  (it switches to EMPTY_CONTEXT, which freezes Geralt), the stick and the cursor.
- X and Y reach the game as its attack actions (dive down while swimming); the `CPlayerInput` handlers are wrapped
  to swallow them while the window is up, and route them to take all / open normally. B's jump and roll are
  blocked while it is up; the window's own B closes it.
- The game's loot movie puts Take All on Y. With a controller that call becomes "open normally"; X is Take All.

Log channel `LootOnHover` (launch with `-debugscripts`).

## Building

`python tools/dry_compile.py` compiles the script over the game's own scripts with REDkit's wcc_lite (no launch).
Install: copy `dist/` into a Mod Organizer mod folder or the game folder.

## Compatibility

Not with Auto Take All (or any mod that takes everything on A): hovering would take everything at once.
