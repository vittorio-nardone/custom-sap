# Project Otto - 8-bit Homebrew Computer

Project Otto is a custom 8-bit TTL homebrew computer with a 6502-inspired (but not identical) instruction set.
The CPU is built from 7400-series TTL ICs, not a commercial microprocessor.

## Build & Tools

- **Python venv**: `source .venv/bin/activate` (Python 3.11, required for simulator)
- **Assembler**: [CustomASM](https://github.com/hlorenzi/customasm) (`cargo install customasm`)
- **Build all**: `./generate-all.sh`
- **Compile single app**: `customasm apps/myapp.asm -f binary -o roms/myapp.bin`
- **Simulator (interactive)**: `python simulate.py --program roms/myapp.bin`
- **Simulator (headless/test)**: `python simulate.py --autorun --program roms/myapp.bin --max-cycles 1000000 --quiet`
- **Microcode generation**: `python microcode.py`

## Architecture

- 8-bit data bus, 24-bit address bus, 13-bit control bus
- 1 MHz clock (reducible to 250 KHz via `SCS` instruction, back to fast with `SCF`)
- ALU: 74181 + shift register

### Registers (all 8-bit)

| Register | Description |
|----------|-------------|
| **A** | Accumulator - primary arithmetic/logic register |
| **X** | Index register |
| **Y** | Index register |
| **D** | General purpose register (also used as MSB of DE pointer) |
| **E** | General purpose register (also used as LSB of DE pointer) |
| **OUT** | Output register (7-segment display) |
| **PC** | Program Counter (24-bit, internal) |
| **SP** | Stack Pointer (16-bit, initialized to 0xFFFF) |
| **INT** | Interrupt mask register (internal, accessed via TAI/TIA) |

### Flag Register

```
Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3 | Bit 2 | Bit 1 | Bit 0
  N   |   x   |   x   |   x   |   Z   |   C   |   x   |   x
```

- **N** (Negative): bit 7 of result
- **Z** (Zero): result is zero
- **C** (Carry): arithmetic carry/borrow
- **O** (Overflow): internal use for indexing, equals carry (NOT like 6502)

### DE Register Pair as Pointer

D (MSB) and E (LSB) form a 16-bit pointer for indirect addressing:
- `LDA DE,X` - load from address DE+X (zero page)
- `LDA YDE,X` - load from address Y:DE+X (absolute, Y=page)
- `STA DE,X` / `STA YDE,X` - store equivalents

## Memory Map

```
0x000000-0x001FFF  (8 KB)  ROM #1 (kernel bank 0)
  0x0000-0x00FE            Boot code
  0x00FF                   Interrupt handler entry point
  0x0200+                  Kernel routines

0x002000-0x003FFF  (8 KB)  ROM #2 (kernel bank 1)
0x004000-0x005FFF  (8 KB)  ROM #3 (FORTH)

0x006000-0x0067FF  (2 KB)  Device I/O
  0x6000-0x600F            Keyboard (read only)
  0x6010                   Random byte (low)
  0x6011                   Random byte (high)
  0x6012                   Random seed (write N times)
  0x6020                   ACIA #1 Control/Status Register
  0x6021                   ACIA #1 Transmit/Receive Data Register

0x006800-0x007FFF  (6 KB)  Video RAM (reserved)

0x008000-0x00FFFF  (32 KB) Main RAM
  0x8000-0x83FF  (1 KB)    Kernel reserved variables
    0x8000-0x800A          Main menu state
    0x8100-0x810F          Memory management
    0x8120-0x812F          VT100 variables
    0x8200-0x82FF          XMODEM buffer
    0x8337-0x833F          XMODEM variables
    0x8340-0x834D          Utility variables
    0x83F1                 ACIA RX buffer size
    0x83F2-0x83F3          ACIA RX push/pull indexes
    0x83F4-0x83F5          ACIA RX buffer pointer
    0x83F6-0x83F7          16-bit timer counter (MSB, LSB)
    0x83F8-0x83F9          INT1 handler pointer
    0x83FA-0x83FB          INT2 handler pointer (serial)
    0x83FC-0x83FD          TIMER handler pointer
    0x83FE-0x83FF          KEYBOARD handler pointer
  0x8400-0xEFFF  (27 KB)   Application RAM (apps load here)
  0xF000-0xFFFF  (4 KB)    Stack (grows downward from 0xFFFF)

0x010000-0x01FFFF (64 KB)  RAM Expansion Page 1
0x020000-0x02FFFF (64 KB)  RAM Expansion Page 2
```

## Addressing Modes

| Mode | Syntax | Bytes | Example |
|------|--------|-------|---------|
| Implied | `INX` | 1 | `INX` |
| Immediate | `LDA {u8}` | 2 | `LDA 0x07` |
| Zero page (16-bit addr) | `LDA {u16}` | 3 | `LDA 0x7503` |
| Absolute (24-bit addr) | `LDA {u24}` | 4 | `LDA 0x2234FA` |
| Zero page, X indexed | `LDA {u16},X` | 3 | `LDA 0x7503,X` |
| Zero page, Y indexed | `LDA {u16},Y` | 3 | `LDA 0x7503,Y` |
| Absolute, X indexed | `LDA {u24},X` | 4 | `LDA 0x2234FA,X` |
| Absolute, Y indexed | `LDA {u24},Y` | 4 | `LDA 0x2234FA,Y` |
| Indirect zero page | `LDA ({u16})` | 3 | `LDA (0x7503)` |
| Indirect ZP, X indexed | `LDA ({u16}),X` | 3 | `LDA (0x7503),X` |
| Indirect ZP, Y indexed | `LDA ({u16}),Y` | 3 | `LDA (0x7503),Y` |
| Register D | `ADC D` | 1 | `ADC D` |
| Register E | `ADC E` | 1 | `ADC E` |
| DE pointer, X indexed | `LDA DE,X` | 1 | `LDA DE,X` |
| YDE pointer, X indexed | `LDA YDE,X` | 1 | `LDA YDE,X` |
| Accumulator | `ASL A` | 1 | `ASL A` |

**Note**: "Zero page" in Otto means 16-bit addresses (0x0000-0xFFFF), "absolute" means 24-bit addresses.

## Complete Instruction Set

### Arithmetic

| Opcode | Mnemonic | Mode | Cycles | Flags | Description |
|--------|----------|------|--------|-------|-------------|
| 0x69 | ADC | immediate | 5 | Z N C | Add with carry |
| 0x6D | ADC | zero page | 8 | Z N C | Add with carry |
| 0x03 | ADC | absolute | 10 | Z N C | Add with carry |
| 0x04 | ADC | ZP,X | 11/12 | Z N C O | Add with carry |
| 0x86 | ADC | ZP,Y | 11/12 | Z N C O | Add with carry |
| 0x05 | ADC | abs,X | 13/14 | Z N C O | Add with carry |
| 0x87 | ADC | abs,Y | 13/14 | Z N C O | Add with carry |
| 0x6F | ADC | D reg | 5 | Z N C | Add D to A |
| 0x06 | ADC | E reg | 5 | Z N C | Add E to A |
| 0xE9 | SBC | immediate | 5 | Z N C | Subtract with borrow |
| 0xED | SBC | zero page | 8 | Z N C | Subtract with borrow |
| 0x5B | SBC | absolute | 10 | Z N C | Subtract with borrow |
| 0x5F | SBC | ZP,X | 11/12 | Z N C | Subtract with borrow |
| 0x88 | SBC | ZP,Y | 11/12 | Z N C | Subtract with borrow |
| 0x61 | SBC | abs,X | 13/14 | Z N C | Subtract with borrow |
| 0x89 | SBC | abs,Y | 13/14 | Z N C | Subtract with borrow |
| 0x5D | SBC | D reg | 5 | Z N C | Subtract D from A |
| 0x5E | SBC | E reg | 5 | Z N C | Subtract E from A |
| 0xEF | SBX | E reg | 5 | Z N C | Subtract E from X |

### Logic

| Opcode | Mnemonic | Mode | Cycles | Flags | Description |
|--------|----------|------|--------|-------|-------------|
| 0x29 | AND | immediate | 5 | Z N | AND with A |
| 0x07 | AND | zero page | 8 | Z N | AND with A |
| 0x08 | AND | absolute | 10 | Z N | AND with A |
| 0x09 | AND | D reg | 5 | Z N | AND D with A |
| 0x0A | AND | E reg | 5 | Z N | AND E with A |
| 0x0B | ORA | immediate | 5 | Z N | OR with A |
| 0x0C | ORA | zero page | 8 | Z N | OR with A |
| 0x0D | ORA | absolute | 10 | Z N | OR with A |
| 0x0E | ORA | D reg | 5 | Z N | OR D with A |
| 0x0F | ORA | E reg | 5 | Z N | OR E with A |
| 0x49 | EOR | immediate | 5 | Z N | XOR with A |
| 0x11 | EOR | zero page | 8 | Z N | XOR with A |
| 0x12 | EOR | absolute | 10 | Z N | XOR with A |
| 0x13 | EOR | D reg | 5 | Z N | XOR D with A |
| 0x14 | EOR | E reg | 5 | Z N | XOR E with A |

### Shift & Rotate

| Opcode | Mnemonic | Mode | Cycles | Flags | Description |
|--------|----------|------|--------|-------|-------------|
| 0xAF | ASL | accumulator | 6 | Z N C | Shift left |
| 0x1A | ASL | zero page | 9 | Z N C | Shift left |
| 0xA8 | LSR | accumulator | 8 | Z N C | Shift right |
| 0x1B | LSR | zero page | 12 | Z N C | Shift right |
| 0x2A | ROL | accumulator | 6 | Z N C | Rotate left through carry |
| 0x26 | ROL | zero page | 9 | Z N C | Rotate left |
| 0x54 | ROL | absolute | 11 | Z N C | Rotate left |
| 0x2C | ROL | D reg | 6 | Z N C | Rotate D left |
| 0x2B | ROL | E reg | 6 | Z N C | Rotate E left |
| 0x6A | ROR | accumulator | 8 | Z N C | Rotate right through carry |
| 0x66 | ROR | zero page | 12 | Z N C | Rotate right |
| 0x55 | ROR | absolute | 14 | Z N C | Rotate right |
| 0x6C | ROR | D reg | 8 | Z N C | Rotate D right |
| 0x6B | ROR | E reg | 8 | Z N C | Rotate E right |

### Load

| Opcode | Mnemonic | Mode | Cycles | Flags | Description |
|--------|----------|------|--------|-------|-------------|
| 0xA9 | LDA | immediate | 4 | Z N | Load A |
| 0xAD | LDA | zero page | 6 | Z N | Load A |
| 0xA7 | LDA | absolute | 8 | Z N | Load A |
| 0xBD | LDA | ZP,X | 9/10 | Z O N | Load A indexed |
| 0x31 | LDA | ZP,Y | 9/10 | Z O N | Load A indexed |
| 0xBE | LDA | abs,X | 11/12 | Z O N | Load A indexed |
| 0x32 | LDA | abs,Y | 11/12 | Z O N | Load A indexed |
| 0xB1 | LDA | (ZP) | 12/14 | Z N | Load A indirect |
| 0xBC | LDA | (ZP),X | 14/16 | Z N C | Load A indirect indexed |
| 0xC1 | LDA | (ZP),Y | 14/16 | Z N C | Load A indirect indexed |
| 0x94 | LDA | DE,X | 7/8 | Z O N | Load A via DE pointer+X |
| 0xB2 | LDA | YDE,X | 8/9 | Z O N | Load A via Y:DE pointer+X |
| 0xA5 | LDD | immediate | 4 | Z N | Load D |
| 0x33 | LDD | zero page | 6 | Z N | Load D |
| 0x34 | LDD | absolute | 8 | Z N | Load D |
| 0x1E | LDD | ZP,X | 9/10 | Z O N | Load D indexed |
| 0xA6 | LDE | immediate | 4 | Z N | Load E |
| 0x35 | LDE | zero page | 6 | Z N | Load E |
| 0x36 | LDE | absolute | 8 | Z N | Load E |
| 0x1F | LDE | ZP,X | 9/10 | Z O N | Load E indexed |
| 0xA2 | LDX | immediate | 4 | Z N | Load X |
| 0xA3 | LDX | zero page | 6 | Z N | Load X |
| 0xA4 | LDX | absolute | 8 | Z N | Load X |
| 0x1C | LDX | ZP,Y | 9/10 | Z O N | Load X indexed |
| 0xA0 | LDY | immediate | 4 | Z N | Load Y |
| 0x37 | LDY | zero page | 6 | Z N | Load Y |
| 0x39 | LDY | absolute | 8 | Z N | Load Y |
| 0x1D | LDY | ZP,X | 9/10 | Z O N | Load Y indexed |
| 0xFE | LDO | immediate | 4 | - | Load OUT register |
| 0xFD | LDO | zero page | 6 | - | Load OUT register |
| 0x41 | LDO | absolute | 8 | - | Load OUT register |

### Store

| Opcode | Mnemonic | Mode | Cycles | Flags | Description |
|--------|----------|------|--------|-------|-------------|
| 0x8D | STA | zero page | 6 | - | Store A |
| 0x8E | STA | absolute | 8 | - | Store A |
| 0x9D | STA | ZP,X | 9/10 | O | Store A indexed |
| 0x6E | STA | ZP,Y | 9/10 | O | Store A indexed |
| 0x62 | STA | abs,X | 11/12 | O | Store A indexed |
| 0x70 | STA | abs,Y | 11/12 | O | Store A indexed |
| 0xB8 | STA | (ZP) | 13/15 | - | Store A indirect |
| 0xBF | STA | (ZP),X | 15/17 | C | Store A indirect indexed |
| 0xC2 | STA | (ZP),Y | 15/17 | C | Store A indirect indexed |
| 0xA1 | STA | DE,X | 7/8 | O | Store A via DE pointer+X |
| 0xB3 | STA | YDE,X | 8/9 | O | Store A via Y:DE pointer+X |
| 0x7A | STD | zero page | 6 | - | Store D |
| 0x7B | STD | absolute | 8 | - | Store D |
| 0x7C | STD | ZP,X | 9/10 | O | Store D indexed |
| 0x7E | STD | ZP,Y | 9/10 | O | Store D indexed |
| 0x7D | STD | abs,X | 11/12 | O | Store D indexed |
| 0x7F | STD | abs,Y | 11/12 | O | Store D indexed |
| 0x80 | STE | zero page | 6 | - | Store E |
| 0x81 | STE | absolute | 8 | - | Store E |
| 0x82 | STE | ZP,X | 9/10 | O | Store E indexed |
| 0x84 | STE | ZP,Y | 9/10 | O | Store E indexed |
| 0x83 | STE | abs,X | 11/12 | O | Store E indexed |
| 0x85 | STE | abs,Y | 11/12 | O | Store E indexed |
| 0x71 | STX | zero page | 6 | - | Store X |
| 0x72 | STX | absolute | 8 | - | Store X |
| 0x73 | STX | ZP,Y | 9/10 | O | Store X indexed |
| 0x74 | STX | abs,Y | 11/12 | O | Store X indexed |
| 0x75 | STY | zero page | 6 | - | Store Y |
| 0x76 | STY | absolute | 8 | - | Store Y |
| 0x77 | STY | ZP,X | 9/10 | O | Store Y indexed |
| 0x79 | STY | abs,X | 11/12 | O | Store Y indexed |

### Compare

| Opcode | Mnemonic | Mode | Cycles | Flags | Description |
|--------|----------|------|--------|-------|-------------|
| 0xC9 | CMP | immediate | 5 | Z N C | Compare A |
| 0x5C | CMP | zero page | 8 | Z N C | Compare A |
| 0x42 | CMP | absolute | 10 | Z N C | Compare A |
| 0xB4 | CMP | ZP,X | 11/12 | Z N C O | Compare A indexed |
| 0xB5 | CMP | ZP,Y | 11/12 | Z N C O | Compare A indexed |
| 0xB6 | CMP | abs,X | 13/14 | Z N C O | Compare A indexed |
| 0xB7 | CMP | abs,Y | 13/14 | Z N C O | Compare A indexed |
| 0xB9 | CMP | (ZP) | 15/17 | Z N C | Compare A indirect |
| 0xC0 | CMP | (ZP),X | 16/18 | Z N C | Compare A indirect indexed |
| 0xC3 | CMP | (ZP),Y | 16/18 | Z N C | Compare A indirect indexed |
| 0xE5 | CPD | immediate | 5 | Z N C | Compare D |
| 0x43 | CPD | zero page | 8 | Z N C | Compare D |
| 0x44 | CPD | absolute | 10 | Z N C | Compare D |
| 0x51 | CPD | E reg | 5 | Z N C | Compare D with E |
| 0xE4 | CPE | immediate | 5 | Z N C | Compare E |
| 0x45 | CPE | zero page | 8 | Z N C | Compare E |
| 0x46 | CPE | absolute | 10 | Z N C | Compare E |
| 0xE0 | CPX | immediate | 5 | Z N C | Compare X |
| 0x47 | CPX | zero page | 8 | Z N C | Compare X |
| 0x4A | CPX | absolute | 10 | Z N C | Compare X |
| 0xEB | CPX | D reg | 5 | Z N C | Compare X with D |
| 0xE2 | CPX | E reg | 5 | Z N C | Compare X with E |
| 0xE1 | CPX | Y reg | 5 | Z N C | Compare X with Y |
| 0xE3 | CPY | immediate | 5 | Z N C | Compare Y |
| 0x4B | CPY | zero page | 8 | Z N C | Compare Y |
| 0x4E | CPY | absolute | 10 | Z N C | Compare Y |
| 0x4F | CPY | D reg | 5 | Z N C | Compare Y with D |
| 0x50 | CPY | E reg | 5 | Z N C | Compare Y with E |
| 0x15 | BIT | immediate | 5 | Z N | Test bits (AND without storing) |
| 0x16 | BIT | zero page | 8 | Z N | Test bits |
| 0x17 | BIT | absolute | 10 | Z N | Test bits |

### Increment / Decrement

| Opcode | Mnemonic | Mode | Cycles | Flags | Description |
|--------|----------|------|--------|-------|-------------|
| 0xEE | INC | zero page | 7 | Z N | Increment memory |
| 0x52 | INC | absolute | 9 | Z N | Increment memory |
| 0xCE | DEC | zero page | 7 | Z N | Decrement memory |
| 0x53 | DEC | absolute | 9 | Z N | Decrement memory |
| 0xE8 | INX | implied | 4 | Z N | Increment X |
| 0xC8 | INY | implied | 4 | Z N | Increment Y |
| 0x2E | IND | implied | 4 | Z N | Increment D |
| 0x2F | INE | implied | 4 | Z N | Increment E |
| 0xCA | DEX | implied | 4 | Z N | Decrement X |
| 0xCB | DEY | implied | 4 | Z N | Decrement Y |
| 0x28 | DED | implied | 4 | Z N | Decrement D |
| 0x2D | DEE | implied | 4 | Z N | Decrement E |
| 0xF1 | INW | zero page | 9/12 | C | Increment 16-bit word |
| 0xF2 | DEW | zero page | 12/9 | C | Decrement 16-bit word |

**INW/DEW**: Operate on a 16-bit value at the given address (LSB at addr, MSB at addr+1). Takes 5 bytes: opcode + addr(2) + addr+1(2).

### Branch

| Opcode | Mnemonic | Mode | Cycles (no/yes) | Description |
|--------|----------|------|------------------|-------------|
| 0xF0 | BEQ | zero page | 5/6 | Branch if zero (Z=1) |
| 0x23 | BEQ | absolute | 6/10 | Branch if zero |
| 0xD0 | BNE | zero page | 6/5 | Branch if not zero (Z=0) |
| 0x25 | BNE | absolute | 10/6 | Branch if not zero |
| 0xB0 | BCS | zero page | 5/6 | Branch if carry set (C=1) |
| 0x22 | BCS | absolute | 6/10 | Branch if carry set |
| 0x90 | BCC | zero page | 6/5 | Branch if carry clear (C=0) |
| 0x19 | BCC | absolute | 10/6 | Branch if carry clear |
| 0x30 | BMI | zero page | 5/6 | Branch if minus (N=1) |
| 0x24 | BMI | absolute | 6/10 | Branch if minus |
| 0x10 | BPL | zero page | 6/5 | Branch if plus (N=0) |
| 0x27 | BPL | absolute | 10/6 | Branch if plus |

**Note**: Branches are NOT relative like 6502. They take an absolute or zero-page target address.

### Jump & Subroutine

| Opcode | Mnemonic | Mode | Cycles | Description |
|--------|----------|------|--------|-------------|
| 0x4C | JMP | zero page | 6 | Jump |
| 0x4D | JMP | absolute | 10 | Jump |
| 0x8F | JMP | (ZP) | 10 | Jump indirect |
| 0x91 | JMP | (abs) | 18 | Jump indirect |
| 0x20 | JSR | zero page | 12 | Jump to subroutine |
| 0x21 | JSR | absolute | 16 | Jump to subroutine |
| 0x92 | JSR | (ZP) | 16 | Jump to subroutine indirect |
| 0x93 | JSR | (abs) | 24 | Jump to subroutine indirect |
| 0x60 | RTS | implied | 11 | Return from subroutine |
| 0x40 | RTI | implied | 9 | Return from interrupt |

### Register Transfer

| Opcode | Mnemonic | Cycles | Flags | Description |
|--------|----------|--------|-------|-------------|
| 0xAA | TAX | 3 | Z N | A -> X |
| 0xBB | TAY | 3 | Z N | A -> Y |
| 0x56 | TAD | 3 | Z N | A -> D |
| 0x57 | TAE | 3 | Z N | A -> E |
| 0xAB | TAO | 3 | Z N | A -> OUT |
| 0xAE | TAI | 3 | - | A -> Interrupt mask |
| 0x8A | TXA | 3 | Z N | X -> A |
| 0xBA | TYA | 3 | Z N | Y -> A |
| 0x59 | TDA | 3 | Z N | D -> A |
| 0x5A | TEA | 3 | Z N | E -> A |
| 0xAC | TIA | 3 | Z N | Interrupt mask -> A |
| 0x9B | TXD | 3 | Z N | X -> D |
| 0x9C | TDX | 3 | Z N | D -> X |
| 0x8B | TYE | 3 | Z N | Y -> E |
| 0x8C | TEY | 3 | Z N | E -> Y |

### Stack

| Opcode | Mnemonic | Cycles | Flags | Description |
|--------|----------|--------|-------|-------------|
| 0x48 | PHA | 4 | - | Push A |
| 0x95 | PHD | 4 | - | Push D |
| 0x96 | PHE | 4 | - | Push E |
| 0x97 | PHX | 4 | - | Push X |
| 0x98 | PHY | 4 | - | Push Y |
| 0x68 | PLA | 4 | Z N | Pull A |
| 0x99 | PLD | 4 | Z N | Pull D |
| 0x9A | PLE | 4 | Z N | Pull E |
| 0x9E | PLX | 4 | Z N | Pull X |
| 0x9F | PLY | 4 | Z N | Pull Y |

### Control

| Opcode | Mnemonic | Cycles | Flags | Description |
|--------|----------|--------|-------|-------------|
| 0xEA | NOP | 2 | - | No operation |
| 0x18 | CLC | 3 | C | Clear carry flag |
| 0x38 | SEC | 3 | C | Set carry flag |
| 0x58 | CLI | 3 | I | Clear interrupt disable |
| 0x78 | SEI | 3 | I | Set interrupt disable |
| 0x00 | BRK | 13 | I | Software interrupt |
| 0xFF | HLT | 3 | - | Halt CPU |
| 0x01 | SCS | 3 | - | Set slow clock (250 KHz) |
| 0x02 | SCF | 3 | - | Set fast clock (1 MHz) |
| 0xF7 | DMP | 2 | - | Dump registers (simulator only) |

## Key Differences from 6502

1. **Addresses are NOT relative for branches** - BEQ/BNE/etc take absolute or zero-page addresses, not relative offsets
2. **Zero page = 16-bit address** (0x0000-0xFFFF), absolute = 24-bit address
3. **Extra registers**: D and E are additional general-purpose registers not in 6502
4. **DE pointer mode**: D:E pair acts as a 16-bit pointer (`LDA DE,X`, `LDA YDE,X`)
5. **Overflow flag** is NOT like 6502 - used internally for indexing, equals carry
6. **No BCD mode**
7. **24-bit PC** allows addressing 16 MB
8. **JSR always uses 4-byte encoding** (opcode + 3 bytes for address padding)
9. **INW/DEW** instructions for 16-bit increment/decrement (not in 6502)
10. **ROL/ROR on D and E registers** directly
11. **SBX** instruction (subtract E from X)
12. **Inter-register compares**: CPX Y, CPX D, CPX E, CPD E, CPY D, CPY E

## Interrupt System

### Interrupt Mask Register (via TAI/TIA)

```
Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3  | Bit 2  | Bit 1  | Bit 0
  1   |   1   |   1   |   1   | KEYB   | TIMER  | EXT2   | EXT1
```

### Interrupt Sources
- **INT_EXTINT1** (0x01): External interrupt 1
- **INT_EXTINT2** (0x02): External interrupt 2 (serial)
- **INT_TIMER** (0x04): Timer interrupt (10 Hz)
- **INT_KEYBOARD** (0x08): Keyboard interrupt

### Setting Up an Interrupt Handler
```assembly
; Set handler pointer (16-bit address, MSB first)
LDA my_handler[15:8]
STA INT_TIMER_HANDLER_POINTER
LDA my_handler[7:0]
STA INT_TIMER_HANDLER_POINTER + 1

; Enable the interrupt
TIA                   ; Read current mask
ORA INT_TIMER         ; Enable timer bit
TAI                   ; Write back
CLI                   ; Enable interrupts globally
```

Handler pointers are stored at fixed addresses:
- `0x83F8-0x83F9` - INT1 handler
- `0x83FA-0x83FB` - INT2 handler (serial)
- `0x83FC-0x83FD` - TIMER handler
- `0x83FE-0x83FF` - KEYBOARD handler

## Kernel API (key functions)

Include `kernel/symbols.asm` to access these. Call with `JSR`.

### Serial I/O
| Symbol | Address | Description |
|--------|---------|-------------|
| ACIA_INIT | 0x0D11 | Initialize serial port |
| ACIA_SEND_CHAR | 0x0D61 | Send char in A |
| ACIA_SEND_STRING | 0x0D29 | Send null-terminated string (D=MSB, E=LSB of pointer) |
| ACIA_SEND_HEX | 0x0D69 | Send A as hex string |
| ACIA_SEND_DECIMAL | 0x0D7D | Send A as decimal string |
| ACIA_SEND_DECIMAL32 | 0x0DF7 | Send 32-bit value as decimal |
| ACIA_SEND_NEWLINE | 0x0D97 | Send CR+LF |
| ACIA_READ_CHAR | 0x0DAA | Blocking read, result in A |
| ACIA_READ_TO_BUFFER | 0x0DB6 | Interrupt-driven buffered read |
| ACIA_PULL_FROM_BUFFER | 0x0DDB | Pull char from RX buffer |

### VT100 Terminal
| Symbol | Address | Description |
|--------|---------|-------------|
| VT100_ERASE_SCREEN | 0x11A0 | Clear screen |
| VT100_CURSOR_HOME | 0x11AE | Cursor to top-left |
| VT100_CURSOR_POSITION | 0x11BB | Set cursor position (D=row, E=col) |
| VT100_TEXT_RESET | 0x1244 | Reset text formatting |
| VT100_TEXT_BOLD | 0x1252 | Bold text |
| VT100_FG_RED | 0x1299 | Red foreground |
| VT100_FG_GREEN | 0x12A8 | Green foreground |
| VT100_BG_RED | 0x1311 | Red background |
| (see symbols.asm for full list) | | |

### Utilities
| Symbol | Address | Description |
|--------|---------|-------------|
| BINHEX | 0x0C60 | Binary to hex string conversion |
| HEXBIN | 0x0C7F | Hex string to binary conversion |
| BINDEC | 0x0CA3 | Binary to decimal string |
| BINDEC32 | 0x0CE3 | 32-bit binary to decimal |
| DIVIDE_INT | 0x0AD0 | Integer division |
| MULTIPLY_INT | 0x0AF9 | Integer multiplication |

### Memory Management
| Symbol | Address | Description |
|--------|---------|-------------|
| MEMORY_INIT_DEFAULT | 0x0B84 | Init memory manager (default) |
| MEMORY_INIT | 0x0B9F | Init memory manager |
| MEMORY_ALLOCATE | 0x0BBA | Allocate memory block |
| MEMORY_DEALLOCATE | 0x0C17 | Free memory block |

### File Transfer
| Symbol | Address | Description |
|--------|---------|-------------|
| XMODEM_RCV | 0x0E16 | Receive file via XMODEM/CRC |

## Application Template

```assembly
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    ; --- Your code starts here ---
    ; Entry point is the first instruction after #bank ram
    ; App is loaded at 0x8400

    ; Example: print a message
    ldd .msg[15:8]          ; D = high byte of string address
    lde .msg[7:0]           ; E = low byte of string address
    jsr ACIA_SEND_STRING    ; Send null-terminated string

    rts                     ; Return to kernel

.msg:
    #d "Hello, Otto!", 0x0A, 0x0D, 0x00
```

### Key Conventions
- Apps load at **0x8400** and have up to **27 KB** (0x6C00 bytes)
- End with `RTS` to return to kernel
- Strings are null-terminated (0x00)
- Newline is `0x0A, 0x0D` (LF, CR)
- Use `label[15:8]` for high byte and `label[7:0]` for low byte of 16-bit addresses
- Local labels start with `.` (e.g., `.loop`, `.msg`)
- DE register pair is the standard way to pass 16-bit pointers (D=MSB, E=LSB)
- Data directives: `#d` for bytes/strings
- Compile: `customasm apps/myapp.asm -f binary -o roms/myapp.bin`
- Upload to hardware via XMODEM protocol (kernel menu) or load in simulator

### Arithmetic Notes
- **ADC/SBC** work with carry flag, like 6502. Use `CLC` before `ADC`, `SEC` before `SBC`
- Compare instructions set flags: Z=1 if equal, C=1 if register >= operand, N=1 if result negative
- Stack at 0xF000-0xFFFF, grows downward. Save/restore registers with PHA/PLA etc.

## Simulator (simulate.py)

The project includes a full Python CPU simulator (`simulate.py`) that emulates Otto's hardware. It uses the same kernel ROM and instruction set as the physical device.

### Python Environment

Requires Python 3.10+ (uses `match/case`). A venv is configured at `.venv/`:

```bash
source .venv/bin/activate   # Always activate before running simulator
```

### Running the Simulator

```bash
# Basic mode: kernel boots, I/O via stdin/stdout
python simulate.py

# Load a program binary at default address (0x8400)
python simulate.py --program roms/myapp.bin

# Load at a specific address
python simulate.py --program roms/myapp.bin --address 0x8400

# Virtual serial port mode (use minicom or other terminal emulator)
python simulate.py --simulate-serial
```

### Headless Mode (for automated testing)

The simulator supports a headless mode for batch/CI usage and automated testing by Claude:

```bash
# Autorun: kernel boots, auto-executes program at 0x8400, no TTY needed
python simulate.py --autorun --program roms/myapp.bin --max-cycles 1000000

# With --quiet: suppress kernel output, show only application output
python simulate.py --autorun --program roms/myapp.bin --max-cycles 1000000 --quiet
```

**Flags**:
- `--headless`: disables TTY (`termios`/`tty.setcbreak`), no stdin reading. Output still goes to stdout.
- `--autorun`: implies `--headless`. Pre-loads `r` + CR in the keyboard buffer so the kernel automatically executes the program at the default address (0x8400) after boot.
- `--max-cycles N`: safety limit on CPU cycles. When reached, the simulator exits. Prevents infinite loops. Set to 0 for unlimited (default).
- `--quiet`: suppresses serial output from kernel code. Only shows output produced while the application is running (including kernel API calls like `ACIA_SEND_STRING` made by the app).

**App execution tracking**: in `--autorun` mode, the simulator automatically detects when the program starts (PC enters app space after the autorun input is consumed) and when it returns (PC back in kernel with SP restored above the JSR level). This means:
- Programs ending with `RTS` exit cleanly (no timeout needed)
- Programs ending with `HLT` also exit cleanly
- `--max-cycles` is only a safety net for infinite loops

**Exit codes** (headless mode):
- `0`: program completed successfully (via RTS or HLT)
- `1`: max-cycles reached (timeout / infinite loop)
- `2`: execution error (invalid opcode, bad memory access)

**Register dump** (`--dump-regs <file>`): saves all CPU registers, flags, cycle count, and stop reason to a JSON file on exit. Use this to verify program results in CI/CD pipelines:

```bash
python simulate.py --autorun --program roms/myapp.bin --max-cycles 1000000 --quiet --dump-regs /tmp/regs.json
```

Output JSON contains: `A`, `X`, `Y`, `D`, `E`, `OUT`, `PC`, `SP`, `flags` (Z/N/C/I/O), `cycles`, `stop_reason` ("completed", "halted", "timeout", "error").

**Workflow for compiling and testing assembly programs**:

```bash
source .venv/bin/activate

# 1. Compile
customasm apps/myapp.asm -f binary -o roms/myapp.bin

# 2. Run in simulator and check output
python simulate.py --autorun --program roms/myapp.bin --max-cycles 1000000 --quiet

# 3. Check exit code
echo $?   # 0 = success
```

Programs can end with either `RTS` (return to kernel, simulator detects and exits) or `HLT` (halt CPU directly). Both work seamlessly in autorun mode.

### Simulator Architecture

The simulator (`OttoCPU` class in `simulate.py`) faithfully emulates:

- **All CPU registers**: A, D, E, X, Y, OUT, PC (24-bit), SP (16-bit), INT, IR
- **All flags**: Z, N, C, I, O, HLT
- **Full 24-bit address space**: 192 KB (`bytearray(0x030000)`)
- **Memory regions** with read-only enforcement for ROM
- **Instruction execution** via `exec()` on microcode-defined simulation strings from `microcode.py`
- **Cycle counting**: tracks total cycles, distinguishing branch taken/not-taken

### Memory Regions in Simulator

| Region | Start | End | Read-only | I/O |
|--------|-------|-----|-----------|-----|
| rom | 0x0000 | 0x3FFF | Yes | No |
| forth | 0x4000 | 0x5FFF | Yes | No |
| ram | 0x8000 | 0xFFFF | No | No |
| ram_ext_1 | 0x010000 | 0x01FFFF | No | No |
| ram_ext_2 | 0x020000 | 0x02FFFF | No | No |
| acia_1 | 0x6020 | 0x6021 | No | Yes |

### I/O Simulation

**Serial (ACIA)**:
- **0x6020** (read): returns status - `0x03` if data available, `0x02` if empty
- **0x6021** (read): returns next byte from serial port or keyboard queue
- **0x6021** (write): sends byte to serial port, or prints to stdout if no serial

**Two modes**:
1. **stdin/stdout** (default): keyboard input is queued via `push_key()`, serial output goes to `print()`. Enter key (0x0A) is converted to CR (0x0D).
2. **Virtual serial port** (`--simulate-serial`): creates virtual serial ports via `PyVirtualSerialPorts`. Connect with `minicom --device <port>` at 115200 baud.

### Hot-Reload of Program Binaries

When `--program` is used, the simulator watches the binary file for changes using `watchdog`. If the file is recompiled, it is automatically reloaded into memory at the specified address, allowing rapid edit-compile-test cycles without restarting the simulator.

### Interactive Development Workflow

For interactive development with hot-reload:

```bash
source .venv/bin/activate

# Terminal 1: Start simulator with the program
python simulate.py --program roms/myapp.bin

# Terminal 2: Edit and recompile (auto-reloaded by simulator)
customasm apps/myapp.asm -f binary -o roms/myapp.bin
```

The simulator runs the kernel first (boots from ROM at 0x0000), which initializes the system. In the kernel menu, type `r` + Enter to execute the loaded program. The program runs until `RTS` (returns to kernel) or `HLT` (halts CPU, exits simulator).

### Simulator Exit

- `HLT` instruction sets `cpu.HLT = True`, stopping the main loop
- On exit, prints `OUT` register value: `System halted. OUT registry: 0x{value}`
- The `OUT` register can be used as a return code: `LDO 0xAA` sets OUT to 0xAA before halting
- Any execution error prints the faulting opcode

### DMP Instruction (Simulator-Only)

The `DMP` (0xF7) instruction is a debug aid that dumps register state to the simulator console. It has no effect on real hardware. Use it for debugging:

```assembly
DMP         ; Print all register values to simulator console
```

### Dependencies

All dependencies are installed in `.venv/` (Python 3.11):

```bash
pip install pyserial     # Serial port support
pip install watchdog     # File change monitoring for hot-reload
pip install intelhex     # Intel HEX file format support
# PyVirtualSerialPorts is included in the project (virtualserialports module)
```

### Key Implementation Details

- Instructions are loaded from `microcode.py`'s `INSTRUCTIONS_SET` dictionary
- Each instruction has a `sim` field (Python code string executed via `exec()`) and cycle counts
- The simulator calls `verifyInstructionSet()` at startup to validate opcodes
- Unimplemented instructions produce a warning at startup
- ROM is loaded from `roms/kernel-rom.bin` and `roms/forth.bin` at boot
- Stack operations: `push()` writes at SP then decrements, `pop()` increments SP then reads

## Project Structure

```
.venv/                   - Python 3.11 virtual environment
assembly/ruledef.asm     - Instruction set definitions for CustomASM
kernel/
  kernel.asm             - Main kernel (v1.2.50)
  banks.asm              - ROM/RAM bank definitions
  symbols.asm            - Exported kernel symbols/constants
  interrupt.asm          - Interrupt handling
  serial.asm             - ACIA serial I/O
  vt100.asm              - VT100 terminal escape sequences
  memory.asm             - Block memory allocator
  math.asm               - Multiplication, division, sqrt
  utils.asm              - Hex/decimal conversions
  xmodem.asm             - XMODEM/CRC file transfer
  tests.asm              - CPU instruction tests
  float.asm              - Floating point (WIP)
apps/                    - Example applications
forth/                   - FORTH language interpreter
roms/                    - Compiled binaries
microcode.py             - Microcode ROM generator
simulate.py              - CPU simulator
istructions.csv          - Instruction reference (CSV)
```
