# Virtual USB stick (CH376 simulator)

When `simulate.py` is run with `--ch376`, this directory is the FAT root exposed
to the kernel over ACIA #2.

Add files here to test menu `l` / `w` or apps that call `STORAGE_*`. The smoke
test (`apps/storage_smoke.asm`) creates `OTSMOKE.BIN` here during a successful run.

Override the path with `--ch376-dir /path/to/stick`.
