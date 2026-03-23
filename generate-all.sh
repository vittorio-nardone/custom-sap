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

# ── Step 2: Build kernel and FORTH binaries ──────────────────────────
python3.11 build-version.py --symbols symbols.txt kernel/kernel.asm roms/kernel-rom.bin
python3.11 build-version.py forth/forth.asm roms/forth.bin

# Intel HEX output (for EEPROM programmer)
customasm kernel/kernel.asm -f intelhex -o roms/kernel-rom.hex

# Split kernel binary into 8 KB ROM chips
split -b 8k -d ./roms/kernel-rom.bin ./roms/kernel-rom.bin.

# ── Step 3: Verify ROM sizes against capacity ────────────────────────
KERNEL_SIZE=$(stat -f%z roms/kernel-rom.bin)
KERNEL_CAP=16384  # 16 KB (2 x 8 KB ROM chips)
KERNEL_FREE=$((KERNEL_CAP - KERNEL_SIZE))
KERNEL_PCT=$((KERNEL_SIZE * 100 / KERNEL_CAP))

FORTH_SIZE=$(stat -f%z roms/forth.bin)
FORTH_CAP=8192  # 8 KB (1 x 8 KB ROM chip)
FORTH_FREE=$((FORTH_CAP - FORTH_SIZE))
FORTH_PCT=$((FORTH_SIZE * 100 / FORTH_CAP))

if [ "$KERNEL_SIZE" -gt "$KERNEL_CAP" ]; then
    echo ""
    echo "ERROR: Kernel ROM exceeds capacity by $((KERNEL_SIZE - KERNEL_CAP)) bytes!"
    exit 1
fi

if [ "$FORTH_SIZE" -gt "$FORTH_CAP" ]; then
    echo ""
    echo "ERROR: FORTH ROM exceeds capacity by $((FORTH_SIZE - FORTH_CAP)) bytes!"
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
FORTH_VER=$(grep -o '"v[0-9.]*"' forth/forth.asm | head -1 | tr -d '"')

INSTR_COUNT=$(grep -c '^\.OPCODE_0x[0-9A-Fa-f][0-9A-Fa-f]:' kernel/istructions.asm)
INSTR_CAP=256  # 8-bit opcode space
INSTR_PCT=$((INSTR_COUNT * 100 / INSTR_CAP))
INSTR_FREE=$((INSTR_CAP - INSTR_COUNT))

echo ""
echo "=== Build complete ==="
echo "  Kernel: ${KERNEL_VER} — ${KERNEL_SIZE} / ${KERNEL_CAP} bytes (${KERNEL_PCT}%) — ${KERNEL_FREE} bytes free"
echo "  FORTH:  ${FORTH_VER} — ${FORTH_SIZE} / ${FORTH_CAP} bytes (${FORTH_PCT}%) — ${FORTH_FREE} bytes free"
echo "  CPU:    ${INSTR_COUNT} / ${INSTR_CAP} instructions (${INSTR_PCT}%) — ${INSTR_FREE} available"
echo "  Apps:   ${APP_COUNT} compiled"
echo ""
