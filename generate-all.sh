#!/bin/bash
#
# generate-all.sh — Project OTTO full build script
#
# Generates microcode ROMs, lookup tables, unified ROM binary, symbols,
# and compiles all applications in apps/
#
# Usage:
#   ./generate-all.sh           Build release (no tests, includes TinyPascal)
#   ./generate-all.sh --debug   Build debug (includes tests, no TinyPascal)
#
set -e

# ── Parse arguments ───────────────────────────────────────────────
BUILD_MODE="release"
if [ "$1" = "--debug" ]; then
    BUILD_MODE="debug"
fi

# ── Step 1: Generate microcode and lookup tables ─────────────────────
python3.11 microcode.py
python3.11 lookup_tables.py

# ── Step 2: Set build configuration ──────────────────────────────────
if [ "$BUILD_MODE" = "debug" ]; then
    sed -i '' 's/^#const BUILD_DEBUG = .*/#const BUILD_DEBUG = 1/' kernel/build_config.asm
else
    sed -i '' 's/^#const BUILD_DEBUG = .*/#const BUILD_DEBUG = 0/' kernel/build_config.asm
fi

# ── Step 3: Build unified ROM binary ────────────────────────────────
python3.11 build-version.py --symbols symbols.txt kernel/kernel.asm roms/system/kernel-rom.bin
python3.11 symbols.py

# Extract pmachine.bin for simulator (bytes 16384+ of unified binary)
UNIFIED_SIZE=$(stat -f%z roms/system/kernel-rom.bin)

if [ "$UNIFIED_SIZE" -gt 16384 ]; then
    dd if=roms/system/kernel-rom.bin of=roms/system/pmachine.bin bs=1 skip=16384 2>/dev/null
else
    # Debug build or no P-Machine: create empty pmachine.bin
    dd if=/dev/zero of=roms/system/pmachine.bin bs=1 count=1 2>/dev/null
fi

# Truncate kernel-rom.bin to first 16 KB for simulator compatibility
dd if=roms/system/kernel-rom.bin of=roms/system/kernel-rom-full.bin bs=1 count="$UNIFIED_SIZE" 2>/dev/null
dd if=roms/system/kernel-rom-full.bin of=roms/system/kernel-rom.bin bs=16384 count=1 2>/dev/null

# Intel HEX output (for EEPROM programmer) — full unified binary
customasm kernel/kernel.asm -f intelhex -o roms/system/kernel-rom.hex

# Split full unified binary into 8 KB ROM chips
split -b 8k -d ./roms/system/kernel-rom-full.bin ./roms/system/kernel-rom.bin.

# Clean up
rm -f roms/system/kernel-rom-full.bin

# ── Step 4: Verify ROM sizes against capacity ────────────────────────
ROM_CAP=24576   # 24 KB (3 x 8 KB ROM chips)
ROM_FREE=$((ROM_CAP - UNIFIED_SIZE))
ROM_PCT=$((UNIFIED_SIZE * 100 / ROM_CAP))

if [ "$UNIFIED_SIZE" -gt "$ROM_CAP" ]; then
    echo ""
    echo "ERROR: Unified ROM exceeds capacity by $((UNIFIED_SIZE - ROM_CAP)) bytes!"
    exit 1
fi

# ── Step 5: Compile applications ─────────────────────────────────────
APP_COUNT=0
for i in apps/*.asm; do
    customasm "apps/$(basename $i)" -f binary -o roms/apps/asm/"$(basename $i .asm)".bin
    APP_COUNT=$((APP_COUNT + 1))
done

# ── Step 6: Compile Pascal examples ────────────────────────────────
PASCAL_COUNT=0
for i in pascal/examples/*.pas; do
    [ -e "$i" ] || continue
    python3.11 pascal_compiler.py "$i" -o roms/apps/pascal/"$(basename "$i" .pas)".bin
    PASCAL_COUNT=$((PASCAL_COUNT + 1))
done

# ── Step 7: Build summary ───────────────────────────────────────────
KERNEL_VER=$(grep -o '"v[0-9.]*"' kernel/kernel.asm | head -1 | tr -d '"')
PMACHINE_VER=$(grep -o '"v[0-9.]*"' pascal/pmachine.asm | head -1 | tr -d '"')

INSTR_COUNT=$(grep -c '^\.OPCODE_0x[0-9A-Fa-f][0-9A-Fa-f]:' kernel/istructions.asm)
INSTR_CAP=256  # 8-bit opcode space
INSTR_PCT=$((INSTR_COUNT * 100 / INSTR_CAP))
INSTR_FREE=$((INSTR_CAP - INSTR_COUNT))

echo ""
echo "=== Build complete (${BUILD_MODE}) ==="
echo "  ROM:       Kernel ${KERNEL_VER} + Pascal ${PMACHINE_VER} — ${UNIFIED_SIZE} / ${ROM_CAP} bytes (${ROM_PCT}%) — ${ROM_FREE} bytes free"
echo "  CPU:       ${INSTR_COUNT} / ${INSTR_CAP} instructions (${INSTR_PCT}%) — ${INSTR_FREE} available"
echo "  Apps:      ${APP_COUNT} compiled"
echo "  Pascal:    ${PASCAL_COUNT} compiled"
echo ""
