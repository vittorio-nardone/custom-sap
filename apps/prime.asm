#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    JMP .start

; === Variables (in app RAM) ===

.ptr:          #d 0x00, 0x00     ; indirect pointer (LSB, MSB)
.bit_idx:      #d 0x00, 0x00     ; 16-bit bit index (LSB, MSB)
.temp:         #d 0x00, 0x00     ; temp for shift/calc
.prime_p:      #d 0x00           ; current prime being sieved (8-bit)
.col_count:    #d 0x00           ; column counter for print formatting
.num_lo:       #d 0x00           ; current number low byte
.num_hi:       #d 0x00           ; current number high byte
.cur_byte:     #d 0x00           ; current bitmap byte during print
.byte_cnt:     #d 0x00, 0x00     ; byte counter for print loop (LSB, MSB)

; === Lookup tables ===

.bit_mask:     #d 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80
.bit_clear:    #d 0xFE, 0xFD, 0xFB, 0xF7, 0xEF, 0xDF, 0xBF, 0x7F

; =============================================================
; MAIN
; =============================================================

.start:
    LDD .msg_header[15:8]
    LDE .msg_header[7:0]
    JSR ACIA_SEND_STRING

    ; --- Step 1: Initialize PrimeMap (4096 bytes = 0xFF) ---
    LDD PrimeMap[15:8]
    LDE PrimeMap[7:0]
    LDY 0x10                  ; 16 pages x 256 bytes = 4096
.init_outer:
    LDX 0x00
    LDA 0xFF
.init_inner:
    STA DE,X
    INX
    BNE .init_inner
    IND                       ; D++ → next 256-byte page
    DEY
    BNE .init_outer

    ; --- Step 2: Sieve of Eratosthenes ---
    LDA 0x03
    STA .prime_p

.sieve_loop:
    ; Test if p is prime (bit_index = (p-3)/2, max 126)
    LDA .prime_p
    SEC
    SBC 0x03
    LSR A                     ; A = bit_index of p (0-126)
    TAX                       ; X = bit_index
    AND 0x07
    TAY                       ; Y = bit_pos
    TXA
    LSR A
    LSR A
    LSR A                     ; A = byte_offset (0-15)
    TAX                       ; X = byte_offset

    LDA .bit_mask,Y
    TAD                       ; D = test mask
    LDA PrimeMap,X            ; byte from PrimeMap
    AND D
    BEQ .next_p               ; bit clear → not prime, skip

    ; p is prime — compute start bit_index = (p*p - 3) / 2
    LDA .prime_p
    LDX .prime_p
    JSR MULTIPLY_INT          ; A(MSB):X(LSB) = p * p

    STX .bit_idx              ; store p*p LSB
    STA .bit_idx+1            ; store p*p MSB

    ; Subtract 3
    SEC
    LDA .bit_idx
    SBC 0x03
    STA .bit_idx
    LDA .bit_idx+1
    SBC 0x00
    STA .bit_idx+1

    ; Divide by 2 (right shift 16-bit)
    CLC
    LSR .bit_idx+1
    ROR .bit_idx

    ; Mark multiples
.mark_loop:
    LDA .bit_idx+1
    BMI .next_p               ; bit_idx >= 32768 → done

    JSR .clear_bit

    ; bit_idx += prime_p
    CLC
    LDA .bit_idx
    ADC .prime_p
    STA .bit_idx
    LDA .bit_idx+1
    ADC 0x00
    STA .bit_idx+1

    JMP .mark_loop

.next_p:
    LDA .prime_p
    CLC
    ADC 0x02
    STA .prime_p
    BCS .do_print             ; overflow past 255
    JMP .sieve_loop

    ; --- Step 3: Print results ---
.do_print:
    ; Print "2" first (the only even prime)
    LDA 0x02
    STA BINDEC32_VALUE
    LDA 0x00
    STA BINDEC32_VALUE+1
    STA BINDEC32_VALUE+2
    STA BINDEC32_VALUE+3
    JSR ACIA_SEND_DECIMAL32
    LDA 0x20
    JSR ACIA_SEND_CHAR

    LDA 0x01
    STA .col_count

    ; Start with number = 3
    LDA 0x03
    STA .num_lo
    LDA 0x00
    STA .num_hi

    ; Setup pointer to PrimeMap
    LDA PrimeMap[7:0]
    STA .ptr
    LDA PrimeMap[15:8]
    STA .ptr+1

    ; Byte counter = 0
    LDA 0x00
    STA .byte_cnt
    STA .byte_cnt+1

.print_byte_loop:
    LDA (.ptr)
    STA .cur_byte
    BNE .process_byte

    ; All 8 bits clear — skip, advance number by 16
    CLC
    LDA .num_lo
    ADC 0x10
    STA .num_lo
    LDA .num_hi
    ADC 0x00
    STA .num_hi
    BCS .print_done
    JMP .next_print_byte

.process_byte:
    LDX 0x00                  ; bit position within byte

.print_bit_loop:
    LDA .bit_mask,X
    TAE                       ; E = test mask
    LDA .cur_byte
    AND E
    BEQ .bit_not_prime

    ; This number is prime — print it
    PHX

    LDA .num_lo
    STA BINDEC32_VALUE
    LDA .num_hi
    STA BINDEC32_VALUE+1
    LDA 0x00
    STA BINDEC32_VALUE+2
    STA BINDEC32_VALUE+3
    JSR ACIA_SEND_DECIMAL32
    LDA 0x20
    JSR ACIA_SEND_CHAR

    INC .col_count
    LDA .col_count
    CMP 0x0A
    BNE .no_newline
    JSR ACIA_SEND_NEWLINE
    LDA 0x00
    STA .col_count
.no_newline:
    PLX

.bit_not_prime:
    ; number += 2
    CLC
    LDA .num_lo
    ADC 0x02
    STA .num_lo
    LDA .num_hi
    ADC 0x00
    STA .num_hi
    BCS .print_done

    INX
    CPX 0x08
    BNE .print_bit_loop

.next_print_byte:
    ; Advance pointer
    INW .ptr

    ; Advance byte counter
    INW .byte_cnt
    LDA .byte_cnt+1
    CMP 0x10                  ; 0x1000 = 4096 bytes
    BNE .print_byte_loop

.print_done:
    JSR ACIA_SEND_NEWLINE
    RTS

; =============================================================
; SUBROUTINE: clear_bit
;   Clears the bit at position .bit_idx in PrimeMap
;   Destroys: A, X, Y, D, E
; =============================================================

.clear_bit:
    ; bit_pos = bit_idx & 0x07
    LDA .bit_idx
    AND 0x07
    TAY                       ; Y = bit_pos

    ; byte_offset = bit_idx >> 3 (store in .temp)
    LDA .bit_idx
    STA .temp
    LDA .bit_idx+1
    STA .temp+1

    CLC
    LSR .temp+1
    ROR .temp
    LSR .temp+1
    ROR .temp
    LSR .temp+1
    ROR .temp

    ; address = PrimeMap + byte_offset → store in .ptr
    CLC
    LDA PrimeMap[7:0]
    ADC .temp
    STA .ptr
    LDA PrimeMap[15:8]
    ADC .temp+1
    STA .ptr+1

    ; Load clearing mask, clear bit, store back
    LDA .bit_clear,Y         ; clearing mask for bit Y
    TAD                       ; D = mask
    LDA (.ptr)                ; load byte from bitmap
    AND D                     ; clear the bit
    STA (.ptr)                ; store back
    RTS

; =============================================================
; DATA
; =============================================================

.msg_header:
    #d 0x0A, 0x0D, "Prime numbers < 65536:", 0x0A, 0x0D, 0x00

PrimeMap:
    #res 4096
