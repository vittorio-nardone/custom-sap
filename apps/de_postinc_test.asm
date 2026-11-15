; @load-address 0x8400
; =========================================================
; LDA/STA (DE)+ hardware / simulator regression
;
; Upload via XMODEM (OT) and run with `r` / `call 8400`.
; Prints: de_postinc_test / OK  or  FAIL <step>
; Steps: 1=STA fill  2=LDA read  3=wrap LDA  4=wrap STA  5=flags N
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

    ; Banner via ACIA_SEND_CHAR only (no string walk dependency)
    ldx 0x00
.ban:
    lda .banner,x
    beq .ban_done
    jsr ACIA_SEND_CHAR
    inx
    jmp .ban
.ban_done:
    jsr ACIA_SEND_NEWLINE

    ; --- 1) STA (DE)+ fill 4 bytes at 0x9000 ---
    lda 0x01
    sta .step

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
    lda 0x02
    sta .step

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

    ; --- 3) wrap: LDA at E=0xFF → D increments ---
    lda 0x03
    sta .step

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

    ; --- 4) wrap: STA at DE=0x9100 after step 3 ---
    lda 0x04
    sta .step

    lda 0xCC
    sta (de)+
    lda 0x9100
    cmp 0xCC
    bne .fail
    cpd 0x91
    bne .fail
    cpe 0x01
    bne .fail

    ; --- 5) Z/N from loaded byte (0x80 → N=1), then post-inc ---
    lda 0x05
    sta .step

    lda 0x80
    sta 0x9200
    ldd 0x92
    lde 0x00
    lda (de)+
    bmi .n_ok
    jmp .fail
.n_ok:
    cmp 0x80
    bne .fail
    cpe 0x01
    bne .fail

    lda "O"
    jsr ACIA_SEND_CHAR
    lda "K"
    jsr ACIA_SEND_CHAR
    jsr ACIA_SEND_NEWLINE
    rts

.fail:
    lda "F"
    jsr ACIA_SEND_CHAR
    lda "A"
    jsr ACIA_SEND_CHAR
    lda "I"
    jsr ACIA_SEND_CHAR
    lda "L"
    jsr ACIA_SEND_CHAR
    lda " "
    jsr ACIA_SEND_CHAR
    lda .step
    ora 0x30                      ; ASCII digit
    jsr ACIA_SEND_CHAR
    jsr ACIA_SEND_NEWLINE
    rts

.step:
    #d 0x00

.banner:
    #d "de_postinc_test", 0x00
