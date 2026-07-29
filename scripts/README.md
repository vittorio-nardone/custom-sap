# Otto build scripts

Build tooling lives under `scripts/`. Root `./generate-all.sh` runs the full ROM + apps pipeline.

## Layout

```
scripts/
  build-apps.sh          Compile apps (and optional Pascal examples)
  save-kernel-abi.sh     Snapshot kernel ABI to kernel/abi/v<version>/
  lib/
    kernel-abi.sh        Shared ABI helpers (symbols swap, output paths)
  python/
    microcode.py         Microcode ROM + instruction set generator
    lookup_tables.py     ALU / decoder lookup tables
    build_version.py     Kernel ROM build with auto version bump
    symbols.py           symbols.txt → kernel/symbols.asm
    add_header.py        OT upload header for XMODEM apps
    update_app_catalog.py   roms/apps/catalog.json for OttoTerminal F10
    7seg.py              7-segment display EEPROM generator
```

All Python build scripts live under `scripts/python/` and assume the current working directory is the repo root.

Run from the repository root:

```bash
source .venv/bin/activate

./generate-all.sh                    # full release build
./generate-all.sh --debug            # debug build (boot tests)
./generate-all.sh --save-abi         # also snapshot kernel ABI
./generate-all.sh --abi v1.2.101     # build apps for saved ABI

./scripts/build-apps.sh --abi v1.2.101 --pascal
./scripts/save-kernel-abi.sh --list

python3.11 scripts/python/update_app_catalog.py
```

All Python build scripts assume the current working directory is the repo root (paths like `roms/system/`, `kernel/`, `apps/` are relative to that).

## Kernel ABI

See `kernel/abi/README.md`. ABI helpers in `scripts/lib/kernel-abi.sh` resolve the repo root from `scripts/lib/` (two levels up).
