#once
#bank kernel

#const PMACHINE_VERSION = "v0.4.39"
#const PMACHINE_BUILDDATE = "04/06/2026"

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

; --- Fetch-decode-execute loop (jump table dispatch) ------

.fetch:
    jsr .fetch_byte
    cmp 0x3F
    bcs .error_invalid
    tax
    lda .dispatch_hi,x
    sta PM_DISPATCH
    lda .dispatch_lo,x
    sta PM_DISPATCH + 1
    jmp (PM_DISPATCH)

; --- Dispatch tables (opcode → handler address) -----------

.dispatch_lo:
    ; 0x00 HALT    0x01 LIT     0x02 LIT16   0x03 LOAD
    #d .op_halt[7:0], .op_lit[7:0], .op_lit16[7:0], .op_load[7:0]
    ; 0x04 STORE   0x05 ADD     0x06 SUB     0x07 MUL
    #d .op_store[7:0], .op_add[7:0], .op_sub[7:0], .op_mul[7:0]
    ; 0x08 DIV     0x09 NEG     0x0A MOD     0x0B JMP
    #d .op_div[7:0], .op_neg[7:0], .op_mod[7:0], .op_jmp[7:0]
    ; 0x0C JPC     0x0D EQ      0x0E NE      0x0F LT
    #d .op_jpc[7:0], .op_eq[7:0], .op_ne[7:0], .op_lt[7:0]
    ; 0x10 CSP     0x11 GE      0x12 GT      0x13 LE
    #d .op_csp[7:0], .op_ge[7:0], .op_gt[7:0], .op_le[7:0]
    ; 0x14 AND     0x15 OR      0x16 NOT     0x17 CALL
    #d .op_and[7:0], .op_or[7:0], .op_not[7:0], .op_call[7:0]
    ; 0x18 ENTER   0x19 RET     0x1A LOAD_L  0x1B STORE_L
    #d .op_enter[7:0], .op_ret[7:0], .op_load_l[7:0], .op_store_l[7:0]
    ; 0x1C LOAD_A  0x1D STORE_A 0x1E LOAD_AL 0x1F STORE_AL
    #d .op_load_a[7:0], .op_store_a[7:0], .op_load_al[7:0], .op_store_al[7:0]
    ; 0x20 ABS     0x21 LOAD_REF 0x22 STORE_REF 0x23 PUSH_ADDR
    #d .op_abs[7:0], .op_load_ref[7:0], .op_store_ref[7:0], .op_push_addr[7:0]
    ; 0x24 PUSH_ADDR_L  0x25 ENTER16  0x26 LOADW  0x27 STOREW
    #d .op_push_addr_l[7:0]
    #d .op_enter16[7:0]
    #d .op_loadw[7:0], .op_storew[7:0]
    ; 0x28-0x2F: exactly 8 slots (was 11 — shifted FLIT.. so float literals failed)
    #d .error_invalid[7:0], .error_invalid[7:0], .error_invalid[7:0]
    #d .error_invalid[7:0], .error_invalid[7:0], .error_invalid[7:0]
    #d .error_invalid[7:0], .error_invalid[7:0]
    ; 0x30 FLIT    0x31 FLOAD   0x32 FSTORE  0x33 FADD
    #d .op_flit[7:0], .op_fload[7:0], .op_fstore[7:0], .op_fadd[7:0]
    ; 0x34 FSUB    0x35 FMUL    0x36 FDIV    0x37 FNEG
    #d .op_fsub[7:0], .op_fmul[7:0], .op_fdiv[7:0], .op_fneg[7:0]
    ; 0x38 ITOF    0x39 FTOI    0x3A FCMP    0x3B FLOAD_L
    #d .op_itof[7:0], .op_ftoi[7:0], .op_fcmp[7:0], .op_fload_l[7:0]
    ; 0x3C FSTORE_L 0x3D FABS   0x3E ITOF_SWAP
    #d .op_fstore_l[7:0], .op_fabs[7:0], .op_itof_swap[7:0]

.dispatch_hi:
    ; 0x00-0x03
    #d .op_halt[15:8], .op_lit[15:8], .op_lit16[15:8], .op_load[15:8]
    ; 0x04-0x07
    #d .op_store[15:8], .op_add[15:8], .op_sub[15:8], .op_mul[15:8]
    ; 0x08-0x0B
    #d .op_div[15:8], .op_neg[15:8], .op_mod[15:8], .op_jmp[15:8]
    ; 0x0C-0x0F
    #d .op_jpc[15:8], .op_eq[15:8], .op_ne[15:8], .op_lt[15:8]
    ; 0x10-0x13
    #d .op_csp[15:8], .op_ge[15:8], .op_gt[15:8], .op_le[15:8]
    ; 0x14-0x17
    #d .op_and[15:8], .op_or[15:8], .op_not[15:8], .op_call[15:8]
    ; 0x18-0x1B
    #d .op_enter[15:8], .op_ret[15:8], .op_load_l[15:8], .op_store_l[15:8]
    ; 0x1C-0x1F
    #d .op_load_a[15:8], .op_store_a[15:8], .op_load_al[15:8], .op_store_al[15:8]
    ; 0x20-0x24
    #d .op_abs[15:8], .op_load_ref[15:8], .op_store_ref[15:8], .op_push_addr[15:8]
    #d .op_push_addr_l[15:8]
    ; 0x25 ENTER16
    #d .op_enter16[15:8]
    ; 0x26-0x27 LOADW, STOREW
    #d .op_loadw[15:8], .op_storew[15:8]
    ; 0x28-0x2F: exactly 8 slots (match .dispatch_lo)
    #d .error_invalid[15:8], .error_invalid[15:8], .error_invalid[15:8]
    #d .error_invalid[15:8], .error_invalid[15:8], .error_invalid[15:8]
    #d .error_invalid[15:8], .error_invalid[15:8]
    ; 0x30-0x33
    #d .op_flit[15:8], .op_fload[15:8], .op_fstore[15:8], .op_fadd[15:8]
    ; 0x34-0x37
    #d .op_fsub[15:8], .op_fmul[15:8], .op_fdiv[15:8], .op_fneg[15:8]
    ; 0x38-0x3B
    #d .op_itof[15:8], .op_ftoi[15:8], .op_fcmp[15:8], .op_fload_l[15:8]
    ; 0x3C-0x3E
    #d .op_fstore_l[15:8], .op_fabs[15:8], .op_itof_swap[15:8]

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

; --- LOADW: push 16-bit variable at FP + offset16 (LE) ---

.op_loadw:
    jsr .fetch_byte
    sta PM_TEMP             ; off lo
    jsr .fetch_byte
    sta PM_TEMP2            ; off hi
    lda PM_FP_LSB
    clc
    adc PM_TEMP
    tae
    lda PM_FP_MSB
    adc PM_TEMP2
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x
    sta PM_TEMP
    inx
    lda de,x
    pha
    lda PM_TEMP
    jsr .push_byte
    pla
    jsr .push_byte
    jmp .fetch

; --- STOREW: pop 16-bit into variable at FP + offset16 (LE)

.op_storew:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pop_byte
    pha
    jsr .pop_byte
    pha
    lda PM_TEMP
    clc
    adc PM_FP_LSB
    tae
    lda PM_TEMP2
    adc PM_FP_MSB
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    pla
    sta de,x
    inx
    pla
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
;     frame_size in MATH16_A (8- or 16-bit); OP_ENTER zero-extends.

.op_enter:
    jsr .fetch_byte
    sta MATH16_A
    lda 0x00
    sta MATH16_A+1
    jmp .enter_body

; --- ENTER16: large frame (frame_size 16-bit LE) --------

.op_enter16:
    jsr .fetch_byte
    sta MATH16_A
    jsr .fetch_byte
    sta MATH16_A+1

.enter_body:
    jsr .fetch_byte         ; nparams
    sta PM_TEMP
    jsr .fetch_byte         ; is_function (0=proc, 1=int func, 2=real func)
    tax
    beq .enter_proc_base
    cpx 0x02
    beq .enter_real_func

    ; Integer function: init return value at FP+2,+3 to zero
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

    lda 0x04                ; param_base = 4 (skip link + 2B retval)
    jmp .enter_set_base

.enter_real_func:
    ; Real function: init return value at FP+2..+5 to zero
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
    inx
    sta de,x
    inx
    sta de,x

    lda 0x06                ; param_base = 6 (skip link + 4B retval)
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
    ; FRAME_TOP = FP + frame_size (16-bit)
    lda PM_FP_LSB
    clc
    adc MATH16_A
    sta PM_FTOP_LSB
    lda PM_FP_MSB
    adc MATH16_A+1
    sta PM_FTOP_MSB
    jmp .fetch

; --- RET: return from procedure/function -----------------

.op_ret:
    jsr .fetch_byte         ; is_function (0=proc, 1=int func, 2=real func)
    tax
    beq .ret_no_retval
    cpx 0x02
    beq .ret_real_func

    ; Integer function: push 2-byte return value from FP+2
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
    jmp .ret_no_retval

.ret_real_func:
    ; Real function: push 4-byte return value from FP+2
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
    lda de,x
    sta FLOAT1
    inx
    lda de,x
    sta FLOAT1+1
    inx
    lda de,x
    sta FLOAT1+2
    inx
    lda de,x
    sta FLOAT1+3
    jsr .push_float1

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

; --- LOAD_A: load array element (FP-relative) -----------
; Operand: adjusted_base (1 byte)
; Stack in: index (16-bit)
; Stack out: value (16-bit)

.op_load_a:
    jsr .fetch_byte         ; A = adjusted_base
    sta PM_TEMP

    jsr .pop_byte           ; index MSB (discard)
    jsr .pop_byte           ; index LSB
    asl a                   ; index * 2
    clc
    adc PM_TEMP             ; + adjusted_base

    clc
    adc PM_FP_LSB
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x                ; element LSB
    sta PM_TEMP
    inx
    lda de,x                ; element MSB
    pha
    lda PM_TEMP
    jsr .push_byte
    pla
    jsr .push_byte
    jmp .fetch

; --- STORE_A: store array element (FP-relative) ---------
; Operand: adjusted_base (1 byte)
; Stack in: index (16-bit), value (16-bit)  [index pushed first]

.op_store_a:
    jsr .fetch_byte         ; A = adjusted_base
    sta PM_TEMP

    jsr .pop_byte           ; value MSB
    sta MATH16_B+1
    jsr .pop_byte           ; value LSB
    sta MATH16_B
    jsr .pop_byte           ; index MSB (discard)
    jsr .pop_byte           ; index LSB
    asl a                   ; index * 2
    clc
    adc PM_TEMP             ; + adjusted_base

    clc
    adc PM_FP_LSB
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda MATH16_B            ; value LSB
    sta de,x
    inx
    lda MATH16_B+1          ; value MSB
    sta de,x
    jmp .fetch

; --- LOAD_AL: load array element via static chain -------
; Operands: depth (1 byte), adjusted_base (1 byte)
; Stack in: index (16-bit)
; Stack out: value (16-bit)

.op_load_al:
    jsr .fetch_byte         ; depth
    tax
    jsr .fetch_byte         ; adjusted_base
    sta PM_TEMP

    jsr .pop_byte           ; index MSB (discard)
    jsr .pop_byte           ; index LSB
    asl a                   ; index * 2
    clc
    adc PM_TEMP             ; + adjusted_base
    sta PM_TEMP             ; final byte offset

    jsr .follow_links       ; PM_TEMP3:PM_TEMP2 = target FP

    lda PM_TEMP
    clc
    adc PM_TEMP2
    tae
    lda PM_TEMP3
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad

    ldx 0x00
    lda de,x                ; element LSB
    sta PM_TEMP
    inx
    lda de,x                ; element MSB
    pha
    lda PM_TEMP
    jsr .push_byte
    pla
    jsr .push_byte
    jmp .fetch

; --- STORE_AL: store array element via static chain -----
; Operands: depth (1 byte), adjusted_base (1 byte)
; Stack in: index (16-bit), value (16-bit)  [index pushed first]

.op_store_al:
    jsr .fetch_byte         ; depth
    tax
    jsr .fetch_byte         ; adjusted_base
    sta PM_TEMP

    jsr .pop_byte           ; value MSB
    sta MATH16_B+1
    jsr .pop_byte           ; value LSB
    sta MATH16_B
    jsr .pop_byte           ; index MSB (discard)
    jsr .pop_byte           ; index LSB
    asl a                   ; index * 2
    clc
    adc PM_TEMP             ; + adjusted_base
    sta PM_TEMP             ; final byte offset

    jsr .follow_links       ; PM_TEMP3:PM_TEMP2 = target FP

    lda PM_TEMP
    clc
    adc PM_TEMP2
    tae
    lda PM_TEMP3
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad

    ldx 0x00
    lda MATH16_B            ; value LSB
    sta de,x
    inx
    lda MATH16_B+1          ; value MSB
    sta de,x
    jmp .fetch

; --- ABS: absolute value of signed 16-bit ----------------

.op_abs:
    jsr .pop_byte            ; MSB
    sta PM_TEMP
    jsr .pop_byte            ; LSB
    sta PM_TEMP2
    lda PM_TEMP
    and 0x80
    beq .op_abs_pos
    ; Negative: negate (two's complement)
    lda PM_TEMP2
    eor 0xFF
    clc
    adc 0x01
    sta PM_TEMP2
    lda PM_TEMP
    eor 0xFF
    adc 0x00
    sta PM_TEMP
.op_abs_pos:
    lda PM_TEMP2
    jsr .push_byte
    lda PM_TEMP
    jsr .push_byte
    jmp .fetch

; --- LOAD_REF: load via reference (indirect through frame) -

.op_load_ref:
    jsr .fetch_byte          ; offset of the pointer in frame
    clc
    adc PM_FP_LSB
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x                 ; pointer LSB
    sta PM_TEMP
    inx
    lda de,x                 ; pointer MSB
    sta PM_TEMP2
    ; Now load 16-bit value at PM_VAR_FRAME + pointer
    lda PM_TEMP
    tae
    lda PM_TEMP2
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x                 ; value LSB
    pha
    inx
    lda de,x                 ; value MSB
    sta PM_TEMP
    pla
    jsr .push_byte
    lda PM_TEMP
    jsr .push_byte
    jmp .fetch

; --- STORE_REF: store via reference -----------------------

.op_store_ref:
    jsr .fetch_byte          ; offset of the pointer in frame
    sta PM_TEMP3
    jsr .pop_byte            ; value MSB
    pha
    jsr .pop_byte            ; value LSB
    pha
    ; Read pointer from frame
    lda PM_TEMP3
    clc
    adc PM_FP_LSB
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x                 ; pointer LSB
    sta PM_TEMP
    inx
    lda de,x                 ; pointer MSB
    sta PM_TEMP2
    ; Write value at PM_VAR_FRAME + pointer
    lda PM_TEMP
    tae
    lda PM_TEMP2
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    pla                      ; value LSB
    sta de,x
    inx
    pla                      ; value MSB
    sta de,x
    jmp .fetch

; --- PUSH_ADDR: push FP+offset as address ----------------

.op_push_addr:
    jsr .fetch_byte          ; offset
    clc
    adc PM_FP_LSB
    jsr .push_byte           ; addr LSB
    lda PM_FP_MSB
    adc 0x00
    jsr .push_byte           ; addr MSB
    jmp .fetch

; --- PUSH_ADDR_L: push target_FP+offset via static chain --

.op_push_addr_l:
    jsr .fetch_byte          ; depth
    tax
    jsr .fetch_byte          ; offset
    sta PM_TEMP
    jsr .follow_links        ; PM_TEMP3:PM_TEMP2 = target FP
    lda PM_TEMP
    clc
    adc PM_TEMP2
    jsr .push_byte           ; addr LSB
    lda PM_TEMP3
    adc 0x00
    jsr .push_byte           ; addr MSB
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
    cmp PM_CSP_WRITE_CHAR
    beq .csp_write_char
    cmp PM_CSP_WRITE_REAL
    beq .csp_write_real
    cmp PM_CSP_WRITELN_REAL
    beq .csp_writeln_real
    cmp PM_CSP_READLN_REAL
    beq .csp_readln_real
    cmp PM_CSP_RANDOM
    beq .csp_random
    cmp PM_CSP_PEEK
    beq .csp_peek
    cmp PM_CSP_POKE
    beq .csp_poke
    cmp PM_CSP_VT100
    beq .csp_vt100
    cmp PM_CSP_WAIT_MS
    beq .csp_wait_ms
    cmp PM_CSP_READLN_STR
    beq .csp_readln_str
    cmp PM_CSP_WRITE_STR
    beq .csp_write_str
    cmp PM_CSP_WRITELN_STR
    beq .csp_writeln_str
    cmp PM_CSP_STR_EQ
    beq .csp_str_eq
    cmp PM_CSP_STR_ASSIGN_LIT
    beq .csp_str_assign_lit
    cmp PM_CSP_STR_COPY
    beq .csp_str_copy
    cmp PM_CSP_LENGTH
    beq .csp_length

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

; CSP 6 — write(char): pop 16-bit, print low byte as character
.csp_write_char:
    jsr .pop_byte            ; MSB (discard)
    jsr .pop_byte            ; LSB = char
    jsr ACIA_SEND_CHAR
    jmp .fetch

; CSP 7 — write(real): pop float(4B), print with 2 decimal places
.csp_write_real:
    jsr .pop_byte
    sta FLOAT1+3
    jsr .pop_byte
    sta FLOAT1+2
    jsr .pop_byte
    sta FLOAT1+1
    jsr .pop_byte
    sta FLOAT1
    ldy 0x02
    jsr FLOAT_PRINT
    jmp .fetch

; CSP 8 — writeln(real): pop float(4B), print + newline
.csp_writeln_real:
    jsr .pop_byte
    sta FLOAT1+3
    jsr .pop_byte
    sta FLOAT1+2
    jsr .pop_byte
    sta FLOAT1+1
    jsr .pop_byte
    sta FLOAT1
    ldy 0x02
    jsr FLOAT_PRINT
    jsr ACIA_SEND_NEWLINE
    jmp .fetch

; CSP 9 — readln(real): read float from serial, push float(4B)
.csp_readln_real:
    jsr FLOAT_READ
    lda FLOAT1
    jsr .push_byte
    lda FLOAT1+1
    jsr .push_byte
    lda FLOAT1+2
    jsr .push_byte
    lda FLOAT1+3
    jsr .push_byte
    jmp .fetch

; CSP 10 — random: push random integer (0..32767)
.csp_random:
    jsr RANDOM_BYTE
    jsr .push_byte
    jsr RANDOM_BYTE
    and 0x7F
    jsr .push_byte
    jmp .fetch

; CSP 11 — peek(page, addr): pop addr(16), pop page(16), read byte via Y:DE
.csp_peek:
    jsr .pop_byte            ; addr MSB
    sta PM_TEMP
    jsr .pop_byte            ; addr LSB
    pha                      ; save addr LSB on Otto stack
    jsr .pop_byte            ; page MSB (discard)
    jsr .pop_byte            ; page LSB
    tay
    pla                      ; addr LSB
    tae
    lda PM_TEMP
    tad
    ldx 0x00
    lda yde,x
    jsr .push_byte           ; value LSB
    lda 0x00
    jsr .push_byte           ; value MSB (always 0)
    jmp .fetch

; CSP 12 — poke(page, addr, value): pop val(16), pop addr(16), pop page(16)
.csp_poke:
    jsr .pop_byte            ; value MSB (discard)
    jsr .pop_byte            ; value LSB
    sta PM_TEMP
    jsr .pop_byte            ; addr MSB
    sta PM_TEMP2
    jsr .pop_byte            ; addr LSB
    pha                      ; save addr LSB on Otto stack
    jsr .pop_byte            ; page MSB (discard)
    jsr .pop_byte            ; page LSB
    tay
    pla                      ; addr LSB
    tae
    lda PM_TEMP2
    tad
    ldx 0x00
    lda PM_TEMP
    sta yde,x
    jmp .fetch

; DE = PM_VAR_FRAME + FP + 16-bit offset in PM_TEMP (lo), PM_TEMP2 (hi)
.pm_fp_addr16:
    lda PM_FP_LSB
    clc
    adc PM_TEMP
    tae
    lda PM_FP_MSB
    adc PM_TEMP2
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    rts

; --- CSP: VT100 (subcode byte follows CSP) ----------------

.csp_vt100:
    jsr .fetch_byte
    cmp 0x02
    beq .vt100_cursor_pos
    cmp 0x20
    beq .vt100_scroll_region
    cmp 0x00
    beq .vt100_jsr_erase
    cmp 0x01
    beq .vt100_jsr_home
    cmp 0x03
    beq .vt100_jsr_up
    cmp 0x04
    beq .vt100_jsr_down
    cmp 0x05
    beq .vt100_jsr_right
    cmp 0x06
    beq .vt100_jsr_left
    cmp 0x07
    beq .vt100_jsr_cle
    cmp 0x08
    beq .vt100_jsr_cls
    cmp 0x09
    beq .vt100_jsr_cel
    cmp 0x0A
    beq .vt100_jsr_tr
    cmp 0x0B
    beq .vt100_jsr_tb
    cmp 0x0C
    beq .vt100_jsr_tu
    cmp 0x0D
    beq .vt100_jsr_tblk
    cmp 0x0E
    beq .vt100_jsr_trev
    cmp 0x0F
    beq .vt100_jsr_fg_black
    cmp 0x10
    beq .vt100_jsr_fg_red
    cmp 0x11
    beq .vt100_jsr_fg_green
    cmp 0x12
    beq .vt100_jsr_fg_yellow
    cmp 0x13
    beq .vt100_jsr_fg_blue
    cmp 0x14
    beq .vt100_jsr_fg_magenta
    cmp 0x15
    beq .vt100_jsr_fg_cyan
    cmp 0x16
    beq .vt100_jsr_fg_white
    cmp 0x17
    beq .vt100_jsr_bg_black
    cmp 0x18
    beq .vt100_jsr_bg_red
    cmp 0x19
    beq .vt100_jsr_bg_green
    cmp 0x1A
    beq .vt100_jsr_bg_yellow
    cmp 0x1B
    beq .vt100_jsr_bg_blue
    cmp 0x1C
    beq .vt100_jsr_bg_magenta
    cmp 0x1D
    beq .vt100_jsr_bg_cyan
    cmp 0x1E
    beq .vt100_jsr_bg_white
    cmp 0x1F
    beq .vt100_jsr_scr_full
    cmp 0x21
    beq .vt100_jsr_scr_down
    cmp 0x22
    beq .vt100_jsr_scr_up
    cmp 0x23
    beq .vt100_jsr_wrap_on
    cmp 0x24
    beq .vt100_jsr_wrap_off
    cmp 0x25
    beq .vt100_jsr_font0
    cmp 0x26
    beq .vt100_jsr_font1
    cmp 0x27
    beq .vt100_jsr_dev_reset
    cmp 0x28
    beq .vt100_jsr_query_cur
    jmp .fetch

.vt100_cursor_pos:
    jsr .pop_byte
    jsr .pop_byte
    tae
    jsr .pop_byte
    jsr .pop_byte
    tad
    jsr VT100_CURSOR_POSITION
    jmp .fetch

.vt100_scroll_region:
    jsr .pop_byte
    jsr .pop_byte
    tae
    jsr .pop_byte
    jsr .pop_byte
    tad
    jsr VT100_SCROLL_SCREEN_REGION
    jmp .fetch

.vt100_jsr_erase:    jsr VT100_ERASE_SCREEN
    jmp .fetch
.vt100_jsr_home:     jsr VT100_CURSOR_HOME
    jmp .fetch
.vt100_jsr_up:       jsr VT100_CURSOR_UP
    jmp .fetch
.vt100_jsr_down:     jsr VT100_CURSOR_DOWN
    jmp .fetch
.vt100_jsr_right:    jsr VT100_CURSOR_RIGHT
    jmp .fetch
.vt100_jsr_left:     jsr VT100_CURSOR_LEFT
    jmp .fetch
.vt100_jsr_cle:     jsr VT100_CLEAR_LINE_END
    jmp .fetch
.vt100_jsr_cls:     jsr VT100_CLEAR_LINE_START
    jmp .fetch
.vt100_jsr_cel:     jsr VT100_CLEAR_ENTIRE_LINE
    jmp .fetch
.vt100_jsr_tr:      jsr VT100_TEXT_RESET
    jmp .fetch
.vt100_jsr_tb:      jsr VT100_TEXT_BOLD
    jmp .fetch
.vt100_jsr_tu:      jsr VT100_TEXT_UNDERLINE
    jmp .fetch
.vt100_jsr_tblk:    jsr VT100_TEXT_BLINK
    jmp .fetch
.vt100_jsr_trev:    jsr VT100_TEXT_REVERSE
    jmp .fetch
.vt100_jsr_fg_black: jsr VT100_FG_BLACK
    jmp .fetch
.vt100_jsr_fg_red:   jsr VT100_FG_RED
    jmp .fetch
.vt100_jsr_fg_green: jsr VT100_FG_GREEN
    jmp .fetch
.vt100_jsr_fg_yellow: jsr VT100_FG_YELLOW
    jmp .fetch
.vt100_jsr_fg_blue:  jsr VT100_FG_BLUE
    jmp .fetch
.vt100_jsr_fg_magenta: jsr VT100_FG_MAGENTA
    jmp .fetch
.vt100_jsr_fg_cyan:  jsr VT100_FG_CYAN
    jmp .fetch
.vt100_jsr_fg_white: jsr VT100_FG_WHITE
    jmp .fetch
.vt100_jsr_bg_black: jsr VT100_BG_BLACK
    jmp .fetch
.vt100_jsr_bg_red:   jsr VT100_BG_RED
    jmp .fetch
.vt100_jsr_bg_green: jsr VT100_BG_GREEN
    jmp .fetch
.vt100_jsr_bg_yellow: jsr VT100_BG_YELLOW
    jmp .fetch
.vt100_jsr_bg_blue:  jsr VT100_BG_BLUE
    jmp .fetch
.vt100_jsr_bg_magenta: jsr VT100_BG_MAGENTA
    jmp .fetch
.vt100_jsr_bg_cyan:  jsr VT100_BG_CYAN
    jmp .fetch
.vt100_jsr_bg_white: jsr VT100_BG_WHITE
    jmp .fetch
.vt100_jsr_scr_full: jsr VT100_SCROLL_SCREEN_FULL
    jmp .fetch
.vt100_jsr_scr_down: jsr VT100_SCROLL_DOWN
    jmp .fetch
.vt100_jsr_scr_up:   jsr VT100_SCROLL_UP
    jmp .fetch
.vt100_jsr_wrap_on:  jsr VT100_ENABLE_WRAP
    jmp .fetch
.vt100_jsr_wrap_off: jsr VT100_DISABLE_WRAP
    jmp .fetch
.vt100_jsr_font0:   jsr VT100_FONT_DEFAULT
    jmp .fetch
.vt100_jsr_font1:   jsr VT100_FONT_ALTERNATE
    jmp .fetch
.vt100_jsr_dev_reset: jsr VT100_DEVICE_RESET
    jmp .fetch
.vt100_jsr_query_cur: jsr VT100_QUERY_CURSOR_POSITION
    jmp .fetch

; --- CSP: WAIT_MS -----------------------------------------

.csp_wait_ms:
    jsr .pop_byte
    sta MATH16_A+1
    jsr .pop_byte
    sta MATH16_A
    jsr WAIT_MS
    jmp .fetch

; --- CSP: READLN_STR ------------------------------------

.csp_readln_str:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ldx 0x00
.rln_loop:
    jsr ACIA_READ_CHAR
    cmp 0x0D
    beq .rln_fin
    cmp 0x0A
    beq .rln_fin
    cpx 0x50
    bcs .rln_loop
    inx
    sta de,x
    jmp .rln_loop
.rln_fin:
    txa
    pha
    ldx 0x00
    pla
    sta de,x
    jmp .fetch

; --- CSP: WRITE_STR / WRITELN_STR -------------------------

.csp_write_str:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ldx 0x00
    lda de,x
    tay
    beq .wrs_done
    ldx 0x01
.wrs_loop:
    lda de,x
    jsr ACIA_SEND_CHAR
    inx
    dey
    bne .wrs_loop
.wrs_done:
    jmp .fetch

.csp_writeln_str:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ldx 0x00
    lda de,x
    tay
    beq .wln_only_nl
    ldx 0x01
.wln_lp:
    lda de,x
    jsr ACIA_SEND_CHAR
    inx
    dey
    bne .wln_lp
.wln_only_nl:
    jsr ACIA_SEND_NEWLINE
    jmp .fetch

; --- CSP: STR_EQ ------------------------------------------

.csp_str_eq:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ste FLOAT1+0
    tda
    sta FLOAT1+1
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ste FLOAT1+2
    tda
    sta FLOAT1+3
    ldd FLOAT1+1
    lde FLOAT1+0
    ldx 0x00
    lda de,x
    sta PM_TEMP3
    ldd FLOAT1+3
    lde FLOAT1+2
    ldx 0x00
    lda de,x
    cmp PM_TEMP3
    bne .seq_push0
    ldx PM_TEMP3
    beq .seq_push1
    ldx 0x01
.seq_clp:
    ldd FLOAT1+1
    lde FLOAT1+0
    lda de,x
    sta PM_TEMP2
    ldd FLOAT1+3
    lde FLOAT1+2
    lda de,x
    cmp PM_TEMP2
    bne .seq_push0
    cpx PM_TEMP3
    beq .seq_push1
    inx
    jmp .seq_clp
.seq_push1:
    lda 0x01
    jsr .push_byte
    lda 0x00
    jsr .push_byte
    jmp .fetch
.seq_push0:
    lda 0x00
    jsr .push_byte
    jsr .push_byte
    jmp .fetch

; --- CSP: STR_ASSIGN_LIT (pool address 16-bit LE) ---------
;     PM_TEMP/PM_TEMP2 = pool ptr; FLOAT1 = dest abs ptr.
;     Use LDA/STA DE,X (16-bit addr) so Y is not required — kernel VT100 may leave Y dirty.

.csp_str_assign_lit:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ste FLOAT1+0
    tda
    sta FLOAT1+1
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    lda 0x00
    sta PM_TEMP3
.sal_loop:
    lda PM_TEMP3
    cmp 0x50
    bcs .sal_done
    clc
    adc PM_TEMP
    tae
    lda PM_TEMP2
    adc 0x00
    tad
    ldx 0x00
    lda de,x
    beq .sal_done
    pha
    ldx PM_TEMP3
    inx
    ldd FLOAT1+1
    lde FLOAT1+0
    pla
    sta de,x
    inc PM_TEMP3
    jmp .sal_loop
.sal_done:
    ldx 0x00
    lda PM_TEMP3
    ldd FLOAT1+1
    lde FLOAT1+0
    sta de,x
    jmp .fetch

; --- CSP: STR_COPY (dst FP off, src FP off) --------------

.csp_str_copy:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ste FLOAT1+0
    tda
    sta FLOAT1+1
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ste FLOAT1+2
    tda
    sta FLOAT1+3
    ldd FLOAT1+3
    lde FLOAT1+2
    ldx 0x00
    lda de,x
    tay
    beq .scpy_zlen
    ldx 0x01
.scpy_loop:
    ldd FLOAT1+3
    lde FLOAT1+2
    lda de,x
    pha
    ldd FLOAT1+1
    lde FLOAT1+0
    pla
    sta de,x
    inx
    dey
    bne .scpy_loop
.scpy_zlen:
    ldd FLOAT1+3
    lde FLOAT1+2
    ldx 0x00
    lda de,x
    pha
    ldd FLOAT1+1
    lde FLOAT1+0
    pla
    ldx 0x00
    sta de,x
    jmp .fetch

; --- CSP: LENGTH -----------------------------------------

.csp_length:
    jsr .fetch_byte
    sta PM_TEMP
    jsr .fetch_byte
    sta PM_TEMP2
    jsr .pm_fp_addr16
    ldx 0x00
    lda de,x
    jsr .push_byte
    lda 0x00
    jsr .push_byte
    jmp .fetch

; --- Float opcodes ----------------------------------------

; FLIT: push 4-byte float literal (4 operand bytes follow)
.op_flit:
    jsr .fetch_byte
    jsr .push_byte           ; byte 0 (FLOAT LSB)
    jsr .fetch_byte
    jsr .push_byte           ; byte 1
    jsr .fetch_byte
    jsr .push_byte           ; byte 2
    jsr .fetch_byte
    jsr .push_byte           ; byte 3 (FLOAT MSB)
    jmp .fetch

; FLOAD offset: load 4-byte float from FP+offset
.op_fload:
    jsr .fetch_byte          ; A = byte offset
    clc
    adc PM_FP_LSB
    tae
    lda PM_FP_MSB
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x
    sta FLOAT1
    inx
    lda de,x
    sta FLOAT1+1
    inx
    lda de,x
    sta FLOAT1+2
    inx
    lda de,x
    sta FLOAT1+3
    jsr .push_float1
    jmp .fetch

; FSTORE offset: pop 4-byte float, store at FP+offset
.op_fstore:
    jsr .fetch_byte          ; A = byte offset
    sta PM_TEMP
    ; Pop 4 bytes (MSB first from stack)
    jsr .pop_byte
    sta FLOAT1+3
    jsr .pop_byte
    sta FLOAT1+2
    jsr .pop_byte
    sta FLOAT1+1
    jsr .pop_byte
    sta FLOAT1
    ; Store to frame
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
    lda FLOAT1
    sta de,x
    inx
    lda FLOAT1+1
    sta de,x
    inx
    lda FLOAT1+2
    sta de,x
    inx
    lda FLOAT1+3
    sta de,x
    jmp .fetch

; Helper: pop float into FLOAT2, then pop float into FLOAT1
.pop_two_floats:
    jsr .pop_byte
    sta FLOAT2+3
    jsr .pop_byte
    sta FLOAT2+2
    jsr .pop_byte
    sta FLOAT2+1
    jsr .pop_byte
    sta FLOAT2
    jsr .pop_byte
    sta FLOAT1+3
    jsr .pop_byte
    sta FLOAT1+2
    jsr .pop_byte
    sta FLOAT1+1
    jsr .pop_byte
    sta FLOAT1
    rts

; Helper: push FLOAT1 result onto eval stack
.push_float1:
    lda FLOAT1
    jsr .push_byte
    lda FLOAT1+1
    jsr .push_byte
    lda FLOAT1+2
    jsr .push_byte
    lda FLOAT1+3
    jsr .push_byte
    rts

; FADD: pop b(4B), pop a(4B), push a+b
.op_fadd:
    jsr .pop_two_floats
    jsr FLOAT_ADD
    jsr .push_float1
    jmp .fetch

; FSUB: pop b(4B), pop a(4B), push a-b
.op_fsub:
    jsr .pop_two_floats
    jsr FLOAT_SUB
    jsr .push_float1
    jmp .fetch

; FMUL: pop b(4B), pop a(4B), push a*b
.op_fmul:
    jsr .pop_two_floats
    jsr FLOAT_MUL
    jsr .push_float1
    jmp .fetch

; FDIV: pop b(4B), pop a(4B), push a/b
.op_fdiv:
    jsr .pop_two_floats
    jsr FLOAT_DIV
    jsr .push_float1
    jmp .fetch

; FNEG: pop float(4B), flip sign bit, push
.op_fneg:
    jsr .pop_byte
    eor 0x80                 ; flip sign bit of byte 3 (MSB)
    jsr .push_byte
    jmp .fetch

; ITOF_SWAP: stack has int(2B) under float(4B); convert int to float
; stack: ..., int16(2B), float(4B) → ..., float(4B), float(4B)
.op_itof_swap:
    ; Pop top float into FLOAT2
    jsr .pop_byte
    sta FLOAT2+3
    jsr .pop_byte
    sta FLOAT2+2
    jsr .pop_byte
    sta FLOAT2+1
    jsr .pop_byte
    sta FLOAT2
    ; Pop int16, convert to float
    jsr .pop_byte
    sta PM_TEMP
    jsr .pop_byte
    ldx PM_TEMP
    jsr INT_TO_FLOAT         ; FLOAT1 = converted int
    ; Push converted int (now float)
    jsr .push_float1
    ; Push original float back on top
    lda FLOAT2
    jsr .push_byte
    lda FLOAT2+1
    jsr .push_byte
    lda FLOAT2+2
    jsr .push_byte
    lda FLOAT2+3
    jsr .push_byte
    jmp .fetch

; FABS: pop float(4B), clear sign bit, push float(4B)
.op_fabs:
    jsr .pop_byte
    and 0x7F                 ; clear sign bit of byte 3 (MSB)
    jsr .push_byte
    jmp .fetch

; ITOF: pop int16(2B), convert to float, push float(4B)
.op_itof:
    jsr .pop_byte            ; MSB of int
    sta PM_TEMP              ; save MSB
    jsr .pop_byte            ; LSB of int → A
    ldx PM_TEMP              ; X = MSB
    jsr INT_TO_FLOAT
    jsr .push_float1
    jmp .fetch

; FTOI: pop float(4B), truncate to int16, push int16(2B)
.op_ftoi:
    jsr .pop_byte
    sta FLOAT1+3
    jsr .pop_byte
    sta FLOAT1+2
    jsr .pop_byte
    sta FLOAT1+1
    jsr .pop_byte
    sta FLOAT1
    jsr FLOAT_TO_INT         ; A=lo, X=hi
    stx PM_TEMP              ; save MSB
    jsr .push_byte           ; push LSB
    lda PM_TEMP
    jsr .push_byte           ; push MSB
    jmp .fetch

; FCMP: pop b(4B), pop a(4B), subtract, push int16 (-1/0/1)
.op_fcmp:
    jsr .pop_two_floats
    jsr FLOAT_SUB            ; FLOAT1 = a - b
    ; Check result (mask sign bit for +0/-0)
    lda FLOAT1+3
    and 0x7F
    ora FLOAT1+2
    ora FLOAT1+1
    ora FLOAT1
    beq .fcmp_eq             ; result == 0
    lda FLOAT1+3
    bmi .fcmp_lt             ; result < 0 (sign bit set)
    ; result > 0
    lda 0x01
    jsr .push_byte
    lda 0x00
    jsr .push_byte
    jmp .fetch
.fcmp_lt:
    lda 0xFF                 ; -1 LSB
    jsr .push_byte
    lda 0xFF                 ; -1 MSB
    jsr .push_byte
    jmp .fetch
.fcmp_eq:
    lda 0x00
    jsr .push_byte
    lda 0x00
    jsr .push_byte
    jmp .fetch

; FLOAD_L depth offset: load 4-byte float via static chain
.op_fload_l:
    jsr .fetch_byte          ; depth
    sta PM_TEMP
    jsr .fetch_byte          ; offset
    pha

    ldx PM_TEMP
    jsr .follow_links        ; PM_TEMP3:PM_TEMP2 = target FP

    pla                      ; A = offset
    clc
    adc PM_TEMP2
    tae
    lda PM_TEMP3
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda de,x
    sta FLOAT1
    inx
    lda de,x
    sta FLOAT1+1
    inx
    lda de,x
    sta FLOAT1+2
    inx
    lda de,x
    sta FLOAT1+3
    jsr .push_float1
    jmp .fetch

; FSTORE_L depth offset: store 4-byte float via static chain
.op_fstore_l:
    jsr .fetch_byte          ; depth
    sta PM_TEMP
    jsr .fetch_byte          ; offset
    pha
    ; Pop float first
    jsr .pop_byte
    sta FLOAT1+3
    jsr .pop_byte
    sta FLOAT1+2
    jsr .pop_byte
    sta FLOAT1+1
    jsr .pop_byte
    sta FLOAT1

    ldx PM_TEMP
    jsr .follow_links        ; PM_TEMP3:PM_TEMP2 = target FP

    pla                      ; A = offset
    clc
    adc PM_TEMP2
    tae
    lda PM_TEMP3
    adc 0x00
    clc
    adc PM_VAR_FRAME[15:8]
    tad
    ldx 0x00
    lda FLOAT1
    sta de,x
    inx
    lda FLOAT1+1
    sta de,x
    inx
    lda FLOAT1+2
    sta de,x
    inx
    lda FLOAT1+3
    sta de,x
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
    #d "P-Machine (", PMACHINE_VERSION, "): started", 0x0A, 0x0D, 0x00

.done_msg:
    #d "P-Machine (", PMACHINE_VERSION, "): execution complete", 0x0A, 0x0D, 0x00

.error_msg:
    #d 0x0A, 0x0D
    #d "P-Machine: invalid P-code.", 0x0A, 0x0D, 0x00

; TinyPascal editor/compiler: load apps/tinypascal_ide.bin to 0x020000 via XMODEM, then run.
