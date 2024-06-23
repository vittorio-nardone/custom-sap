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
; TESTS START HERE
;

MATH_test:
    ;ldo 0xA1                ; Test #A1: Integer division
    ldx 0x85
    ldy 0x05
    jsr DIVIDE_INT
    cmp 0x1A
    bne .fail
    cpx 0x03
    bne .fail
    cpy 0x05
    bne .fail
    rts

.fail:
    hlt



