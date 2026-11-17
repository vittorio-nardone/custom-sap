; Shared helpers for Otto OS /BIN apps (include from apps/*.asm).
; Scratch: 0xB180+ (avoid TinyPascal ED_* and edit TE_* where possible).

#once

#const OS_ARG        = 0xB180  ; 32 bytes — copy of SHELL_APP_ARG
#const OS_NAME1      = 0xB1A0  ; 16 bytes
#const OS_NAME2      = 0xB1B0  ; 16 bytes
#const OS_TMP        = 0xB1C0
#const OS_TMP2       = 0xB1C1
#const OS_LINES      = 0xB1C2  ; more: lines on page
#const OS_MATCH_LO   = 0xB1C3
#const OS_MATCH_HI   = 0xB1C4
#const OS_NEED       = 0xB1C5  ; find: needle length
#const OS_HAVE       = 0xB1C6
#const OS_BUF        = 0xB1D0  ; 48-byte I/O scratch (0xB1D0-0xB1FF)

; Copy SHELL_APP_ARG → OS_ARG. C=1 if non-empty.
os_take_arg:
    lda SHELL_APP_ARGC
    beq .no
    ldx 0x00
.cp:
    lda SHELL_APP_ARG,x
    sta OS_ARG,x
    beq .ok
    inx
    cpx 0x1F
    bcc .cp
    lda 0x00
    sta OS_ARG,x
.ok:
    lda OS_ARG
    beq .no
    sec
    rts
.no:
    clc
    rts

; Split OS_ARG into OS_NAME1 and optional OS_NAME2 (space-separated).
; C=1 if NAME1 present; OS_TMP=1 if NAME2 also present.
os_split_args:
    lda 0x00
    sta OS_TMP
    ldx 0x00
    ldy 0x00
.s1:
    lda OS_ARG,x
    beq .n1end
    cmp 0x20
    beq .n1sp
    jsr os_upcase
    sta OS_NAME1,y
    inx
    iny
    cpy 0x0F
    bcc .s1
    jmp .n1nul
.n1sp:
    inx
.n1end:
.n1nul:
    lda 0x00
    sta OS_NAME1,y
    lda OS_NAME1
    beq .fail
.skip:
    lda OS_ARG,x
    beq .one
    cmp 0x20
    bne .s2
    inx
    jmp .skip
.s2:
    ldy 0x00
.s2c:
    lda OS_ARG,x
    beq .n2nul
    cmp 0x20
    beq .n2nul
    jsr os_upcase
    sta OS_NAME2,y
    inx
    iny
    cpy 0x0F
    bcc .s2c
.n2nul:
    lda 0x00
    sta OS_NAME2,y
    lda OS_NAME2
    beq .one
    lda 0x01
    sta OS_TMP
.one:
    sec
    rts
.fail:
    clc
    rts

os_upcase:
    cmp 0x61
    bcc .ok
    cmp 0x7B
    bcs .ok
    sec
    sbc 0x20
.ok:
    rts

; Build CH376_FNBUF from D:E name using CH376_DEPTH (shell left CWD synced).
; C=1 ok.
os_build_fname:
    lda CH376_DEPTH
    bne .noslash
    lda 0x2F
    sta CH376_FNBUF
    ldy 0x01
    jmp .c
.noslash:
    ldy 0x00
.c:
    ldx 0x00
.cl:
    lda de,x
    beq .done
    cmp 0x2F
    beq .sk
    cmp 0x5C
    beq .sk
    jsr os_upcase
    sta CH376_FNBUF,y
    iny
.sk:
    inx
    cpy 0x0F
    bcc .cl
.done:
    lda 0x00
    sta CH376_FNBUF,y
    sec
    rts

; SET_NAME from OS_NAME1. C=1 ok.
os_set_name1:
    jsr STORAGE_ENSURE_MOUNTED
    bcc .fail
    lda 0x00
    jsr STORAGE_CLOSE
    ldd OS_NAME1[15:8]
    lde OS_NAME1[7:0]
    jsr os_build_fname
    ldy 0x00
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jmp STORAGE_SET_NAME
.fail:
    clc
    rts

os_set_name2:
    jsr STORAGE_ENSURE_MOUNTED
    bcc .fail
    lda 0x00
    jsr STORAGE_CLOSE
    ldd OS_NAME2[15:8]
    lde OS_NAME2[7:0]
    jsr os_build_fname
    ldy 0x00
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jmp STORAGE_SET_NAME
.fail:
    clc
    rts

os_print_de:
    jmp ACIA_SEND_STRING

os_err_arg:
    ldd .earg[15:8]
    lde .earg[7:0]
    jsr ACIA_SEND_STRING
    rts
.earg:
    #d "?arg", 0x0A, 0x0D, 0x00

os_err_usb:
    ldd .eusb[15:8]
    lde .eusb[7:0]
    jsr ACIA_SEND_STRING
    rts
.eusb:
    #d "?usb", 0x0A, 0x0D, 0x00

os_ok:
    ldd .ok[15:8]
    lde .ok[7:0]
    jmp ACIA_SEND_STRING
.ok:
    #d "OK", 0x0A, 0x0D, 0x00
