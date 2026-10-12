# Run the synergydbl headless test suite.
#
#   .\tests\run.ps1
#
# Equivalent to running, from the plugin root:
#   nvim --headless --noplugin -u tests/minimal_init.lua -l tests/run.lua

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    & nvim --headless --noplugin -u tests/minimal_init.lua -l tests/run.lua
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
