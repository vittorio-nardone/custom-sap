# Virtual USB stick (CH376 simulator)

When `simulate.py` is run with `--ch376`, this directory is the FAT root exposed
to the kernel over ACIA #2.

Layout (for shell `cd` / `dir` / `type` / `exec` tests):

```
roms/sim/ch376/          ← root (/)
  DEMO.BIN               ← helloworld (OT header → 0x8400), try: exec DEMO.BIN
  HELLO.TXT, OTSMOKE.BIN, …
  BIN/HELLO.BIN          ← same app under /BIN
  BIN/README.TXT
  DOCS/GUIDE.TXT
  GAMES/SCORE.TXT
```

`DEMO.BIN` / `BIN/HELLO.BIN` / `EDIT.BIN` / `BIN/EDIT.BIN` are refreshed
from the current app build (`helloworld.bin`, `edit.bin`) after each
`./generate-all.sh` / `./scripts/build-apps.sh` (current kernel only).
Mapping: `CH376_COPIES` in `scripts/build-apps.sh`.


Add other files or subdirectories here to test menu `l` / `w`, shell commands,
or apps that call `STORAGE_*`. The smoke test (`apps/storage_smoke.asm`) creates
`OTSMOKE.BIN` here during a successful run (not refreshed by the build).

Override the path with `--ch376-dir /path/to/stick`.
