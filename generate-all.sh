python3.11 microcode.py
python3.11 lookup_tables.py
customasm kernel.asm -f intelhex -o roms/kernel-rom.hex
customasm kernel.asm -f binary -o roms/kernel-rom.bin -- -f symbols -o symbols.txt 
python3.11 symbols.py
for i in apps/*.asm; do customasm "apps/$(basename $i)" -f binary -o roms/"$(basename $i .asm)".bin; done
