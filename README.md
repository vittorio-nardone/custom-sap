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
* **pascal/** - Tiny Pascal support (WIP)
  * **pmachine.asm** - P-Machine bytecode interpreter (ROM #3)
  * **consts.asm** - P-Machine constants and RAM layout
  * **examples/** - Pascal example programs
* **pascal_compiler.py** - Tiny Pascal cross-compiler (Python, produces P-code binaries)
* **forth/** - FORTH language interpreter (deprecated, files retained but excluded from build)
* **roms/** - Binary files
  * Microcode EEPROMs
  * Kernel image
  * P-Machine ROM
  * Example applications (loadable via kernel upload function)

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
   python pascal_compiler.py pascal/examples/hello.pas -o roms/hello.bin
   python simulate.py --autorun --program roms/hello.bin --max-cycles 1000000 --quiet
   ```

## Otto simulator

Otto Simulator is a Python application that emulates Otto's hardware architecture. The simulator uses the same kernel and implements the identical instruction set as the physical device.
To run the simulator, use the following command:
```bash
python ./simulate.py
```

The simulator can also communicate through a virtual serial port, allowing you to use terminal emulators like minicom - just as you would with the actual Otto hardware:
```bash
python ./simulate.py --simulate-serial
```

The simulator can also load a specific binary file in the memory and monitor it for updates.
```bash
python ./simulate.py --program roms/_test_.bin
```

### Headless mode

The simulator supports a headless mode for automated testing and CI/CD pipelines. In this mode, no interactive terminal is required: the kernel boots, automatically executes the loaded program, and exits when the program completes (either via `RTS` or `HLT`).

```bash
python ./simulate.py --autorun --program roms/helloworld.bin --max-cycles 1000000 --quiet
```

Available flags:
* `--headless` - Run without TTY (no stdin, no termios)
* `--autorun` - Automatically execute the loaded program after kernel boot (implies `--headless`)
* `--max-cycles N` - Safety limit on CPU cycles to prevent infinite loops
* `--quiet` - Suppress kernel output, show only application output
* `--dump-regs <file>` - Save CPU registers, flags, cycle count and stop reason to a JSON file on exit

Exit codes: `0` = program completed, `1` = timeout, `2` = execution error. Use `--dump-regs` to inspect the full CPU state (including `OUT` register value) after execution.

<img src="media/otto-kernel.png" width="600">

## Tiny Pascal (WIP)

Otto includes experimental support for a minimal Pascal language. The system consists of two components:

* **P-Machine** — a stack-based bytecode interpreter that resides in ROM #3 (0x4000-0x5FFF). It executes P-code produced by the compiler, using the kernel serial I/O API for output.
* **Cross-compiler** (`pascal_compiler.py`) — a Python tool that compiles Pascal source files into self-executing P-code binaries. The output can be loaded at 0x8400 and run with either the `r` (run) or `p` (Pascal) kernel commands.

Currently supported (Milestone 1): `program` structure, `writeln` / `write` with string literals.

```pascal
program HelloWorld;
begin
  writeln('Hello, World!');
end.
```

```bash
# Compile and run
python pascal_compiler.py pascal/examples/hello.pas -o roms/hello.bin
python simulate.py --autorun --program roms/hello.bin --max-cycles 1000000 --quiet
```

> **Note**: The FORTH interpreter (`forth/`) has been deprecated and is no longer included in the build process or kernel menu. Its source files are retained in the repository for reference.

## Control words ROM generation
```sh
python microcode.py
```

## ROM generation
```sh
customasm kernel.asm -f intelhex -o roms/kernel-rom.hex
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

I use minicom to communicate with Otto and upload files using XMODEM protocol.

```sh
ls /dev/cu*
minicom --device /dev/cu.usbserial-1433240 
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