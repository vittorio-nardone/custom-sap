#once
#addr 0x1000
#include "square.asm"

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
;
; INPUTS:
;   A : factor
;   X : factor
;
; OUTPUTS:
;   A : result MSB
;   X : result LSB
;
; DESTROY:
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;   lda 0x15   
;   ldx 0x23   
;   jsr MULTIPLY_INT 
    ; 0x15 * 0x23 = 0x02DF
;   ; Result: A = 0x02   
;   ;         X = 0xDF
;
; AUTHOR: VN
; LAST UPDATE: 13/09/2024
; **********************************************************

MULTIPLY_INT:
	sta 0x80fd          ; 0x15 -> 0xfd
	cpx 0x80fd          ; 0x23 > 0x15 -> C = 1
	bcc .sorted         ; not jump
	txa                 ; swap
	ldx 0x80fd
.sorted:
	sta 0x80ff          ; 0x23 -> ff
	stx 0x80fd          ; 0x15 -> fd
	sec                 ; C -> 1
	sbc 0x80fd          ; 0x23 - 0x15 = 0x0E -> acc
	tay                 ; y = 0x0E
   	ldx 0x80ff          ; x = 0x23
	lda SQTAB_LSB,x     ; acc = 0xC9
	sub SQTAB_LSB,y     ; 0xC9 - 0xC4 = 0x05
	sta 0x80fe          ; 0x05 -> fe
	lda SQTAB_MSB,x     ; acc = 0x04
	sub SQTAB_MSB,y     ; 0x04 - 0x00 = 0x04
	sta 0x80ff          ; 0x04 -> ff
	clc
	ldx 0x80fd          ; x = 0x15
	lda 0x80fe          ; a = 0x05
	add SQTAB_LSB,x     ; 0x05 + 0xb9 = 0xbe
	sta 0x80fe          ; 0xbe -> fe
	lda 0x80ff          ; a = 0x04
	add SQTAB_MSB,x     ; 0x04 + 0x01 = 0x05
 
	bit 0x01
    bne .carry
    clc
    ror a               ; 0x05 >> a = 0x02
    ror 0x80fe          ; 0xbe >> 0x5f
	ldx 0x80fe	        ; x = 0xdf
    rts

.carry:
    clc
    ror a               ; 0x05 >> a = 0x02
    sec
    ror 0x80fe          ; 0xbe >> 0x5f + C = 0xdf
	ldx 0x80fe	        ; x = 0xdf
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

    rts

.fail:
    ldo 0xFA
    hlt



