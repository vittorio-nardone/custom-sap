# TODO

This file is used to track possible enhancements.

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
DEW      
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

## [hardware] PAL/NTSC video board
Add a video card to Otto!

## [hardware] Keyboard interface board
The keyboard interface board was tested quickly but is not working as expected.