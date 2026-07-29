#!/bin/bash
#
# generate-all.sh — Project OTTO full build script
#
# Generates microcode ROMs, lookup tables, unified ROM binary, symbols,
# and compiles all applications in apps/
#
# Usage:
#   ./generate-all.sh                  Build release (no tests, includes TinyPascal)
#   ./generate-all.sh --debug          Build debug (includes tests, no TinyPascal)
#   ./generate-all.sh --save-abi       Also snapshot symbols to kernel/abi/v<version>/
#   ./generate-all.sh --abi v1.2.101   Compile apps for a saved kernel ABI
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/kernel-abi.sh
source "${SCRIPT_DIR}/scripts/lib/kernel-abi.sh"

# ── Parse arguments ───────────────────────────────────────────────
BUILD_MODE="release"
SAVE_ABI=0
KERNEL_ABI=""
while [ $# -gt 0 ]; do
    case "$1" in
        --debug)
            BUILD_MODE="debug"
            shift
            ;;
        --save-abi)
            SAVE_ABI=1
            shift
            ;;
        --abi)
            shift
            KERNEL_ABI="${1:-}"
            if [ -z "$KERNEL_ABI" ]; then
                echo "ERROR: --abi requires a version argument" >&2
                exit 1
            fi
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# ── Step 1: Generate microcode and lookup tables ─────────────────────
python3.11 scripts/python/microcode.py
python3.11 scripts/python/lookup_tables.py

# ── Step 2: Set build configuration ──────────────────────────────────
if [ "$BUILD_MODE" = "debug" ]; then
    sed -i '' 's/^#const BUILD_DEBUG = .*/#const BUILD_DEBUG = 1/' kernel/build_config.asm
else
    sed -i '' 's/^#const BUILD_DEBUG = .*/#const BUILD_DEBUG = 0/' kernel/build_config.asm
fi

# ── Step 3: Build unified ROM binary ────────────────────────────────
python3.11 scripts/python/build_version.py --symbols symbols.txt kernel/kernel.asm roms/system/kernel-rom.bin
python3.11 scripts/python/symbols.py

UNIFIED_SIZE=$(stat -f%z roms/system/kernel-rom.bin)

# Intel HEX output (for EEPROM programmer)
customasm kernel/kernel.asm -f intelhex -o roms/system/kernel-rom.hex

# Split unified binary into 8 KB ROM chips for EEPROM programming
split -b 8k -d ./roms/system/kernel-rom.bin ./roms/system/kernel-rom.bin.

# ── Step 4: Verify ROM sizes against capacity ────────────────────────
ROM_CAP=24576   # 24 KB (3 x 8 KB ROM chips)
ROM_FREE=$((ROM_CAP - UNIFIED_SIZE))
ROM_PCT=$((UNIFIED_SIZE * 100 / ROM_CAP))

if [ "$UNIFIED_SIZE" -gt "$ROM_CAP" ]; then
    echo ""
    echo "ERROR: Unified ROM exceeds capacity by $((UNIFIED_SIZE - ROM_CAP)) bytes!"
    exit 1
fi

# ── Step 5: Snapshot kernel ABI (optional) ───────────────────────────
if [ "$SAVE_ABI" = "1" ]; then
    if otto_abi_save "" "0"; then
        :
    else
        echo "NOTE: ABI snapshot already exists (use ./scripts/save-kernel-abi.sh --force to overwrite)"
    fi
fi

# ── Step 6: Compile applications ─────────────────────────────────────
BUILD_APPS_ARGS=()
if [ -n "$KERNEL_ABI" ]; then
    BUILD_APPS_ARGS+=(--abi "$KERNEL_ABI")
fi
BUILD_APPS_ARGS+=(--pascal)
"${SCRIPT_DIR}/scripts/build-apps.sh" "${BUILD_APPS_ARGS[@]}"

SUMMARY_FILE="${SCRIPT_DIR}/.otto-build-apps.summary"
if [ -f "$SUMMARY_FILE" ]; then
    # shellcheck source=/dev/null
    source "$SUMMARY_FILE"
else
    echo "ERROR: build-apps summary not found: ${SUMMARY_FILE}" >&2
    exit 1
fi

# ── Step 7: Build summary ───────────────────────────────────────────
KERNEL_VER=$(grep -o '"v[0-9.]*"' kernel/kernel.asm | head -1 | tr -d '"')
PMACHINE_VER=$(grep -o '"v[0-9.]*"' pascal/pmachine.asm | head -1 | tr -d '"')

INSTR_COUNT=$(grep -c '^\.OPCODE_0x[0-9A-Fa-f][0-9A-Fa-f]:' apps/istructions.asm)
INSTR_CAP=256  # 8-bit opcode space
INSTR_PCT=$((INSTR_COUNT * 100 / INSTR_CAP))
INSTR_FREE=$((INSTR_CAP - INSTR_COUNT))

if [ -n "$KERNEL_ABI" ]; then
    echo "=== Build complete (${BUILD_MODE}) — apps for kernel ABI v${KERNEL_ABI#v} ==="
else
    echo "=== Build complete (${BUILD_MODE}) ==="
fi
echo "  ROM:       Kernel ${KERNEL_VER} + Pascal ${PMACHINE_VER} — ${UNIFIED_SIZE} / ${ROM_CAP} bytes (${ROM_PCT}%) — ${ROM_FREE} bytes free"
echo "  CPU:       ${INSTR_COUNT} / ${INSTR_CAP} instructions (${INSTR_PCT}%) — ${INSTR_FREE} available"
echo "  Apps:      ${APP_COUNT} compiled (${OT_COUNT} with OT header) -> ${ASM_OUT}/"
if [ "${BUILD_PASCAL:-0}" = "1" ]; then
    echo "  Pascal:    ${PASCAL_COUNT} compiled -> ${PASCAL_OUT}/"
fi
echo ""
