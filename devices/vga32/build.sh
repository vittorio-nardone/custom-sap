#!/usr/bin/env bash
# Build / flash AdvancedTerminal (ESP32 + FabGL) for Project Otto.
#
# Target board: LilyGO TTGO T7 Mini32 v1.4 (VGA32, ESP32-WROVER + PSRAM)
#
# Prerequisites:
#   - Arduino ESP32 core 2.0.17 (esp32:esp32) — project default
#     arduino-cli core install esp32:esp32@2.0.17
#   - FabGL library in ~/Documents/Arduino/libraries/FabGL
#   - arduino-cli on PATH, or Arduino IDE 2.x installed
#   - `python` on PATH (symlink to python3); build.sh tries to fix this on macOS
#
# Usage:
#   ./devices/vga32/build.sh              # compile only
#   ./devices/vga32/build.sh compile
#   ./devices/vga32/build.sh upload       # compile + flash (default USB port)
#   ./devices/vga32/build.sh upload-sd-test   # SD diagnostic (no UART on GPIO 2)
#
# Environment (override defaults):
#   FQBN          Board FQBN for AdvancedTerminal (default: esp32wrover 2.x)
#   SD_TEST_FQBN  Board FQBN for SdCardTest (default: esp32wrover, PSRAM disabled)
#   PORT          USB serial port for upload (default: /dev/cu.usbserial-5B212326931)
#
# SdCardTest uses FabGL FileBrowser (works with ESP32 core 1.0.6 and 2.x).
# Project default is 2.0.17 (AdvancedTerminal). For SD-only experiments
# on stubborn boards, optional: arduino-cli core install esp32:esp32@1.0.6

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKETCH="${SCRIPT_DIR}/AdvancedTerminal"

# LilyGO TTGO T7 v1.4 — match Arduino IDE: Board "ESP32 Wrover Module",
# Partition Scheme "Default 4MB with spiffs" (max app ~1310720 bytes), Upload 460800.
FQBN="${FQBN:-esp32:esp32:esp32wrover:PartitionScheme=default,UploadSpeed=460800}"
SD_TEST_FQBN="${SD_TEST_FQBN:-esp32:esp32:esp32wrover:PartitionScheme=default,UploadSpeed=460800}"
PORT="${PORT:-/dev/cu.usbserial-5B212326931}"

# ESP32 core 2.x build scripts call "python"; macOS Arduino GUI often lacks it.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
if ! command -v python >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  mkdir -p "${HOME}/.local/bin"
  ln -sf "$(command -v python3)" "${HOME}/.local/bin/python" 2>/dev/null || true
  export PATH="${HOME}/.local/bin:${PATH}"
fi

find_arduino_cli() {
  if command -v arduino-cli >/dev/null 2>&1; then
    command -v arduino-cli
    return 0
  fi
  local bundled="/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli"
  if [[ -x "$bundled" ]]; then
    echo "$bundled"
    return 0
  fi
  echo "arduino-cli not found. Install arduino-cli or Arduino IDE 2.x." >&2
  exit 1
}

ARDUINO_CLI="$(find_arduino_cli)"

compile() {
  compile_sketch "${SKETCH}"
}

compile_sketch() {
  local sketch="$1"
  local fqbn="${2:-${FQBN}}"
  echo "-> compile ${sketch}"
  echo "   board: LilyGO TTGO T7 Mini32 v1.4 (ESP32 Wrover)"
  echo "   fqbn:  ${fqbn}"
  "$ARDUINO_CLI" compile --fqbn "$fqbn" "$sketch"
}

upload() {
  local port="${1:-${PORT}}"
  if [[ -z "$port" ]]; then
    echo "Serial port required for upload." >&2
    echo "Usage: $0 upload [PORT]" >&2
    exit 1
  fi
  if [[ ! -e "$port" ]]; then
    echo "Warning: serial port not found: ${port}" >&2
    echo "         plug in the TTGO or set PORT=... before upload." >&2
  fi
  compile
  echo "-> upload to ${port}"
  "$ARDUINO_CLI" upload -p "$port" --fqbn "$FQBN" "$SKETCH"
}

case "${1:-compile}" in
  compile)
    compile
    ;;
  upload|flash)
    upload "${2:-}"
    ;;
  build)
    upload "${2:-}"
    ;;
  compile-sd-test|sd-test)
    compile_sketch "${SCRIPT_DIR}/SdCardTest" "${SD_TEST_FQBN}"
    ;;
  upload-sd-test|flash-sd-test)
    compile_sketch "${SCRIPT_DIR}/SdCardTest" "${SD_TEST_FQBN}"
    echo "-> upload SdCardTest to ${PORT}"
    "$ARDUINO_CLI" upload -p "${PORT}" --fqbn "${SD_TEST_FQBN}" "${SCRIPT_DIR}/SdCardTest"
    ;;
  -h|--help|help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Run: $0 help" >&2
    exit 1
    ;;
esac
