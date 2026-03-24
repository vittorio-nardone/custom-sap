#once
#bank kernel
#include "square.asm"
#include "power2.asm"

; **********************************************************
; SUBROUTINE: DIVIDE_INT
;
; DESCRIPTION:
;   This subroutine performs integer division by dividing
;   the contents of the X registry (numerator) by the
;   contents of the Y registry (denominator).
;
; INPUTS:
;   X : numerator.
;   Y : denominator.
;
; OUTPUTS:
;   A : quotient of the division operation 
;   X : remainder of the division operation 
;
; DESTROY:
;   A, X, D, E 
;
; FLAGS AFFECTED:
;   (Z) - unpredictable value 
;   (N) - unpredictable value
;   (C) - unpredictable value
;
; USAGE:
;   Call this subroutine with the numerator in the X registry
;   and the denominator in the Y registry.
;   After execution, the quotient will be stored in the 
;   accumulator and the remainder in the X registry
;   If Y value is 0, returns immediatly.
;
; EXAMPLE:
;   ldx 0x15   ; Numerator = 21
;   ldy 0x5    ; Denominator = 5
;   jsr DIVIDE_INT
;   ; Result: A = 4 (21 / 5 = 4)
;   ;         X = 1 (21 % 5 = 1)
;
; AUTHOR: VN
; LAST UPDATE: 15/02/2024
; **********************************************************

DIVIDE_INT:
    tya 
    beq .l4
    lda 0x00
    cpx Y
    bcc .l4
.l0:
    ldd 0x01
    tye
    clc
.l1:
    cpe 0x80
    bcs .l3
    rol E
    cpx E
    bcc .l2
    clc
    rol D
    jmp .l1 
.l2: 
    clc
    ror E
.l3:
    clc
    adc D
    sec
    sbx E
    cpx Y
    bcs .l0
.l4:
    rts

; **********************************************************
; SUBROUTINE: MULTIPLY_INT
;
; DESCRIPTION:
;   This subroutine performs an integer multiplication of two 8-bit values stored in registers A and X. 
;   The result is a 16-bit value, with the most significant byte (MSB) returned in A, and the least significant byte (LSB) returned in X.
;   The subroutine utilizes lookup tables (SQTAB_LSB and SQTAB_MSB) to efficiently perform the multiplication through table-based squaring 
;   and difference of squares method.
;
; INPUTS:
;   A : 8-bit factor 1
;   X : 8-bit factor 2
;
; OUTPUTS:
;   A : Most Significant Byte (MSB) of the multiplication result
;   X : Least Significant Byte (LSB) of the multiplication result
;
; DESTROY:
;   A : Modified during calculation
;   X : Modified during calculation
;   Y : Used as a temporary register during calculation
;
; FLAGS AFFECTED:
;   (Z) - Zero flag: unpredictable result
;   (N) - Negative flag: unpredictable result
;   (C) - Carry flag: unpredictable result
;
; USAGE:
;   To use this subroutine, load the two 8-bit values into registers A and X, then call the subroutine using `jsr MULTIPLY_INT`.
;   After execution, the MSB of the result will be in register A, and the LSB will be in register X.
;
; EXAMPLE:
;   lda 0x15        ; Load 0x15 into A (first factor)
;   ldx 0x23        ; Load 0x23 into X (second factor)
;   jsr MULTIPLY_INT ; Call the MULTIPLY_INT subroutine
;   ; After execution:
;   ; A = 0x02      ; MSB of the result (0x02DF)
;   ; X = 0xDF      ; LSB of the result (0x02DF)
;
; AUTHOR: VN
; LAST UPDATE: 15/04/2025
; **********************************************************

MULTIPLY_INT:
	sta MUL_TMP          ; 0x15 -> 0xfd
	cpx MUL_TMP          ; 0x23 > 0x15 -> C = 1
	bcc .sorted         ; not jump
	txa                 ; swap
	ldx MUL_TMP
.sorted:
	sta MUL_TMP + 2          ; 0x23 -> ff
	stx MUL_TMP          ; 0x15 -> fd
	sec                 ; C -> 1
	sbc MUL_TMP          ; 0x23 - 0x15 = 0x0E -> acc
	tay                 ; y = 0x0E
   	ldx MUL_TMP + 2          ; x = 0x23
	lda SQTAB_LSB,x     ; acc = 0xC9
	sec                 ; C -> 1
	sbc SQTAB_LSB,y     ; 0xC9 - 0xC4 = 0x05
	sta MUL_TMP + 1          ; 0x05 -> fe
	lda SQTAB_MSB,x     ; acc = 0x04
	sbc SQTAB_MSB,y     ; 0x04 - 0x00 = 0x04
	sta MUL_TMP + 2          ; 0x04 -> ff
	ldx MUL_TMP          ; x = 0x15
	lda MUL_TMP + 1          ; a = 0x05
    clc
	adc SQTAB_LSB,x     ; 0x05 + 0xb9 = 0xbe
	sta MUL_TMP + 1          ; 0xbe -> fe
	lda MUL_TMP + 2          ; a = 0x04
	adc SQTAB_MSB,x     ; 0x04 + 0x01 = 0x05 (carry from ADC preserved for ROR)
    ror a               ; 0x05 >> a = 0x02 + C
    ror MUL_TMP + 1          ; 0xbe >> 0x5f + C = 0xdf
	ldx MUL_TMP + 1	        ; x = 0xdf
    rts

; **********************************************************
; SUBROUTINE: MUL16S
;
; DESCRIPTION:
;   Signed 16-bit multiplication.  Result is the lower 16 bits
;   of the full 32-bit product (overflow is silently truncated).
;   Uses MULTIPLY_INT (8x8->16) internally via decomposition:
;     (A_hi*256+A_lo)*(B_hi*256+B_lo) low-16 =
;       A_lo*B_lo + ((A_lo*B_hi + A_hi*B_lo) << 8)
;
; INPUTS:
;   MATH16_A : 16-bit signed factor (little-endian)
;   MATH16_B : 16-bit signed factor (little-endian)
;
; OUTPUTS:
;   MATH16_A : 16-bit signed product (little-endian)
;
; DESTROY:  A, X, Y
; **********************************************************

MUL16S:
    lda MATH16_A+1
    eor MATH16_B+1
    sta MATH16_SIGN

    lda MATH16_A+1
    bpl .a_pos
    jsr MATH16_NEGATE_A
.a_pos:
    lda MATH16_B+1
    bpl .b_pos
    jsr MATH16_NEGATE_B
.b_pos:
    ; Save original A_lo, A_hi (MULTIPLY_INT will use A,X,Y)
    lda MATH16_A
    sta MATH16_WORK
    lda MATH16_A+1
    sta MATH16_WORK+1

    ; Step 1: A_lo * B_lo (full 16-bit)
    lda MATH16_WORK
    ldx MATH16_B
    jsr MULTIPLY_INT
    stx MATH16_A
    sta MATH16_A+1

    ; Step 2: A_lo * B_hi -> add LSB to result_hi
    lda MATH16_WORK
    ldx MATH16_B+1
    jsr MULTIPLY_INT
    txa
    clc
    adc MATH16_A+1
    sta MATH16_A+1

    ; Step 3: A_hi * B_lo -> add LSB to result_hi
    lda MATH16_WORK+1
    ldx MATH16_B
    jsr MULTIPLY_INT
    txa
    clc
    adc MATH16_A+1
    sta MATH16_A+1

    lda MATH16_SIGN
    bpl .mul_done
    jsr MATH16_NEGATE_A
.mul_done:
    rts

; **********************************************************
; SUBROUTINE: DIV16S
;
; DESCRIPTION:
;   Signed 16-bit integer division (truncated toward zero).
;
; INPUTS:
;   MATH16_A : 16-bit signed dividend (little-endian)
;   MATH16_B : 16-bit signed divisor  (little-endian)
;
; OUTPUTS:
;   MATH16_A : 16-bit signed quotient
;   (MATH16_WORK contains unsigned remainder after .div16u)
;
; DESTROY:  A, Y
; **********************************************************

DIV16S:
    lda MATH16_B
    ora MATH16_B+1
    beq .div_by_zero

    lda MATH16_A+1
    eor MATH16_B+1
    sta MATH16_SIGN

    lda MATH16_A+1
    bpl .da_pos
    jsr MATH16_NEGATE_A
.da_pos:
    lda MATH16_B+1
    bpl .db_pos
    jsr MATH16_NEGATE_B
.db_pos:
    jsr .div16u

    lda MATH16_SIGN
    bpl .div_done
    jsr MATH16_NEGATE_A
.div_done:
    rts

.div_by_zero:
    lda 0x00
    sta MATH16_A
    sta MATH16_A+1
    rts

; --- unsigned 16/16 -> quotient in MATH16_A, remainder in MATH16_WORK
.div16u:
    lda 0x00
    sta MATH16_WORK
    sta MATH16_WORK+1

    ldy 16
.div_loop:
    asl MATH16_A
    rol MATH16_A+1
    rol MATH16_WORK
    rol MATH16_WORK+1

    lda MATH16_WORK+1
    cmp MATH16_B+1
    bcc .div_skip
    bne .div_sub
    lda MATH16_WORK
    cmp MATH16_B
    bcc .div_skip
.div_sub:
    lda MATH16_WORK
    sec
    sbc MATH16_B
    sta MATH16_WORK
    lda MATH16_WORK+1
    sbc MATH16_B+1
    sta MATH16_WORK+1
    inc MATH16_A
.div_skip:
    dey
    bne .div_loop
    rts

; **********************************************************
; SUBROUTINE: MOD16S
;
; DESCRIPTION:
;   Signed 16-bit modulo.  The sign of the result follows
;   the sign of the dividend (Pascal convention).
;
; INPUTS:
;   MATH16_A : 16-bit signed dividend
;   MATH16_B : 16-bit signed divisor
;
; OUTPUTS:
;   MATH16_A : 16-bit signed remainder
;
; DESTROY:  A, Y
; **********************************************************

MOD16S:
    lda MATH16_B
    ora MATH16_B+1
    beq .mod_by_zero

    lda MATH16_A+1
    sta MATH16_SIGN

    bpl .ma_pos
    jsr MATH16_NEGATE_A
.ma_pos:
    lda MATH16_B+1
    bpl .mb_pos
    jsr MATH16_NEGATE_B
.mb_pos:
    jsr .div16u_mod

    lda MATH16_WORK
    sta MATH16_A
    lda MATH16_WORK+1
    sta MATH16_A+1

    lda MATH16_SIGN
    bpl .mod_done
    jsr MATH16_NEGATE_A
.mod_done:
    rts

.mod_by_zero:
    lda 0x00
    sta MATH16_A
    sta MATH16_A+1
    rts

; same algorithm as DIV16S's .div16u, duplicated under MOD16S scope
.div16u_mod:
    lda 0x00
    sta MATH16_WORK
    sta MATH16_WORK+1
    ldy 16
.div_loop_m:
    asl MATH16_A
    rol MATH16_A+1
    rol MATH16_WORK
    rol MATH16_WORK+1
    lda MATH16_WORK+1
    cmp MATH16_B+1
    bcc .div_skip_m
    bne .div_sub_m
    lda MATH16_WORK
    cmp MATH16_B
    bcc .div_skip_m
.div_sub_m:
    lda MATH16_WORK
    sec
    sbc MATH16_B
    sta MATH16_WORK
    lda MATH16_WORK+1
    sbc MATH16_B+1
    sta MATH16_WORK+1
    inc MATH16_A
.div_skip_m:
    dey
    bne .div_loop_m
    rts

; **********************************************************
; HELPER: MATH16_NEGATE_A / MATH16_NEGATE_B
;
; Two's complement negation of 16-bit value in MATH16_A / B.
; DESTROY: A
; **********************************************************

MATH16_NEGATE_A:
    lda MATH16_A
    eor 0xFF
    clc
    adc 0x01
    sta MATH16_A
    lda MATH16_A+1
    eor 0xFF
    adc 0x00
    sta MATH16_A+1
    rts

MATH16_NEGATE_B:
    lda MATH16_B
    eor 0xFF
    clc
    adc 0x01
    sta MATH16_B
    lda MATH16_B+1
    eor 0xFF
    adc 0x00
    sta MATH16_B+1
    rts

; **********************************************************
; SUBROUTINE: CMP16S
;
; DESCRIPTION:
;   Signed 16-bit comparison of MATH16_A vs MATH16_B.
;   Result stored in MATH16_TMP (not flags, because RTS
;   clobbers Z/N via stack pops on Otto hardware).
;
; INPUTS:
;   MATH16_A : 16-bit signed value (little-endian)
;   MATH16_B : 16-bit signed value (little-endian)
;
; OUTPUTS:
;   MATH16_TMP = 0x00 if A == B
;   MATH16_TMP = 0x01 if A > B (signed)
;   MATH16_TMP = 0xFF if A < B (signed)
;
; Caller checks: LDA MATH16_TMP then BEQ/BNE/BMI/BPL.
;
; DESTROY: A
; **********************************************************

CMP16S:
    lda MATH16_A
    cmp MATH16_B
    bne .cmp_ne
    lda MATH16_A+1
    cmp MATH16_B+1
    bne .cmp_ne
    lda 0x00
    sta MATH16_TMP
    rts

.cmp_ne:
    lda MATH16_A+1
    eor MATH16_B+1
    bmi .cmp_diff

    lda MATH16_A+1
    cmp MATH16_B+1
    bne .cmp_msb
    lda MATH16_A
    cmp MATH16_B
.cmp_msb:
    bcs .cmp_gt_res
    lda 0xFF
    sta MATH16_TMP
    rts
.cmp_gt_res:
    lda 0x01
    sta MATH16_TMP
    rts

.cmp_diff:
    lda MATH16_B+1
    bmi .cmp_gt_res
    lda 0xFF
    sta MATH16_TMP
    rts

; **********************************************************
; TESTS START HERE
;

MATH_test:
; ;    ldo 0xA1                ; Test #A1: Integer division
    ldx 0x85
    ldy 0x05
    jsr DIVIDE_INT
    cmp 0x1A
    bne .fail
    cpx 0x03
    bne .fail
    cpy 0x05
    bne .fail

;    ldo 0xA2               ; Test #A2: Integer multiplication
    lda 0x58
    ldx 0x45
    jsr MULTIPLY_INT        ; 0x58 * 0x45 = 0x17B8
    cmp 0x17
    bne .fail
    cpx 0xB8
    bne .fail

;    ldo 0xA3               ; Test #A3: Integer multiplication
    lda 0x3c
    ldx 0x02
    jsr MULTIPLY_INT        ; 0x3C * 0x02 = 0x0078
    cmp 0x00
    bne .fail
    cpx 0x78
    bne .fail

    rts

.fail:
    ldo 0xFA
    hlt



