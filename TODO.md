# TODO

This file is used to track possible enhancements.

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

## [assembly] INC/DEC for 16bit 
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
