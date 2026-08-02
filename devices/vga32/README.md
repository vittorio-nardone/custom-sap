# VGA32 console (OttoTerminal)

Firmware for the [LilyGO TTGO VGA32](https://github.com/Xinyuan-LilyGO/LilyGo-TTGO-T-Display) (ESP32 + FabGL **VGATextController**): VGA monitor and PS/2 keyboard as a serial console for **Project Otto**. Sources live in `OttoTerminal/`.

Text mode keeps enough DRAM for WiFi, HTTPS, and XMODEM upload alongside the terminal.

## Features

- Otto ACIA #1 bridge (115200 8N1) with level shifter
- **F1** — help
- **F10** — Apps Repository (WiFi catalog + XMODEM send to Otto)
- **F11** — settings (WiFi, display rows, UI colors)
- Footer status line; overlay pages use **ESC** to close

## UI keys

| Context | Keys |
|---------|------|
| Idle footer | F1 Help · F10 Upload · F11 Settings |
| F10 Apps Repository | ↑↓ select · **Enter** upload · **Tab** / **[ ]** kernel target · **A** auto-detect · **R** refresh · **ESC** exit |
| F11 / sub-pages | ↑↓ · **Enter** · **ESC** exit |
| Upload | On Otto first: **`u` + Enter** (XMODEM receive), then F10 → pick app → Enter |

Use **`u020000`** on Otto for apps outside default load address (e.g. TinyPascal IDE).

## Display size

VGATextController is **640×480** with 8-pixel-wide fonts → **80 columns** always. Row count = `480 / font_height` (8×8 … 8×19). Change in **F11 → Display**; saves to NVS and reboots.

## WiFi

Configure in **F11 → WiFi** (stored in ESP32 NVS). Optional one-time seed if NVS is empty:

```bash
cp devices/vga32/OttoTerminal/otto_secrets.h.example \
   devices/vga32/OttoTerminal/otto_secrets.h
# edit SSID / password — file is gitignored
```

Apps catalog: `roms/apps/catalog.json` on GitHub (per-kernel trees under `roms/apps/v*/`).
Regenerate locally with `python3.11 scripts/python/update_app_catalog.py` after building apps.
Configure repo URL in `otto_config.h` (`OTTO_WIFI_CATALOG_INDEX_URL`).

**GitHub raw CDN:** `raw.githubusercontent.com` can serve stale `.bin` files for a few minutes
after a push. OttoTerminal appends `?sha=<blob>` (from the GitHub Contents API) to each
`download_url` so F10 always fetches the current binary. Reflash OttoTerminal after updating
`otto_wifi.cpp` if uploads still show an old app banner after R + upload.

## Wiring (Otto serial 1 → ESP32)

Otto MC68B50 (5 V) through a **bidirectional level shifter** (BSS138 recommended). Do not use a resistor divider on Otto TX.

| Direction | Otto | ESP32 |
|-----------|------|-------|
| Otto → ESP32 | Pin **2** TX | GPIO **34** RX |
| ESP32 → Otto | Pin **3** RX | GPIO **2** TX |
| Ground | Pin **6** GND | GND |

Verify header pin labels with a meter — some TTGO boards have incorrect silkscreen.

**USB bridge (OttoTerminal 1.0.10+):** bidirectional link on the TTGO USB serial port
at 115200 8N1 (same port as firmware upload):

- Otto ACIA #1 RX → USB Serial (print, raw VT100)
- USB Serial → Otto ACIA #1 TX (type; LF converted to CR)

```bash
minicom -D /dev/cu.usbserial-XXXX -b 115200
```

Disable with `OTTO_USB_MIRROR 0` in `otto_config.h`. PS/2 keyboard defaults to
**Italian** layout (`fabgl::ItalianLayout`).

## Build / flash

Requires Arduino ESP32 core **2.0.17**, FabGL, `arduino-cli`. Partition: **huge_app**.

**Versioning (SemVer 2.0):** `OttoTerminal/otto_version.txt` holds `MAJOR.MINOR.PATCH`. Each compile/upload increments **PATCH** (e.g. `1.0.0` → `1.0.1`). Use `./devices/vga32/build.sh bump minor|major` for release bumps; `OTTO_SKIP_VERSION_BUMP=1` skips the patch increment on compile.

```bash
./devices/vga32/build.sh              # compile
./devices/vga32/build.sh upload       # flash (default PORT in build.sh)
PORT=/dev/cu.usbserial-XXXX ./devices/vga32/build.sh upload
```

## Simulator bridge

With Otto running in `simulate.py`, map the emulated ACIA to the VGA32 UART USB port:

```bash
python simulate.py --serial-device /dev/cu.usbserial-XXXX
```

See the root `README.md` for full simulator options.
