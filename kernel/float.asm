#once
#bank kernel

; **********************************************************
; SUBROUTINE: INT_TO_FLOAT
;
; DESCRIPTION:
;   Converts a signed 16-bit integer (2's complement) to
;   IEEE 754 single precision float (32-bit).
;
; INPUTS:
;   A : low byte of signed 16-bit integer.
;   X : high byte of signed 16-bit integer.
;
; OUTPUTS:
;   FLOAT1    ; Float byte 0 (mantissa low)
;   FLOAT1 + 1    ; Float byte 1 (mantissa mid)
;   FLOAT1 + 2    ; Float byte 2 (mantissa high + exponent LSB)
;   FLOAT1 + 3    ; Float byte 3 (sign + exponent)
;
; DESTROY:
;   A, X, Y
;
; FLAGS AFFECTED:
;   (Z) - unpredictable value
;   (N) - unpredictable value
;   (C) - unpredictable value
;
; EXAMPLE:
;   lda 0x64        ; Low byte = 100
;   ldx 0x00        ; High byte = 0
;   jsr INT_TO_FLOAT
;   ; Result at FLOAT1-FLOAT1 + 3: 42C80000 (IEEE 754 for 100.0)
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************
INT_TO_FLOAT:
    ; Save input registers
    STA ITF_TMP    ; Store low byte of input
    STX ITF_TMP + 1    ; Store high byte of input
    ; Handle zero case first
    ORA ITF_TMP + 1    ; Combine low and high bytes
    BNE .NONZERO

    ; If zero, store IEEE 754 zero representation
    LDA 0x00
    STA FLOAT1    ; Mantissa low
    STA FLOAT1 + 1    ; Mantissa mid
    STA FLOAT1 + 2    ; Mantissa high + exponent LSB
    STA FLOAT1 + 3    ; Sign and exponent
    RTS

.NONZERO:
    ; Determine sign
    LDA ITF_TMP + 1    ; Load high byte
    AND 0x80      ; Check sign bit
    STA FLOAT_SIGN_TMP    ; Temporary sign storage

    ; Take absolute value if negative
    BPL .POSITIVE
    
    ; Two's complement for negative numbers
    LDA ITF_TMP
    EOR 0xFF
    CLC
    ADC 0x01
    STA ITF_TMP
    LDA ITF_TMP + 1
    EOR 0xFF
    ADC 0x00
    STA ITF_TMP + 1

.POSITIVE:
    ; Normalize the number
    LDY 0x0F   ; Max shift counter (15 bits)
    LDX 0x00   ; Shift counter

.NORMALIZE_LOOP:
    LDA ITF_TMP + 1    ; Check high byte
    BMI .FOUND_NORMALIZED
    ASL ITF_TMP    ; Shift low byte left
    ROL ITF_TMP + 1    ; Shift high byte left
    INX        ; Increment shift count
    DEY        ; Decrement max shift counter
    BPL .NORMALIZE_LOOP

.FOUND_NORMALIZED:
 
    ; Calculate exponent (127 bias + bit position)
    TXA        ; Shift count
    EOR 0x0F   ; Invert (because we shifted left)
    CLC
    ADC 0x7F   ; Add 127 bias
    STA FLOAT1 + 3    ; Store in exponent byte

    ; Prepare mantissa
    ASL ITF_TMP    ; Shift out implicit leading 1
    ROL ITF_TMP + 1    ; Roll into high byte

    ; Store mantissa bytes (little-endian)
    LDA ITF_TMP + 1
    STA FLOAT1 + 2    ; Mantissa high byte
    LDA ITF_TMP
    STA FLOAT1 + 1    ; Mantissa mid byte
    LDA 0x00
    STA FLOAT1    ; Mantissa low byte

    LSR FLOAT1 + 3    ; Shift all byte right to get sign bit in place
    ROR FLOAT1 + 2
    ROR FLOAT1 + 1
    ROR FLOAT1

    ; Add sign bit if negative
    LDA FLOAT_SIGN_TMP    ; Retrieve sign
    BEQ .DONE
    LDA FLOAT1 + 3
    ORA 0x80   ; Set sign bit in exponent byte
    STA FLOAT1 + 3

.DONE:
    RTS



; **********************************************************
; SUBROUTINE: FLOAT_TO_INT
;
; DESCRIPTION:
;   Converts an IEEE 754 single precision float (32-bit)
;   to a signed 16-bit integer. Truncates toward zero.
;   Returns zero if exponent is negative.
;   Saturates to 0x7FFF / 0x8000 on overflow.
;
; INPUTS:
;   FLOAT1    ; Float byte 0 (mantissa low)
;   FLOAT1 + 1    ; Float byte 1 (mantissa mid)
;   FLOAT1 + 2    ; Float byte 2 (mantissa high + exponent LSB)
;   FLOAT1 + 3    ; Float byte 3 (sign + exponent)
;
; OUTPUTS:
;   A : low byte of signed 16-bit integer.
;   X : high byte of signed 16-bit integer.
;
; DESTROY:
;   A, X, Y
;
; FLAGS AFFECTED:
;   (Z) - unpredictable value
;   (N) - unpredictable value
;   (C) - unpredictable value
;
; EXAMPLE:
;   ; Assuming FLOAT1-FLOAT1 + 3 contains 42C80000 (100.0)
;   jsr FLOAT_TO_INT
;   ; Result: A = 0x64 (low byte), X = 0x00 (high byte) -> 100
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************

FLOAT_TO_INT:
    ; Check if float is zero
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BEQ .RETURN_ZERO

    ; Extract exponent
    LDA FLOAT1 + 2
    ASL A
    LDA FLOAT1 + 3
    ROL A
    SEC
    SBC 0x7F    ; Remove bias
    BMI .RETURN_ZERO  ; If exponent < 0, result is zero

    ; Check if exponent is too large for 16-bit integer
    CMP 0x0F    ; Max shift for 16-bit number
    BPL .OVERFLOW

    ; Calculate shift count = 23 - exponent
    STA ITF_TMP      ; Save exponent temporarily
    LDA 0x17        ; 23
    SEC
    SBC ITF_TMP      ; 23 - exponent = number of right shifts needed
    TAY             ; Y = shift count

    ; Reconstruct significand: implicit leading 1 + mantissa bits from FLOAT1 + 2
    LDA FLOAT1 + 2
    AND 0x7F        ; Mask off exponent LSB, keep mantissa bits 22:16
    ORA 0x80        ; Set implicit leading 1 (bit 23)
    STA FLOAT_SIGN_TMP      ; High byte of 24-bit significand
    ; FLOAT1 + 1 and FLOAT1 already contain mantissa bits 15:0

    ; Shift significand right by Y positions to get integer value
.SHIFT_MANTISSA:
    CPY 0x00
    BEQ .CHECK_SIGN
    LSR FLOAT_SIGN_TMP      ; Shift high byte
    ROR FLOAT1 + 1      ; Shift mid byte
    ROR FLOAT1      ; Shift low byte
    DEY
    JMP .SHIFT_MANTISSA

.CHECK_SIGN:
    ; Check sign bit
    LDA FLOAT1 + 3
    AND 0x80
    BEQ .POSITIVE_NUMBER

    ; Negate if negative
    LDA FLOAT1
    EOR 0xFF
    CLC
    ADC 0x01
    STA FLOAT1
    LDA FLOAT1 + 1
    EOR 0xFF
    ADC 0x00
    STA FLOAT1 + 1

.POSITIVE_NUMBER:
    ; Prepare return values
    LDA FLOAT1     ; Low byte
    LDX FLOAT1 + 1     ; High byte
    RTS

.RETURN_ZERO:
    ; Return zero
    LDA 0x00
    TAX
    RTS

.OVERFLOW:
    ; Handle overflow (saturate to max/min 16-bit integer)
    LDA FLOAT1 + 3     ; Check sign bit
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

; 32-bit integer / float conversion memory: FLOAT_INT32 (in memmap.asm)

; **********************************************************
; SUBROUTINE: INT32_TO_FLOAT
;
; DESCRIPTION:
;   Converts a signed 32-bit integer (2's complement) to
;   IEEE 754 single precision float (32-bit).
;
; INPUTS:
;   FLOAT_INT32 (0x80F5) : byte 0 (LSB)
;   FLOAT_INT32 + 1 (0x80F6) : byte 1
;   FLOAT_INT32 + 2 (0x80F7) : byte 2
;   FLOAT_INT32 + 3 (0x80F8) : byte 3 (MSB, sign bit)
;
; OUTPUTS:
;   FLOAT1-FLOAT1 + 3 : Result float (standard float location)
;
; DESTROY:
;   A, X, Y
;
; EXAMPLE:
;   lda 0xA0          ; 100000 = 0x000186A0
;   sta FLOAT_INT32
;   lda 0x86
;   sta FLOAT_INT32 + 1
;   lda 0x01
;   sta FLOAT_INT32 + 2
;   lda 0x00
;   sta FLOAT_INT32 + 3
;   jsr INT32_TO_FLOAT ; float = 100000.0
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************
INT32_TO_FLOAT:
    ; Check for zero
    LDA FLOAT_INT32
    ORA FLOAT_INT32 + 1
    ORA FLOAT_INT32 + 2
    ORA FLOAT_INT32 + 3
    BNE .i32_nonzero

    ; Zero: return IEEE 754 zero
    STA FLOAT1
    STA FLOAT1 + 1
    STA FLOAT1 + 2
    STA FLOAT1 + 3
    RTS

.i32_nonzero:
    ; Extract and save sign
    LDA FLOAT_INT32 + 3
    AND 0x80
    STA FLOAT_SIGN_TMP              ; sign storage

    ; If negative, take absolute value (two's complement on 4 bytes)
    BEQ .i32_positive
    LDA FLOAT_INT32
    EOR 0xFF
    CLC
    ADC 0x01
    STA FLOAT_INT32
    LDA FLOAT_INT32 + 1
    EOR 0xFF
    ADC 0x00
    STA FLOAT_INT32 + 1
    LDA FLOAT_INT32 + 2
    EOR 0xFF
    ADC 0x00
    STA FLOAT_INT32 + 2
    LDA FLOAT_INT32 + 3
    EOR 0xFF
    ADC 0x00
    STA FLOAT_INT32 + 3

.i32_positive:
    ; Normalize: shift left until bit 7 of FLOAT_INT32 + 3 is set
    LDY 0x1F               ; max shifts = 31
    LDX 0x00               ; shift counter

.i32_norm_loop:
    LDA FLOAT_INT32 + 3
    BMI .i32_normalized     ; bit 7 set = leading 1 found
    ASL FLOAT_INT32
    ROL FLOAT_INT32 + 1
    ROL FLOAT_INT32 + 2
    ROL FLOAT_INT32 + 3
    INX
    DEY
    BPL .i32_norm_loop

.i32_normalized:
    ; Exponent = (31 XOR shift_count) + 127
    TXA
    EOR 0x1F
    CLC
    ADC 0x7F
    STA FLOAT1 + 3              ; biased exponent

    ; Shift out implicit leading 1, get top 23 mantissa bits
    ASL FLOAT_INT32
    ROL FLOAT_INT32 + 1
    ROL FLOAT_INT32 + 2
    ROL FLOAT_INT32 + 3

    ; Pack: B3=mantissa high, B2=mantissa mid, B1=mantissa low (B0 discarded)
    LDA FLOAT_INT32 + 3
    STA FLOAT1 + 2
    LDA FLOAT_INT32 + 2
    STA FLOAT1 + 1
    LDA FLOAT_INT32 + 1
    STA FLOAT1

    ; Right-shift chain to merge exponent LSB into mantissa
    LSR FLOAT1 + 3
    ROR FLOAT1 + 2
    ROR FLOAT1 + 1
    ROR FLOAT1

    ; Apply sign
    LDA FLOAT_SIGN_TMP
    BEQ .i32_done
    LDA FLOAT1 + 3
    ORA 0x80
    STA FLOAT1 + 3

.i32_done:
    RTS

; **********************************************************
; SUBROUTINE: FLOAT_TO_INT32
;
; DESCRIPTION:
;   Converts an IEEE 754 single precision float (32-bit)
;   to a signed 32-bit integer. Truncates toward zero.
;   Returns zero if exponent is negative.
;   Saturates to 0x7FFFFFFF / 0x80000000 on overflow.
;
; INPUTS:
;   FLOAT1-FLOAT1 + 3 : Float (standard float location)
;
; OUTPUTS:
;   FLOAT_INT32 (0x80F5) : byte 0 (LSB)
;   FLOAT_INT32 + 1 (0x80F6) : byte 1
;   FLOAT_INT32 + 2 (0x80F7) : byte 2
;   FLOAT_INT32 + 3 (0x80F8) : byte 3 (MSB, sign bit)
;
; DESTROY:
;   A, X, Y
;
; EXAMPLE:
;   ; Assuming float = 100000.0 at FLOAT1-FLOAT1 + 3
;   jsr FLOAT_TO_INT32
;   ; FLOAT_INT32-B3 = 0x000186A0 (100000)
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************
FLOAT_TO_INT32:
    ; Check for zero
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BEQ .fi32_return_zero

    ; Extract exponent
    LDA FLOAT1 + 2
    ASL A                   ; carry = exponent bit 0
    LDA FLOAT1 + 3
    ROL A                   ; A = full 8-bit biased exponent, carry = sign
    SEC
    SBC 0x7F                ; A = unbiased exponent (0-30 for valid range)
    BMI .fi32_return_zero   ; exponent < 0: value < 1.0

    ; Check overflow: exponent >= 31 can't fit in 32-bit signed
    CMP 0x1F
    BPL .fi32_overflow

    ; Save exponent to Y and sign to FLOAT_SIGN_TMP
    TAY                     ; Y = unbiased exponent
    LDA FLOAT1 + 3
    AND 0x80
    STA FLOAT_SIGN_TMP              ; sign

    ; Reconstruct 24-bit significand with implicit leading 1
    ; Place it at bits 31:8 of the 32-bit result (B3:B2:B1, B0=0)
    LDA FLOAT1 + 2
    AND 0x7F
    ORA 0x80
    STA FLOAT_INT32 + 3      ; high byte with implicit 1
    LDA FLOAT1 + 1
    STA FLOAT_INT32 + 2
    LDA FLOAT1
    STA FLOAT_INT32 + 1
    LDA 0x00
    STA FLOAT_INT32

    ; The significand occupies bits 31:8 (implicit 1 at bit 31)
    ; For exponent E, we need to shift right by (31 - E) to get the integer value
    ; shift_count = 31 - E
    LDA 0x1F                ; 31
    STY FLOAT_INT32      ; temp store Y (exponent) - will be overwritten by shift
    SEC
    SBC FLOAT_INT32      ; A = 31 - exponent
    TAX                     ; X = shift count

    ; Clear B0 again (was used as temp)
    LDA 0x00
    STA FLOAT_INT32

    ; If shift count is 0, no shifting needed
    CPX 0x00
    BEQ .fi32_check_sign

    ; Shift right X times
.fi32_shift:
    LSR FLOAT_INT32 + 3
    ROR FLOAT_INT32 + 2
    ROR FLOAT_INT32 + 1
    ROR FLOAT_INT32
    DEX
    BNE .fi32_shift

.fi32_check_sign:
    ; Apply sign (two's complement if negative)
    LDA FLOAT_SIGN_TMP
    BEQ .fi32_done

    ; Negate 32-bit value
    LDA FLOAT_INT32
    EOR 0xFF
    CLC
    ADC 0x01
    STA FLOAT_INT32
    LDA FLOAT_INT32 + 1
    EOR 0xFF
    ADC 0x00
    STA FLOAT_INT32 + 1
    LDA FLOAT_INT32 + 2
    EOR 0xFF
    ADC 0x00
    STA FLOAT_INT32 + 2
    LDA FLOAT_INT32 + 3
    EOR 0xFF
    ADC 0x00
    STA FLOAT_INT32 + 3

.fi32_done:
    RTS

.fi32_return_zero:
    LDA 0x00
    STA FLOAT_INT32
    STA FLOAT_INT32 + 1
    STA FLOAT_INT32 + 2
    STA FLOAT_INT32 + 3
    RTS

.fi32_overflow:
    ; Check sign for saturation direction
    LDA FLOAT1 + 3
    AND 0x80
    BNE .fi32_neg_overflow
    ; Positive overflow: 0x7FFFFFFF
    LDA 0xFF
    STA FLOAT_INT32
    STA FLOAT_INT32 + 1
    STA FLOAT_INT32 + 2
    LDA 0x7F
    STA FLOAT_INT32 + 3
    RTS
.fi32_neg_overflow:
    ; Negative overflow: 0x80000000
    LDA 0x00
    STA FLOAT_INT32
    STA FLOAT_INT32 + 1
    STA FLOAT_INT32 + 2
    LDA 0x80
    STA FLOAT_INT32 + 3
    RTS

; **********************************************************
; Float operand 2 memory locations
; **********************************************************
; FLOAT2 operand memory: FLOAT2 (in memmap.asm)

; **********************************************************
; SUBROUTINE: FLOAT_COPY_TO_F2
;
; DESCRIPTION:
;   Copy float from FLOAT1-FLOAT1 + 3 to FLOAT2 (0x80F0-0x80F3)
;   for use as second operand in FLOAT_MUL etc.
;
; DESTROY:
;   A
; **********************************************************
FLOAT_COPY_TO_F2:
    LDA FLOAT1
    STA FLOAT2
    LDA FLOAT1 + 1
    STA FLOAT2 + 1
    LDA FLOAT1 + 2
    STA FLOAT2 + 2
    LDA FLOAT1 + 3
    STA FLOAT2 + 3
    RTS

; **********************************************************
; SUBROUTINE: FLOAT_MUL
;
; DESCRIPTION:
;   Multiplies two IEEE 754 single precision floats.
;   Result = Float1 * Float2
;
; INPUTS:
;   FLOAT1-FLOAT1 + 3 : Float 1 (standard float location)
;   0x80F0-0x80F3 : Float 2 (second operand)
;
; OUTPUTS:
;   FLOAT1-FLOAT1 + 3 : Result (overwrites Float 1)
;
; DESTROY:
;   A, X, Y
;
; EXAMPLE:
;   lda 0x64          ; 100
;   ldx 0x00
;   jsr INT_TO_FLOAT  ; float1 = 100.0
;   jsr FLOAT_COPY_TO_F2  ; copy to float2
;   lda 0x0A          ; 10
;   ldx 0x00
;   jsr INT_TO_FLOAT  ; float1 = 10.0
;   jsr FLOAT_MUL     ; float1 = 10.0 * 100.0 = 1000.0
;   jsr FLOAT_TO_INT  ; A=0xE8, X=0x03 (1000)
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************

; Temporary storage for FLOAT_MUL
; MUL temp variables: FML_* (in memmap.asm)

FLOAT_MUL:
    ; --- Check for zero inputs ---
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BEQ .fmul_return_zero       ; float1 == 0

    LDA FLOAT2
    ORA FLOAT2 + 1
    ORA FLOAT2 + 2
    ORA FLOAT2 + 3
    BEQ .fmul_return_zero       ; float2 == 0

    ; --- Compute result sign (XOR of sign bits) ---
    LDA FLOAT1 + 3
    EOR FLOAT2 + 3
    AND 0x80
    STA FML_SIGN

    ; --- Extract exponent 1 ---
    LDA FLOAT1 + 2
    ASL A                       ; carry = exponent bit 0
    LDA FLOAT1 + 3
    ROL A                       ; A = full 8-bit exponent, carry = sign
    STA FML_EXP

    ; --- Extract exponent 2 and add ---
    LDA FLOAT2 + 2
    ASL A                       ; carry = exponent bit 0
    LDA FLOAT2 + 3
    ROL A                       ; A = full 8-bit exponent

    ; result_exp = exp1 + exp2 (16-bit)
    CLC
    ADC FML_EXP
    STA FML_EXP
    LDA 0x00
    ADC 0x00
    STA FML_EXP + 1              ; high byte of sum (0 or 1)

    ; Subtract bias (127)
    LDA FML_EXP
    SEC
    SBC 0x7F
    STA FML_EXP
    LDA FML_EXP + 1
    SBC 0x00
    STA FML_EXP + 1

    ; Check underflow (result_exp negative → high byte has bit 7 set)
    BMI .fmul_return_zero

    ; Check overflow (high byte > 0 means exp > 255)
    BNE .fmul_overflow

    ; Check if exponent >= 255
    LDA FML_EXP
    CMP 0xFF
    BCS .fmul_overflow

    ; --- Extract mantissa 1 with implicit leading 1 ---
    LDA FLOAT1 + 2
    AND 0x7F
    ORA 0x80
    STA FML_M1
    LDA FLOAT1 + 1
    STA FML_M1 + 1
    LDA FLOAT1
    STA FML_M1 + 2

    ; --- Extract mantissa 2 with implicit leading 1 ---
    LDA FLOAT2 + 2
    AND 0x7F
    ORA 0x80
    STA FML_M2
    LDA FLOAT2 + 1
    STA FML_M2 + 1
    LDA FLOAT2
    STA FML_M2 + 2

    ; --- Clear product accumulator R5:R4:R3:R2 ---
    LDA 0x00
    STA FML_RES
    STA FML_RES + 1
    STA FML_RES + 2
    STA FML_RES + 3

    ; --- 24x24 bit multiplication using 8 calls to MULTIPLY_INT ---
    ; Each MULTIPLY_INT: A(factor1) * X(factor2) → A(MSB):X(LSB)
    ; MULTIPLY_INT clobbers FLOAT1 + 2-FLOAT_SIGN_TMP but our mantissas are safe at 0x80E3-0x80E8

    ; Product 1: M1L * M2M → MSB to R2
    LDA FML_M1 + 2
    LDX FML_M2 + 1
    JSR MULTIPLY_INT            ; A=MSB, X=LSB
    STA FML_RES + 3                  ; R2 = MSB (LSB goes to R1, ignored)

    ; Product 2: M1M * M2L → MSB adds to R2 with carry to R3
    LDA FML_M1 + 1
    LDX FML_M2 + 2
    JSR MULTIPLY_INT
    CLC
    ADC FML_RES + 3
    STA FML_RES + 3
    LDA 0x00
    ADC FML_RES + 2
    STA FML_RES + 2

    ; Product 3: M1L * M2H → X(LSB) adds to R2, A(MSB) adds to R3
    LDA FML_M1 + 2
    LDX FML_M2
    JSR MULTIPLY_INT            ; A=MSB, X=LSB
    PHA                         ; save MSB
    TXA                         ; A=LSB
    CLC
    ADC FML_RES + 3
    STA FML_RES + 3
    PLA                         ; A=MSB
    ADC FML_RES + 2
    STA FML_RES + 2
    LDA 0x00
    ADC FML_RES + 1
    STA FML_RES + 1

    ; Product 4: M1M * M2M → X(LSB) adds to R2, A(MSB) adds to R3
    LDA FML_M1 + 1
    LDX FML_M2 + 1
    JSR MULTIPLY_INT
    PHA
    TXA
    CLC
    ADC FML_RES + 3
    STA FML_RES + 3
    PLA
    ADC FML_RES + 2
    STA FML_RES + 2
    LDA 0x00
    ADC FML_RES + 1
    STA FML_RES + 1

    ; Product 5: M1H * M2L → X(LSB) adds to R2, A(MSB) adds to R3
    LDA FML_M1
    LDX FML_M2 + 2
    JSR MULTIPLY_INT
    PHA
    TXA
    CLC
    ADC FML_RES + 3
    STA FML_RES + 3
    PLA
    ADC FML_RES + 2
    STA FML_RES + 2
    LDA 0x00
    ADC FML_RES + 1
    STA FML_RES + 1

    ; Product 6: M1M * M2H → X(LSB) adds to R3, A(MSB) adds to R4
    LDA FML_M1 + 1
    LDX FML_M2
    JSR MULTIPLY_INT
    PHA
    TXA
    CLC
    ADC FML_RES + 2
    STA FML_RES + 2
    PLA
    ADC FML_RES + 1
    STA FML_RES + 1
    LDA 0x00
    ADC FML_RES
    STA FML_RES

    ; Product 7: M1H * M2M → X(LSB) adds to R3, A(MSB) adds to R4
    LDA FML_M1
    LDX FML_M2 + 1
    JSR MULTIPLY_INT
    PHA
    TXA
    CLC
    ADC FML_RES + 2
    STA FML_RES + 2
    PLA
    ADC FML_RES + 1
    STA FML_RES + 1
    LDA 0x00
    ADC FML_RES
    STA FML_RES

    ; Product 8: M1H * M2H → X(LSB) adds to R4, A(MSB) adds to R5
    LDA FML_M1
    LDX FML_M2
    JSR MULTIPLY_INT
    PHA
    TXA
    CLC
    ADC FML_RES + 1
    STA FML_RES + 1
    PLA
    ADC FML_RES
    STA FML_RES

    ; --- Normalize ---
    ; Check if bit 47 (R5 bit 7) is set
    LDA FML_RES
    BMI .fmul_no_shift          ; bit 7 set → already normalized, exp += 1

    ; Bit 47 = 0: shift left to normalize (bit 46 must be set)
    ASL FML_RES + 3
    ROL FML_RES + 2
    ROL FML_RES + 1
    ROL FML_RES
    JMP .fmul_pack

.fmul_no_shift:
    ; Product overflowed to bit 47, increment exponent
    INC FML_EXP
    ; Check for exponent overflow after increment
    LDA FML_EXP
    CMP 0xFF
    BCS .fmul_overflow

.fmul_pack:
    ; --- Remove implicit leading 1 and pack into IEEE 754 ---
    ; Shift left to remove implicit 1 from R5 bit 7
    ASL FML_RES + 2
    ROL FML_RES + 1
    ROL FML_RES
    ; R5 = fraction[22:16], R4 = fraction[15:8], R3 = fraction[7:0]

    ; Pack: same method as INT_TO_FLOAT
    LDA FML_EXP
    STA FLOAT1 + 3                  ; exponent
    LDA FML_RES
    STA FLOAT1 + 2                  ; fraction high
    LDA FML_RES + 1
    STA FLOAT1 + 1                  ; fraction mid
    LDA FML_RES + 2
    STA FLOAT1                  ; fraction low

    ; Right-shift chain to merge exponent LSB into fraction
    LSR FLOAT1 + 3
    ROR FLOAT1 + 2
    ROR FLOAT1 + 1
    ROR FLOAT1

    ; Apply sign
    LDA FML_SIGN
    BEQ .fmul_done
    LDA FLOAT1 + 3
    ORA 0x80
    STA FLOAT1 + 3

.fmul_done:
    RTS

.fmul_return_zero:
    LDA 0x00
    STA FLOAT1
    STA FLOAT1 + 1
    STA FLOAT1 + 2
    STA FLOAT1 + 3
    RTS

.fmul_overflow:
    ; Return infinity (exponent = 0xFF, mantissa = 0, preserve sign)
    LDA FML_SIGN
    ORA 0x7F                    ; sign + exponent high bits = 0xFF or 0x7F
    STA FLOAT1 + 3
    LDA 0x80                    ; exponent LSB = 1 (0xFF exponent) + mantissa = 0
    STA FLOAT1 + 2
    LDA 0x00
    STA FLOAT1 + 1
    STA FLOAT1
    RTS

; **********************************************************
; SUBROUTINE: FLOAT_ADD
;
; DESCRIPTION:
;   Adds two IEEE 754 single precision floats.
;   Result = Float1 + Float2
;
; INPUTS:
;   FLOAT1-FLOAT1 + 3 : Float 1 (standard float location)
;   0x80F0-0x80F3 : Float 2 (second operand)
;
; OUTPUTS:
;   FLOAT1-FLOAT1 + 3 : Result (overwrites Float 1)
;
; DESTROY:
;   A, X, Y
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************

; Temporary storage for FLOAT_ADD (reuses FLOAT_MUL range - never called together)
; ADD temp variables: FAD_* (in memmap.asm)

FLOAT_ADD:
    ; Check if float1 is zero → result = float2
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BNE .fadd_check_f2
    ; Copy float2 to float1
    LDA FLOAT2
    STA FLOAT1
    LDA FLOAT2 + 1
    STA FLOAT1 + 1
    LDA FLOAT2 + 2
    STA FLOAT1 + 2
    LDA FLOAT2 + 3
    STA FLOAT1 + 3
    RTS

.fadd_check_f2:
    ; Check if float2 is zero → result = float1 (unchanged)
    LDA FLOAT2
    ORA FLOAT2 + 1
    ORA FLOAT2 + 2
    ORA FLOAT2 + 3
    BNE .fadd_extract
    RTS

.fadd_extract:
    ; Extract float1: sign, exponent, mantissa
    LDA FLOAT1 + 3
    AND 0x80
    STA FAD_SIGN1

    LDA FLOAT1 + 2
    ASL A
    LDA FLOAT1 + 3
    ROL A
    STA FAD_EXP1            ; biased exponent 1

    LDA FLOAT1 + 2
    AND 0x7F
    ORA 0x80
    STA FAD_M1
    LDA FLOAT1 + 1
    STA FAD_M1 + 1
    LDA FLOAT1
    STA FAD_M1 + 2

    ; Extract float2: sign, exponent, mantissa
    LDA FLOAT2 + 3
    AND 0x80
    STA FAD_SIGN2

    LDA FLOAT2 + 2
    ASL A
    LDA FLOAT2 + 3
    ROL A
    STA FAD_EXP2            ; biased exponent 2

    LDA FLOAT2 + 2
    AND 0x7F
    ORA 0x80
    STA FAD_M2
    LDA FLOAT2 + 1
    STA FAD_M2 + 1
    LDA FLOAT2
    STA FAD_M2 + 2

    ; Ensure exp1 >= exp2 (swap if needed)
    LDA FAD_EXP1
    CMP FAD_EXP2
    BCS .fadd_no_swap       ; exp1 >= exp2, no swap needed
    BCC .fadd_swap

.fadd_swap:
    ; Swap exponents
    LDA FAD_EXP1
    LDX FAD_EXP2
    STA FAD_EXP2
    STX FAD_EXP1
    ; Swap signs
    LDA FAD_SIGN1
    LDX FAD_SIGN2
    STA FAD_SIGN2
    STX FAD_SIGN1
    ; Swap mantissas
    LDA FAD_M1
    LDX FAD_M2
    STA FAD_M2
    STX FAD_M1
    LDA FAD_M1 + 1
    LDX FAD_M2 + 1
    STA FAD_M2 + 1
    STX FAD_M1 + 1
    LDA FAD_M1 + 2
    LDX FAD_M2 + 2
    STA FAD_M2 + 2
    STX FAD_M1 + 2

.fadd_no_swap:
    ; Now exp1 >= exp2. Shift mantissa2 right by (exp1 - exp2)
    LDA FAD_EXP1
    SEC
    SBC FAD_EXP2
    BEQ .fadd_aligned       ; same exponent, no shift needed
    CMP 0x18                ; if diff >= 24, mantissa2 shifts to 0
    BCS .fadd_m2_zero

    TAX                     ; X = shift count
.fadd_align_loop:
    LSR FAD_M2
    ROR FAD_M2 + 1
    ROR FAD_M2 + 2
    DEX
    BNE .fadd_align_loop
    JMP .fadd_aligned

.fadd_m2_zero:
    ; Mantissa2 is negligible, result = float1 (which is the larger one)
    ; Since we may have swapped, rebuild from current FAD state
    JMP .fadd_pack_m1

.fadd_aligned:
    ; Check if same sign or different sign
    LDA FAD_SIGN1
    EOR FAD_SIGN2
    BNE .fadd_subtract      ; different signs → subtract

    ; --- Same sign: ADD mantissas ---
    LDA FAD_M1 + 2
    CLC
    ADC FAD_M2 + 2
    STA FAD_M1 + 2
    LDA FAD_M1 + 1
    ADC FAD_M2 + 1
    STA FAD_M1 + 1
    LDA FAD_M1
    ADC FAD_M2
    STA FAD_M1
    LDA 0x00
    ADC 0x00
    STA FAD_CARRY           ; carry from bit 24

    ; If carry (bit 24 overflow), shift right and increment exponent
    LDA FAD_CARRY
    BEQ .fadd_pack_m1
    LSR FAD_M1
    ROR FAD_M1 + 1
    ROR FAD_M1 + 2
    ; Set bit 23 (the carry becomes the new implicit 1)
    LDA FAD_M1
    ORA 0x80
    STA FAD_M1
    INC FAD_EXP1
    JMP .fadd_pack_m1

.fadd_subtract:
    ; --- Different signs: SUBTRACT mantissa2 from mantissa1 ---
    ; Since exp1 >= exp2, and if exp1 > exp2 then m1 > m2 (after alignment)
    ; If exp1 == exp2, m1 might be < m2 → check and swap
    LDA FAD_EXP1
    CMP FAD_EXP2
    BNE .fadd_do_sub        ; exp1 > exp2 → m1 > m2 guaranteed

    ; exp1 == exp2: compare mantissas
    LDA FAD_M1
    CMP FAD_M2
    BCC .fadd_sub_swap      ; m1 < m2
    BNE .fadd_do_sub        ; m1 > m2
    LDA FAD_M1 + 1
    CMP FAD_M2 + 1
    BCC .fadd_sub_swap
    BNE .fadd_do_sub
    LDA FAD_M1 + 2
    CMP FAD_M2 + 2
    BCC .fadd_sub_swap
    BNE .fadd_do_sub

    ; m1 == m2 and different signs → result is zero
    JMP .fadd_return_zero

.fadd_sub_swap:
    ; m2 > m1 (same exponent): swap mantissas and use sign2 as result sign
    LDA FAD_M1
    LDX FAD_M2
    STA FAD_M2
    STX FAD_M1
    LDA FAD_M1 + 1
    LDX FAD_M2 + 1
    STA FAD_M2 + 1
    STX FAD_M1 + 1
    LDA FAD_M1 + 2
    LDX FAD_M2 + 2
    STA FAD_M2 + 2
    STX FAD_M1 + 2
    ; Result sign = sign2 (the larger mantissa)
    LDA FAD_SIGN2
    STA FAD_SIGN1

.fadd_do_sub:
    ; m1 >= m2: compute m1 - m2
    LDA FAD_M1 + 2
    SEC
    SBC FAD_M2 + 2
    STA FAD_M1 + 2
    LDA FAD_M1 + 1
    SBC FAD_M2 + 1
    STA FAD_M1 + 1
    LDA FAD_M1
    SBC FAD_M2
    STA FAD_M1

    ; Check for zero result
    LDA FAD_M1
    ORA FAD_M1 + 1
    ORA FAD_M1 + 2
    BEQ .fadd_return_zero

    ; Normalize: shift left until bit 7 of M1H is set
.fadd_norm_loop:
    LDA FAD_M1
    BMI .fadd_pack_m1       ; bit 7 set → normalized
    ASL FAD_M1 + 2
    ROL FAD_M1 + 1
    ROL FAD_M1
    DEC FAD_EXP1
    ; Check for exponent underflow
    LDA FAD_EXP1
    BEQ .fadd_return_zero   ; exponent hit 0 → underflow
    JMP .fadd_norm_loop

.fadd_pack_m1:
    ; Pack mantissa1 with exp1 and sign1 into IEEE 754
    ; Remove implicit 1
    ASL FAD_M1 + 2
    ROL FAD_M1 + 1
    ROL FAD_M1

    LDA FAD_EXP1
    STA FLOAT1 + 3
    LDA FAD_M1
    STA FLOAT1 + 2
    LDA FAD_M1 + 1
    STA FLOAT1 + 1
    LDA FAD_M1 + 2
    STA FLOAT1

    ; Right-shift chain to merge exponent LSB
    LSR FLOAT1 + 3
    ROR FLOAT1 + 2
    ROR FLOAT1 + 1
    ROR FLOAT1

    ; Apply sign
    LDA FAD_SIGN1
    BEQ .fadd_done
    LDA FLOAT1 + 3
    ORA 0x80
    STA FLOAT1 + 3

.fadd_done:
    RTS

.fadd_return_zero:
    LDA 0x00
    STA FLOAT1
    STA FLOAT1 + 1
    STA FLOAT1 + 2
    STA FLOAT1 + 3
    RTS

; **********************************************************
; SUBROUTINE: FLOAT_SUB
;
; DESCRIPTION:
;   Subtracts Float2 from Float1.
;   Result = Float1 - Float2
;   Implemented by flipping Float2 sign and calling FLOAT_ADD.
;
; INPUTS:
;   FLOAT1-FLOAT1 + 3 : Float 1
;   0x80F0-0x80F3 : Float 2
;
; OUTPUTS:
;   FLOAT1-FLOAT1 + 3 : Result
;
; DESTROY:
;   A, X, Y
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************
FLOAT_SUB:
    ; Flip sign bit of float2
    LDA FLOAT2 + 3
    EOR 0x80
    STA FLOAT2 + 3
    ; Call FLOAT_ADD
    JSR FLOAT_ADD
    ; Restore float2 sign (in case caller needs it unchanged)
    LDA FLOAT2 + 3
    EOR 0x80
    STA FLOAT2 + 3
    RTS

; **********************************************************
; SUBROUTINE: FLOAT_DIV
;
; DESCRIPTION:
;   Divides Float1 by Float2.
;   Result = Float1 / Float2
;   Uses long division on 24-bit mantissas.
;
; INPUTS:
;   FLOAT1-FLOAT1 + 3 : Float 1 (dividend)
;   0x80F0-0x80F3 : Float 2 (divisor)
;
; OUTPUTS:
;   FLOAT1-FLOAT1 + 3 : Result (overwrites Float 1)
;
; DESTROY:
;   A, X, Y
;
; EXAMPLE:
;   lda 0x0A
;   ldx 0x00
;   jsr INT_TO_FLOAT        ; float1 = 10.0
;   jsr FLOAT_COPY_TO_F2    ; float2 = 10.0
;   lda 0x64
;   ldx 0x00
;   jsr INT_TO_FLOAT        ; float1 = 100.0
;   jsr FLOAT_DIV            ; float1 = 100.0 / 10.0 = 10.0
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************

; Temporary storage for FLOAT_DIV (reuses FLOAT_MUL/ADD range)
; DIV temp variables: FDV_* (in memmap.asm)

FLOAT_DIV:
    ; Check for zero dividend → result = 0
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BEQ .fdiv_return_zero

    ; Check for zero divisor → return infinity (or just max value)
    LDA FLOAT2
    ORA FLOAT2 + 1
    ORA FLOAT2 + 2
    ORA FLOAT2 + 3
    BEQ .fdiv_overflow

    ; --- Compute result sign (XOR of sign bits) ---
    LDA FLOAT1 + 3
    EOR FLOAT2 + 3
    AND 0x80
    STA FDV_SIGN

    ; --- Extract exponent 1 ---
    LDA FLOAT1 + 2
    ASL A
    LDA FLOAT1 + 3
    ROL A
    STA FDV_EXP

    ; --- Extract exponent 2 and subtract ---
    LDA FLOAT2 + 2
    ASL A
    LDA FLOAT2 + 3
    ROL A
    ; result_exp = exp1 - exp2 + 127 (bias)
    STA FDV_EXP + 1              ; temp: exp2
    LDA FDV_EXP
    SEC
    SBC FDV_EXP + 1              ; A = exp1 - exp2 (may be negative)
    CLC
    ADC 0x7F                   ; A = exp1 - exp2 + 127
    STA FDV_EXP
    ; Check for underflow/overflow (simplified: if result is 0 or >= 255)
    BEQ .fdiv_return_zero
    CMP 0xFF
    BCS .fdiv_overflow

    ; --- Extract mantissa 1 with implicit leading 1 ---
    LDA FLOAT1 + 2
    AND 0x7F
    ORA 0x80
    STA FDV_M1
    LDA FLOAT1 + 1
    STA FDV_M1 + 1
    LDA FLOAT1
    STA FDV_M1 + 2

    ; --- Extract mantissa 2 with implicit leading 1 ---
    LDA FLOAT2 + 2
    AND 0x7F
    ORA 0x80
    STA FDV_M2
    LDA FLOAT2 + 1
    STA FDV_M2 + 1
    LDA FLOAT2
    STA FDV_M2 + 2

    ; --- 24-bit mantissa division: M1 / M2 → quotient in QH:QM:QL ---
    ; Remainder starts as M1. Each iteration: shift R left (25-bit),
    ; compare with M2, subtract if R >= M2 (set Q bit).
    ; Uses FDV_CARRY as bit 24 of the remainder for the shift overflow.

    ; Initialize: remainder = M1, quotient = 0, carry = 0
    LDA FDV_M1
    STA FDV_R
    LDA FDV_M1 + 1
    STA FDV_R + 1
    LDA FDV_M1 + 2
    STA FDV_R + 2
    LDA 0x00
    STA FDV_Q
    STA FDV_Q + 1
    STA FDV_Q + 2
    STA FDV_CARRY               ; no overflow initially

    LDY 0x18                    ; 24 quotient bits

.fdiv_div_loop:
    ; Shift quotient left (make room for next bit)
    ASL FDV_Q + 2
    ROL FDV_Q + 1
    ROL FDV_Q

    ; Compare: if carry bit (25th) is set, R > M2 definitely
    LDA FDV_CARRY
    BNE .fdiv_do_sub

    ; 24-bit compare: R vs M2
    LDA FDV_R
    CMP FDV_M2
    BCC .fdiv_no_sub
    BNE .fdiv_do_sub
    LDA FDV_R + 1
    CMP FDV_M2 + 1
    BCC .fdiv_no_sub
    BNE .fdiv_do_sub
    LDA FDV_R + 2
    CMP FDV_M2 + 2
    BCC .fdiv_no_sub

.fdiv_do_sub:
    ; R >= M2: subtract and set quotient bit
    LDA FDV_R + 2
    SEC
    SBC FDV_M2 + 2
    STA FDV_R + 2
    LDA FDV_R + 1
    SBC FDV_M2 + 1
    STA FDV_R + 1
    LDA FDV_R
    SBC FDV_M2
    STA FDV_R
    INC FDV_Q + 2

.fdiv_no_sub:
    ; Shift remainder left by 1 (25-bit: capture overflow in FAD_CARRY)
    ASL FDV_R + 2
    ROL FDV_R + 1
    ROL FDV_R
    LDA 0x00
    ROL A
    STA FDV_CARRY

    DEY
    BNE .fdiv_div_loop

    ; --- Check if quotient needs normalization ---
    ; If Q bit 23 is set → normalized. If not → shift left, decrement exp
    LDA FDV_Q
    BMI .fdiv_q_normalized

    ASL FDV_Q + 2
    ROL FDV_Q + 1
    ROL FDV_Q
    DEC FDV_EXP

.fdiv_q_normalized:
    ; --- Quotient is in QH:QM:QL with implicit 1 at bit 23 ---
    ; Pack into IEEE 754

    ; Remove implicit 1
    ASL FDV_Q + 2
    ROL FDV_Q + 1
    ROL FDV_Q

    LDA FDV_EXP
    STA FLOAT1 + 3
    LDA FDV_Q
    STA FLOAT1 + 2
    LDA FDV_Q + 1
    STA FLOAT1 + 1
    LDA FDV_Q + 2
    STA FLOAT1

    ; Right-shift chain to merge exponent LSB
    LSR FLOAT1 + 3
    ROR FLOAT1 + 2
    ROR FLOAT1 + 1
    ROR FLOAT1

    ; Apply sign
    LDA FDV_SIGN
    BEQ .fdiv_done
    LDA FLOAT1 + 3
    ORA 0x80
    STA FLOAT1 + 3

.fdiv_done:
    RTS

.fdiv_return_zero:
    LDA 0x00
    STA FLOAT1
    STA FLOAT1 + 1
    STA FLOAT1 + 2
    STA FLOAT1 + 3
    RTS

.fdiv_overflow:
    ; Return infinity (preserve sign)
    LDA FDV_SIGN
    ORA 0x7F
    STA FLOAT1 + 3
    LDA 0x80
    STA FLOAT1 + 2
    LDA 0x00
    STA FLOAT1 + 1
    STA FLOAT1
    RTS

; **********************************************************
; SUBROUTINE: FLOAT_READ
;
; DESCRIPTION:
;   Reads a decimal number from serial input and converts
;   it to IEEE 754 single precision float.
;   Input format: [-][digits][.digits] terminated by CR (0x0D).
;   Characters are echoed back to serial as they are typed.
;   Max ~5 total significant digits (16-bit accumulator).
;
; INPUTS:
;   Characters from serial via ACIA_READ_CHAR
;
; OUTPUTS:
;   FLOAT1-FLOAT1 + 3 : Parsed float (standard float location)
;
; DESTROY:
;   A, X, Y, D, E
;
; EXAMPLE:
;   jsr FLOAT_READ   ; user types "3.14" + CR
;   ; FLOAT1-FLOAT1 + 3 now contains ~3.14 in IEEE 754
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************

; Temporary storage for FLOAT_READ (32-bit accumulator)
; FLOAT_READ temp variables: FR_* (in memmap.asm)

FLOAT_READ:
    ; Initialize
    LDA 0x00
    STA FR_VALUE
    STA FR_VALUE + 1
    STA FR_VALUE + 2
    STA FR_VALUE + 3
    STA FR_FRAC_CNT
    STA FR_SIGN
    STA FR_HAS_DOT

    ; Read first character
    JSR ACIA_READ_CHAR
    JSR ACIA_SEND_CHAR          ; echo

    ; Check for '-'
    CMP 0x2D
    BNE .fr_check_char
    LDA 0x80
    STA FR_SIGN
    JSR ACIA_READ_CHAR
    JSR ACIA_SEND_CHAR          ; echo

.fr_check_char:
    ; CR? done
    CMP 0x0D
    BEQ .fr_parse_done

    ; '.'?
    CMP 0x2E
    BNE .fr_check_digit
    LDA 0x01
    STA FR_HAS_DOT
    JMP .fr_read_next

.fr_check_digit:
    ; Must be '0'-'9'
    CMP 0x30
    BCC .fr_read_next           ; < '0', ignore
    CMP 0x3A
    BCS .fr_read_next           ; > '9', ignore

    ; Convert ASCII to digit value
    SEC
    SBC 0x30
    STA FR_DIGIT

    ; Overflow protection: skip digit if value * 10 + 9 > 2147483647
    ; Safe limit: MSB (B3) >= 0x0D means value >= 218103808, * 10 overflows
    ; Simplified: if B3 >= 0x0D, skip
    LDA FR_VALUE + 3
    CMP 0x0D
    BCS .fr_read_next

.fr_accumulate:
    ; Multiply current value by 10 (32-bit)
    JSR .fr_mul10_32

    ; Add digit to value (32-bit)
    LDA FR_VALUE
    CLC
    ADC FR_DIGIT
    STA FR_VALUE
    LDA FR_VALUE + 1
    ADC 0x00
    STA FR_VALUE + 1
    LDA FR_VALUE + 2
    ADC 0x00
    STA FR_VALUE + 2
    LDA FR_VALUE + 3
    ADC 0x00
    STA FR_VALUE + 3

    ; If past decimal point, increment fractional digit count
    LDA FR_HAS_DOT
    BEQ .fr_read_next
    INC FR_FRAC_CNT

.fr_read_next:
    JSR ACIA_READ_CHAR
    JSR ACIA_SEND_CHAR          ; echo
    JMP .fr_check_char

.fr_parse_done:
    ; Convert accumulated 32-bit integer to float
    LDA FR_VALUE
    STA FLOAT_INT32
    LDA FR_VALUE + 1
    STA FLOAT_INT32 + 1
    LDA FR_VALUE + 2
    STA FLOAT_INT32 + 2
    LDA FR_VALUE + 3
    STA FLOAT_INT32 + 3
    JSR INT32_TO_FLOAT

    ; Apply sign
    LDA FR_SIGN
    BEQ .fr_no_sign
    LDA FLOAT1 + 3
    ORA 0x80
    STA FLOAT1 + 3
.fr_no_sign:

    ; Divide by 10^frac_cnt using repeated FLOAT_MUL with 0.1
    LDA FR_FRAC_CNT
    BEQ .fr_read_done

    ; Setup 0.1 in FLOAT2 (IEEE 754: 0x3DCCCCCD)
    LDA 0xCD
    STA FLOAT2
    LDA 0xCC
    STA FLOAT2 + 1
    LDA 0xCC
    STA FLOAT2 + 2
    LDA 0x3D
    STA FLOAT2 + 3

.fr_div_loop:
    JSR FLOAT_MUL
    DEC FR_FRAC_CNT
    BNE .fr_div_loop

.fr_read_done:
    RTS

; Helper: multiply FR_VALUE (32-bit) by 10
; value * 10 = (value * 4 + value) * 2 = value * 5 * 2
.fr_mul10_32:
    ; Save original value
    LDA FR_VALUE
    STA FR_TMP
    LDA FR_VALUE + 1
    STA FR_TMP + 1
    LDA FR_VALUE + 2
    STA FR_TMP + 2
    LDA FR_VALUE + 3
    STA FR_TMP + 3

    ; value << 2 (multiply by 4)
    ASL FR_VALUE
    ROL FR_VALUE + 1
    ROL FR_VALUE + 2
    ROL FR_VALUE + 3
    ASL FR_VALUE
    ROL FR_VALUE + 1
    ROL FR_VALUE + 2
    ROL FR_VALUE + 3

    ; Add original (value*4 + value = value*5)
    LDA FR_VALUE
    CLC
    ADC FR_TMP
    STA FR_VALUE
    LDA FR_VALUE + 1
    ADC FR_TMP + 1
    STA FR_VALUE + 1
    LDA FR_VALUE + 2
    ADC FR_TMP + 2
    STA FR_VALUE + 2
    LDA FR_VALUE + 3
    ADC FR_TMP + 3
    STA FR_VALUE + 3

    ; Shift left 1 (value*5 * 2 = value*10)
    ASL FR_VALUE
    ROL FR_VALUE + 1
    ROL FR_VALUE + 2
    ROL FR_VALUE + 3

    RTS

; **********************************************************
; SUBROUTINE: FLOAT_PRINT
;
; DESCRIPTION:
;   Prints an IEEE 754 float as a decimal string to serial.
;   Format: [-]integer.fraction
;   Limited to values that fit in a signed 16-bit integer part
;   (approx -32768 to 32767).
;
; INPUTS:
;   FLOAT1-FLOAT1 + 3 : Float to print (standard float location)
;   Y : Number of decimal places (0-6)
;
; OUTPUTS:
;   Decimal string sent to serial via ACIA
;
; DESTROY:
;   A, X, Y, D, E
;
; EXAMPLE:
;   lda 0x64
;   ldx 0x00
;   jsr INT_TO_FLOAT    ; float = 100.0
;   ldy 0x02
;   jsr FLOAT_PRINT     ; prints "100.00"
;
; AUTHOR: VN
; LAST UPDATE: 23/03/2026
; **********************************************************

; Temporary storage for FLOAT_PRINT
; FLOAT_PRINT temp variables: FP_* (in memmap.asm)

FLOAT_PRINT:
    STY FP_DECIMALS

    ; Check zero
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BNE .fpr_not_zero

    ; Print "0" and decimal zeros
    LDA 0x30
    JSR ACIA_SEND_CHAR
    LDA FP_DECIMALS
    BEQ .fpr_done
    LDA 0x2E
    JSR ACIA_SEND_CHAR
.fpr_zero_dec:
    LDA 0x30
    JSR ACIA_SEND_CHAR
    DEC FP_DECIMALS
    BNE .fpr_zero_dec
    JMP .fpr_done

.fpr_not_zero:
    ; Check sign
    LDA FLOAT1 + 3
    BPL .fpr_positive
    ; Print "-"
    LDA 0x2D
    JSR ACIA_SEND_CHAR
    ; Clear sign bit (make positive)
    LDA FLOAT1 + 3
    AND 0x7F
    STA FLOAT1 + 3

.fpr_positive:
    ; Save positive float
    LDA FLOAT1
    STA FP_SAVE
    LDA FLOAT1 + 1
    STA FP_SAVE + 1
    LDA FLOAT1 + 2
    STA FP_SAVE + 2
    LDA FLOAT1 + 3
    STA FP_SAVE + 3

    ; Get integer part (32-bit)
    JSR FLOAT_TO_INT32

    ; Print integer part using ACIA_SEND_DECIMAL32
    LDA FLOAT_INT32
    STA BINDEC32_VALUE
    LDA FLOAT_INT32 + 1
    STA BINDEC32_VALUE + 1
    LDA FLOAT_INT32 + 2
    STA BINDEC32_VALUE + 2
    LDA FLOAT_INT32 + 3
    STA BINDEC32_VALUE + 3
    JSR ACIA_SEND_DECIMAL32

    ; Check if decimals needed
    LDA FP_DECIMALS
    BEQ .fpr_done

    ; Print "."
    LDA 0x2E
    JSR ACIA_SEND_CHAR

    ; Restore float
    LDA FP_SAVE
    STA FLOAT1
    LDA FP_SAVE + 1
    STA FLOAT1 + 1
    LDA FP_SAVE + 2
    STA FLOAT1 + 2
    LDA FP_SAVE + 3
    STA FLOAT1 + 3

    ; Extract fractional part: zero the integer bits from the float
    ; so we only have 0.xxxx remaining
    JSR .fpr_float_frac

    ; Setup 10.0 in FLOAT2 (IEEE 754: 0x41200000)
    LDA 0x00
    STA FLOAT2
    STA FLOAT2 + 1
    LDA 0x20
    STA FLOAT2 + 2
    LDA 0x41
    STA FLOAT2 + 3

    ; Extract fractional digits by repeated multiply-by-10
    ; After FLOAT_FRAC, float is 0 <= f < 1.0
    ; After *10, float is 0 <= f < 10.0
    ; FLOAT_TO_INT gives digit 0-9 (always fits in 8-bit)
.fpr_digit_loop:
    JSR FLOAT_MUL               ; float *= 10.0 (result is 0..9.xxx)

    ; Save float (FLOAT_TO_INT modifies FLOAT1/FC)
    LDA FLOAT1
    STA FP_SAVE
    LDA FLOAT1 + 1
    STA FP_SAVE + 1
    LDA FLOAT1 + 2
    STA FP_SAVE + 2
    LDA FLOAT1 + 3
    STA FP_SAVE + 3

    ; Get integer of scaled value (always 0-9)
    JSR FLOAT_TO_INT            ; A=digit (0-9), X=0

    ; Print digit
    CLC
    ADC 0x30
    JSR ACIA_SEND_CHAR

    ; Restore float and remove integer part for next iteration
    LDA FP_SAVE
    STA FLOAT1
    LDA FP_SAVE + 1
    STA FLOAT1 + 1
    LDA FP_SAVE + 2
    STA FLOAT1 + 2
    LDA FP_SAVE + 3
    STA FLOAT1 + 3
    JSR .fpr_float_frac         ; keep only fractional part

    DEC FP_DECIMALS
    BNE .fpr_digit_loop

.fpr_done:
    RTS

; Helper: extract fractional part of float (remove integer part)
; Input/Output: FLOAT1-FLOAT1 + 3
; After call, 0 <= float < 1.0
; Destroys: A, X, Y
.fpr_float_frac:
    ; Extract unbiased exponent
    LDA FLOAT1 + 2
    ASL A
    LDA FLOAT1 + 3
    ROL A                       ; A = biased exponent
    SEC
    SBC 0x7F                    ; A = unbiased exponent
    BMI .frac_keep              ; E < 0: entire number is fraction, keep as-is
    CMP 0x17                    ; 23
    BCS .frac_set_zero          ; E >= 23: no fractional part

    ; Save sign and exponent
    TAX                         ; X = unbiased exponent (0-22)
    LDA FLOAT1 + 3
    AND 0x80
    STA FP_TEMP                 ; save sign bit

    ; Reconstruct significand with implicit 1
    LDA FLOAT1 + 2
    AND 0x7F
    ORA 0x80
    STA FLOAT1 + 2                  ; high byte with implicit 1
    ; FLOAT1 + 1, FLOAT1 already have mid/low bytes

    ; Shift left by (E+1) to discard integer bits
    INX                         ; X = E+1
.frac_shift_out:
    ASL FLOAT1
    ROL FLOAT1 + 1
    ROL FLOAT1 + 2
    DEX
    BNE .frac_shift_out

    ; Check if anything remains
    LDA FLOAT1 + 2
    ORA FLOAT1 + 1
    ORA FLOAT1
    BEQ .frac_set_zero          ; all fraction bits were 0

    ; Renormalize: shift left until bit 7 of FLOAT1 + 2 is set
    LDY 0x00                    ; normalize shift counter
.frac_normalize:
    LDA FLOAT1 + 2
    BMI .frac_norm_done         ; leading 1 found at bit 7
    ASL FLOAT1
    ROL FLOAT1 + 1
    ROL FLOAT1 + 2
    INY
    CPY 0x18                    ; safety: max 24 shifts
    BEQ .frac_set_zero
    JMP .frac_normalize

.frac_norm_done:
    ; New biased exponent = 126 - Y
    ; (original frac starts at 2^(-1), each normalize shift decreases by 1)
    LDA 0x7E                    ; 126
    STY FP_SAVE              ; temp store Y
    SEC
    SBC FP_SAVE              ; A = 126 - Y = new biased exponent
    STA FLOAT1 + 3                  ; store exponent

    ; Remove implicit 1 and pack
    ASL FLOAT1
    ROL FLOAT1 + 1
    ROL FLOAT1 + 2                  ; shift out implicit 1

    ; Right-shift to merge exponent LSB into mantissa
    LSR FLOAT1 + 3
    ROR FLOAT1 + 2
    ROR FLOAT1 + 1
    ROR FLOAT1

    ; Restore sign
    LDA FP_TEMP
    BEQ .frac_keep
    LDA FLOAT1 + 3
    ORA 0x80
    STA FLOAT1 + 3

.frac_keep:
    RTS

.frac_set_zero:
    LDA 0x00
    STA FLOAT1
    STA FLOAT1 + 1
    STA FLOAT1 + 2
    STA FLOAT1 + 3
    RTS

; **********************************************************
; TESTS START HERE
;

FLOAT_test:
;   Test #F1: INT_TO_FLOAT(1) = 0x3F800000
    LDA 0x01
    LDX 0x00
    JSR INT_TO_FLOAT
    LDA FLOAT1 + 3
    CMP 0x3F
    BNE .fail
    LDA FLOAT1 + 2
    CMP 0x80
    BNE .fail
    LDA FLOAT1 + 1
    BNE .fail
    LDA FLOAT1
    BNE .fail

;   Test #F2: INT_TO_FLOAT(0) = 0x00000000
    LDA 0x00
    LDX 0x00
    JSR INT_TO_FLOAT
    LDA FLOAT1 + 3
    BNE .fail
    LDA FLOAT1 + 2
    BNE .fail
    LDA FLOAT1 + 1
    BNE .fail
    LDA FLOAT1
    BNE .fail

;   Test #F3: INT_TO_FLOAT(-1) = 0xBF800000
    LDA 0xFF
    LDX 0xFF
    JSR INT_TO_FLOAT
    LDA FLOAT1 + 3
    CMP 0xBF
    BNE .fail
    LDA FLOAT1 + 2
    CMP 0x80
    BNE .fail
    LDA FLOAT1 + 1
    BNE .fail
    LDA FLOAT1
    BNE .fail

;   Test #F4: Roundtrip INT_TO_FLOAT(100) -> FLOAT_TO_INT = 0x0064
    LDA 0x64
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_TO_INT
    CMP 0x64
    BNE .fail
    CPX 0x00
    BNE .fail

;   Test #F5: Roundtrip INT_TO_FLOAT(1000) -> FLOAT_TO_INT = 0x03E8
    LDA 0xE8
    LDX 0x03
    JSR INT_TO_FLOAT
    JSR FLOAT_TO_INT
    CMP 0xE8
    BNE .fail
    CPX 0x03
    BNE .fail

    ; --- FLOAT_MUL tests ---

;   Test #FM1: 1.0 * 1.0 = 1.0 → roundtrip = 1
    LDA 0x01
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    JSR FLOAT_MUL
    JSR FLOAT_TO_INT
    CMP 0x01
    BNE .fail
    CPX 0x00
    BNE .fail

;   Test #FM2: 2.0 * 3.0 = 6.0 → roundtrip = 6
    LDA 0x02
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    LDA 0x03
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_MUL
    JSR FLOAT_TO_INT
    CMP 0x06
    BNE .fail
    CPX 0x00
    BNE .fail

;   Test #FM3: 100.0 * 10.0 = 1000.0 → roundtrip = 0x03E8
    LDA 0x64
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    LDA 0x0A
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_MUL
    JSR FLOAT_TO_INT
    CMP 0xE8
    BNE .fail
    CPX 0x03
    BNE .fail

;   Test #FM4: -5.0 * 4.0 = -20.0 → roundtrip = -20 (0xFFEC)
    LDA 0xFB
    LDX 0xFF
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    LDA 0x04
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_MUL
    JSR FLOAT_TO_INT
    CMP 0xEC
    BNE .fail
    CPX 0xFF
    BNE .fail

;   Test #FM5: 0 * 42.0 = 0
    LDA 0x2A
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    LDA 0x00
    STA FLOAT1
    STA FLOAT1 + 1
    STA FLOAT1 + 2
    STA FLOAT1 + 3
    JSR FLOAT_MUL
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BNE .fail

    ; --- INT32_TO_FLOAT / FLOAT_TO_INT32 tests ---

;   Test #FI32_1: INT32_TO_FLOAT(100000) → FLOAT_TO_INT32 roundtrip
;   100000 = 0x000186A0
    LDA 0xA0
    STA FLOAT_INT32
    LDA 0x86
    STA FLOAT_INT32 + 1
    LDA 0x01
    STA FLOAT_INT32 + 2
    LDA 0x00
    STA FLOAT_INT32 + 3
    JSR INT32_TO_FLOAT
    JSR FLOAT_TO_INT32
    LDA FLOAT_INT32
    CMP 0xA0
    BNE .fail
    LDA FLOAT_INT32 + 1
    CMP 0x86
    BNE .fail
    LDA FLOAT_INT32 + 2
    CMP 0x01
    BNE .fail
    LDA FLOAT_INT32 + 3
    CMP 0x00
    BNE .fail

;   Test #FI32_2: INT32_TO_FLOAT(1000000) → roundtrip
;   1000000 = 0x000F4240
    LDA 0x40
    STA FLOAT_INT32
    LDA 0x42
    STA FLOAT_INT32 + 1
    LDA 0x0F
    STA FLOAT_INT32 + 2
    LDA 0x00
    STA FLOAT_INT32 + 3
    JSR INT32_TO_FLOAT
    JSR FLOAT_TO_INT32
    LDA FLOAT_INT32
    CMP 0x40
    BNE .fail
    LDA FLOAT_INT32 + 1
    CMP 0x42
    BNE .fail
    LDA FLOAT_INT32 + 2
    CMP 0x0F
    BNE .fail
    LDA FLOAT_INT32 + 3
    CMP 0x00
    BNE .fail

;   Test #FI32_3: INT32_TO_FLOAT(-50000) → roundtrip
;   -50000 = 0xFFFF3CB0
    LDA 0xB0
    STA FLOAT_INT32
    LDA 0x3C
    STA FLOAT_INT32 + 1
    LDA 0xFF
    STA FLOAT_INT32 + 2
    STA FLOAT_INT32 + 3
    JSR INT32_TO_FLOAT
    JSR FLOAT_TO_INT32
    LDA FLOAT_INT32
    CMP 0xB0
    BNE .fail
    LDA FLOAT_INT32 + 1
    CMP 0x3C
    BNE .fail
    LDA FLOAT_INT32 + 2
    CMP 0xFF
    BNE .fail
    LDA FLOAT_INT32 + 3
    CMP 0xFF
    BNE .fail

;   Test #FI32_4: INT32_TO_FLOAT(0) → should give zero float
    LDA 0x00
    STA FLOAT_INT32
    STA FLOAT_INT32 + 1
    STA FLOAT_INT32 + 2
    STA FLOAT_INT32 + 3
    JSR INT32_TO_FLOAT
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BNE .fail

    ; --- FLOAT_ADD tests ---

;   Test #FA1: 1.0 + 2.0 = 3.0 → roundtrip = 3
    LDA 0x02
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2        ; float2 = 2.0
    LDA 0x01
    LDX 0x00
    JSR INT_TO_FLOAT            ; float1 = 1.0
    JSR FLOAT_ADD               ; 1.0 + 2.0 = 3.0
    JSR FLOAT_TO_INT
    CMP 0x03
    BNE .fail
    CPX 0x00
    BNE .fail

;   Test #FA2: 100.0 + 200.0 = 300.0
    LDA 0xC8
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2        ; float2 = 200.0
    LDA 0x64
    LDX 0x00
    JSR INT_TO_FLOAT            ; float1 = 100.0
    JSR FLOAT_ADD               ; 100.0 + 200.0 = 300.0
    JSR FLOAT_TO_INT
    CMP 0x2C                    ; 300 = 0x012C
    BNE .fail
    CPX 0x01
    BNE .fail

;   Test #FA3: 5.0 + (-3.0) = 2.0 (different signs)
    LDA 0xFD                    ; -3
    LDX 0xFF
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2        ; float2 = -3.0
    LDA 0x05
    LDX 0x00
    JSR INT_TO_FLOAT            ; float1 = 5.0
    JSR FLOAT_ADD               ; 5.0 + (-3.0) = 2.0
    JSR FLOAT_TO_INT
    CMP 0x02
    BNE .fail
    CPX 0x00
    BNE .fail

;   Test #FA4: -10.0 + 10.0 = 0.0
    LDA 0x0A
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2        ; float2 = 10.0
    LDA 0xF6                    ; -10
    LDX 0xFF
    JSR INT_TO_FLOAT            ; float1 = -10.0
    JSR FLOAT_ADD               ; -10.0 + 10.0 = 0.0
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BNE .fail

;   Test #FA5: 0.0 + 42.0 = 42.0
    LDA 0x2A
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2        ; float2 = 42.0
    LDA 0x00
    STA FLOAT1
    STA FLOAT1 + 1
    STA FLOAT1 + 2
    STA FLOAT1 + 3                  ; float1 = 0.0
    JSR FLOAT_ADD               ; 0.0 + 42.0 = 42.0
    JSR FLOAT_TO_INT
    CMP 0x2A
    BNE .fail
    CPX 0x00
    BNE .fail

    ; --- FLOAT_SUB tests ---

;   Test #FS1: 10.0 - 3.0 = 7.0
    LDA 0x03
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2        ; float2 = 3.0
    LDA 0x0A
    LDX 0x00
    JSR INT_TO_FLOAT            ; float1 = 10.0
    JSR FLOAT_SUB               ; 10.0 - 3.0 = 7.0
    JSR FLOAT_TO_INT
    CMP 0x07
    BNE .fail
    CPX 0x00
    BNE .fail

;   Test #FS2: 3.0 - 10.0 = -7.0
    LDA 0x0A
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2        ; float2 = 10.0
    LDA 0x03
    LDX 0x00
    JSR INT_TO_FLOAT            ; float1 = 3.0
    JSR FLOAT_SUB               ; 3.0 - 10.0 = -7.0
    JSR FLOAT_TO_INT
    CMP 0xF9                    ; -7 low byte
    BNE .fail
    CPX 0xFF                    ; -7 high byte
    BNE .fail

;   Test #FS3: 100.0 - 100.0 = 0.0
    LDA 0x64
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    JSR FLOAT_SUB
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BNE .fail

    ; --- FLOAT_DIV tests ---

;   Test #FD1: 100.0 / 10.0 = 10.0
    LDA 0x0A
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    LDA 0x64
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_DIV
    JSR FLOAT_TO_INT
    CMP 0x0A
    BNE .fail
    CPX 0x00
    BNE .fail

;   Test #FD2: 1.0 / 2.0 = 0.5 (0x3F000000)
    LDA 0x02
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    LDA 0x01
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_DIV
    LDA FLOAT1 + 3
    CMP 0x3F
    BNE .fail
    LDA FLOAT1 + 2
    BNE .fail
    LDA FLOAT1 + 1
    BNE .fail
    LDA FLOAT1
    BNE .fail

;   Test #FD3: -20.0 / 4.0 = -5.0
    LDA 0x04
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    LDA 0xEC
    LDX 0xFF
    JSR INT_TO_FLOAT
    JSR FLOAT_DIV
    JSR FLOAT_TO_INT
    CMP 0xFB
    BNE .fail
    CPX 0xFF
    BNE .fail

;   Test #FD4: 7.0 / 7.0 = 1.0
    LDA 0x07
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    JSR FLOAT_DIV
    JSR FLOAT_TO_INT
    CMP 0x01
    BNE .fail
    CPX 0x00
    BNE .fail

;   Test #FD5: 0.0 / 42.0 = 0.0
    LDA 0x2A
    LDX 0x00
    JSR INT_TO_FLOAT
    JSR FLOAT_COPY_TO_F2
    LDA 0x00
    STA FLOAT1
    STA FLOAT1 + 1
    STA FLOAT1 + 2
    STA FLOAT1 + 3
    JSR FLOAT_DIV
    LDA FLOAT1
    ORA FLOAT1 + 1
    ORA FLOAT1 + 2
    ORA FLOAT1 + 3
    BNE .fail


    RTS

.fail:
    LDO 0xFB
    HLT
