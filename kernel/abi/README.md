# Kernel ABI snapshots

Otto apps are **statically linked** to kernel routine addresses at compile time
(`jsr ACIA_SEND_STRING` becomes a fixed ROM address). When the kernel changes,
those addresses move. Hardware that still runs an older EEPROM image needs apps
compiled against that kernel's symbol table.

Each subdirectory `v<KERNEL_VERSION>/` holds everything required to rebuild apps
for that kernel:

| File | Purpose |
|------|---------|
| `symbols.txt` | Raw symbol map from the kernel build |
| `symbols.asm` | `#const` definitions included by apps |
| `kernel-rom.bin` | Matching ROM image (simulator / reference) |
| `kernel-rom.bin` | Matching ROM image (simulator / reference) |
| `manifest.json` | Version, build date, git commit, ROM size, `ot_header` |

`ot_header` in `manifest.json` indicates whether built app binaries include the
6-byte OT upload prefix (kernels with `XMODEM_AUTO_ADDR` in symbols.asm).
Legacy kernels (e.g. v1.2.101) use raw binaries without the OT header.

Built app binaries live under `roms/apps/` (not in `kernel/abi/`):

```
roms/apps/
  catalog.json
  current/           # latest kernel (./generate-all.sh / ./scripts/build-apps.sh)
    asm/
    pascal/
  v1.2.101/          # older kernel target
    asm/
    pascal/
```

## Save a snapshot (after flashing EEPROMs)

```bash
source .venv/bin/activate
./generate-all.sh
./scripts/save-kernel-abi.sh
```

Overwrite an existing snapshot:

```bash
./scripts/save-kernel-abi.sh --force
```

List saved versions:

```bash
./scripts/save-kernel-abi.sh --list
```

`./generate-all.sh --save-abi` runs the same save step automatically after a
kernel build (skips if the snapshot already exists).

## Build apps for a specific kernel

```bash
./scripts/build-apps.sh --abi v1.2.101
./scripts/build-apps.sh --abi v1.2.101 apps/helloworld.asm
./scripts/build-apps.sh --abi v1.2.101 --pascal
```

Output goes to `roms/apps/v1.2.101/asm/` and `roms/apps/v1.2.101/pascal/`.
Current kernel output goes to `roms/apps/current/`.

Use the matching `kernel-rom.bin` from `kernel/abi/v<version>/` when testing
in the simulator on a workstation.

## Workflow

1. Change kernel → `./generate-all.sh --save-abi` → flash EEPROMs.
2. Develop apps as usual (`./generate-all.sh` or `./scripts/build-apps.sh`).
3. Deploy to older hardware → `./scripts/build-apps.sh --abi v<version-on-board>`.

Apps must only use kernel APIs that exist in the target version. Pascal binaries
also depend on `PM_ENTRY` and the P-Machine version in that kernel ROM — use
`--pascal` with the same `--abi` when targeting older hardware.

## OttoTerminal (F10 upload)

OttoTerminal downloads `roms/apps/catalog.json` from GitHub, then lists apps from
the selected kernel target (e.g. `roms/apps/v1.2.101/asm`). On F10 open it
auto-detects the kernel version from Otto's serial boot banner when possible.

Publish to GitHub after building:

```bash
./scripts/build-apps.sh --abi v1.2.101 --pascal
./scripts/build-apps.sh --pascal
python3.11 scripts/python/update_app_catalog.py
```
