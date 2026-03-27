# TODO

This file is used to track possible enhancements.

## [assembly] LDDE / STDE (ZP)
Load/Store both D and E registers from/to a ZP and ZP+1 addresses

```sh
ldd PM_IP_MSB      
lde PM_IP_LSB       
→ ldde PM_IP_MSB  
```

## [assembly] LDDE / STDE (immediate 16 bit)
Load DE registers from a single 16 bit value. Use # prefix to avoid conflicts with the LDDE zero page

```sh
LDDE #0xB100 
```

## [assembly] LDA DE+ / STA DE+ / LDA DE-,
Load A from DE (address) and increment DE
Load A from DE (address) and decrement DE
Store A to DE (address) and increment DE
Store A to DE (address) and decrement DE

## [assembly] ADE A
Increment DE pointer with A

```sh
E = E + A; if carry, D = D + 1.
```

## [assembly] ADD D, imm8
Increment D of a immediate 8 bit value

```sh
add d, 0xB2 
```

## [assembly] NEG A
Increment D of a immediate 8 bit value

```sh
EOR 0xFF; CLC; ADC 0x01
→ NEG A
```

## [DONE] [assembly] CMP 
Index address mode for CMP. Example:

```sh
CMP 0x0000,y 
```

## [DONE] [assembly] ADC /SBC
Index address mode for ADC/SBC. Replace ADD/SUB. Example:

```sh
ADC 0x0000,y 
```

## [assembly] INC/DEC 
Index address mode for INC and DEC. Example:

```sh
INC 0x0000,x 
```

## [assembly] INC/DEC for A
INC and DEC for A registry. One of the following syntax:

```sh
INC A  
INA      
```

## [assembly] INC/DEC for 16bit - not possible?
INC and DEC for a 16bit integer in memory. The u16/u24 value is the address of the LSB.

Example: INW meaning is "increment word" (unsigned 16bit integer)
```sh
INW 0x0112 
DEW 0x0112     
```

## [assembly] JEQ / JNE  
Jump on Result Zero to New Location Saving Return Address.
* JEQ as a combination of BEQ and JSR istructions
* JNE as a combination of BNE and JSR istructions

Support both absolute / zero-page address modes.
Evaluate the equivalent istruction for other conditions, like JCS (BCS + JSR)

Example:
```sh
LDA 0x8600
JEQ 0x8900  ; do something if A == 0 then RTS
...         
...
```

## [DONE] [assembly] INC/DEC/INX.. should set N flag
INC and DEC operations set Z flag only but should set N flag too (according to the 6502 datasheet)

## [hardware] PAL/NTSC video board
Add a video card to Otto!

## [hardware] Keyboard interface board
The keyboard interface board was tested quickly but is not working as expected.

## [hardware] Add Commodore IEC interface
Add a Commodore IEC interface to Otto and use it for storage on FDD/SD

## [hardware] CF Card interface
Add a permanent storage to Otto

## [hardware] Extended MARs
Add a 2x 24bit registers for complex memory address operation: 
- load value to the register (1 byte at time)
- save value of the register (1 byte at time)
- set zero page (MSB of the register = 0)
- inc/dec register
- enable register (address bus)
Example: implement LDA (ZP)+
- first register will load ZP (MSB -> PCP -> LSB)
- enable first register to load LSB in the second register
- inc first register 
- enable first register to load MSB in the second register
- enable second register to load data to A
- inc second register
- enable first register to save MSB of the second register in memory
- dec first register
- enable first register to save LSB of the second register in memory

Optimization? 

## [DONE] [pascal] Onboard editor / pascal compiler
Enable programming directly on Otto hardware without a host PC.

### Not implemented
- [ ] SAVE command (dump source to serial for backup)
- [ ] XMODEM file transfer for source code
