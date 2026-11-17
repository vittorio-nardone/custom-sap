# Otto OS v0.1

CP/M-inspired split: a **light kernel shell** (monitor + USB navigate + PATH/exec)
and **transient apps** on the USB stick under `/BIN`.

## Kernel builtins (ROM)

- System: `help`, `ver`, `cls`, `path`
- Memory monitor: `addr`, `dump`, `peek`, `poke`, `fill`, `copy`, `call`
- Ingress: `upload`, `load`, `save`
- USB: `mount`, `umount`, `dir`, `cd`
- Run: `exec` / bare `name` → `NAME.BIN` in CWD, then each `PATH` dir

Default after boot: `PATH=/BIN`.

Memory-facing commands stay in ROM so they do not overwrite App RAM (`0x8400`)
by loading a tool over the subject.

## Stick layout

```
/BIN      EDIT MORE FCOPY REN FIND DEL MKDIR RMDIR DISASM
/DOCS     README.TXT GUIDE.TXT
/GAMES    demos
/TMP      scratch
```

Apps load at **`0x8400`** (TPA), except `DISASM` / TinyPascal IDE (`0x020000` via OT).

## Tests

```bash
source .venv/bin/activate
./generate-all.sh
python scripts/python/test_shell_mount_dir.py
python scripts/python/test_otto_os.py
```
