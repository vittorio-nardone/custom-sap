#!/bin/bash
set -e

python3.11 microcode.py
python3.11 lookup_tables.py
python3.11 build-version.py --symbols symbols.txt kernel/kernel.asm roms/kernel-rom.bin
python3.11 build-version.py forth/forth.asm roms/forth.bin
customasm kernel/kernel.asm -f intelhex -o roms/kernel-rom.hex
split -b 8k -d ./roms/kernel-rom.bin ./roms/kernel-rom.bin. 
python3.11 symbols.py
for i in apps/*.asm; do customasm "apps/$(basename $i)" -f binary -o roms/"$(basename $i .asm)".bin; done
