#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

.loop:
    ldd .header[15:8]
    lde .header[7:0]
    jsr ACIA_SEND_STRING

    ; Read first operand
    ldd .prompt_a[15:8]
    lde .prompt_a[7:0]
    jsr ACIA_SEND_STRING
    jsr FLOAT_READ
    jsr ACIA_SEND_NEWLINE

    ; Save A to app-local storage
    lda 0x80FB
    sta .save_a_b0
    lda 0x80FC
    sta .save_a_b1
    lda 0x80FD
    sta .save_a_b2
    lda 0x80FE
    sta .save_a_b3

    ; Read second operand
    ldd .prompt_b[15:8]
    lde .prompt_b[7:0]
    jsr ACIA_SEND_STRING
    jsr FLOAT_READ
    jsr ACIA_SEND_NEWLINE

    ; Save B to app-local storage
    lda 0x80FB
    sta .save_b_b0
    lda 0x80FC
    sta .save_b_b1
    lda 0x80FD
    sta .save_b_b2
    lda 0x80FE
    sta .save_b_b3

    ; --- ADD: A + B ---
    ldd .op_add[15:8]
    lde .op_add[7:0]
    jsr ACIA_SEND_STRING

    jsr .load_a_f1_b_f2
    jsr FLOAT_ADD
    ldy 0x05
    jsr FLOAT_PRINT
    jsr ACIA_SEND_NEWLINE

    ; --- SUB: A - B ---
    ldd .op_sub[15:8]
    lde .op_sub[7:0]
    jsr ACIA_SEND_STRING

    jsr .load_a_f1_b_f2
    jsr FLOAT_SUB
    ldy 0x05
    jsr FLOAT_PRINT
    jsr ACIA_SEND_NEWLINE

    ; --- MUL: A * B ---
    ldd .op_mul[15:8]
    lde .op_mul[7:0]
    jsr ACIA_SEND_STRING

    jsr .load_a_f1_b_f2
    jsr FLOAT_MUL
    ldy 0x05
    jsr FLOAT_PRINT
    jsr ACIA_SEND_NEWLINE

    ; --- DIV: A / B ---
    ldd .op_div[15:8]
    lde .op_div[7:0]
    jsr ACIA_SEND_STRING

    jsr .load_a_f1_b_f2
    jsr FLOAT_DIV
    ldy 0x05
    jsr FLOAT_PRINT
    jsr ACIA_SEND_NEWLINE

    jmp .loop

; Helper: load A into float1 (0x80FB-FE), B into FLOAT2 (0x80F0-F3)
; Both operands are restored from app-local storage
.load_a_f1_b_f2:
    lda .save_a_b0
    sta 0x80FB
    lda .save_a_b1
    sta 0x80FC
    lda .save_a_b2
    sta 0x80FD
    lda .save_a_b3
    sta 0x80FE
    lda .save_b_b0
    sta FLOAT2_B0
    lda .save_b_b1
    sta FLOAT2_B1
    lda .save_b_b2
    sta FLOAT2_B2
    lda .save_b_b3
    sta FLOAT2_B3
    rts

.header:
    #d 0x0A, 0x0D, "=== Float Calculator ===", 0x0A, 0x0D, 0x00
.prompt_a:
    #d "  A = ", 0x00
.prompt_b:
    #d "  B = ", 0x00
.op_add:
    #d "  A + B = ", 0x00
.op_sub:
    #d "  A - B = ", 0x00
.op_mul:
    #d "  A * B = ", 0x00
.op_div:
    #d "  A / B = ", 0x00

; App-local storage for operands (safe from kernel clobbering)
.save_a_b0: #d 0x00
.save_a_b1: #d 0x00
.save_a_b2: #d 0x00
.save_a_b3: #d 0x00
.save_b_b0: #d 0x00
.save_b_b1: #d 0x00
.save_b_b2: #d 0x00
.save_b_b3: #d 0x00