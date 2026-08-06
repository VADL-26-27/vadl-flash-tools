#!/usr/bin/env bash
# flash.sh
# Usage:
#   ./flash.sh [device] [addr] [options]
# Examples:
#   ./flash.sh                          -> /dev/ttyACM0, 0x08000000, verify on
#   ./flash.sh /dev/ttyACM0 0x08000000
#   ./flash.sh --board f411
#   ./flash.sh --board h753 --erase --reset
#   ./flash.sh --board f411 --build
#   ./flash.sh --no-verify
#
# Options:
#   --board NAME  Source boards/NAME.conf for MCU-specific settings
#   --build       Run `make` before flashing
#   --no-verify   Skip post-write verification
#   --reset       Reset the MCU after flashing (st-flash reset)
#   --erase       Mass erase before writing
#   -h, --help    Show this help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEVICE="/dev/ttyACM0"
FLASH_ADDR="0x08000000"
BIN="./build/firmware.bin"
VERIFY=1
DO_RESET=0
DO_ERASE=0
DO_BUILD=0
BOARD=""

usage() { grep '^#' "$0" | sed -n '2,18p' | sed 's/^# \{0,1\}//'; }

# --- parse args (positional device/addr first, then flags anywhere) ---
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --no-verify) VERIFY=0 ;;
    --reset)     DO_RESET=1 ;;
    --erase)     DO_ERASE=1 ;;
    --build)     DO_BUILD=1 ;;
    --board)
      shift
      BOARD="${1:-}"
      [ -n "$BOARD" ] || { echo "--board requires a name" >&2; exit 1; }
      ;;
    -h|--help)   usage; exit 0 ;;
    *)           POSITIONAL+=("$1") ;;
  esac
  shift
done

# --- load board config if specified (sets MCU_NAME/FLASH_ADDR/BIN etc.) ---
if [ -n "$BOARD" ]; then
  CONF="$SCRIPT_DIR/boards/${BOARD}/flash.conf"
  [ -f "$CONF" ] || { echo "Unknown board: $BOARD (no $CONF)" >&2; exit 1; }
  # shellcheck source=/dev/null
  source "$CONF"
fi

# positional args still win over board config / defaults
[ "${#POSITIONAL[@]}" -ge 1 ] && DEVICE="${POSITIONAL[0]}"
[ "${#POSITIONAL[@]}" -ge 2 ] && FLASH_ADDR="${POSITIONAL[1]}"

# --- optional build step ---
if [ "$DO_BUILD" -eq 1 ]; then
  echo "Building..."
  make || { echo "Build failed" >&2; exit 1; }
fi

# --- sanity checks ---
command -v st-flash >/dev/null 2>&1 || {
  echo "st-flash not found. Install stlink-tools first." >&2
  exit 1
}

if [ ! -f "$BIN" ]; then
  echo "Binary not found: $BIN"
  echo "Run: make  (or pass --build)"
  exit 1
fi

# confirm a probe is actually attached before doing anything else
if ! st-info --probe >/dev/null 2>&1; then
  echo "No ST-Link probe detected. Check USB connection." >&2
  exit 1
fi

# soft-check detected chip against board config, if provided
if [ -n "${MCU_NAME:-}" ]; then
  DETECTED="$(st-info --probe 2>/dev/null || true)"
  echo "Board: $BOARD ($MCU_NAME)"
  if ! echo "$DETECTED" | grep -qi "${MCU_FAMILY:-$MCU_NAME}"; then
    echo "Warning: could not confirm $MCU_NAME from probe info. Continuing anyway." >&2
  fi
fi

# --- free the device if something's holding it open ---
if lsof "$DEVICE" >/dev/null 2>&1; then
  echo "Device $DEVICE is in use. Listing PIDs:"
  lsof "$DEVICE"
  echo
  echo "Attempting to kill processes using $DEVICE..."
  PIDS=$(lsof -t "$DEVICE" || true)
  if [ -n "$PIDS" ]; then
    echo "Sending SIGTERM to: $PIDS"
    kill $PIDS 2>/dev/null || true
    sleep 0.5
    STILL=$(lsof -t "$DEVICE" 2>/dev/null || true)
    if [ -n "$STILL" ]; then
      echo "Still alive, sending SIGKILL to: $STILL"
      kill -9 $STILL 2>/dev/null || echo "Failed to kill some processes. You may need sudo."
      sleep 0.5
    fi
  fi
fi

# --- optional mass erase ---
if [ "$DO_ERASE" -eq 1 ]; then
  echo "Erasing flash..."
  st-flash erase
fi

# --- flash ---
echo "Flashing $BIN to $FLASH_ADDR using st-flash..."
if [ "$VERIFY" -eq 1 ]; then
  st-flash --verify write "$BIN" "$FLASH_ADDR"
else
  st-flash write "$BIN" "$FLASH_ADDR"
fi

# --- optional reset ---
if [ "$DO_RESET" -eq 1 ]; then
  echo "Resetting target..."
  st-flash reset
fi

echo "Done."