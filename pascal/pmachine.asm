#bankdef rom3
{
    #addr 0x4000
    #size 0x2000
    #outp 0
}
#bank rom3

#const PMACHINE_VERSION = "v0.4.18"
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

    ; init eval stack and call frame state
    lda 0x00
    sta PM_ESP
    sta PM_FP_MSB
    sta PM_FP_LSB
    sta PM_CSP_PTR
    sta PM_FTOP_MSB
    sta PM_FTOP_LSB

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
    cmp PM_OP_JMP
    beq .op_jmp
    cmp PM_OP_JPC
    beq .op_jpc
    cmp PM_OP_EQ
    beq .op_eq
    cmp PM_OP_NE
    beq .op_ne
    cmp PM_OP_LT
    beq .op_lt
    cmp PM_OP_CSP
    beq .op_csp
    cmp PM_OP_GE
    beq .op_ge
    cmp PM_OP_GT
    beq .op_gt
    cmp PM_OP_LE
    beq .op_le
    cmp PM_OP_AND
    beq .op_and
    cmp PM_OP_OR
    beq .op_or
    cmp PM_OP_NOT
    beq .op_not
    cmp PM_OP_CALL
    beq .op_call
    cmp PM_OP_ENTER
    beq .op_enter
    cmp PM_OP_RET
    beq .op_ret
    cmp PM_OP_LOAD_L
    beq .op_load_l
    cmp PM_OP_STORE_L
    beq .op_store_l

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

; --- LOAD offset: push 16-bit variable (FP-relative) -----

.op_load:
    jsr .fetch_byte         ; A = byte offset (relative to FP)

    clc
    adc PM_FP_LSB
    tae                     ; E = offset + FP_LSB (VAR_FRAME LSB=0x00)
    lda PM_FP_MSB
    adc 0x00                ; carry from LSB add
    clc
    adc PM_VAR_FRAME[15:8]  ; + base MSB
    tad
    ldx 0x00
    lda de,x                ; var LSB
    sta PM_TEMP
    inx
    lda de,x                ; var MSB
    pha
    lda PM_TEMP
    jsr .push_byte          ; push LSB
    pla
    jsr .push_byte          ; push MSB
    jmp .fetch

; --- STORE offset: pop 16-bit, store (FP-relative) -------

.op_store:
    jsr .fetch_byte         ; A = byte offset
    sta PM_TEMP
    jsr .pop_byte           ; MSB
    pha
    jsr .pop_byte           ; LSB
    pha
    lda PM_TEMP
    clc
    adc PM_FP_LSB
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
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

; --- JMP: unconditional jump ------------------------------

.op_jmp:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
.set_ip_from_offset:
    lda PM_TEMP
    clc
    adc PM_BASE_LSB
    sta PM_IP_LSB
    lda PM_TEMP2
    adc PM_BASE_MSB
    sta PM_IP_MSB
    jmp .fetch

; --- JPC: jump if false (top == 0) -----------------------

.op_jpc:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pop_byte
    pha
    jsr .pop_byte
    sta MATH16_A
    pla
    ora MATH16_A
    beq .set_ip_from_offset
    jmp .fetch

; --- EQ: pop b, pop a, push (a = b) ---------------------

.op_eq:
    jsr .pop_two_operands
    jsr CMP16S
    lda MATH16_TMP
    beq .push_true
    jmp .push_false

; --- NE: pop b, pop a, push (a <> b) --------------------

.op_ne:
    jsr .pop_two_operands
    jsr CMP16S
    lda MATH16_TMP
    bne .push_true
    jmp .push_false

; --- LT: pop b, pop a, push (a < b) signed --------------

.op_lt:
    jsr .pop_two_operands
    jsr CMP16S
    lda MATH16_TMP
    bmi .push_true
    jmp .push_false

; --- GE: pop b, pop a, push (a >= b) signed -------------

.op_ge:
    jsr .pop_two_operands
    jsr CMP16S
    lda MATH16_TMP
    bpl .push_true
    jmp .push_false

; --- GT: pop b, pop a, push (a > b) signed --------------

.op_gt:
    jsr .pop_two_operands
    jsr CMP16S
    lda MATH16_TMP
    cmp 0x01
    beq .push_true
    jmp .push_false

; --- LE: pop b, pop a, push (a <= b) signed -------------

.op_le:
    jsr .pop_two_operands
    jsr CMP16S
    lda MATH16_TMP
    cmp 0x01
    beq .push_false
    jmp .push_true

; --- AND: pop b, pop a, push (a and b) logical ----------

.op_and:
    jsr .pop_byte
    pha
    jsr .pop_byte
    sta MATH16_B
    pla
    ora MATH16_B
    sta MATH16_B
    jsr .pop_byte
    pha
    jsr .pop_byte
    sta MATH16_A
    pla
    ora MATH16_A
    beq .push_false
    lda MATH16_B
    beq .push_false
    jmp .push_true

; --- OR: pop b, pop a, push (a or b) logical ------------

.op_or:
    jsr .pop_byte
    pha
    jsr .pop_byte
    sta MATH16_B
    pla
    ora MATH16_B
    sta MATH16_B
    jsr .pop_byte
    pha
    jsr .pop_byte
    sta MATH16_A
    pla
    ora MATH16_A
    ora MATH16_B
    bne .push_true
    jmp .push_false

; --- NOT: pop a, push (not a) logical -------------------

.op_not:
    jsr .pop_byte
    pha
    jsr .pop_byte
    sta MATH16_A
    pla
    ora MATH16_A
    beq .push_true
    jmp .push_false

; --- CALL: call procedure/function -----------------------

.op_call:
    jsr .fetch_byte         ; addr_lo
    pha
    jsr .fetch_byte         ; addr_hi
    pha
    jsr .fetch_byte         ; static_depth
    tax

    jsr .follow_links       ; PM_TEMP3:PM_TEMP2 = static link value

    ; Save return info to call stack (IP_MSB, IP_LSB, FP_MSB, FP_LSB)
    ldd PM_CALL_STACK[15:8]
    lde PM_CALL_STACK[7:0]
    ldx PM_CSP_PTR
    lda PM_IP_MSB
    sta de,x
    inx
    lda PM_IP_LSB
    sta de,x
    inx
    lda PM_FP_MSB
    sta de,x
    inx
    lda PM_FP_LSB
    sta de,x
    inx
    stx PM_CSP_PTR

    ; New FP = FRAME_TOP
    lda PM_FTOP_MSB
    sta PM_FP_MSB
    lda PM_FTOP_LSB
    sta PM_FP_LSB

    ; Write static link at new frame base (FP+0, FP+1)
    lda PM_FP_LSB
    tae
    lda PM_FP_MSB
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda PM_TEMP2            ; static_link LSB
    sta de,x
    inx
    lda PM_TEMP3            ; static_link MSB
    sta de,x

    ; Jump: IP = PM_BASE + addr
    pla                     ; addr_hi
    sta PM_TEMP2
    pla                     ; addr_lo
    sta PM_TEMP
    jmp .set_ip_from_offset

; --- ENTER: set up activation record --------------------

.op_enter:
    jsr .fetch_byte         ; frame_size
    sta PM_TEMP3
    jsr .fetch_byte         ; nparams
    sta PM_TEMP
    jsr .fetch_byte         ; is_function

    beq .enter_proc_base

    ; Function: init return value at FP+2,+3 to zero
    lda PM_FP_LSB
    clc
    adc 0x02
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda 0x00
    sta de,x
    inx
    sta de,x

    lda 0x04                ; param_base = 4 (skip link + retval)
    jmp .enter_set_base

.enter_proc_base:
    lda 0x02                ; param_base = 2 (skip link only)

.enter_set_base:
    sta PM_TEMP2            ; PM_TEMP2 = param_base

    ldx PM_TEMP             ; X = nparams
    beq .enter_set_ftop

    ; Compute initial offset = param_base + (nparams-1)*2
    dex
    txa
    asl a                   ; (nparams-1)*2
    clc
    adc PM_TEMP2            ; + param_base
    sta PM_TEMP2            ; PM_TEMP2 = current store offset (highest param)
    ldx PM_TEMP             ; X = nparams counter

.enter_copy_loop:
    phx                     ; save counter before pop_byte clobbers X
    jsr .pop_byte
    sta MATH16_B+1          ; MSB
    jsr .pop_byte
    sta MATH16_B            ; LSB

    lda PM_TEMP2
    clc
    adc PM_FP_LSB
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda MATH16_B            ; LSB
    sta de,x
    inx
    lda MATH16_B+1          ; MSB
    sta de,x
    plx                     ; restore counter

    lda PM_TEMP2
    sec
    sbc 0x02
    sta PM_TEMP2            ; next param slot (lower offset)

    dex
    bne .enter_copy_loop

.enter_set_ftop:
    ; FRAME_TOP = FP + frame_size
    lda PM_FP_LSB
    clc
    adc PM_TEMP3
    sta PM_FTOP_LSB
    lda PM_FP_MSB
    adc 0x00
    sta PM_FTOP_MSB
    jmp .fetch

; --- RET: return from procedure/function -----------------

.op_ret:
    jsr .fetch_byte         ; is_function
    beq .ret_no_retval

    ; Push return value (at FP+2, FP+3) onto eval stack
    lda PM_FP_LSB
    clc
    adc 0x02
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x                ; retval LSB
    sta PM_TEMP
    inx
    lda de,x                ; retval MSB
    pha
    lda PM_TEMP
    jsr .push_byte
    pla
    jsr .push_byte

.ret_no_retval:
    ; FRAME_TOP = FP (deallocate frame)
    lda PM_FP_MSB
    sta PM_FTOP_MSB
    lda PM_FP_LSB
    sta PM_FTOP_LSB

    ; Pop (IP_MSB, IP_LSB, FP_MSB, FP_LSB) from call stack
    lda PM_CSP_PTR
    sec
    sbc 0x04
    sta PM_CSP_PTR
    tax

    ldd PM_CALL_STACK[15:8]
    lde PM_CALL_STACK[7:0]
    lda de,x                ; IP_MSB
    sta PM_IP_MSB
    inx
    lda de,x                ; IP_LSB
    sta PM_IP_LSB
    inx
    lda de,x                ; FP_MSB
    sta PM_FP_MSB
    inx
    lda de,x                ; FP_LSB
    sta PM_FP_LSB
    jmp .fetch

; --- LOAD_L: load variable via static chain --------------

.op_load_l:
    jsr .fetch_byte         ; level
    sta PM_TEMP
    jsr .fetch_byte         ; offset
    pha

    ldx PM_TEMP
    jsr .follow_links       ; PM_TEMP3:PM_TEMP2 = target FP

    pla                     ; A = offset
    clc
    adc PM_TEMP2
    tae
    lda PM_TEMP3
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad

    ldx 0x00
    lda de,x                ; var LSB
    sta PM_TEMP
    inx
    lda de,x                ; var MSB
    pha
    lda PM_TEMP
    jsr .push_byte
    pla
    jsr .push_byte
    jmp .fetch

; --- STORE_L: store variable via static chain ------------

.op_store_l:
    jsr .fetch_byte         ; level
    sta PM_TEMP
    jsr .fetch_byte         ; offset
    pha

    jsr .pop_byte
    sta MATH16_B+1          ; value MSB
    jsr .pop_byte
    sta MATH16_B            ; value LSB

    ldx PM_TEMP
    jsr .follow_links       ; PM_TEMP3:PM_TEMP2 = target FP

    pla                     ; A = offset
    clc
    adc PM_TEMP2
    tae
    lda PM_TEMP3
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad

    ldx 0x00
    lda MATH16_B            ; LSB
    sta de,x
    inx
    lda MATH16_B+1          ; MSB
    sta de,x
    jmp .fetch

; --- Shared helpers for comparisons ----------------------

.pop_two_operands:
    jsr .pop_byte
    sta MATH16_B+1
    jsr .pop_byte
    sta MATH16_B
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte
    sta MATH16_A
    rts

.push_true:
    lda 0x01
    jsr .push_byte
    lda 0x00
    jsr .push_byte
    jmp .fetch

.push_false:
    lda 0x00
    jsr .push_byte
    lda 0x00
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
    cmp PM_CSP_READLN_INT
    beq .csp_readln_int

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

; CSP 5 — readln(integer): read signed decimal, push on eval stack
.csp_readln_int:
    jsr ACIA_READ_DECIMAL16S
    lda MATH16_A
    jsr .push_byte
    lda MATH16_A+1
    jsr .push_byte
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

; Follow X static links starting from PM_FP.
; Out: PM_TEMP3 = target FP MSB, PM_TEMP2 = target FP LSB.
; Clobbers A, D, E, X (saved/restored internally).
.follow_links:
    lda PM_FP_MSB
    sta PM_TEMP3
    lda PM_FP_LSB
    sta PM_TEMP2
.follow_loop:
    cpx 0x00
    beq .follow_done
    dex
    phx
    ; Read static link at PM_VAR_FRAME + PM_TEMP3:PM_TEMP2
    lda PM_TEMP2
    tae
    lda PM_TEMP3
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x                ; static_link LSB
    pha
    inx
    lda de,x                ; static_link MSB
    sta PM_TEMP3
    pla
    sta PM_TEMP2
    plx
    jmp .follow_loop
.follow_done:
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
