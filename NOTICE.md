# Loot on Hover (The Witcher 3) - copyright and licence

Copyright (C) 2026 ApocryphaRealm

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program (`LICENSE`). If not, see
<https://www.gnu.org/licenses/>.

SPDX-License-Identifier: GPL-3.0-or-later

## What is ours, and what is not

Ours: the WitcherScript (`dist/Mods/modLootOnHover/content/scripts/local/LootOnHover.ws`), the test probe and the tools
(`tools/bindings.py`, `tools/dry_compile.py`). It changes no game file: it wraps methods of the game's own scripts with
annotations, which the game compiles in at start-up. The game's scripts and data are CD PROJEKT RED's and are not in
this repository.
