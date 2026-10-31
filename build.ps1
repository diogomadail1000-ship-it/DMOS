# Builds the DMOS ISO from Windows. The result lands in .\dist
# The first run creates the "dmos-builder" WSL instance (Debian 13); nothing else in WSL is touched.
param([ValidateSet("iso", "clean")][string]$Action = "iso")

$ErrorActionPreference = "Stop"
$env:WSL_UTF8 = 1

if (-not ((wsl -l -q) -match "dmos-builder")) {
    wsl --install -d Debian --name dmos-builder --no-launch
}

$project = (wsl -d dmos-builder -u root -- wslpath -a ($PSScriptRoot -replace "\\", "/")).Trim()
wsl -d dmos-builder -u root -- bash "$project/scripts/setup_builder.sh"
wsl -d dmos-builder -u root -- bash "$project/scripts/build.sh" $Action
