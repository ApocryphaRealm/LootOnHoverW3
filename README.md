# Loot on Hover (The Witcher 3, 5.0)

Version 1.0.1 - this build's own number (an original mod; there is no upstream version).

The loot window opens by itself when Geralt looks at anything he can loot - chests, barrels, crates, corpses, loot
bags, herbs - with no button press. It works while exploring and swimming, never in combat, and Geralt keeps moving
with it open.

| While the window is up | Controller | Keyboard |
|---|---|---|
| take the highlighted item | A | E |
| take everything | Y | Space |
| close it | B | Esc |

Y is the button the loot window's own hint shows for Take All. X does nothing while it is up. Outside the window every
button is the game's own. Looking away closes it, and so
does a fight starting; closed with B, it stays closed until Geralt looks at something else.

Locked chests, empty containers and corpses under the game's Auto-loot setting behave exactly as before.

## Controller bindings

A, Y and B reach the mod through its own three input actions (LohTake, LohTakeAll, LohClose), added beside the
player's own bindings in input.settings' [Exploration] and [Swimming] sections - so they follow the buttons whatever
controller map is installed:

    IK_Pad_A_CROSS=(Action=LohTake)
    IK_Pad_Y_TRIANGLE=(Action=LohTakeAll)
    IK_Pad_B_CIRCLE=(Action=LohClose)

`tools/bindings.py <input.settings>` adds them (`--remove` takes them out), with the game closed; it backs the file up
first. **Updating from 1.0.0:** 1.0.0 put take-all on X (`IK_Pad_X_SQUARE=(Action=LohTakeAll)`); run the script again
and it replaces that line with the Y one, in both sections. The shipped installer is still to come.

## How it works

`dist/Mods/modLootOnHover/content/scripts/local/LootOnHover.ws`, annotations only - no game script is replaced:

- `CInteractionsManager.OnGuiInteractionChanged` (the game's "what Geralt is looking at" event) opens the window when
  the target is a lootable container: the container's own pre-window steps (quest facts, NG+ schematics), then its
  window - without the press animation, so Geralt never kneels at a corpse he only glanced at.
- `CR4LootPopup.OnConfigUI` / `OnClosingPopup` run the game's own steps for a window opened by looking, less four:
  the open and close sounds (`gui_loot_popup_open` / `gui_loot_popup_close`), the input context (EMPTY_CONTEXT
  freezes Geralt), the UI stick and the cursor - so it opens and closes silently and Geralt keeps walking. The loot
  movie's own sounds (`OnPlaySoundEvent`) are quiet for its first half second. Take sounds are untouched.
- While it is up, whatever else the player's map puts on A, X, Y and B (attacks, swords, signs, sprint, jump, diving,
  the container's own A press) is held off - through the game's action locks and by swallowing the press - and the
  game's "You cannot do that now" for those is kept quiet.
- The press that closes the window is held off too. Y takes everything and closes the window inside its own press, and
  the game goes on handling that press with the window gone (on Modern Control Remapping's map Y is also Jump, climb
  and Axii; swimming, Dive Up). So for a tenth of a second after one of the mod's windows closes a face-button press is
  swallowed, and Jump and climbing - which the exploration code polls every frame (`CExplorationInput.IsJumpJustPressed`
  and the rest) - stay held off until their buttons are let go. A press that began with the window up never jumps or
  climbs; keyboard Space (Take All, and Jump on the vanilla map) gets the same.
  Sprint is held off at `CR4Player.CanSprint`, not with an EIAB_Sprint lock: that lock makes the game treat Geralt as
  indoors and switch to its close indoor camera (`UpdateCameraInterior`), which zoomed in each time the window opened.
- The per-frame check closes the window once the target has stayed gone for a third of a second (running an
  interaction drops the target for a moment).
- A herb emptied one item at a time is marked picked, as its take-everything path does.
- No rumble on hover: from the moment the window is asked for until half a second after it closes, the pad's
  vibration is off (`theGame.SetVibrationEnabled`, the switch the game's quests use), then put back as it was; a
  player whose vibration setting is off is never touched. A take lets the game's own take rumble through (herbs and
  armour rumble in the vanilla game).

Log channel `LootOnHover` (launch with `-debugscripts`). The test probe (`probe/`, never shipped) shows each log
line on screen.

## Building

`python tools/dry_compile.py` compiles the script over the game's own scripts with REDkit's wcc_lite (no launch).

## Compatibility

Not with Auto Take All (or any mod that takes everything on A): hovering would take everything at once.
