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

## Level shifter → ESP32 (FabGL UART)

| Direction | Otto (5 V) | Shifter | ESP32 (3.3 V) |
|-----------|------------|---------|----------------|
| Otto → display | Pin **2** TX | HV1 ↔ LV1 | GPIO **34** (RX) |
| Keyboard → Otto | Pin **3** RX | HV2 ↔ LV2 | GPIO **2** (TX) |
| Ground | Pin **6** GND | GND | GND |
| Power | 5 V rail | **HV** | — |
| Power | — | **LV** | 3.3 V (TTGO) |

```
Otto pin 2 (TX)  ─── HV1 ─── LV1 ─── GPIO 34 (ESP32 RX)
Otto pin 3 (RX)  ─── HV2 ─── LV2 ─── GPIO  2 (ESP32 TX)
Otto pin 6 (GND) ─── GND ─────────── GND (TTGO)
Otto 5 V         ─── HV
TTGO 3.3 V       ─── LV
```

GPIO 34 is input-only on the ESP32; GPIO 2 is used as UART TX by FabGL. Cross the data lines as shown (Otto TX to ESP32 RX, Otto RX to ESP32 TX).

## FabGL terminal settings

Press **F12** on the VGA display (or use defaults after **CTRL+ALT+F12** reset):

| Setting | Value |
|---------|--------|
| Resolution | **800×600, 8 Colors** (VGA8) |
| Font | **Auto** (~8×16 at this mode → **100×37** terminal) |
| Columns / Rows | **Max** (fill viewport) |
| Terminal type | **ANSI** (native VT100/CSI — best match for Otto) |
| Keyboard layout | **Italian** |
| Serial port | `FabGL Terminal: TX=2 RX=34` |
| Baud rate | 115200 |
| Data / parity / stop | 8 / None / 1 |
| Flow control | None |

AdvancedTerminal ships with these defaults (firmware **v2.3**). Reflash to apply; stored settings reset when the firmware version changes. Otto kernel help lines are ≤80 columns; at 100 columns they fit with margin.

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

Build and flash `AdvancedTerminal/AdvancedTerminal.ino` with the Arduino ESP32 core and FabGL library. Board: ESP32 Wrover module (PSRAM enabled on TTGO T7).

Otto kernel serial parameters are defined in `kernel/serial.asm` (`ACIA_INIT_115200_8N1`).

## Simulator + VGA32 (Mac as Otto)

While Otto hardware is not connected, the Python simulator can drive AdvancedTerminal over a USB–serial adapter (FTDI) on the Mac. The simulator’s ACIA maps to the real port instead of stdin/stdout.

**Wiring (FTDI chip-centric → FabGL UART):**

| FTDI pin | ESP32 GPIO |
|----------|------------|
| TX | 34 (RX) |
| RX | 2 (TX) |
| GND | GND |

Use a **second** USB serial adapter (not the TTGO programming port on GPIO 1/3). Set serial port to `FabGL Terminal: TX=2 RX=34`, 115200 8N1, terminal type **ANSI**.

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
```

Replace `/dev/cu.usbserial-XXXX` with your adapter (`ls /dev/cu.*`). Do **not** combine `--serial-device` with `--simulate-serial` (virtual PTY pair for minicom).

**Note:** `--quiet` hides kernel boot text on the serial line; omit it when using the interactive kernel menu on VGA. `--autorun` implies headless and sends `r` + CR (or `rADDR`) on the serial port automatically.
