# VGA32 AdvancedTerminal (Otto + FabGL)

**AdvancedTerminal** is the VGA32 companion firmware for **Project Otto**: an ESP32 board with VGA output (e.g. LilyGO TTGO T7 Mini32 v1.4) that today provides a serial console (display + PS/2 keyboard), and is intended to grow with SD storage, network connectivity, RTC, and other services on the same hardware.

The current release is based on [FabGL](https://github.com/fdivitto/FabGL) AnsiTerminal (serial ANSI/VT100 front-end). Firmware sources: `AdvancedTerminal/`.

## Hardware overview

Otto **serial port 1** (MC68B50 ACIA, 115200 8N1) is connected to the ESP32 through a **bidirectional level shifter** (5 V ↔ 3.3 V). Do **not** use a resistor divider on Otto TX: the ACIA transmit output is current-limited and cannot drive a divider to ground reliably.

Recommended module: **4-channel BSS138** level shifter (HV = 5 V, LV = 3.3 V).

## Otto serial 1 connector

| Pin | Signal | Connect to |
|-----|--------|------------|
| **2** | TX (Otto → peer) | Level shifter **HV** (high side), channel 1 |
| **3** | RX (Otto ← peer) | Level shifter **HV**, channel 2 |
| **6** | GND | Common ground (Otto, shifter, ESP32) |

Other Otto serial signals (for reference):

| ACIA signal | Typical Otto wiring |
|-------------|---------------------|
| CTS | 100 kΩ to GND (transmit always enabled) |
| RTS | Not connected |
| DCD | Tie to GND if not used |

## Level shifter → ESP32 (FabGL UART) — default: PS/2 mouse port

Firmware default (F12 → Serial port): **`PS/2 Mouse: TX=27 RX=26`**. Otto uses the **mouse** mini-DIN on the VGA32 board so **GPIO 2 stays free for the SD card** (MISO on PICO-D4 boards).

| Direction | Otto (5 V) | Shifter | ESP32 PS/2 mouse |
|-----------|------------|---------|------------------|
| Otto → display | Pin **2** TX | HV1 ↔ LV1 | Pin **5** CLK = GPIO **26** (RX) |
| Keyboard → Otto | Pin **3** RX | HV2 ↔ LV2 | Pin **1** DATA = GPIO **27** (TX) |
| Ground | Pin **6** GND | GND | Pin **3** GND |

```
Otto pin 2 (TX)  ─── HV1 ─── LV1 ─── PS/2 mouse CLK (GPIO 26)
Otto pin 3 (RX)  ─── HV2 ─── LV2 ─── PS/2 mouse DATA (GPIO 27)
Otto pin 6 (GND) ─── GND ─────────── PS/2 mouse GND
Otto 5 V         ─── HV
TTGO 3.3 V       ─── LV
```

PS/2 mouse pinout (socket on PCB, front view): **1** = DATA (27), **3** = GND, **5** = CLK (26). Do not use pin **4** (+5 V from the board) for the level shifter — power HV from Otto 5 V.

### Legacy: 6-pin header (GPIO 2 / 34)

| Direction | ESP32 |
|-----------|--------|
| Otto TX → ESP32 RX | GPIO **34** |
| Otto RX ← ESP32 TX | GPIO **2** (shares SD MISO — avoid for OTIO + SD) |

Select `FabGL Terminal: TX=2 RX=34` in F12 only for temporary FTDI/simulator use without SD access.

## FabGL terminal settings

Press **F12** on the VGA display (or use defaults after **CTRL+ALT+F12** reset):

| Setting | Value |
|---------|--------|
| Resolution | **800×600, 8 Colors** (VGA8) |
| Font | **Auto** (~8×16 at this mode → **100×37** terminal) |
| Columns / Rows | **Max** (fill viewport) |
| Terminal type | **ANSI** (native VT100/CSI — best match for Otto) |
| Keyboard layout | **Italian** |
| Serial port | **`PS/2 Mouse: TX=27 RX=26`** (Otto default) |
| SD browser | **F11** — read-only browse of `otto/` on microSD |
| Baud rate | 115200 |
| Data / parity / stop | 8 / None / 1 |
| Flow control | None |

AdvancedTerminal ships with these defaults (firmware **v2.11**). Reflash to apply; stored settings reset when the firmware version changes.

After Otto boots, the kernel prints a newline and `>` on the serial port without waiting for input. Reset Otto once AdvancedTerminal is running if both boards power on at the same time.

## Terminal compatibility (Otto ↔ FabGL)

Otto’s `VT100_*` kernel routines (`kernel/vt100.asm`) emit standard **ANSI CSI** sequences (`ESC [ …`), not a full DEC VT100 emulator. FabGL’s native **ANSI** mode parses these directly.

### Otto → display (serial output)

| Otto output | FabGL **ANSI** |
|-------------|----------------|
| `ESC [2J`, `[H`, `[row;colH` | Yes |
| `ESC [A/B/C/D`, `[K` | Yes |
| `ESC [0m`, `[1m`, colours `30–37`, `40–47` | Yes |
| `ESC [7h/l`, `ESC [r`, `ESC D`, `ESC M` | Yes |

Avoid retro emulations (**VT52**, **ADM 3A**, **ADM 31**, **Osborne**, **Kaypro**, **Hazeltine**): FabGL expects *those* host dialects on the serial line and will not interpret Otto’s CSI sequences correctly.

**ANSI Legacy** usually works for Otto, but **ANSI** is the recommended setting.

### Keyboard → Otto (serial input)

The Otto kernel menu accepts plain ASCII (`d`, `u`, `r`, `h`, Enter) and backspace (`0x08` / `0x7F`). Letter keys and Enter work with any ANSI-family terminal type.

Arrow keys **left** / **right** move the cursor within the current command line; **backspace** deletes before the cursor. Up/down and function keys are ignored. Sequences are not echoed (avoids FabGL interpreting echoed CSI as cursor motion).

### Rare edge cases

- `VT100_QUERY_CURSOR_POSITION` (`ESC [6n`): FabGL replies on the serial line; unused by the kernel today.
- Otto newline convention is **LF + CR** (`0x0A 0x0D`); FabGL handles this in normal use.

## Software

Build and flash `AdvancedTerminal/AdvancedTerminal.ino` with the Arduino ESP32 core and FabGL library. Target: **LilyGO TTGO T7 Mini32 v1.4** (ESP32 Wrover module, PSRAM).

```bash
./devices/vga32/build.sh              # compile — same as Arduino IDE (default partition, ~58%)
./devices/vga32/build.sh upload       # flash — default /dev/cu.usbserial-5B212326931
./devices/vga32/build.sh upload /dev/cu.other-port
```

Arduino IDE equivalent: **ESP32 Wrover Module**, partition **Default 4MB with spiffs**, upload **460800** (Tools → Upload Speed).

For a larger app partition (optional): `FQBN='esp32:esp32:esp32wrover:PartitionScheme=huge_app,UploadSpeed=460800' ./devices/vga32/build.sh compile`

If upload fails, fall back to 230400 or 115200: `FQBN='...UploadSpeed=230400' ./devices/vga32/build.sh upload`

On TTGO VGA32, the SD card uses **HSPI** via FabGL:

| Signal | GPIO | Notes |
|--------|------|--------|
| CS | **13** | |
| MOSI | **12** | |
| CLK | **14** | |
| MISO | **2** or **35** | **2** on ESP32-PICO-D4 (most TTGO VGA32 boards); **35** on ESP32-D0WDQ5 WROVER |

FabGL picks MISO from the chip package (eFuse). If your board reports `MISO=2`, you have **PICO-D4** wiring — that is correct. **GPIO 2 is also UART TX to Otto**; OTIO must pause UART before mounting SD and restore it before sending OTIO replies. Do not call `SD.begin(cs)` on the default VSPI bus (shares VGA pins 18/19/23).

### SD card vs UART on GPIO 2 (critical on TTGO VGA32)

On PICO-D4 boards, **GPIO 2 = SD MISO and UART TX** (Otto / FTDI on pin 34+2).

| Situation | SD mount |
|-----------|----------|
| FTDI or Otto level shifter **powered** on GPIO 2/34 | Usually **fails** (`INVALID_RESPONSE` / FabGL Mount Failed) |
| FTDI **unplugged or powered off**, only VGA32 + SD | **Works** (confirmed on TTGO v1.4) |

For **SdCardTest** or **FabGL HardwareTest**, disconnect or power off the **second** USB serial adapter (FTDI) on GPIO 2/34 before testing the microSD. The TTGO programming port (GPIO 1/3) is unrelated.

When running **OTIO** with Otto attached, AdvancedTerminal pauses UART on GPIO 2 during `l` / `g`; if the external adapter still drives the line, SD may still fail — prefer Otto + shifter without a parallel FTDI on the same pins, or power down the debug adapter during SD access.

Card layout on SD (FAT32): copy **`roms/apps/`** to **`otto/apps/`** at the card root (mounted as `/SD/otto` on the ESP32). The simulator `--otio-stub` uses the same paths with default root `roms/`.


## Simulator + VGA32 (Mac as Otto)

While Otto hardware is not connected, the Python simulator can drive AdvancedTerminal over a USB–serial adapter (FTDI) on the Mac. The simulator’s ACIA maps to the real port instead of stdin/stdout.

**Wiring (FTDI chip-centric → FabGL UART):**

| FTDI pin | ESP32 GPIO |
|----------|------------|
| TX | 34 (RX) |
| RX | 2 (TX) |
| GND | GND |

Use a **second** USB serial adapter (not the TTGO programming port on GPIO 1/3). Set serial port to `FabGL Terminal: TX=2 RX=34`, 115200 8N1, terminal type **ANSI**.

**Simulator tip:** `simulate.py --serial-device` opens the port with `dsrdtr=False` so the Mac does not reset the VGA32 via DTR when the simulator starts. Start AdvancedTerminal first, then the simulator.

**SD + simulator:** While testing the microSD (SdCardTest, HardwareTest, or kernel `l` over OTIO), **disconnect or power off the FTDI** on GPIO 2/34. With the adapter active, SD mount fails even if pins and cards are correct.


```bash
source .venv/bin/activate

# Interactive: kernel menu on VGA, type on PS/2 keyboard
python simulate.py --serial-device /dev/cu.usbserial-XXXX

# Autorun a program (output on VGA; no kernel menu)
python simulate.py --serial-device /dev/cu.usbserial-XXXX \
  --autorun --program roms/apps/asm/helloworld.bin

# Scripted input after boot (example: help, then quit)
python simulate.py --serial-device /dev/cu.usbserial-XXXX \
  --input $'h\rq\r'

# Automated OTIO test (kernel `t` — VGA32 must be booted first)
python simulate.py --otio-test --serial-device /dev/cu.usbserial-XXXX

# Other kernel OTIO commands (custom input)
python simulate.py --headless --max-cycles 50000000 \
  --serial-device /dev/cu.usbserial-XXXX \
  --input $'l apps/asm\r'
```

Replace `/dev/cu.usbserial-XXXX` with your adapter (`ls /dev/cu.*`). Do **not** combine `--serial-device` with `--simulate-serial` (virtual PTY pair for minicom).

For **software-only** OTIO (no VGA32): `python simulate.py --otio-stub --input $'t\r'` (see `otio_stub.py`).

`SdCardTest` is a minimal sketch (no Otto UART) to verify the microSD mounts and list `otto/` on the VGA screen:

```bash
./devices/vga32/build.sh upload-sd-test
```

Expected on screen: `mountSDCard: OK` and directory listings. If mount fails, fix the SD card (FAT32, inserted) before OTIO. Re-flash AdvancedTerminal when done: `./devices/vga32/build.sh upload`.
