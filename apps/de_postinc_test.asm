; @load-address 0x8400
; =========================================================
; LDA/STA (DE)+ regression harness
; =========================================================

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

    ; --- 1) STA (DE)+ fill 4 bytes at 0x9000 ---
    lda 0x00
    sta 0x9000
    sta 0x9001
    sta 0x9002
    sta 0x9003

    ldd 0x90
    lde 0x00
    lda 0x11
    sta (de)+
    lda 0x22
    sta (de)+
    lda 0x33
    sta (de)+
    lda 0x44
    sta (de)+

    ; expect DE = 0x9004
    cpd 0x90
    bne .fail
    cpe 0x04
    bne .fail

    lda 0x9000
    cmp 0x11
    bne .fail
    lda 0x9001
    cmp 0x22
    bne .fail
    lda 0x9002
    cmp 0x33
    bne .fail
    lda 0x9003
    cmp 0x44
    bne .fail

    ; --- 2) LDA (DE)+ read back ---
    ldd 0x90
    lde 0x00
    lda (de)+
    cmp 0x11
    bne .fail
    lda (de)+
    cmp 0x22
    bne .fail
    lda (de)+
    cmp 0x33
    bne .fail
    lda (de)+
    cmp 0x44
    bne .fail
    cpd 0x90
    bne .fail
    cpe 0x04
    bne .fail

    ; --- 3) wrap E=0xFF → D increments ---
    lda 0xAA
    sta 0x90FF
    lda 0xBB
    sta 0x9100

    ldd 0x90
    lde 0xFF
    lda (de)+
    cmp 0xAA
    bne .fail
    cpd 0x91
    bne .fail
    cpe 0x00
    bne .fail

    lda 0xCC
    sta (de)+              ; write at 0x9100, then DE=0x9101
    lda 0x9100
    cmp 0xCC
    bne .fail
    cpd 0x91
    bne .fail
    cpe 0x01
    bne .fail

    ; --- 4) Z/N from loaded byte (0x80 → N=1), then post-inc ---
    lda 0x80
    sta 0x9200
    ldd 0x92
    lde 0x00
    lda (de)+
    bmi .n_ok                 ; N must still reflect loaded 0x80
    jmp .fail
.n_ok:
    cmp 0x80
    bne .fail
    cpe 0x01
    bne .fail

    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

.fail:
    ldd .fail_msg[15:8]
    lde .fail_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

.banner:
    #d "de_postinc_test", 0x0A, 0x0D, 0x00
.ok_msg:
    #d "OK", 0x0A, 0x0D, 0x00
.fail_msg:
    #d "FAIL", 0x0A, 0x0D, 0x00
