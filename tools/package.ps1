# Package Loot on Hover (The Witcher 3) for testing:
#   1. tools\dry_compile.py   (the script must compile over the game's 5.0 scripts - REDkit wcc_lite; a compile error
#                              stops the game at start-up for every mod)
#   2. copy dist\ (Mods\modLootOnHover with its string tables, and since 1.0.2 the settings menu
#      bin\config\r4game\user_config_matrix\pc\LootOnHover.xml), LICENSE, NOTICE.md, README.md as README.txt and tools\bindings.py to
#      <stage>\Witcher 3 - Loot on Hover\Loot on Hover <VERSION>[ (<Label>)]\ - the layout 1.0.0 shipped with
#   3. stamp the version into the package README (rule 6: the version at the top of the README)
# The version comes from VERSION, which only version-gate.ps1 writes. The stage folder comes from the project's resolver
# (distro-names.ps1 Resolve-PackageRoot), never a hand-joined path. The same shape as Witcher Gear Overhaul's.
param(
    [string]$ProjectRoot = 'D:\Claude output',
    [string]$Stage = '7. current test builds',
    # a test build carries a label so its folder says what it is for; a retest of a number reuses the number (rule 48)
    [string]$Label = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $repo 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$' -or $version -eq '0.0.0') { throw "VERSION is '$version' - issue a number with version-gate.ps1 -Action bump first" }

# the settings menu's string tables (dist\Mods\modLootOnHover\content\*.w3strings) must match tools\gen_strings.py
& python -I (Join-Path $PSScriptRoot 'gen_strings.py') --check
if ($LASTEXITCODE -ne 0) { throw 'string tables differ from tools\gen_strings.py - run it' }
& python -I (Join-Path $PSScriptRoot 'dry_compile.py') (Join-Path $repo 'dist')
if ($LASTEXITCODE -ne 0) { throw 'dry_compile.py failed - the script does not compile (build\dry_compile.log)' }

. (Join-Path $ProjectRoot '.MD\scripts\distro-names.ps1')
$root = Resolve-PackageRoot -Root (Join-Path $ProjectRoot $Stage) -ModName 'Loot on Hover' -Game 'Witcher 3' -ProjectRoot $ProjectRoot
$name = "Loot on Hover $version"
if ($Label) { $name = "$name ($Label)" }
$pkg = Join-Path $root $name
if (Test-Path -LiteralPath $pkg) { throw "$pkg already exists - a version is packaged once" }
New-Item -ItemType Directory -Force -Path $pkg | Out-Null
Copy-Item -Path (Join-Path $repo 'dist\*') -Destination $pkg -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination $pkg
Copy-Item -LiteralPath (Join-Path $repo 'NOTICE.md') -Destination $pkg
New-Item -ItemType Directory -Force -Path (Join-Path $pkg 'tools') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'bindings.py') -Destination (Join-Path $pkg 'tools')

$readme = Join-Path $pkg 'README.txt'
$text = [System.IO.File]::ReadAllText((Join-Path $repo 'README.md'))
if ($text -notmatch '(?m)^Version \d+\.\d+\.\d+') { throw 'README.md has no "Version X.Y.Z" line under its title' }
$text = [regex]::Replace($text, '(?m)^Version \d+\.\d+\.\d+', "Version $version", 1)
[System.IO.File]::WriteAllText($readme, $text, (New-Object System.Text.UTF8Encoding($false)))

Write-Output "packaged $pkg"
