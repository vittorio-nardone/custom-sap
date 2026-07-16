# Project Otto

<img src="media/otto-wip.jpg" width="300">

Project Otto, or simply Otto, is an 8-bit TTL homebrew retro computer. I call it "homebrew" because it was designed, simulated, and assembled entirely in my apartment. "Retro" because it was built using integrated circuits typically used during the 70s/80s.

The choice that heavily influenced the development effort was not to use microprocessors from that era. Instead, I opted to create a custom CPU, building its individual components with TTL integrated circuits from the 7400 series, mostly of the LS (Low-power Schottky TTL) type.

Otto is inspired by the SAP (Simple As Possible) computer, described in the book ["Digital Computer Electronics"](https://ia803000.us.archive.org/8/items/367026792DigitalComputerElectronicsAlbertPaulMalvinoAndJeraldABrownPdf1/367026792-Digital-Computer-Electronics-Albert-Paul-Malvino-and-Jerald-A-Brown-pdf%20%281%29.pdf) by Albert Paul Malvino and Jerald A. Brown (ISBN 0-02-800594-5).

This choice allowed me to understand and experience firsthand how a single assembly instruction is executed by hardware components and gave me great freedom in terms of CPU characteristics. I still implemented an instruction set not too different from the MOS 6502, to have the ability to easily port a vast library of open source software available online.

Otto is designed as a laboratory for experimenting and having fun. This is the reason for its multiple-board layout, connected to a main board that acts as a backplane and control unit.

This layout provides the ability to modify or evolve individual parts of the system. In contrast, a single board layout, although more compact, would have forced me to redesign the entire board with every change.

The microcode needed to execute assembly instructions is stored on EEPROM. Each board hosts one or more EEPROMs if necessary.

Summarizing the technical characteristics, Otto is configured as follows:
* 8-bit TTL CPU (7400 family)
* 1 MHz clock frequency (software reducible to 250KHz)
* 1 KHz debugging clock frequency (software reducible to 250Hz)
* 6 user-accessible registers (A, X, Y, D, E, and OUT)
* 24 KB ROM
* 32 KB zero-page RAM (4 KB for stack)
* 128 KB RAM expansion (2x 64KB pages)
* 8-bit ALU (74181) and shift register
* 8-bit data bus - 24-bit address bus - 13-bit control bus
* 2x serial/USB interface
* 3x maskable interrupt lines and 10Hz timer interrupt

**Display and I/O (in use):** a [LilyGO TTGO VGA32](devices/vga32/README.md) board runs FabGL **AdvancedTerminal** as Otto's console — VGA monitor + PS/2 keyboard over UART (115200 8N1) via a level shifter. Program storage on Otto is planned via **CH376S** on serial port 2 (not implemented yet). The VGA32 microSD slot remains in firmware behind `OTTO_SD_ENABLED 0` for future local experiments only.

# Repository Contents

This repository houses the complete design files and software components for the Otto retro computer project, including PCB designs, firmware, and development tools.

## Hardware Resources

### PCB Design Files
* **easyeda/** - Complete board designs importable into EasyEDA
  * Circuit schematics
  * PCB layouts
  * Component libraries
* **gerber/** - Manufacturing-ready Gerber files for all PCBs

## Software Resources

### Core Components
* **simulation.dig** - Complete digital simulation of Otto
  * Compatible with [Digital by Helmut Neemann](https://github.com/hneemann/Digital)
  * Allows testing and verification of CPU behavior

### Development Tools
* **assembly/** - Instruction set architecture definitions
  * Compatible with [CustomASM](https://github.com/hlorenzi/customasm)
  * Defines Otto's complete instruction set
* **microcode.py** - Core microcode generation toolchain
* **7seg.py** - EEPROM content generator for 7-segment displays
* **generate-all.sh** - One-click build script for all components

### System Software
* **kernel/** - Operating system kernel source code
* **apps/** - Example applications and demos
* **pascal/** - Tiny Pascal system (part of the unified ROM build)
  * **pmachine.asm** - P-Machine bytecode interpreter
  * **editor.asm** - On-board line editor
  * **compiler.asm** - On-board single-pass Pascal compiler
  * **consts.asm** - Constants and RAM layout
  * **LANGUAGE.md** - Tiny Pascal language reference
  * **examples/** - Pascal example programs
* **pascal_compiler.py** - Tiny Pascal cross-compiler (Python, produces P-code binaries)
* **forth/** - FORTH language interpreter (deprecated, files retained but excluded from build)
* **devices/vga32/** - VGA32 AdvancedTerminal firmware and build scripts
* **roms/** - Binary files
  * **system/** - Microcode EEPROMs, unified kernel ROM (kernel + P-Machine + editor + compiler)
  * **apps/asm/** - Assembly app binaries (compiled from `apps/*.asm`)
  * **apps/pascal/** - Pascal app binaries (compiled from `pascal/examples/*.pas`)

### Documentation
* **instruction.csv** - Complete assembly instruction reference
  * Instruction formats
  * Operation descriptions
  * Addressing modes

## Getting Started

1. To build all components, run:
```bash
./generate-all.sh
```

2. For hardware manufacturing:
   * Import EasyEDA files for circuit and PCB design review
   * Use Gerber files for PCB fabrication

3. For software development:
   * Refer to the instruction set documentation
   * Use the example applications as reference
   * Build and upload applications

4. For Tiny Pascal development:
   ```bash
   # Cross-compile on host PC
   python pascal_compiler.py pascal/examples/hello.pas -o roms/apps/pascal/hello.bin
   python simulate.py --autorun --program roms/apps/pascal/hello.bin --max-cycles 1000000 --quiet

   # Or use the on-board editor (kernel menu: 'e')
   python simulate.py   # then type 'e' to enter editor
   ```

## Otto simulator

Otto Simulator is a Python application that emulates Otto's hardware architecture. The simulator uses the same kernel and implements the identical instruction set as the physical device.

**Terminal options:**

| Mode | Command |
|------|---------|
| Local stdin/stdout | `python simulate.py` |
| Virtual serial (minicom) | `python simulate.py --simulate-serial` |
| **VGA32 AdvancedTerminal** (recommended) | `python simulate.py --serial-device /dev/cu.usbserial-XXXX` |

With `--serial-device`, the emulated ACIA is mapped to a USB serial adapter connected to the VGA32 Otto UART. The kernel menu, VT100 output, and PS/2 keyboard on the VGA board behave like a real Otto session. Flash firmware with `devices/vga32/build.sh upload` and read `devices/vga32/README.md` for wiring and F12/F11 settings.

**Mac-as-Otto (no CPU board):** the same flag lets you develop against a real VGA32 while the kernel runs only in the simulator — useful before the level shifter and Otto serial are wired.

```bash
source .venv/bin/activate

# Interactive kernel on the VGA display
python simulate.py --serial-device /dev/cu.usbserial-XXXX

# Load a program; use 'r' + Enter on the VGA keyboard to run it
python simulate.py --serial-device /dev/cu.usbserial-XXXX \
  --program roms/apps/asm/helloworld.bin

# Autorun: send 'r'+CR on the serial line and exit when the app returns
python simulate.py --serial-device /dev/cu.usbserial-XXXX \
  --autorun --program roms/apps/asm/helloworld.bin --max-cycles 1000000
```

Use `ls /dev/cu.*` to find your adapter. `--serial-device` and `--simulate-serial` are mutually exclusive. Baud rate defaults to 115200 (`--serial-baud` to override).

The simulator can also load a binary and watch the file for changes (interactive local mode):

```bash
python simulate.py --program roms/apps/asm/_test_.bin
```

### Headless mode

The simulator supports a headless mode for automated testing and CI/CD pipelines. In this mode, no interactive terminal is required: the kernel boots, automatically executes the loaded program, and exits when the program completes (either via `RTS` or `HLT`).

```bash
python ./simulate.py --autorun --program roms/apps/asm/helloworld.bin --max-cycles 1000000 --quiet
```

Available flags:
* `--headless` - Run without TTY (no stdin, no termios)
* `--autorun` - Automatically execute the loaded program after kernel boot (implies `--headless`)
* `--max-cycles N` - Safety limit on CPU cycles to prevent infinite loops (0 = unlimited)
* `--quiet` - Suppress kernel output, show only application output
* `--dump-regs <file>` - Save CPU registers, flags, cycle count, and stop reason to JSON on exit
* `--input '...'` - Pre-load keyboard/serial input after boot (use `\r` for CR)
* `--serial-device <path>` - Real serial port for ACIA I/O (VGA32 Otto UART)
* `--serial-baud N` - Baud rate for `--serial-device` (default: 115200)
* `--simulate-serial` - Virtual serial port pair for minicom

Exit codes: `0` = success, `1` = timeout, `2` = execution error.

<img src="media/otto-kernel.png" width="600">

## Tiny Pascal

Otto includes a complete Tiny Pascal system: a P-Machine bytecode interpreter, a Python cross-compiler, and an on-board editor/compiler — all part of the unified 24 KB ROM build (kernel + P-Machine + editor + compiler share the same address space).

### Components

* **P-Machine** — a stack-based bytecode interpreter that executes P-code with support for 16-bit signed integers, 32-bit IEEE 754 floating point (`real` type), procedures, functions, recursion, arrays, `var` parameters, constants, and lexical scoping via static links.
* **Cross-compiler** (`pascal_compiler.py`) — a Python tool that compiles Pascal source files into self-executing P-code binaries. The output can be loaded at 0x8400 and run with either the `r` (run) or `p` (Pascal) kernel commands.
* **On-board editor/compiler** — a line editor and single-pass recursive descent compiler in native assembly, accessible via the kernel `e` command. Allows writing and running Pascal programs directly on Otto hardware without a host PC.

### Language Features

Two data types (`integer`: 16-bit signed, `real`: 32-bit IEEE 754 float with automatic coercion), named constants, arrays (`array[lo..hi] of integer`), procedures and functions with parameters (by value and by reference via `var`), recursion, nested scopes with lexical scoping, `if/then/else`, `while/do`, `for/to/downto`, `repeat/until`, `begin..end`, `write`/`writeln`/`readln` (polymorphic: string, integer, real, char), boolean and arithmetic operators, built-in functions (`abs`, `odd`, `chr`, `ord`).

See `pascal/LANGUAGE.md` for the full language reference.

### Cross-compilation (host PC)

```bash
python pascal_compiler.py pascal/examples/hello.pas -o roms/apps/pascal/hello.bin
python simulate.py --autorun --program roms/apps/pascal/hello.bin --max-cycles 1000000 --quiet
```

### On-board editor (on Otto or in simulator)

From the kernel menu, type `e` to enter the Pascal editor. Use `lo` to paste a program, `r` to compile and run:

```
> e
Pascal v0.2
H=help

> lo
Paste, end w/empty:
program Factorial;
var n: integer;
function fact(x: integer): integer;
begin
  if x <= 1 then fact := 1
  else fact := x * fact(x - 1)
end;
begin
  for n := 1 to 7 do
    writeln(fact(n))
end.

  11 ok
> r
Compiling..OK(90B)
1
2
6
24
120
720
5040
```

### Examples

| File | Description |
|------|-------------|
| `hello.pas` | Hello World |
| `calc.pas` | Variables and arithmetic |
| `fizzbuzz.pas` | Control flow: for, if/else, mod |
| `functions.pas` | Recursive factorial |
| `bubblesort.pas` | Bubble sort with arrays |
| `constants.pas` | Named constants and const expressions |
| `chars.pas` | Character output with chr/ord |
| `varparams.pas` | Var (by-reference) parameters |
| `float_simple.pas` | Basic real arithmetic |
| `float_test.pas` | Real type: arithmetic, comparisons, coercion |
| `float_func.pas` | Functions with real parameters and return values |
| `float_mix.pas` | Mixed integer/real expressions |
| `float_two.pas` | Two real variables |
| `simple_func.pas` | Simple function call |
| `debug_func.pas` | Function call debugging |

> **Note**: The FORTH interpreter (`forth/`) has been deprecated and is no longer included in the build process or kernel menu. Its source files are retained in the repository for reference.

## Control words ROM generation
```sh
python microcode.py
```

## ROM generation

The three ROM chips (24 KB total) are built as a single compilation unit via `generate-all.sh`. The kernel, P-Machine, editor, and compiler share the same address space (0x0000-0x5FFF) and are compiled together.

```sh
source .venv/bin/activate && ./generate-all.sh
```

You need an EEPROM programmer for kernel and microcode.
I use [TommyPROM](https://github.com/TomNisbet/TommyPROM), an Arduino-based EEPROM programmer.

## Requirements

### Rust & customasm installation
```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

cargo install customasm
```

### Python library IntelHex
```sh
pip install intelhex
```

### Python libraries required by the simulator
```sh
pip install pyserial
pip install watchdog
```

# Serial communication

**Console:** day-to-day development uses the VGA32 AdvancedTerminal (`devices/vga32/`). A second USB serial adapter (FTDI) on the VGA32 Otto UART is used for simulator `--serial-device`, or connects Otto CPU ↔ VGA32 once the level shifter is installed.

For direct Otto CPU upload and minicom (kernel ROM workflow, XMODEM):

```sh
ls /dev/cu*
minicom --device  /dev/cu.usbserial-2110
minicom --device /dev/cu.usbserial-A50285BI  -c on
```

# Credits

* porting of the ["XMODEM/CRC Receiver for the 65C02" by Daryl Rictor & Ross Archer](https://codebase64.org/doku.php?id=base:xmodem-receive)
* the great ["virtual serial port" Python library by Ezra Morris](https://github.com/ezramorris/PyVirtualSerialPorts)  

# License

Project Otto is released under the [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) license.
You are free to share and adapt but you can not use the material for commercial purposes.
The manufacturing and sale of assembly kits, PCBs, or complete devices based on or derived from this repository is strictly prohibited. This includes, but is not limited to, direct copies, modifications, and derivative works intended for commercial purposes.
For more information please refer to the LICENSE file.