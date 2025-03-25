#once
#bank kernel

; **********************************************************
; SUBROUTINE: INT_TO_FLOAT
;
; DESCRIPTION:
;   This subroutine performs signed integer (two bytes) to IEEE 754 float conversion 
;   using the IEEE 754 standard.
; INPUTS:
;   Input is stored in the X and Y registers as a signed integer (2's complement for negative numbers)
;   X : low byte of input.
;   Y : high byte of input.
;
; OUTPUTS:
;   0x80FB    ; Mantissa low
;   0x80FC    ; Mantissa mid
;   0x80FD    ; Mantissa high
;   0x80FE    ; Sign and exponent
;
; DESTROY:
;   A, X, Y 
;
; FLAGS AFFECTED:
;   (Z) - unpredictable value 
;   (N) - unpredictable value
;   (C) - unpredictable value
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 15/03/2025
; **********************************************************
INT_TO_FLOAT:
    ; Save input registers
    STA 0x80F9    ; Store low byte of input
    STX 0x80FA    ; Store high byte of input
    ; Handle zero case first
    ORA 0x80FA    ; Combine low and high bytes
    BNE .NONZERO

    ; If zero, store IEEE 754 zero representation
    LDA 0x00
    STA 0x80FB    ; Mantissa low
    STA 0x80FC    ; Mantissa mid
    STA 0x80FD    ; Mantissa high + exponent LSB
    STA 0x80FE    ; Sign and exponent
    RTS

.NONZERO:
    ; Determine sign
    LDA 0x80FA    ; Load high byte
    AND 0x80      ; Check sign bit
    STA 0x80FF    ; Temporary sign storage

    ; Take absolute value if negative
    BPL .POSITIVE
    
    ; Two's complement for negative numbers
    LDA 0x80F9
    EOR 0xFF
    CLC
    ADC 0x01
    STA 0x80F9
    LDA 0x80FA
    EOR 0xFF
    ADC 0x00
    STA 0x80FA

.POSITIVE:
    ; Normalize the number
    LDY 0x0F   ; Max shift counter (15 bits)
    LDX 0x00   ; Shift counter

.NORMALIZE_LOOP:
    LDA 0x80FA    ; Check high byte
    BMI .FOUND_NORMALIZED
    ASL 0x80F9    ; Shift low byte left
    ROL 0x80FA    ; Shift high byte left
    INX        ; Increment shift count
    DEY        ; Decrement max shift counter
    BPL .NORMALIZE_LOOP

.FOUND_NORMALIZED:
 
    ; Calculate exponent (127 bias + bit position)
    TXA        ; Shift count
    EOR 0x0F   ; Invert (because we shifted left)
    CLC
    ADC 0x7F   ; Add 127 bias
    STA 0x80FE    ; Store in exponent byte

    ; Prepare mantissa
    ASL 0x80F9    ; Shift out implicit leading 1
    ROL 0x80FA    ; Roll into high byte

    ; Store mantissa bytes (little-endian)
    LDA 0x80FA
    STA 0x80FD    ; Mantissa high byte
    LDA 0x80F9
    STA 0x80FC    ; Mantissa mid byte
    LDA 0x00
    STA 0x80FB    ; Mantissa low byte

    LSR 0x80FE    ; Shift all byte right to get sign bit in place
    ROR 0x80FD
    ROR 0x80FC
    ROR 0x80FB

    ; Add sign bit if negative
    LDA 0x80FF    ; Retrieve sign
    BEQ .DONE
    LDA 0x80FE
    ORA 0x80   ; Set sign bit in exponent byte
    STA 0x80FE

.DONE:
    RTS



; IEEE 754 Float to Integer Conversion
; Input: IEEE 754 float stored in 0x80FB, 0x80FC, 0x80FD, 0x80FE (4 bytes, little-endian)
; Output: 16-bit signed integer in A (low byte) and X (high byte)

FLOAT_TO_INT:
    ; Check if float is zero
    LDA 0x80FB
    ORA 0x80FC
    ORA 0x80FD
    ORA 0x80FE
    BEQ .RETURN_ZERO

    ; Extract exponent
    LDA 0x80FD
    ASL A
    LDA 0x80FE
    ROL A
    SEC
    SBC 0x7F    ; Remove bias
    dmp
    BMI .RETURN_ZERO  ; If exponent < 0, result is zero

    ; Check if exponent is too large for 16-bit integer
    CMP 0x0F    ; Max shift for 16-bit number
    BPL .OVERFLOW

    ; Prepare for conversion
    TAY         ; Y = shift count
    
    ; Reconstruct mantissa with implicit leading 1
    LDA 0x80    ; Set implicit leading 1
    STA 0x80FF     ; Temporary storage for high byte of mantissa

    ; Shift mantissa to correct position
.SHIFT_MANTISSA:
    CPY 0x00
    BEQ .CHECK_SIGN
    LSR 0x80FF     ; Shift high byte
    ROR 0x80FC     ; Shift mid byte
    ROR 0x80FB     ; Shift low byte
    DEY
    JMP .SHIFT_MANTISSA

.CHECK_SIGN:
    ; Check sign bit
    LDA 0x80FE
    AND 0x80
    BEQ .POSITIVE_NUMBER

    ; Negate if negative
    LDA 0x80FB
    EOR 0xFF
    CLC
    ADC 0x01
    STA 0x80FB
    LDA 0x80FC
    EOR 0xFF
    ADC 0x00
    STA 0x80FC

.POSITIVE_NUMBER:
    ; Prepare return values
    LDA 0x80FB     ; Low byte
    LDX 0x80FC     ; High byte
    RTS

.RETURN_ZERO:
    ; Return zero
    LDA 0x00
    TAX
    RTS

.OVERFLOW:
    ; Handle overflow (saturate to max/min 16-bit integer)
    LDA 0x80FE     ; Check sign bit
    AND 0x80
    BNE .NEG_OVERFLOW

    ; Positive overflow
    LDA 0xFF
    LDX 0x7F
    RTS

.NEG_OVERFLOW:
    ; Negative overflow
    LDA 0x00
    LDX 0x80
    RTS
