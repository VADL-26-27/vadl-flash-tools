<#
.SYNOPSIS
  flash.ps1 - Windows equivalent of flash.sh for st-flash based STM32 flashing.

.EXAMPLE
  ./flash.ps1
  ./flash.ps1 -Device COM5 -FlashAddr 0x08000000
  ./flash.ps1 -Board f411
  ./flash.ps1 -Board h753 -Erase -Reset
  ./flash.ps1 -Board f411 -Build
  ./flash.ps1 -NoVerify

.PARAMETER Device
  Serial port for the board, e.g. COM5. Only used for the busy-port check;
  st-flash itself talks to the ST-Link over USB, not the COM port.

.PARAMETER FlashAddr
  Flash start address. Default 0x08000000.

.PARAMETER Board
  Name of a board config file in .\boards\<name>.ps1 to source.

.PARAMETER Build
  Run `make` before flashing (requires make + arm-none-eabi-gcc on PATH).

.PARAMETER NoVerify
  Skip post-write verification.

.PARAMETER Reset
  Reset the MCU after flashing.

.PARAMETER Erase
  Mass erase before writing.
#>

param(
    [string]$Device = "COM5",
    [string]$FlashAddr = "0x08000000",
    [string]$Board = "",
    [switch]$Build,
    [switch]$NoVerify,
    [switch]$Reset,
    [switch]$Erase
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Bin = ".\build\firmware.bin"
$MCUName = $null
$MCUFamily = $null

# --- load board config if specified ---
if ($Board -ne "") {
    $ConfPath = Join-Path $ScriptDir "boards\$Board\flash.ps1"
    if (-not (Test-Path $ConfPath)) {
        Write-Error "Unknown board: $Board (no $ConfPath)"
        exit 1
    }
    . $ConfPath
    if ($MCUFlashAddr) { $FlashAddr = $MCUFlashAddr }
    if ($MCUBin) { $Bin = $MCUBin }
}

# --- optional build step ---
if ($Build) {
    Write-Host "Building..."
    make
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed"
        exit 1
    }
}

# --- sanity checks ---
if (-not (Get-Command st-flash -ErrorAction SilentlyContinue)) {
    Write-Error "st-flash not found. Install stlink-tools and add it to PATH."
    exit 1
}

if (-not (Test-Path $Bin)) {
    Write-Host "Binary not found: $Bin"
    Write-Host "Run: make  (or pass -Build)"
    exit 1
}

# confirm a probe is attached
try {
    $probeInfo = & st-info --probe 2>&1
    if ($LASTEXITCODE -ne 0) { throw "probe check failed" }
}
catch {
    Write-Error "No ST-Link probe detected. Check USB connection."
    exit 1
}

if ($MCUName) {
    Write-Host "Board: $Board ($MCUName)"
    $needle = if ($MCUFamily) { $MCUFamily } else { $MCUName }
    if ($probeInfo -notmatch [regex]::Escape($needle)) {
        Write-Warning "Could not confirm $MCUName from probe info. Continuing anyway."
    }
}

# --- best-effort check that the COM port isn't held open ---
# st-flash talks over USB to the ST-Link, not the COM port, so this is only
# relevant if something (a serial monitor, PuTTY, etc.) is holding the VCP
# open and you want a heads-up. Windows doesn't have a lsof equivalent for
# this, so we just try to open/close it.
try {
    $port = New-Object System.IO.Ports.SerialPort $Device
    $port.Open()
    $port.Close()
}
catch {
    Write-Warning "$Device appears to be in use by another program (e.g. PuTTY, Tera Term, Arduino Serial Monitor)."
    Write-Warning "Close it manually if flashing fails or output looks wrong."
}

# --- optional mass erase ---
if ($Erase) {
    Write-Host "Erasing flash..."
    & st-flash erase
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- flash ---
Write-Host "Flashing $Bin to $FlashAddr using st-flash..."
if ($NoVerify) {
    & st-flash write $Bin $FlashAddr
}
else {
    & st-flash --verify write $Bin $FlashAddr
}
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flash failed"
    exit 1
}

# --- optional reset ---
if ($Reset) {
    Write-Host "Resetting target..."
    & st-flash reset
}

Write-Host "Done."