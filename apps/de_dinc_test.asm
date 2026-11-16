; @load-address 0x8400
; =========================================================
; de_dinc_test — page-wrap of LDA/STA (DE)+ and (YDE)+
;
; Prints D:E (and Y) before and after each op. D must increment
; only when E wraps FF→00. C=1 on that wrap, C=0 otherwise.
; Y must stay put on the (YDE)+ forms.
;
; 1 LDA (DE)+  9000 → D unchanged, C=0, A=11
; 2 LDA (DE)+  90FE → D unchanged, E=FF, C=0, A=22
; 3 LDA (DE)+  90FF → D+1, E=00, C=1, A=AA
; 4 LDA (DE)+  next → reads 9100, D stays, C=0, A=BB
; 5 STA (DE)+  92FF → D+1, E=00, C=1, [92FF]=CC
; 6 LDA (YDE)+ 01:09FF → D+1, Y unchanged, C=1, A=DD
; 7 STA (YDE)+ 01:0AFF → D+1, Y unchanged, C=1, [010AFF]=EE
;
; Uses ACIA_SEND_CHAR / ACIA_SEND_HEX / ACIA_SEND_NEWLINE only,
; so it links against kernel v1.2.101 as well as current.
; Prints: de_dinc_test / one line per step / OK  or  FAIL <step>
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

    ldx 0x00
.ban:
    lda .banner,x
    beq .ban_done
    jsr ACIA_SEND_CHAR
    inx
    jmp .ban
.ban_done:
    jsr ACIA_SEND_NEWLINE

    lda 0x11
    sta 0x9000
    lda 0x22
    sta 0x90FE
    lda 0xAA
    sta 0x90FF
    lda 0xBB
    sta 0x9100
    lda 0x00
    sta 0x92FF
    lda 0xDD
    sta 0x0109FF
    lda 0x00
    sta 0x010AFF

    ; --- 1) no wrap: E=00, D stays ---
    lda 0x01
    sta .step
    ldd 0x90
    lde 0x00
    jsr .begin_line
    lda (de)+
    jsr .save_ac
    jsr .end_line
    lda .loaded
    cmp 0x11
    bne .fail
    cpd 0x90
    bne .fail
    cpe 0x01
    bne .fail
    lda .carry
    bne .fail

    ; --- 2) E=FE → FF, D must NOT increment ---
    lda 0x02
    sta .step
    ldd 0x90
    lde 0xFE
    jsr .begin_line
    lda (de)+
    jsr .save_ac
    jsr .end_line
    lda .loaded
    cmp 0x22
    bne .fail
    cpd 0x90
    bne .fail
    cpe 0xFF
    bne .fail
    lda .carry
    bne .fail

    ; --- 3) E=FF → D increments ---
    lda 0x03
    sta .step
    ldd 0x90
    lde 0xFF
    jsr .begin_line
    lda (de)+
    jsr .save_ac
    jsr .end_line
    lda .loaded
    cmp 0xAA
    bne .fail
    cpd 0x91
    bne .fail
    cpe 0x00
    bne .fail
    lda .carry
    beq .fail

    ; --- 4) pointer left on the next page ---
    lda 0x04
    sta .step
    jsr .begin_line
    lda (de)+
    jsr .save_ac
    jsr .end_line
    lda .loaded
    cmp 0xBB
    bne .fail
    cpd 0x91
    bne .fail
    cpe 0x01
    bne .fail
    lda .carry
    bne .fail

    ; --- 5) STA (DE)+ wrap ---
    lda 0x05
    sta .step
    ldd 0x92
    lde 0xFF
    jsr .begin_line
    lda 0xCC
    sta (de)+
    jsr .save_ac
    jsr .end_line
    lda .loaded
    cmp 0xCC
    bne .fail
    cpd 0x93
    bne .fail
    cpe 0x00
    bne .fail
    lda .carry
    beq .fail
    lda 0x92FF
    cmp 0xCC
    bne .fail

    ; --- 6) LDA (YDE)+ wrap, Y unchanged ---
    lda 0x06
    sta .step
    ldy 0x01
    ldd 0x09
    lde 0xFF
    jsr .begin_yline
    lda (yde)+
    jsr .save_ac
    jsr .end_yline
    lda .loaded
    cmp 0xDD
    bne .fail
    cpy 0x01
    bne .fail
    cpd 0x0A
    bne .fail
    cpe 0x00
    bne .fail
    lda .carry
    beq .fail

    ; --- 7) STA (YDE)+ wrap, Y unchanged ---
    lda 0x07
    sta .step
    ldy 0x01
    ldd 0x0A
    lde 0xFF
    jsr .begin_yline
    lda 0xEE
    sta (yde)+
    jsr .save_ac
    jsr .end_yline
    lda .loaded
    cmp 0xEE
    bne .fail
    cpy 0x01
    bne .fail
    cpd 0x0B
    bne .fail
    cpe 0x00
    bne .fail
    lda .carry
    beq .fail
    lda 0x010AFF
    cmp 0xEE
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
    ora 0x30
    jsr ACIA_SEND_CHAR
    jsr ACIA_SEND_NEWLINE
    rts

; Print "<step> " and D:E as they are now. Preserves D, E, Y.
.begin_line:
    lda .step
    ora 0x30
    jsr ACIA_SEND_CHAR
    lda " "
    jsr ACIA_SEND_CHAR
    jsr .show_de
    jsr .print_arrow
    rts

.begin_yline:
    lda .step
    ora 0x30
    jsr ACIA_SEND_CHAR
    lda " "
    jsr ACIA_SEND_CHAR
    jsr .show_y
    jsr .show_de
    jsr .print_arrow
    rts

; Print D:E, then " A=xx C=n". Preserves D, E, Y.
.end_line:
    jsr .show_de
    lda " "
    jsr ACIA_SEND_CHAR
    lda "A"
    jsr ACIA_SEND_CHAR
    lda "="
    jsr ACIA_SEND_CHAR
    lda .loaded
    jsr ACIA_SEND_HEX
    lda " "
    jsr ACIA_SEND_CHAR
    lda "C"
    jsr ACIA_SEND_CHAR
    lda "="
    jsr ACIA_SEND_CHAR
    lda .carry
    ora 0x30
    jsr ACIA_SEND_CHAR
    jsr ACIA_SEND_NEWLINE
    rts

.end_yline:
    jsr .show_y
    jsr .end_line
    rts

.show_y:
    lda "Y"
    jsr ACIA_SEND_CHAR
    tya
    jsr ACIA_SEND_HEX
    lda " "
    jsr ACIA_SEND_CHAR
    rts

.show_de:
    phd
    phe
    tda
    jsr ACIA_SEND_HEX
    tea
    jsr ACIA_SEND_HEX
    ple
    pld
    rts

.print_arrow:
    lda "-"
    jsr ACIA_SEND_CHAR
    lda ">"
    jsr ACIA_SEND_CHAR
    rts

; A = byte just loaded or stored, C = post-inc carry. Preserves D, E, Y.
.save_ac:
    sta .loaded
    bcc .save_c0
    lda 0x01
    jmp .save_cstore
.save_c0:
    lda 0x00
.save_cstore:
    sta .carry
    rts

.step:
    #d 0x00
.loaded:
    #d 0x00
.carry:
    #d 0x00
.banner:
    #d "de_dinc_test", 0x00
