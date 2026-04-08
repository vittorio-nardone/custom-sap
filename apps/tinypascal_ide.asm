; @load-address 0x020000
; =========================================================
; TinyPascal on-board editor + compiler (standalone app)
;
; Load to expansion RAM page 2 (0x020000) via XMODEM + OT header:
;   u020000  then send roms/apps/asm/tinypascal_ide.bin
; Run:
;   r020000
;
; Source lines: expansion page 1 (0x010000+). Compiler workspace: page 1 high
; (see pascal/consts.asm CC_SYM_BASE). P-code output at 0x8400 (PM_PCODE_BASE).
; =========================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef tinypascal_ide
{
    #addr 0x020000
    #size 0x10000
    #outp 0
}

#bank tinypascal_ide

; Editor/compiler constants come from kernel/symbols.asm (rebuild kernel before this app).
#include "../pascal/editor.asm"
