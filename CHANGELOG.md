# Changelog

## 1.0.2 - 2026-10-16 - working (the owner, 2026-10-16: "Update Nexus with the loot on hover build.")

### Added
- A settings page, Options > Mods > Loot on Hover (and the same row in Apocrypha Menu Framework), with one switch: "Gather herbs without the loot window", on by default. Off brings back 1.0.1's hover window on herbs. Labels in every game language file (English, Japanese, Korean, Chinese, Russian, German, French, Spanish, Italian, Polish, Czech and Brazilian Portuguese written out; string idspace 7721). (2026-10-16)
- Herbs are gathered without the loot window: looking at a herb opens no hover window, the game's own "Gather Ingredients" prompt stays, and A gathers everything on it the game's way (its gathering animation, the looted notifications, the herb marked picked and regrowing). A window that is up for something else closes the moment Geralt looks at a herb, so one A press never both gathers the herb and takes from that window. Asked for in a player's Nexus comment and promised by the project owner for this version. (2026-10-16)

- No hover window on containers that count as stealing. The game's own test (LootPopup.SignalLootingReactionEvent / SignalStealingReactionEvent): a container whose disableStealing is off, with no quest item, not a herb and not a body. Owned containers keep the game's red steal prompt and the guards' reaction; bodies, ordinary chests and herbs are unchanged. (2026-10-16)

Read from 5.01's scripts: the game's own A at a herb never opened a window (W3Container.ProcessLoot sends a W3Herb, and
any container that skips the inventory panel, to TakeAllItems and OnContainerClosed), so the mod now simply stays out of
the way there. The game's Loot merge never lists a herb in a body's window (PopulateData gathers only W3ActorRemains).
Dry compile 2026-10-16: COMPILE OK over the game's scripts alone, and over the owner's ticked MO2 set (30 script
folders, TW3SE stubs applied) with both installed Loot on Hover folders left out.

## 1.0.1 - 2026-10-14 - working (the 'loot merge' build, c51cfae; the owner's release order 2026-10-15: "post loot on hover since it has the loot merge fix")

### Changed
- On a controller, Y now takes everything - the button the loot window's own hint shows for Take All. X no longer takes
  everything; while the window is up X does nothing. The owner, 2026-10-14: "pressing X in the loot menu takes all
  instead of Y, when Y should take all." (2026-10-14)
- tools/bindings.py writes take-all on Y (`IK_Pad_Y_TRIANGLE=(Action=LohTakeAll)`) and, run over a 1.0.0 install,
  replaces the old X line; two runs in the same second no longer share one backup name. (2026-10-14)
### Fixed
- The press that closes the window no longer does the button's other job on the way out: Y takes everything and closes
  the window in the same press, and on Modern Control Remapping's map Y is also Jump and climb (Dive Up when swimming).
  A face-button press in the tenth of a second after the window closes is held off, and Jump and climbing stay held off
  until their buttons are let go. This covers keyboard Space (Take All, and Jump on the vanilla map) too, and B (close,
  and Sprint on that map). (2026-10-14)
- The game's Loot merge setting (Options > Gameplay, var Gameplay / LootMergeEnabled) now works fully in the hover
  window. The window already gathered nearby bodies through the game's own list builder (CR4LootPopup.PopulateData:
  bodies within 15 m, not loot bags, setting on). But with merge on, the window closed as soon as the looked-at body
  was emptied, though the other bodies' items were still listed, and looking from one merged body to the next closed
  and reopened it. A body that is in the window now counts as the window's target, so the merged list can be taken one
  item at a time to the end. Off: only the one container, as before. The project owner, 2026-10-14: "Make sure that the
  loot merge setting in the game applies to the loot window that our mod alters." (2026-10-15)

Keyboard unchanged: E takes, Space takes everything, Esc closes. The open line in the log now names the Loot merge
setting and how many nearby containers were merged in. Dry compile 2026-10-15 (loot merge build): COMPILE OK over the
game's scripts and over the ticked MO2 set with both installed Loot on Hover folders left out. Dry compile 2026-10-14: COMPILE OK over the game's
scripts alone, and over the owner's ticked MO2 set (31 script folders, Modern Control Remapping's own Jump wrappers
among them) with the installed 1.0.0 left out.

## 1.0.0 - 2026-10-13 - working

- The loot window opens when Geralt looks at anything lootable - chests, barrels, crates, corpses, loot bags, herbs -
  exploring or swimming, never in combat, and he keeps moving with it open.
- While it is up: A takes the highlighted item, X takes everything, B closes it, Y does nothing. The buttons follow
  the controller whatever map is installed (the mod's own three input actions).
- Looking away, or a fight starting, closes it.
- While it is up the D-pad only moves through its list: the quick wheel, the potions, the quick item and focus
  (whatever the player's map puts on the D-pad) are held off until it closes. (2026-10-07)

In game (2026-10-06, a dropped loot bag, the owner's controller map): opens on look; A took one item; X took the rest
and closed it; B closed it and it stayed closed; walking away closed it and coming back reopened it - no sword drawn,
no jump, no kneel. Not yet seen in game: this build's Y, a chest, a herb, swimming, combat.

In game (2026-10-13, the owner's own test of commit 2920bf9): "both of those mods are working now properly". The
log shows the window opening and closing silently on a herb (balisse fruit), the rumble switched off while it is up and
put back after it closes. Recorded working in the version ledger against LootOnHover.ws 534396A1...49AC.

### Changed
- No sound when the window pops up or closes: the window opened by looking now opens and closes silently (the game's own open and close sounds, and the list's first highlight click, are skipped for it). Taking items still sounds as usual. (2026-10-13)
- No controller rumble on hover: while the window opened by looking is up, and for half a second after it closes, the pad's vibration is switched off and then put back as it was (a player whose vibration setting is off is never touched). Taking items (A, X) still gives the game's own take rumble. (2026-10-13)
### Fixed
- The camera no longer zooms in when the window pops up: holding sprint off with the game's sprint lock made the game treat Geralt as indoors and switch to its close indoor camera. Sprint is now held off at the game's own sprint check instead, and the camera stays as it was. (2026-10-13)