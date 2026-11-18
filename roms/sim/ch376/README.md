# Virtual USB stick (CH376 simulator) — Otto OS layout

When `simulate.py` is run with `--ch376`, this directory is the FAT root.

```
roms/sim/ch376/          ← root (/)
  BIN/                   ← PATH default (/BIN)
    EDIT.BIN MORE.BIN FCOPY.BIN REN.BIN FIND.BIN
    DEL.BIN MKDIR.BIN RMDIR.BIN DISASM.BIN
  DOCS/                  ← README.TXT GUIDE.TXT
  GAMES/                 ← HELLO.BIN HANGMAN.BIN …
  TMP/                   ← scratch
  HELLO.TXT NOTES.TXT …
```

`scripts/build-apps.sh` (current kernel) refreshes `/BIN` and `/GAMES`
from compiled apps (`CH376_COPIES`).

Override with `--ch376-dir /path/to/stick`.
