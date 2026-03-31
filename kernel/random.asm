; **********************************************************
; RANDOM NUMBER GENERATOR
;
; LFSR (Linear Feedback Shift Register) Galois 16-bit
; Polynomial: x^16 + x^14 + x^13 + x^11 + 1 (0xB400)
; Period: 65535 (all values except 0)
;
; RAM variables defined in memmap.asm:
;   RANDOM_STATE (2 bytes) - 16-bit LFSR state
;
; **********************************************************

#once
#bank kernel

; **********************************************************
; SUBROUTINE: RANDOM_SEED
;
; Initializes the LFSR state from timer counters and
; hardware xorshift RNG. Ensures state is never zero.
;
; INPUTS:  none
; OUTPUTS: none
; DESTROY: A
; **********************************************************

RANDOM_SEED:
    lda INT_TIMER_COUNTER_LSB
    eor 0x37
    sta RANDOM_STATE
    lda INT_TIMER_COUNTER_MSB
    eor 0xA5
    sta RANDOM_STATE + 1
    ; Ensure state is not zero (LFSR would lock up)
    lda RANDOM_STATE
    ora RANDOM_STATE + 1
    bne .random_seed_done
    lda 0x01
    sta RANDOM_STATE
.random_seed_done:
    rts

; **********************************************************
; SUBROUTINE: RANDOM_BYTE
;
; Advances the 16-bit LFSR and returns a pseudo-random byte.
; XORs with timer counter LSB for decorrelation.
;
; INPUTS:  none
; OUTPUTS: A = pseudo-random byte (0-255)
; DESTROY: A
; FLAGS:   Z, N
; **********************************************************

RANDOM_BYTE:
    pha
    lda RANDOM_STATE
    and 0x01
    beq .random_no_feedback
    ; Shift right: MSB first
    lsr RANDOM_STATE + 1
    ror RANDOM_STATE
    ; XOR with feedback polynomial 0xB400
    lda RANDOM_STATE + 1
    eor 0xB4
    sta RANDOM_STATE + 1
    jmp .random_done
.random_no_feedback:
    lsr RANDOM_STATE + 1
    ror RANDOM_STATE
.random_done:
    pla
    lda RANDOM_STATE
    eor INT_TIMER_COUNTER_LSB
    rts
