# TODO

This file is used to track possible enhancements.

## [assembly] INC/DEC 
Index address mode for INC and DEC. Example:

```sh
INC 0x0000,x 
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