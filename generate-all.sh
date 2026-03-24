#!/bin/bash
#
# generate-all.sh — Project OTTO full build script
#
# Generates microcode ROMs, lookup tables, kernel binary, symbols,
# and compiles all applications in apps/
#
set -e

# ── Step 1: Generate microcode and lookup tables ─────────────────────
python3.11 microcode.py
python3.11 lookup_tables.py

# ── Step 2: Build kernel and Pascal P-Machine binaries ───────────────
python3.11 build-version.py --symbols symbols.txt kernel/kernel.asm roms/kernel-rom.bin
python3.11 build-version.py pascal/pmachine.asm roms/pmachine.bin

# Intel HEX output (for EEPROM programmer)
customasm kernel/kernel.asm -f intelhex -o roms/kernel-rom.hex

# Split kernel binary into 8 KB ROM chips
split -b 8k -d ./roms/kernel-rom.bin ./roms/kernel-rom.bin.

# ── Step 3: Verify ROM sizes against capacity ────────────────────────
KERNEL_SIZE=$(stat -f%z roms/kernel-rom.bin)
KERNEL_CAP=16384  # 16 KB (2 x 8 KB ROM chips)
KERNEL_FREE=$((KERNEL_CAP - KERNEL_SIZE))
KERNEL_PCT=$((KERNEL_SIZE * 100 / KERNEL_CAP))

PMACHINE_SIZE=$(stat -f%z roms/pmachine.bin)
PMACHINE_CAP=8192  # 8 KB (1 x 8 KB ROM chip)
PMACHINE_FREE=$((PMACHINE_CAP - PMACHINE_SIZE))
PMACHINE_PCT=$((PMACHINE_SIZE * 100 / PMACHINE_CAP))

if [ "$KERNEL_SIZE" -gt "$KERNEL_CAP" ]; then
    echo ""
    echo "ERROR: Kernel ROM exceeds capacity by $((KERNEL_SIZE - KERNEL_CAP)) bytes!"
    exit 1
fi

if [ "$PMACHINE_SIZE" -gt "$PMACHINE_CAP" ]; then
    echo ""
    echo "ERROR: P-Machine ROM exceeds capacity by $((PMACHINE_SIZE - PMACHINE_CAP)) bytes!"
    exit 1
fi

# ── Step 4: Export kernel symbols and compile applications ───────────
python3.11 symbols.py

APP_COUNT=0
for i in apps/*.asm; do
    customasm "apps/$(basename $i)" -f binary -o roms/"$(basename $i .asm)".bin
    APP_COUNT=$((APP_COUNT + 1))
done

# ── Step 5: Build summary ───────────────────────────────────────────
KERNEL_VER=$(grep -o '"v[0-9.]*"' kernel/kernel.asm | head -1 | tr -d '"')
PMACHINE_VER=$(grep -o '"v[0-9.]*"' pascal/pmachine.asm | head -1 | tr -d '"')

INSTR_COUNT=$(grep -c '^\.OPCODE_0x[0-9A-Fa-f][0-9A-Fa-f]:' kernel/istructions.asm)
INSTR_CAP=256  # 8-bit opcode space
INSTR_PCT=$((INSTR_COUNT * 100 / INSTR_CAP))
INSTR_FREE=$((INSTR_CAP - INSTR_COUNT))

# ── Step 5b: Compile Pascal examples ────────────────────────────────
PASCAL_COUNT=0
for i in pascal/examples/*.pas; do
    [ -e "$i" ] || continue
    python3.11 pascal_compiler.py "$i" -o roms/"$(basename "$i" .pas)".bin
    PASCAL_COUNT=$((PASCAL_COUNT + 1))
done

echo ""
echo "=== Build complete ==="
echo "  Kernel:    ${KERNEL_VER} — ${KERNEL_SIZE} / ${KERNEL_CAP} bytes (${KERNEL_PCT}%) — ${KERNEL_FREE} bytes free"
echo "  P-Machine: ${PMACHINE_VER} — ${PMACHINE_SIZE} / ${PMACHINE_CAP} bytes (${PMACHINE_PCT}%) — ${PMACHINE_FREE} bytes free"
echo "  CPU:       ${INSTR_COUNT} / ${INSTR_CAP} instructions (${INSTR_PCT}%) — ${INSTR_FREE} available"
echo "  Apps:      ${APP_COUNT} compiled"
echo "  Pascal:    ${PASCAL_COUNT} compiled"
echo ""
