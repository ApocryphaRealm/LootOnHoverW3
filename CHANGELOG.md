# Changelog

## 1.0.0 (untested as a whole)

- The loot window opens when Geralt looks at anything lootable - chests, barrels, crates, corpses, loot bags, herbs -
  exploring or swimming, never in combat, and he keeps moving with it open.
- While it is up: A takes the highlighted item, X takes everything, B closes it, Y does nothing. The buttons follow
  the controller whatever map is installed (the mod's own three input actions).
- Looking away, or a fight starting, closes it.
- While it is up the D-pad only moves through its list: the quick wheel, the potions, the quick item and focus
  (whatever the player's map puts on the D-pad) are held off until it closes. (2026-10-07, untested)

In game (2026-10-06, a dropped loot bag, the owner's controller map): opens on look; A took one item; X took the rest
and closed it; B closed it and it stayed closed; walking away closed it and coming back reopened it - no sword drawn,
no jump, no kneel. Not yet seen in game: this build's Y, a chest, a herb, swimming, combat.

### Changed
- No sound when the window pops up or closes: the window opened by looking now opens and closes silently (the game's own open and close sounds, and the list's first highlight click, are skipped for it). Taking items still sounds as usual. (2026-10-13, untested)
- No controller rumble on hover: while the window opened by looking is up, and for half a second after it closes, the pad's vibration is switched off and then put back as it was (a player whose vibration setting is off is never touched). Taking items (A, X) still gives the game's own take rumble. (2026-10-13, untested)
### Fixed
- The camera no longer zooms in when the window pops up: holding sprint off with the game's sprint lock made the game treat Geralt as indoors and switch to its close indoor camera. Sprint is now held off at the game's own sprint check instead, and the camera stays as it was. (2026-10-13, untested)