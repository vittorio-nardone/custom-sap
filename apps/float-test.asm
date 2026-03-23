#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    ; =====================================================
    ; TEST 1: INT_TO_FLOAT with value 1 (0x0001)
    ; IEEE 754: 1.0 = 0x3F800000
    ;   0x80FB = 0x00, 0x80FC = 0x00, 0x80FD = 0x80, 0x80FE = 0x3F
    ; =====================================================
    ldd .test1_msg[15:8]
    lde .test1_msg[7:0]
    jsr ACIA_SEND_STRING

    lda 0x01            ; low byte = 1
    ldx 0x00            ; high byte = 0
    jsr INT_TO_FLOAT

    ; Print result bytes
    jsr .print_float

    ; Verify
    lda 0x80FB
    cmp 0x00
    bne .fail_test1
    lda 0x80FC
    cmp 0x00
    bne .fail_test1
    lda 0x80FD
    cmp 0x80
    bne .fail_test1
    lda 0x80FE
    cmp 0x3F
    bne .fail_test1

    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING

    ; =====================================================
    ; TEST 2: INT_TO_FLOAT with value 0 (0x0000)
    ; IEEE 754: 0.0 = 0x00000000
    ; =====================================================
    ldd .test2_msg[15:8]
    lde .test2_msg[7:0]
    jsr ACIA_SEND_STRING

    lda 0x00
    ldx 0x00
    jsr INT_TO_FLOAT

    jsr .print_float

    lda 0x80FB
    bne .fail_test2
    lda 0x80FC
    bne .fail_test2
    lda 0x80FD
    bne .fail_test2
    lda 0x80FE
    bne .fail_test2

    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING

    ; =====================================================
    ; TEST 3: INT_TO_FLOAT with value 256 (0x0100)
    ; IEEE 754: 256.0 = 0x43800000
    ;   0x80FB = 0x00, 0x80FC = 0x00, 0x80FD = 0x80, 0x80FE = 0x43
    ; =====================================================
    ldd .test3_msg[15:8]
    lde .test3_msg[7:0]
    jsr ACIA_SEND_STRING

    lda 0x00            ; low byte = 0
    ldx 0x01            ; high byte = 1  -> 256
    jsr INT_TO_FLOAT

    jsr .print_float

    lda 0x80FB
    cmp 0x00
    bne .fail_test3
    lda 0x80FC
    cmp 0x00
    bne .fail_test3
    lda 0x80FD
    cmp 0x80
    bne .fail_test3
    lda 0x80FE
    cmp 0x43
    bne .fail_test3

    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING

    ; =====================================================
    ; TEST 4: INT_TO_FLOAT with value -1 (0xFFFF)
    ; IEEE 754: -1.0 = 0xBF800000
    ;   0x80FB = 0x00, 0x80FC = 0x00, 0x80FD = 0x80, 0x80FE = 0xBF
    ; =====================================================
    ldd .test4_msg[15:8]
    lde .test4_msg[7:0]
    jsr ACIA_SEND_STRING

    lda 0xFF            ; low byte
    ldx 0xFF            ; high byte  -> -1
    jsr INT_TO_FLOAT

    jsr .print_float

    lda 0x80FB
    cmp 0x00
    bne .fail_test4
    lda 0x80FC
    cmp 0x00
    bne .fail_test4
    lda 0x80FD
    cmp 0x80
    bne .fail_test4
    lda 0x80FE
    cmp 0xBF
    bne .fail_test4

    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING

    ; =====================================================
    ; TEST 5: Roundtrip - INT_TO_FLOAT(100) then FLOAT_TO_INT
    ; 100 = 0x0064 -> float -> back to 0x0064
    ; =====================================================
    ldd .test5_msg[15:8]
    lde .test5_msg[7:0]
    jsr ACIA_SEND_STRING

    lda 0x64            ; low byte = 100
    ldx 0x00            ; high byte = 0
    jsr INT_TO_FLOAT

    jsr .print_float

    jsr FLOAT_TO_INT    ; A = low, X = high
    sta .result_lo      ; Save results before printing
    stx .result_hi

    ; Print result
    lda 0x20            ; space
    jsr ACIA_SEND_CHAR
    lda 0x2D            ; '-'
    jsr ACIA_SEND_CHAR
    lda 0x3E            ; '>'
    jsr ACIA_SEND_CHAR
    lda 0x20            ; space
    jsr ACIA_SEND_CHAR
    lda .result_hi
    jsr ACIA_SEND_HEX
    lda .result_lo
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE

    ; Verify
    lda .result_lo
    cmp 0x64
    bne .fail_test5
    lda .result_hi
    cmp 0x00
    bne .fail_test5

    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING

    ; =====================================================
    ; TEST 6: Roundtrip - INT_TO_FLOAT(1000) then FLOAT_TO_INT
    ; 1000 = 0x03E8 -> float -> back to 0x03E8
    ; =====================================================
    ldd .test6_msg[15:8]
    lde .test6_msg[7:0]
    jsr ACIA_SEND_STRING

    lda 0xE8            ; low byte
    ldx 0x03            ; high byte -> 1000
    jsr INT_TO_FLOAT

    jsr .print_float

    jsr FLOAT_TO_INT
    sta .result_lo
    stx .result_hi

    lda 0x20
    jsr ACIA_SEND_CHAR
    lda 0x2D
    jsr ACIA_SEND_CHAR
    lda 0x3E
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda .result_hi
    jsr ACIA_SEND_HEX
    lda .result_lo
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE

    lda .result_lo
    cmp 0xE8
    bne .fail_test6
    lda .result_hi
    cmp 0x03
    bne .fail_test6

    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING

    ; All tests passed
    ldd .all_ok_msg[15:8]
    lde .all_ok_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

; =====================================================
; Fail handlers - print FAIL and the float bytes for debugging
; =====================================================
.fail_test1:
    ldd .fail1_msg[15:8]
    lde .fail1_msg[7:0]
    jsr ACIA_SEND_STRING
    rts
.fail_test2:
    ldd .fail2_msg[15:8]
    lde .fail2_msg[7:0]
    jsr ACIA_SEND_STRING
    rts
.fail_test3:
    ldd .fail3_msg[15:8]
    lde .fail3_msg[7:0]
    jsr ACIA_SEND_STRING
    rts
.fail_test4:
    ldd .fail4_msg[15:8]
    lde .fail4_msg[7:0]
    jsr ACIA_SEND_STRING
    rts
.fail_test5:
    ldd .fail5_msg[15:8]
    lde .fail5_msg[7:0]
    jsr ACIA_SEND_STRING
    rts
.fail_test6:
    ldd .fail6_msg[15:8]
    lde .fail6_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

; =====================================================
; Helper: print 4 float bytes at 0x80FB-0x80FE as hex
; =====================================================
.print_float:
    lda 0x80FE
    jsr ACIA_SEND_HEX
    lda 0x80FD
    jsr ACIA_SEND_HEX
    lda 0x80FC
    jsr ACIA_SEND_HEX
    lda 0x80FB
    jsr ACIA_SEND_HEX
    rts

; =====================================================
; Strings
; =====================================================
.test1_msg:
    #d "T1 int2float(1)    = ", 0x00
.test2_msg:
    #d 0x0A, 0x0D, "T2 int2float(0)    = ", 0x00
.test3_msg:
    #d 0x0A, 0x0D, "T3 int2float(256)  = ", 0x00
.test4_msg:
    #d 0x0A, 0x0D, "T4 int2float(-1)   = ", 0x00
.test5_msg:
    #d 0x0A, 0x0D, "T5 roundtrip(100)  = ", 0x00
.test6_msg:
    #d 0x0A, 0x0D, "T6 roundtrip(1000) = ", 0x00
.ok_msg:
    #d " OK", 0x00
.all_ok_msg:
    #d 0x0A, 0x0D, "All tests passed!", 0x0A, 0x0D, 0x00
.fail1_msg:
    #d " FAIL test 1", 0x0A, 0x0D, 0x00
.fail2_msg:
    #d " FAIL test 2", 0x0A, 0x0D, 0x00
.fail3_msg:
    #d " FAIL test 3", 0x0A, 0x0D, 0x00
.fail4_msg:
    #d " FAIL test 4", 0x0A, 0x0D, 0x00
.fail5_msg:
    #d " FAIL test 5", 0x0A, 0x0D, 0x00
.fail6_msg:
    #d " FAIL test 6", 0x0A, 0x0D, 0x00

; =====================================================
; Variables
; =====================================================
.result_lo:
    #d 0x00
.result_hi:
    #d 0x00

; Float routines now available from kernel via symbols.asm:
; INT_TO_FLOAT and FLOAT_TO_INT
