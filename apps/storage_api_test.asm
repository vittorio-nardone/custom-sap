; @load-address 0x8400
; Exercise kernel STORAGE_* API exposed to apps (Otto OS).
; Creates /OSTEST.TXT, writes, reads back, mkdir/rmdir, delete.
;
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

    jsr STORAGE_MOUNT
    bcc .fail_mount

    ; --- write file ---
    ldy 0x00
    ldd .fname[15:8]
    lde .fname[7:0]
    jsr STORAGE_SET_NAME
    bcc .fail_set
    jsr STORAGE_CREATE
    bcc .fail_create
    lda .payload_len
    sta CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd .payload[15:8]
    lde .payload[7:0]
    jsr STORAGE_WRITE
    bcc .fail_write
    lda 0x01
    jsr STORAGE_CLOSE

    ; --- read back ---
    ldy 0x00
    ldd .fname[15:8]
    lde .fname[7:0]
    jsr STORAGE_SET_NAME
    bcc .fail_set2
    jsr STORAGE_OPEN
    bcc .fail_open
    lda 0x20
    sta CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd 0xC0
    lde 0x00
    jsr STORAGE_READ
    bcc .fail_read
    lda 0x00
    jsr STORAGE_CLOSE

    ldy 0x00
    ldd 0xC0
    lde 0x00
    ldx 0x00
.cmp:
    lda .payload,x
    beq .cmp_ok
    sta .tmp
    lda yde,x
    cmp .tmp
    bne .fail_cmp
    inx
    jmp .cmp
.cmp_ok:

    ; mkdir/rmdir covered by /BIN MKDIR+RMDIR in test_otto_os.py.

    ; --- delete file (DELETE re-sends from CH376_FNBUF) ---
    ldx 0x00
.fncp:
    lda .fname,x
    sta CH376_FNBUF,x
    beq .fndone
    inx
    cpx 0x10
    bcc .fncp
.fndone:
    jsr STORAGE_DELETE
    bcc .fail_del

    ldd .pass[15:8]
    lde .pass[7:0]
    jsr ACIA_SEND_STRING
    rts

.fail_mount:
    ldd .emount[15:8]
    lde .emount[7:0]
    jmp ACIA_SEND_STRING
.fail_set:
    ldd .eset[15:8]
    lde .eset[7:0]
    jmp ACIA_SEND_STRING
.fail_create:
    ldd .ecreate[15:8]
    lde .ecreate[7:0]
    jmp ACIA_SEND_STRING
.fail_write:
    ldd .ewrite[15:8]
    lde .ewrite[7:0]
    jmp ACIA_SEND_STRING
.fail_set2:
    ldd .eset2[15:8]
    lde .eset2[7:0]
    jmp ACIA_SEND_STRING
.fail_open:
    ldd .eopen[15:8]
    lde .eopen[7:0]
    jmp ACIA_SEND_STRING
.fail_read:
    ldd .eread[15:8]
    lde .eread[7:0]
    jmp ACIA_SEND_STRING
.fail_cmp:
    ldd .ecmp[15:8]
    lde .ecmp[7:0]
    jmp ACIA_SEND_STRING
.fail_mkdir:
    ldd .emkdir[15:8]
    lde .emkdir[7:0]
    jmp ACIA_SEND_STRING
.fail_rmdir:
    ldd .ermdir[15:8]
    lde .ermdir[7:0]
    jmp ACIA_SEND_STRING
.fail_del:
    ldd .edel[15:8]
    lde .edel[7:0]
    jmp ACIA_SEND_STRING


.banner:
    #d "storage_api_test", 0x0A, 0x0D, 0x00
.pass:
    #d "PASS", 0x0A, 0x0D, 0x00
.emount:
    #d "FAIL mount", 0x0A, 0x0D, 0x00
.eset:
    #d "FAIL set", 0x0A, 0x0D, 0x00
.ecreate:
    #d "FAIL create", 0x0A, 0x0D, 0x00
.ewrite:
    #d "FAIL write", 0x0A, 0x0D, 0x00
.eset2:
    #d "FAIL set2", 0x0A, 0x0D, 0x00
.eopen:
    #d "FAIL open", 0x0A, 0x0D, 0x00
.eread:
    #d "FAIL read", 0x0A, 0x0D, 0x00
.ecmp:
    #d "FAIL cmp", 0x0A, 0x0D, 0x00
.emkdir:
    #d "FAIL mkdir", 0x0A, 0x0D, 0x00
.ermdir:
    #d "FAIL rmdir", 0x0A, 0x0D, 0x00
.edel:
    #d "FAIL del", 0x0A, 0x0D, 0x00
.fname:
    #d "/OSTEST.TXT", 0x00
.dname:
    #d "/OSDIR", 0x00
.dname_rel:
    #d "OSDIR", 0x00
.payload:
    #d "otto-os-api", 0x0A, 0x00
.payload_len:
    #d 0x0C
.tmp:
    #d 0x00
