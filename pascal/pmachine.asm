#bankdef rom3
{
    #addr 0x4000
    #size 0x2000
    #outp 0
}
#bank rom3

#const PMACHINE_VERSION = "v0.2.2"
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
    cmp PM_OP_LOAD
    beq .op_load
    cmp PM_OP_STORE
    beq .op_store
    cmp PM_OP_ADD
    beq .op_add
    cmp PM_OP_SUB
    beq .op_sub
    cmp PM_OP_MUL
    beq .op_mul
    cmp PM_OP_DIV
    beq .op_div
    cmp PM_OP_NEG
    beq .op_neg
    cmp PM_OP_MOD
    beq .op_mod
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

; --- LOAD offset: push 16-bit variable -------------------

.op_load:
    jsr .fetch_byte         ; A = byte offset into var frame
    tax
    ldd PM_VAR_FRAME[15:8]
    lde PM_VAR_FRAME[7:0]
    lda de,x                ; var LSB
    sta PM_TEMP             ; save LSB before push_byte clobbers D/E/X
    inx
    lda de,x                ; var MSB
    pha                     ; save MSB on hardware stack
    lda PM_TEMP
    jsr .push_byte          ; push LSB
    pla
    jsr .push_byte          ; push MSB
    jmp .fetch

; --- STORE offset: pop 16-bit, store to variable ---------

.op_store:
    jsr .fetch_byte         ; A = byte offset
    sta PM_TEMP
    jsr .pop_byte           ; MSB
    pha
    jsr .pop_byte           ; LSB
    pha
    ldd PM_VAR_FRAME[15:8]
    lde PM_VAR_FRAME[7:0]
    ldx PM_TEMP
    pla                     ; LSB
    sta de,x
    inx
    pla                     ; MSB
    sta de,x
    jmp .fetch

; --- ADD: pop b16, pop a16, push a+b --------------------
; Note: push_byte/pop_byte do NOT affect carry flag.

.op_add:
    jsr .pop_byte
    sta MATH16_B+1          ; b MSB
    jsr .pop_byte
    sta MATH16_B            ; b LSB
    jsr .pop_byte
    sta MATH16_A+1          ; a MSB
    jsr .pop_byte           ; A = a LSB
    clc
    adc MATH16_B
    jsr .push_byte          ; result LSB (carry preserved)
    lda MATH16_A+1
    adc MATH16_B+1
    jsr .push_byte          ; result MSB
    jmp .fetch

; --- SUB: pop b16, pop a16, push a-b --------------------

.op_sub:
    jsr .pop_byte
    sta MATH16_B+1
    jsr .pop_byte
    sta MATH16_B
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte           ; A = a LSB
    sec
    sbc MATH16_B
    jsr .push_byte          ; result LSB (carry/borrow preserved)
    lda MATH16_A+1
    sbc MATH16_B+1
    jsr .push_byte          ; result MSB
    jmp .fetch

; --- MUL: pop b16, pop a16, push a*b (signed 16-bit) ----

.op_mul:
    jsr .pop_byte
    sta MATH16_B+1
    jsr .pop_byte
    sta MATH16_B
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte
    sta MATH16_A
    jsr MUL16S
    lda MATH16_A
    jsr .push_byte
    lda MATH16_A+1
    jsr .push_byte
    jmp .fetch

; --- DIV: pop b16, pop a16, push a div b (signed) -------

.op_div:
    jsr .pop_byte
    sta MATH16_B+1
    jsr .pop_byte
    sta MATH16_B
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte
    sta MATH16_A
    jsr DIV16S
    lda MATH16_A
    jsr .push_byte
    lda MATH16_A+1
    jsr .push_byte
    jmp .fetch

; --- NEG: pop a16, push -a (two's complement) -----------

.op_neg:
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte
    sta MATH16_A
    jsr MATH16_NEGATE_A
    lda MATH16_A
    jsr .push_byte
    lda MATH16_A+1
    jsr .push_byte
    jmp .fetch

; --- MOD: pop b16, pop a16, push a mod b (signed) -------

.op_mod:
    jsr .pop_byte
    sta MATH16_B+1
    jsr .pop_byte
    sta MATH16_B
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte
    sta MATH16_A
    jsr MOD16S
    lda MATH16_A
    jsr .push_byte
    lda MATH16_A+1
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
    cmp PM_CSP_WRITE_INT
    beq .csp_write_int
    cmp PM_CSP_WRITELN_INT
    beq .csp_writeln_int

    jmp .error_invalid

; CSP 0 — write(string)
.csp_write:
    jsr .pop_byte
    pha
    jsr .pop_byte
    tae
    pla
    tad
    jsr ACIA_SEND_STRING
    jmp .fetch

; CSP 1 — writeln(string)
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

; CSP 2 — writeln() (no argument)
.csp_writeln_noarg:
    jsr ACIA_SEND_NEWLINE
    jmp .fetch

; CSP 3 — write(integer): print signed 16-bit decimal
.csp_write_int:
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte
    sta MATH16_A
    jsr ACIA_SEND_DECIMAL16S
    jmp .fetch

; CSP 4 — writeln(integer): print signed 16-bit decimal + newline
.csp_writeln_int:
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte
    sta MATH16_A
    jsr ACIA_SEND_DECIMAL16S
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
