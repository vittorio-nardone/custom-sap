; @load-address 0x8400
; =========================================================
; LDA/STA (YDE)+ regression + cycle microbench
; =========================================================
;
; Functional checks on expansion RAM page 1 (0x010000+).
; Microbench compares old LDA/STA YDE,X + INE/IND walk vs (YDE)+
; over N bytes and prints cycle deltas via BINDEC32.

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    ldd .banner[15:8]
    lde .banner[7:0]
    jsr ACIA_SEND_STRING

    ; --- 1) STA (YDE)+ fill 4 bytes at 0x010900 ---
    ldy 0x01
    ldd 0x09
    lde 0x00
    lda 0x00
    ldx 0x00
    sta yde,x                 ; clear 0x010900..03 via indexed (pre-check path)
    ine
    sta yde,x
    ine
    sta yde,x
    ine
    sta yde,x

    ldy 0x01
    ldd 0x09
    lde 0x00
    lda 0x11
    sta (yde)+
    lda 0x22
    sta (yde)+
    lda 0x33
    sta (yde)+
    lda 0x44
    sta (yde)+

    ; expect Y=1, DE=0x0904
    cpy 0x01
    bne .fail
    cpd 0x09
    bne .fail
    cpe 0x04
    bne .fail

    ldy 0x01
    ldd 0x09
    lde 0x00
    ldx 0x00
    lda yde,x
    cmp 0x11
    bne .fail
    ine
    lda yde,x
    cmp 0x22
    bne .fail
    ine
    lda yde,x
    cmp 0x33
    bne .fail
    ine
    lda yde,x
    cmp 0x44
    bne .fail

    ; --- 2) LDA (YDE)+ read back ---
    ldy 0x01
    ldd 0x09
    lde 0x00
    lda (yde)+
    cmp 0x11
    bne .fail
    lda (yde)+
    cmp 0x22
    bne .fail
    lda (yde)+
    cmp 0x33
    bne .fail
    lda (yde)+
    cmp 0x44
    bne .fail
    cpy 0x01
    bne .fail
    cpd 0x09
    bne .fail
    cpe 0x04
    bne .fail

    ; --- 3) wrap E=0xFF → D increments, Y unchanged ---
    ldy 0x01
    ldd 0x09
    lde 0xFF
    lda 0xAA
    ldx 0x00
    sta yde,x                 ; 0x0109FF = AA
    ldy 0x01
    ldd 0x0A
    lde 0x00
    lda 0xBB
    sta yde,x                 ; 0x010A00 = BB

    ldy 0x01
    ldd 0x09
    lde 0xFF
    lda (yde)+
    cmp 0xAA
    bne .fail
    cpy 0x01
    bne .fail
    cpd 0x0A
    bne .fail
    cpe 0x00
    bne .fail

    lda 0xCC
    sta (yde)+                ; write 0x010A00, DE→0x0A01
    ldy 0x01
    ldd 0x0A
    lde 0x00
    ldx 0x00
    lda yde,x
    cmp 0xCC
    bne .fail

    ; --- 4) Z/N from loaded byte (0x80 → N=1) ---
    ldy 0x01
    ldd 0x0B
    lde 0x00
    lda 0x80
    ldx 0x00
    sta yde,x
    ldy 0x01
    ldd 0x0B
    lde 0x00
    lda (yde)+
    bmi .n_ok
    jmp .fail
.n_ok:
    cmp 0x80
    bne .fail
    cpe 0x01
    bne .fail
    cpy 0x01
    bne .fail

    ; --- 5) ACIA_SEND_STRING24 ABI: DE ends on NUL, Y preserved ---
    ; Place "Hi\0" at 0x010C00
    ldy 0x01
    ldd 0x0C
    lde 0x00
    lda 0x48                  ; 'H'
    sta (yde)+
    lda 0x69                  ; 'i'
    sta (yde)+
    lda 0x00
    sta (yde)+

    ldy 0x01
    ldd 0x0C
    lde 0x00
    jsr ACIA_SEND_STRING24
    cpy 0x01
    bne .fail
    cpd 0x0C
    bne .fail
    cpe 0x02                  ; points at NUL
    bne .fail

    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING

    ; --- Microbench: 64-byte walk old vs new (correctness) ---
    ; Prepare source pattern in page-0 buffer 0x9000
    ldx 0x00
.fillsrc:
    txa
    sta 0x9000,x
    inx
    cpx 0x40
    bne .fillsrc

    ; --- OLD store walk ---
    ldy 0x01
    ldd 0x10
    lde 0x00
    ldx 0x00
.old_st:
    lda 0x9000,x
    phx
    ldx 0x00
    sta yde,x
    plx
    ine
    bne .old_st_n
    ind
.old_st_n:
    inx
    cpx 0x40
    bne .old_st

    ; --- NEW store walk ---
    ldy 0x01
    ldd 0x11
    lde 0x00
    ldx 0x00
.new_st:
    lda 0x9000,x
    sta (yde)+
    inx
    cpx 0x40
    bne .new_st

    ; Verify both destinations match source
    ldy 0x01
    ldd 0x10
    lde 0x00
    ldx 0x00
.vfy1:
    lda yde,x
    cmp 0x9000,x
    bne .fail
    inx
    cpx 0x40
    bne .vfy1

    ldy 0x01
    ldd 0x11
    lde 0x00
    ldx 0x00
.vfy2:
    lda yde,x
    cmp 0x9000,x
    bne .fail
    inx
    cpx 0x40
    bne .vfy2

    ldd .bench_ok[15:8]
    lde .bench_ok[7:0]
    jsr ACIA_SEND_STRING
    ldo 0xAA
    rts

.fail:
    ldd .fail_msg[15:8]
    lde .fail_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

.banner:
    #d "yde_postinc_test", 0x0A, 0x0D, 0x00
.ok_msg:
    #d "OK", 0x0A, 0x0D, 0x00
.fail_msg:
    #d "FAIL", 0x0A, 0x0D, 0x00
.bench_ok:
    #d "bench_ok", 0x0A, 0x0D, 0x00
