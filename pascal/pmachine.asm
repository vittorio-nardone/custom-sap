#bankdef rom3
{
    #addr 0x4000
    #size 0x2000
    #outp 0
}
#bank rom3

#const PMACHINE_VERSION = "v0.1.2"
#const PMACHINE_BUILDDATE = "03/24/2026"

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"
#include "consts.asm"

; =========================================================
; P-Machine Interpreter for Project Otto
; Executes P-code bytecode produced by the Pascal compiler.
;
; Entry: JSR to 0x4000 (PMACHINE_START)
;   D = MSB of P-code header address
;   E = LSB of P-code header address
; Exit:  Returns via RTS. All registers restored.
; =========================================================

PM_ENTRY:
    ; Save pcode base before clobbering D:E
    std PM_BASE_MSB
    ste PM_BASE_LSB

    pha
    phd
    phe
    phx
    phy

    ldd .welcome_msg[15:8]
    lde .welcome_msg[7:0]
    jsr ACIA_SEND_STRING

    ; --- Validate P-code header at PM_BASE -----------------
    ldd PM_BASE_MSB
    lde PM_BASE_LSB
    ldx 0x00

    lda de,x                ; offset 0x00: magic 'P'
    cmp PM_MAGIC_P
    bne .error_invalid

    inx
    lda de,x                ; offset 0x01: magic 'M'
    cmp PM_MAGIC_M
    bne .error_invalid

    ; skip version byte at offset 0x02
    inx
    inx

    lda de,x                ; offset 0x03: code_offset low
    sta PM_TEMP
    inx
    lda de,x                ; offset 0x04: code_offset high

    ; IP = PM_BASE + code_offset  (16-bit addition)
    pha                      ; save code_offset_hi
    lda PM_TEMP              ; code_offset_lo
    clc
    adc PM_BASE_LSB          ; + base LSB
    sta PM_IP_LSB
    pla                      ; code_offset_hi
    adc PM_BASE_MSB          ; + base MSB + carry
    sta PM_IP_MSB

    ; init eval stack
    lda 0x00
    sta PM_ESP

    jmp .fetch

; --- Fetch-decode-execute loop ----------------------------

.fetch:
    jsr .fetch_byte

    cmp PM_OP_HALT
    beq .op_halt
    cmp PM_OP_LIT
    beq .op_lit
    cmp PM_OP_LIT16
    beq .op_lit16
    cmp PM_OP_CSP
    beq .op_csp

    jmp .error_invalid

; --- HALT -------------------------------------------------

.op_halt:
    ldd .done_msg[15:8]
    lde .done_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .exit

; --- LIT: push 8-bit literal -----------------------------

.op_lit:
    jsr .fetch_byte
    jsr .push_byte
    jmp .fetch

; --- LIT16: push 16-bit literal (little-endian) ----------

.op_lit16:
    jsr .fetch_byte
    jsr .push_byte
    jsr .fetch_byte
    jsr .push_byte
    jmp .fetch

; --- CSP: call standard procedure ------------------------

.op_csp:
    jsr .fetch_byte

    cmp PM_CSP_WRITE
    beq .csp_write
    cmp PM_CSP_WRITELN
    beq .csp_writeln
    cmp PM_CSP_WRITELN_NOARG
    beq .csp_writeln_noarg

    jmp .error_invalid

; CSP 0 — write(string): print string without newline
.csp_write:
    jsr .pop_byte
    pha
    jsr .pop_byte
    tae
    pla
    tad
    jsr ACIA_SEND_STRING
    jmp .fetch

; CSP 1 — writeln(string): print string then CR/LF
.csp_writeln:
    jsr .pop_byte
    pha
    jsr .pop_byte
    tae
    pla
    tad
    jsr ACIA_SEND_STRING
    jsr ACIA_SEND_NEWLINE
    jmp .fetch

; CSP 2 — writeln(): just CR/LF
.csp_writeln_noarg:
    jsr ACIA_SEND_NEWLINE
    jmp .fetch

; --- Exit & error -----------------------------------------

.exit:
    ply
    plx
    ple
    pld
    pla
    rts

.error_invalid:
    ldd .error_msg[15:8]
    lde .error_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .exit

; =========================================================
; Internal helpers
; =========================================================

; Fetch one byte from P-code at IP, advance IP.
; Out: A = fetched byte.  Clobbers D, E, X.
.fetch_byte:
    ldd PM_IP_MSB
    lde PM_IP_LSB
    ldx 0x00
    lda de,x
    ine
    bne .fetch_byte_nc
    ind
.fetch_byte_nc:
    std PM_IP_MSB
    ste PM_IP_LSB
    rts

; Push A onto the eval stack.  Clobbers D, E, X.
.push_byte:
    pha
    ldd PM_EVAL_STACK[15:8]
    lde PM_EVAL_STACK[7:0]
    ldx PM_ESP
    pla
    sta de,x
    inc PM_ESP
    rts

; Pop one byte from the eval stack into A.  Clobbers D, E, X.
.pop_byte:
    dec PM_ESP
    ldd PM_EVAL_STACK[15:8]
    lde PM_EVAL_STACK[7:0]
    ldx PM_ESP
    lda de,x
    rts

; =========================================================
; Strings
; =========================================================

.welcome_msg:
    #d 0x0A, 0x0D
    #d "P-Machine ", PMACHINE_VERSION, 0x0A, 0x0D, 0x00

.done_msg:
    #d "P-Machine: execution complete.", 0x0A, 0x0D, 0x00

.error_msg:
    #d 0x0A, 0x0D
    #d "P-Machine: invalid P-code.", 0x0A, 0x0D, 0x00
