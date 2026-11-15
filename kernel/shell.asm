; Otto shell v1.b04 — word commands + legacy single-letter monitor.
; Prompt: ">" (no USB), "?>" (USB error), "/path>" (mounted).

#once
#bank kernel

; **********************************************************
SHELL_INIT:
    lda 0x00
    sta SHELL_FLAGS
    sta SHELL_ARGC
    sta SHELL_HIST_LEN
    sta SHELL_HIST_HEAD
    sta SHELL_HIST_DRAFT_LEN
    sta SHELL_HIST_PAINTED
    lda 0xFF
    sta SHELL_HIST_POS
    lda 0x2F
    sta SHELL_CWD
    lda 0x00
    sta SHELL_CWD+1
    lda 0x01
    sta SHELL_CWD_LEN
    lda 0x00
    sta SHELL_APP_ARGC
    rts

; **********************************************************
SHELL_PROMPT:
    ; No leading newline — DISPATCH already ends the input line; an extra
    ; blank row here wasted a terminal line on every Enter.
    lda CH376_STATUS
    and STORAGE_ST_MOUNTED
    beq .bare
    ldd SHELL_CWD[15:8]
    lde SHELL_CWD[7:0]
    jsr ACIA_SEND_STRING
    lda 0x3E
    jmp ACIA_SEND_CHAR
.bare:
    lda CH376_STATUS
    and STORAGE_ST_PRESENT
    beq .gt
    ; module present but not mounted
    lda 0x3F
    jsr ACIA_SEND_CHAR
.gt:
    lda 0x3E
    jmp ACIA_SEND_CHAR

; **********************************************************
SHELL_DISPATCH:
    jsr ACIA_SEND_NEWLINE
    ldx MAIN_MENU_INPUT_BUFFER_COUNT
    beq .ret
    lda 0x00
    sta MAIN_MENU_INPUT_BUFFER,x
    jsr shell_tokenize
    lda SHELL_ARGC
    beq .ret
    jsr shell_try_legacy
    bcc .ret
    jsr shell_lookup_builtin
    bcs .ret
    jsr shell_cmd_external
.ret:
    rts

; ============================================================
; Tokenizer
; ============================================================
shell_tokenize:
    lda 0x00
    sta SHELL_ARGC
    tax
.skip:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .done
    lda MAIN_MENU_INPUT_BUFFER,x
    cmp 0x20
    bne .start
    inx
    jmp .skip
.start:
    lda SHELL_ARGC
    cmp 0x04
    bcs .done
    tay
    txa
    sta SHELL_ARGV0,y
    inc SHELL_ARGC
.scan:
    inx
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .done
    lda MAIN_MENU_INPUT_BUFFER,x
    cmp 0x20
    bne .scan
    lda 0x00
    sta MAIN_MENU_INPUT_BUFFER,x
    inx
    jmp .skip
.done:
    rts

; A = argv index → D:E = pointer into input buffer
shell_arg_ptr:
    tax
    lda SHELL_ARGV0,x
    clc
    adc MAIN_MENU_INPUT_BUFFER[7:0]
    tae
    lda MAIN_MENU_INPUT_BUFFER[15:8]
    adc 0x00
    tad
    rts

shell_upcase:
    cmp 0x61
    bcc .ok
    cmp 0x7B
    bcs .ok
    sec
    sbc 0x20
.ok:
    rts

; Compare argv0 to NUL string at D:E. C=1 match (case-insensitive).
; Pattern walked with LDA DE,X + INE/IND (ROM constants are uppercase).
shell_cmp0:
    ldx SHELL_ARGV0
.loop:
    phx
    ldx 0x00
    lda de,x
    sta SHELL_WORK+4            ; keep char; PLX clobbers Z
    plx
    lda SHELL_WORK+4
    beq .end_n
    lda MAIN_MENU_INPUT_BUFFER,x
    jsr shell_upcase
    cmp SHELL_WORK+4
    bne .no
    inx
    ine
    bne .loop
    ind
    jmp .loop
.end_n:
    lda MAIN_MENU_INPUT_BUFFER,x
    bne .no
    sec
    rts
.no:
    clc
    rts

; D:E string → X = length
shell_strlen:
    ldx 0x00
.s:
    lda de,x
    beq .sd
    inx
    cpx SHELL_INPUT_MAX
    bcc .s
.sd:
    rts

; ============================================================
; Legacy single-letter (d/u/r/l/w/h) glued hex. C=0 handled.
; ============================================================
shell_try_legacy:
    lda SHELL_ARGC
    cmp 0x01
    bne .no
    lda 0x00
    jsr shell_arg_ptr
    lda SHELL_ARGV0
    beq .at0
    jsr shell_move_arg0_front
.at0:
    lda 0x00
    jsr shell_arg_ptr
    jsr shell_strlen
    stx MAIN_MENU_INPUT_BUFFER_COUNT
    ; Only legacy if len=1, or len=5/7 with hex body (d8400 / d008400)
    cpx 0x01
    beq .leg_ok
    cpx 0x05
    beq .check_hex
    cpx 0x07
    beq .check_hex
    jmp .no
.check_hex:
    ldx 0x01
.hx:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .leg_ok
    lda MAIN_MENU_INPUT_BUFFER,x
    jsr shell_is_hex
    bcc .no
    inx
    jmp .hx
.leg_ok:
    lda MAIN_MENU_INPUT_BUFFER
    jsr shell_upcase
    cmp "D"
    beq .d
    cmp "U"
    beq .u
    cmp "R"
    beq .r
    cmp "H"
    beq .h
.no:
    sec
    rts
.d:
    jsr MENU_DUMP
    clc
    rts
.u:
    jsr MENU_UPLOAD
    clc
    rts
.r:
    jsr MENU_RUN
    clc
    rts
.h:
    jsr MENU_HELP
    clc
    rts

; A = char, C=1 if hex digit
shell_is_hex:
    cmp 0x30
    bcc .nohex
    cmp 0x3A
    bcc .yeshex
    jsr shell_upcase
    cmp "A"
    bcc .nohex
    cmp "G"
    bcs .nohex
.yeshex:
    sec
    rts
.nohex:
    clc
    rts

shell_move_arg0_front:
    lda 0x00
    jsr shell_arg_ptr
    ldx 0x00
.m:
    lda de,x
    sta MAIN_MENU_INPUT_BUFFER,x
    beq .md
    inx
    jmp .m
.md:
    rts

; ============================================================
; Builtin words. C=1 if handled (handler RTS, or miss with C=0).
; Table: 4 bytes/entry = name ptr (MSB,LSB) + handler (MSB,LSB).
; ============================================================
#const SHELL_BUILTIN_TAB_BYTES = 92   ; 23 commands × 4

shell_lookup_builtin:
    ldx 0x00
.l:
    ldd shell_builtin_tab,x
    lde shell_builtin_tab+1,x
    phx
    jsr shell_cmp0
    plx
    bcs .hit
    txa
    clc
    adc 0x04
    tax
    cpx SHELL_BUILTIN_TAB_BYTES
    bcc .l
    clc
    rts
.hit:
    jmp (shell_builtin_tab+2,x)

shell_cmd_help:
    jsr MENU_HELP
    sec
    rts

shell_cmd_dump:
    jsr shell_prep_addr_cmd
    jsr MENU_DUMP
    sec
    rts

shell_cmd_call:
    jsr shell_prep_addr_cmd
    jsr MENU_RUN
    sec
    rts

shell_cmd_upload:
    jsr shell_prep_addr_cmd
    jsr MENU_UPLOAD
    sec
    rts

shell_cmd_cls:
    jsr VT100_ERASE_SCREEN
    jsr VT100_CURSOR_HOME
    sec
    rts

shell_cmd_ver:
    ldd sh_msg_ver[15:8]
    lde sh_msg_ver[7:0]
    jsr ACIA_SEND_STRING
    sec
    rts

; Build legacy buffer: first letter of argv0 + optional argv1 hex
shell_prep_addr_cmd:
    lda 0x00
    jsr shell_arg_ptr
    ldx 0x00
    lda de,x
    jsr shell_upcase
    ; DUMP→D UPLOAD→U CALL→R (MENU_* legacy letters)
    cmp "D"
    beq .okc
    cmp "U"
    beq .okc
    cmp "C"
    bne .okc
    lda "R"
.okc:
    sta MAIN_MENU_INPUT_BUFFER
    lda SHELL_ARGC
    cmp 0x02
    bcc .one
    lda 0x01
    jsr shell_arg_ptr
    ldx 0x00
    ldy 0x01
.cp:
    lda de,x
    beq .cpd
    sta MAIN_MENU_INPUT_BUFFER,y
    inx
    iny
    cpy 0x08
    bcc .cp
.cpd:
    sty MAIN_MENU_INPUT_BUFFER_COUNT
    rts
.one:
    lda 0x01
    sta MAIN_MENU_INPUT_BUFFER_COUNT
    rts

; ============================================================
; Hex parsers — string at D:E
; shell_parse_hex8:  2 digits → A, C=1 err
; shell_hex16:       4 digits → D:E (MSB in D), C=1 err
; shell_parse_addr:  4 or 6 digits → Y:D:E, C=1 err
; ============================================================
shell_parse_hex8:
    jsr shell_strlen
    cpx 0x02
    bne .bad8
    ldx 0x00
    lda de,x
    pha
    ine
    bne .h8b
    ind
.h8b:
    lda de,x
    tax
    pla
    jsr HEXBIN
    clc
    rts
.bad8:
    sec
    rts

shell_hex16:
    jsr shell_strlen
    cpx 0x04
    bne .e16
    ldx 0x00
    lda de,x
    pha
    ine
    bne .h16a
    ind
.h16a:
    lda de,x
    tax
    pla
    jsr HEXBIN
    pha                           ; MSB
    ine
    bne .h16b
    ind
.h16b:
    ldx 0x00
    lda de,x
    pha
    ine
    bne .h16c
    ind
.h16c:
    lda de,x
    tax
    pla
    jsr HEXBIN
    tae                           ; LSB in E
    pla
    tad                           ; MSB in D
    clc
    rts
.e16:
    sec
    rts

shell_parse_addr:
    jsr shell_strlen
    cpx 0x04
    beq .p4
    cpx 0x06
    beq .p6
    sec
    rts
.p4:
    ldy 0x00
    jmp shell_hex16
.p6:
    ldx 0x00
    lda de,x
    pha
    ine
    bne .p6a
    ind
.p6a:
    lda de,x
    tax
    pla
    jsr HEXBIN
    tay
    phy
    ine
    bne .p6b
    ind
.p6b:
    jsr shell_hex16               ; DE advanced past page byte
    ply
    rts

; ============================================================
; addr [hex]
; ============================================================
shell_cmd_addr:
    lda SHELL_ARGC
    cmp 0x02
    bcc .show
    lda 0x01
    jsr shell_arg_ptr
    jsr shell_parse_addr
    bcs .bad
    sty MAIN_MENU_ADDR_PAGE
    std MAIN_MENU_ADDR_MSB
    ste MAIN_MENU_ADDR_LSB
.show:
    ldd sh_msg_addr[15:8]
    lde sh_msg_addr[7:0]
    jsr ACIA_SEND_STRING
    lda MAIN_MENU_ADDR_PAGE
    jsr ACIA_SEND_HEX
    lda MAIN_MENU_ADDR_MSB
    jsr ACIA_SEND_HEX
    lda MAIN_MENU_ADDR_LSB
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
    sec
    rts
.bad:
    jmp shell_err_arg

; ============================================================
; peek addr
; ============================================================
shell_cmd_peek:
    lda SHELL_ARGC
    cmp 0x02
    bcc .bad
    lda 0x01
    jsr shell_arg_ptr
    jsr shell_parse_addr
    bcs .bad
    ldx 0x00
    lda yde,x
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
    sec
    rts
.bad:
    jmp shell_err_arg

; ============================================================
; poke addr val
; ============================================================
shell_cmd_poke:
    lda SHELL_ARGC
    cmp 0x03
    bcc .bad
    lda 0x01
    jsr shell_arg_ptr
    jsr shell_parse_addr
    bcs .bad
    sty SHELL_WORK+0
    std SHELL_WORK+1
    ste SHELL_WORK+2
    lda 0x02
    jsr shell_arg_ptr
    jsr shell_parse_hex8
    bcs .bad
    sta SHELL_WORK+3
    ldy SHELL_WORK+0
    ldd SHELL_WORK+1
    lde SHELL_WORK+2
    ldx 0x00
    lda SHELL_WORK+3
    sta yde,x
    sec
    rts
.bad:
    jmp shell_err_arg

; ============================================================
; fill addr len val   (len = 16-bit hex byte count)
; ============================================================
shell_cmd_fill:
    lda SHELL_ARGC
    cmp 0x04
    bcc .bad
    lda 0x01
    jsr shell_arg_ptr
    jsr shell_parse_addr
    bcs .bad
    sty SHELL_WORK+0
    std SHELL_WORK+1
    ste SHELL_WORK+2
    lda 0x02
    jsr shell_arg_ptr
    jsr shell_hex16
    bcs .bad
    ste SHELL_WORK+4              ; len LSB (for DEW)
    std SHELL_WORK+5              ; len MSB
    lda 0x03
    jsr shell_arg_ptr
    jsr shell_parse_hex8
    bcs .bad
    sta SHELL_WORK+3              ; fill byte
    ldy SHELL_WORK+0
    ldd SHELL_WORK+1
    lde SHELL_WORK+2
.loop:
    lda SHELL_WORK+4
    ora SHELL_WORK+5
    beq .done
    lda SHELL_WORK+3
    ldx 0x00
    sta yde,x                     ; no Y carry on 64 KB wrap
    ine
    bne .fill_nc
    ind
.fill_nc:
    dew SHELL_WORK+4
    jmp .loop
.done:
    sec
    rts
.bad:
    jmp shell_err_arg

; ============================================================
; copy src dst len
; ============================================================
shell_cmd_copy:
    lda SHELL_ARGC
    cmp 0x04
    bcc .bad
    lda 0x01
    jsr shell_arg_ptr
    jsr shell_parse_addr
    bcs .bad
    sty SHELL_WORK+0
    std SHELL_WORK+1
    ste SHELL_WORK+2
    lda 0x02
    jsr shell_arg_ptr
    jsr shell_parse_addr
    bcs .bad
    sty SHELL_WORK+6
    std SHELL_WORK+7
    ste SHELL_WORK+8
    lda 0x03
    jsr shell_arg_ptr
    jsr shell_hex16
    bcs .bad
    ste SHELL_WORK+4              ; len LSB (for DEW)
    std SHELL_WORK+5              ; len MSB
.loop:
    lda SHELL_WORK+4
    ora SHELL_WORK+5
    beq .done
    ldy SHELL_WORK+0
    ldd SHELL_WORK+1
    lde SHELL_WORK+2
    ldx 0x00
    lda yde,x
    ine
    bne .copy_s
    ind
.copy_s:
    std SHELL_WORK+1
    ste SHELL_WORK+2
    pha
    ldy SHELL_WORK+6
    ldd SHELL_WORK+7
    lde SHELL_WORK+8
    pla
    ldx 0x00
    sta yde,x
    ine
    bne .copy_d
    ind
.copy_d:
    std SHELL_WORK+7
    ste SHELL_WORK+8
    dew SHELL_WORK+4
    jmp .loop
.done:
    sec
    rts
.bad:
    jmp shell_err_arg

; ============================================================
; USB helpers
; ============================================================
shell_require_usb:
    jsr STORAGE_ENSURE_MOUNTED
    bcc .fail
    lda SHELL_FLAGS
    and 0xFE                      ; clear USB_ERR
    sta SHELL_FLAGS
    sec
    rts
.fail:
    lda SHELL_FLAGS
    ora SHELL_F_USB_ERR
    sta SHELL_FLAGS
    lda CH376_STATUS
    and STORAGE_ST_PRESENT
    beq .nousb
    ldd sh_err_nodisk[15:8]
    lde sh_err_nodisk[7:0]
    jsr ACIA_SEND_STRING
    clc
    rts
.nousb:
    ldd sh_err_nousb[15:8]
    lde sh_err_nousb[7:0]
    jsr ACIA_SEND_STRING
    clc
    rts

shell_cwd_reset:
    lda 0x2F
    sta SHELL_CWD
    lda 0x00
    sta SHELL_CWD+1
    lda 0x01
    sta SHELL_CWD_LEN
    lda 0x00
    sta CH376_DEPTH
    rts

; Remount and walk SHELL_CWD segments so CH376 matches prompt.
shell_sync_cwd:
    jsr STORAGE_ENSURE_MOUNTED
    bcc .fail
    lda 0x00
    sta CH376_DEPTH
    ; if cwd is just "/", done
    lda SHELL_CWD_LEN
    cmp 0x01
    beq .ok
    ; walk segments starting after leading '/'
    ldx 0x01
.seg:
    cpx SHELL_CWD_LEN
    bcs .ok
    ; copy segment into FNBUF
    lda CH376_DEPTH
    bne .rel
    lda 0x2F
    sta CH376_FNBUF
    ldy 0x01
    jmp .copy
.rel:
    ldy 0x00
.copy:
    lda SHELL_CWD,x
    beq .open
    cmp 0x2F
    beq .open
    sta CH376_FNBUF,y
    iny
    inx
    cpy 0x0E
    bcc .copy
.open:
    lda 0x00
    sta CH376_FNBUF,y
    phx
    jsr shell_open_dir
    plx
    bcc .fail
    inc CH376_DEPTH
    ; skip slash
    lda SHELL_CWD,x
    cmp 0x2F
    bne .seg
    inx
    jmp .seg
.ok:
    sec
    rts
.fail:
    clc
    rts

; Open CH376_FNBUF as a directory. C=1 if ERR_OPEN_DIR.
shell_open_dir:
    jsr storage_set_name_fnbuf
    jsr ch376_set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .tmo
    jsr ch376_set_timeout
    lda CH376_LAST_STATUS
    cmp CH376_ERR_OPEN_DIR
    bne .fail
    sec
    rts
.tmo:
    jsr ch376_set_timeout
.fail:
    clc
    rts

; Build open name for file argv in A into CH376_FNBUF (respect depth).
shell_build_fname:
    jsr shell_arg_ptr
    std SHELL_WORK+10
    ste SHELL_WORK+11
    lda CH376_DEPTH
    bne .noslash
    lda 0x2F
    sta CH376_FNBUF
    ldy 0x01
    jmp .c
.noslash:
    ldy 0x00
.c:
    ldd SHELL_WORK+10
    lde SHELL_WORK+11
    ldx 0x00
.cl:
    lda de,x
    beq .done
    jsr shell_upcase
    sta CH376_FNBUF,y
    inx
    iny
    cpy 0x0F
    bcc .cl
.done:
    lda 0x00
    sta CH376_FNBUF,y
    sec
    rts

; D:E → "#HH" (exactly 2 hex digits, NUL). C=1 → CH376_SELECT set (1-based).
shell_hash_select:
    ldx 0x00
    lda de,x
    cmp 0x23                      ; '#'
    bne .no
    ldx 0x03
    lda de,x
    bne .no                       ; must be exactly 3 chars + NUL
    ldx 0x01
    lda de,x
    jsr shell_is_hex
    bcc .no
    pha                           ; hi ASCII
    ldx 0x02
    lda de,x
    jsr shell_is_hex
    bcc .bad_pl
    tax                           ; lo ASCII
    pla
    jsr HEXBIN                    ; A = index
    beq .no                       ; #00 invalid
    cmp CH376_FILE_COUNT
    beq .ok
    bcc .ok
    clc
    rts
.ok:
    sta CH376_SELECT
    sec
    rts
.bad_pl:
    pla
.no:
    clc
    rts

; SELECT set → SHELL_WORK NUL 8.3 ("NAME.EXT" / "..").
; Keeps Y = STORAGE_NAMES page for YDE (dest index in WORK+14).
shell_entry_to_work:
    jsr storage_entry_ptr_select
    lda 0x00
    sta SHELL_WORK+14
    ldx 0x00
.nm:
    cpx 0x08
    bcs .ext
    lda yde,x
    cmp 0x20
    beq .ns
    phx
    ldx SHELL_WORK+14
    sta SHELL_WORK+0,x
    inx
    stx SHELL_WORK+14
    plx
.ns:
    inx
    jmp .nm
.ext:
    lda yde,x
    cmp 0x20
    beq .term
    phx
    ldx SHELL_WORK+14
    lda 0x2E
    sta SHELL_WORK+0,x
    inx
    stx SHELL_WORK+14
    plx
.ex:
    cpx 0x0B
    bcs .term
    lda yde,x
    cmp 0x20
    beq .es
    phx
    ldx SHELL_WORK+14
    sta SHELL_WORK+0,x
    inx
    stx SHELL_WORK+14
    plx
.es:
    inx
    jmp .ex
.term:
    ldx SHELL_WORK+14
    lda 0x00
    sta SHELL_WORK+0,x
    rts

; A = argv index. If "#HH", fill FNBUF from listing (C=1). Else C=0.
shell_argv_hash_fnbuf:
    jsr shell_arg_ptr
    jsr shell_hash_select
    bcc .no
    jsr storage_entry_ptr_select
    jsr storage_build_open_name
    bcc .no
    lda 0x00
    jsr ch376_cmd_file_close      ; drop cwd dir handle left by sync
    sec
    rts
.no:
    clc
    rts

; ============================================================
; mount / umount
; ============================================================
shell_cmd_mount:
    jsr storage_mount_verbose
    bcc .fail
    lda SHELL_FLAGS
    and 0xFE
    sta SHELL_FLAGS
    jsr shell_cwd_reset
    sec
    rts
.fail:
    lda SHELL_FLAGS
    ora SHELL_F_USB_ERR
    sta SHELL_FLAGS
    sec
    rts

shell_cmd_umount:
    lda CH376_STATUS
    and 0xFD
    sta CH376_STATUS
    jsr shell_cwd_reset
    lda SHELL_FLAGS
    and 0xFE
    sta SHELL_FLAGS
    ldd sh_msg_umount[15:8]
    lde sh_msg_umount[7:0]
    jsr ACIA_SEND_STRING
    sec
    rts

; ============================================================
; mkdir name / del name / rmdir name
; ============================================================
shell_cmd_mkdir:
    lda SHELL_ARGC
    cmp 0x02
    bcc .bad
    jsr shell_require_usb
    bcc .done
    jsr shell_sync_cwd
    bcc .ufail
    lda 0x01
    jsr shell_build_fname
    jsr STORAGE_MKDIR
    bcc .ufail
    jsr shell_sync_cwd
    sec
    rts
.bad:
    jmp shell_err_arg
.ufail:
    jsr shell_usb_fail
.done:
    sec
    rts

shell_cmd_del:
    lda SHELL_ARGC
    cmp 0x02
    bcc .bad
    jsr shell_require_usb
    bcc .done
    jsr shell_sync_cwd
    bcc .ufail
    lda 0x01
    jsr shell_argv_hash_fnbuf
    bcs .go
    lda 0x01
    jsr shell_build_fname
.go:
    jsr STORAGE_DELETE
    bcc .ufail
    sec
    rts
.bad:
    jmp shell_err_arg
.ufail:
    jsr shell_usb_fail
.done:
    sec
    rts

shell_cmd_rmdir:
    lda SHELL_ARGC
    cmp 0x02
    bcc .bad
    jsr shell_require_usb
    bcc .done
    jsr shell_sync_cwd
    bcc .ufail
    lda 0x01
    jsr shell_argv_hash_fnbuf
    bcs .go
    lda 0x01
    jsr shell_build_fname
.go:
    jsr STORAGE_RMDIR
    bcc .ufail
    jsr shell_sync_cwd
    sec
    rts
.bad:
    jmp shell_err_arg
.ufail:
    jsr shell_usb_fail
.done:
    sec
    rts

; ============================================================
; dir
; ============================================================
shell_cmd_dir:
    jsr shell_require_usb
    bcc .done
    jsr shell_sync_cwd
    bcc .syncfail
    lda 0x01
    sta CH376_LIST_STYLE          ; tabular (no N.)
    jsr storage_list_dir
    lda 0x00                      ; preserve C from list_dir
    sta CH376_LIST_STYLE
    bcc .listfail
    sec
    rts
.syncfail:
.listfail:
    jsr shell_usb_fail
.done:
    sec
    rts

; ============================================================
; cd [path]
; ============================================================
shell_cmd_cd:
    jsr shell_require_usb
    bcc .done
    lda SHELL_ARGC
    cmp 0x02
    bcc .show
    lda 0x01
    jsr shell_arg_ptr
    ; #HH → last dir listing index (must be a directory)
    jsr shell_hash_select
    bcc .snap
    jsr storage_entry_is_dir
    bcc .bad
    jsr shell_entry_to_work
    jmp .abs_or_rel
.snap:
    ; Snapshot dirname into SHELL_WORK+0..14 (before USB clobbers input)
    lda 0x01
    jsr shell_arg_ptr
    ldx 0x00
.snap_l:
    lda de,x
    sta SHELL_WORK+0,x
    beq .snap_done
    inx
    cpx 0x0E
    bcc .snap_l
    lda 0x00
    sta SHELL_WORK+0,x
.snap_done:
    ; check for "/"
    lda SHELL_WORK+0
    cmp 0x2F
    bne .notroot
    lda SHELL_WORK+1
    bne .abs_or_rel
    ; cd /
    jsr STORAGE_MOUNT
    bcc .fail
    jsr shell_cwd_reset
    sec
    rts
.notroot:
.abs_or_rel:
    ; ".." ?
    lda SHELL_WORK+0
    cmp 0x2E
    bne .enter
    lda SHELL_WORK+1
    cmp 0x2E
    bne .enter
    lda SHELL_WORK+2
    bne .enter
    jmp shell_cd_dotdot
.enter:
    jmp shell_cd_enter
.show:
    ldd SHELL_CWD[15:8]
    lde SHELL_CWD[7:0]
    jsr ACIA_SEND_STRING
    jsr ACIA_SEND_NEWLINE
    sec
    rts
.bad:
    jmp shell_err_arg
.fail:
    jsr shell_usb_fail
.done:
    sec
    rts

shell_cd_dotdot:
    jsr shell_sync_cwd
    bcc .f
    lda CH376_DEPTH
    beq .root
    lda 0x2E
    sta CH376_FNBUF
    sta CH376_FNBUF+1
    lda 0x00
    sta CH376_FNBUF+2
    jsr shell_open_dir
    bcc .f
    dec CH376_DEPTH
    jsr shell_cwd_pop
    sec
    rts
.root:
    jsr shell_cwd_reset
    sec
    rts
.f:
    jmp shell_err_path

shell_cd_enter:
    ; dirname already in SHELL_WORK+0; build FNBUF and open
    jsr shell_sync_cwd
    bcc .f
    ; build FNBUF from SHELL_WORK
    lda CH376_DEPTH
    bne .noslash
    lda 0x2F
    sta CH376_FNBUF
    ldy 0x01
    jmp .copy
.noslash:
    ldy 0x00
.copy:
    ldx 0x00
.cl:
    lda SHELL_WORK+0,x
    beq .copied
    jsr shell_upcase
    sta CH376_FNBUF,y
    inx
    iny
    cpy 0x0F
    bcc .cl
.copied:
    lda 0x00
    sta CH376_FNBUF,y
    jsr shell_open_dir
    bcc .f
    inc CH376_DEPTH
    ; set cwd from FNBUF when at root, else append
    lda SHELL_CWD_LEN
    cmp 0x01
    bne .append
    ldx 0x00
.cpfn:
    lda CH376_FNBUF,x
    sta SHELL_CWD,x
    beq .cpfn_done
    inx
    cpx 0x1F
    bcc .cpfn
    lda 0x00
    sta SHELL_CWD,x
.cpfn_done:
    stx SHELL_CWD_LEN
    sec
    rts
.append:
    ldy 0x00
    lda CH376_FNBUF
    cmp 0x2F
    bne .ptr
    ldy 0x01
.ptr:
    clc
    tya
    adc CH376_FNBUF[7:0]
    tae
    lda CH376_FNBUF[15:8]
    adc 0x00
    tad
    jsr shell_cwd_append
    bcs .ok
    jsr shell_cwd_reset
.ok:
    sec
    rts
.f:
    jmp shell_err_path

; Append "/" + string at D:E to SHELL_CWD. C=1 ok.
; D:E = name string (advanced via INE/IND).
shell_cwd_append:
    ldx SHELL_CWD_LEN
    cpx 0x01
    beq .copy
    cpx 0x20                      ; SHELL_CWD_MAX
    bcs .ov
    lda 0x2F
    sta SHELL_CWD,x
    inx
.copy:
    phx
    ldx 0x00
    lda de,x
    sta SHELL_WORK+4            ; PLX clobbers Z
    plx
    lda SHELL_WORK+4
    beq .term
    jsr shell_upcase
    cpx 0x20
    bcs .ov
    sta SHELL_CWD,x
    inx
    ine
    bne .copy
    ind
    jmp .copy
.term:
    cpx 0x20
    bcs .ov
    lda 0x00
    sta SHELL_CWD,x
    stx SHELL_CWD_LEN
    sec
    rts
.ov:
    clc
    rts

shell_cwd_pop:
    ; remove last /segment from cwd
    ldx SHELL_CWD_LEN
    cpx 0x02
    bcc .to_root
    dex
.trim:
    lda SHELL_CWD,x
    cmp 0x2F
    beq .cut
    cpx 0x00
    beq .to_root
    dex
    jmp .trim
.cut:
    cpx 0x00
    beq .to_root
    lda 0x00
    sta SHELL_CWD,x
    stx SHELL_CWD_LEN
    rts
.to_root:
    jmp shell_cwd_reset

; ============================================================
; load file [addr]  — USB load via STORAGE_LOAD_FILE
; ============================================================
shell_cmd_load:
    lda SHELL_ARGC
    cmp 0x02
    bcc .bad
    jsr shell_require_usb
    bcc .done
    jsr shell_sync_cwd
    bcc .ufail
    ; optional addr in argv2
    lda SHELL_ARGC
    cmp 0x03
    bcc .auto
    lda 0x02
    jsr shell_arg_ptr
    jsr shell_parse_addr
    bcs .bad
    sty STORAGE_ADDR_PAGE
    std STORAGE_ADDR_MSB
    ste STORAGE_ADDR_LSB
    lda 0x00
    sta CH376_OT_AUTO
    jmp .dofile
.auto:
    lda 0x01
    sta CH376_OT_AUTO
.dofile:
    jsr shell_load_by_name
    bcc .ufail
    sec
    rts
.bad:
    jmp shell_err_arg
.ufail:
    jsr shell_usb_fail
.done:
    sec
    rts

; argv1 = filename or #HH from last dir. Find size, then STORAGE_LOAD_FILE.
shell_load_by_name:
    lda 0x01
    jsr shell_arg_ptr
    jsr shell_hash_select
    bcc .scan
    jsr storage_entry_is_dir
    bcs .fail
    jsr storage_entry_ptr_select
    jsr storage_build_open_name
    bcc .fail
    ; sync_cwd may leave the cwd directory open; close it so FILE_OPEN
    ; opens the file (not the directory handle).
    lda 0x00
    jsr ch376_cmd_file_close
    jmp .gotsize
.scan:
    lda 0x01
    jsr shell_build_fname
    ; Enumerate quietly (need size from STORAGE_NAMES; no dir dump)
    lda 0x02
    sta CH376_LIST_STYLE
    jsr storage_list_dir
    lda 0x00                      ; preserve C from list_dir
    sta CH376_LIST_STYLE
    bcc .fail
    jsr shell_find_listed
    bcc .fail
    ; rebuild fname (list may have clobbered FNBUF)
    lda 0x01
    jsr shell_build_fname
.gotsize:
    ; size in CH376_SIZE_* 
    lda CH376_SIZE_3
    ora CH376_SIZE_2
    bne .toobig
    lda CH376_SIZE_0
    sta CH376_TOTAL_LO
    lda CH376_SIZE_1
    sta CH376_TOTAL_HI
    jsr STORAGE_LOAD_FILE
    bcc .fail
    ; update working address
    lda STORAGE_LOAD_PTRP
    sta MAIN_MENU_ADDR_PAGE
    lda STORAGE_LOAD_PTRH
    sta MAIN_MENU_ADDR_MSB
    lda STORAGE_LOAD_PTR
    sta MAIN_MENU_ADDR_LSB
    sec
    rts
.toobig:
.fail:
    clc
    rts

; Match argv1 against STORAGE_NAMES using padded 8.3 form.
; C=1 found; size → CH376_SIZE_*.
shell_find_listed:
    lda 0x01
    jsr shell_arg_ptr
    jsr shell_to_fat83               ; → SHELL_WORK+0..10
    lda 0x00
    sta CH376_SELECT
.find:
    inc CH376_SELECT
    lda CH376_SELECT
    cmp CH376_FILE_COUNT
    beq .try
    bcc .try
    clc
    rts
.try:
    jsr storage_entry_ptr_select
    ldx 0x00
.cmp:
    lda yde,x
    cmp SHELL_WORK+0,x
    bne .find
    inx
    cpx 0x0B
    bcc .cmp
    ldx 0x0B
    lda yde,x
    sta CH376_SIZE_0
    inx
    lda yde,x
    sta CH376_SIZE_1
    inx
    lda yde,x
    sta CH376_SIZE_2
    inx
    lda yde,x
    sta CH376_SIZE_3
    sec
    rts

; D:E = "NAME.EXT" or "NAME" → SHELL_WORK[0..10] as FAT 8.3 (spaces).
; Source walked with LDA DE,X + INE/IND; X = dest index.
shell_to_fat83:
    ldx 0x00
.sp:
    lda 0x20
    sta SHELL_WORK+0,x
    inx
    cpx 0x0B
    bcc .sp
    ldx 0x00
.nloop:
    phx
    ldx 0x00
    lda de,x
    tay                         ; Y = src char (PLX clobbers Z)
    plx
    tya
    beq .done
    jsr shell_upcase
    cmp 0x2E
    beq .ext
    cpx 0x08
    bcs .nskip
    sta SHELL_WORK+0,x
    inx
.nskip:
    ine
    bne .nloop
    ind
    jmp .nloop
.ext:
    ldx 0x08
    ine
    bne .eloop
    ind
.eloop:
    phx
    ldx 0x00
    lda de,x
    tay
    plx
    tya
    beq .done
    jsr shell_upcase
    cpx 0x0B
    bcs .eskip
    sta SHELL_WORK+0,x
    inx
.eskip:
    ine
    bne .eloop
    ind
    jmp .eloop
.done:
    rts

; ============================================================
; save file len [addr]  — USB save via STORAGE_SAVE_FILE (+ OT)
; len = 4 hex digits; addr defaults to working address
; ============================================================
shell_cmd_save:
    lda SHELL_ARGC
    cmp 0x03
    bcc .bad
    jsr shell_require_usb
    bcc .done
    jsr shell_sync_cwd
    bcc .ufail
    lda 0x01
    jsr shell_build_fname
    lda 0x02
    jsr shell_arg_ptr
    jsr shell_hex16
    bcs .bad
    ste CH376_TOTAL_LO
    std CH376_TOTAL_HI
    lda CH376_TOTAL_LO
    ora CH376_TOTAL_HI
    beq .bad
    lda SHELL_ARGC
    cmp 0x04
    bcc .work
    lda 0x03
    jsr shell_arg_ptr
    jsr shell_parse_addr
    bcs .bad
    sty CH376_SAVE_PAGE
    std CH376_SAVE_MSB
    ste CH376_SAVE_LSB
    jmp .go
.work:
    lda MAIN_MENU_ADDR_PAGE
    sta CH376_SAVE_PAGE
    lda MAIN_MENU_ADDR_MSB
    sta CH376_SAVE_MSB
    lda MAIN_MENU_ADDR_LSB
    sta CH376_SAVE_LSB
.go:
    ; sync_cwd may leave the directory open
    lda 0x00
    jsr ch376_cmd_file_close
    lda 0x01
    sta CH376_OT_FLAG
    jsr STORAGE_SAVE_FILE
    bcc .ufail
    jsr shell_sync_cwd
    sec
    rts
.bad:
    jmp shell_err_arg
.ufail:
    jsr shell_usb_fail
.done:
    sec
    rts

; ============================================================
; exec file  / external command
; ============================================================
shell_cmd_exec:
    lda SHELL_ARGC
    cmp 0x02
    bcc .bad
    ; Preserve optional path for the app (exec EDIT.BIN notes.txt)
    lda 0x00
    sta SHELL_APP_ARGC
    lda SHELL_ARGC
    cmp 0x03
    bcc .no_app_arg
    lda 0x02
    jsr shell_app_arg_stash
.no_app_arg:
    jsr shell_require_usb
    bcc .done
    jsr shell_sync_cwd
    bcc .ufail
    lda 0x01
    sta CH376_OT_AUTO
    jsr shell_load_by_name
    bcc .ufail
    jsr MENU_RUN_START
    sec
    rts
.bad:
    jmp shell_err_arg
.ufail:
    jsr shell_usb_fail
.done:
    sec
    rts

shell_cmd_external:
    ; Bare name → load NAME.BIN. Optional argv1 is stashed for the app
    ; ("edit notes.txt" → load EDIT.BIN, path in SHELL_APP_ARG).
    lda 0x00
    sta SHELL_APP_ARGC
    lda SHELL_ARGC
    cmp 0x02
    bcc .no_app_arg
    lda 0x01
    jsr shell_app_arg_stash
.no_app_arg:
    jsr shell_require_usb
    bcc .unknown
    jsr shell_sync_cwd
    bcc .unknown
    lda SHELL_ARGV0
    sta SHELL_ARGV1
    lda 0x02
    sta SHELL_ARGC
    ; "#02" is a dir index — do not append .BIN
    lda 0x00
    jsr shell_arg_ptr
    ldx 0x00
    lda de,x
    cmp 0x23                      ; '#'
    beq .load
    jsr shell_argv1_ensure_bin    ; "demo" → "demo.BIN"
.load:
    lda 0x01
    sta CH376_OT_AUTO
    jsr shell_load_by_name
    bcc .unknown
    jsr MENU_RUN_START
    rts
.unknown:
    ldd sh_err_unk[15:8]
    lde sh_err_unk[7:0]
    jsr ACIA_SEND_STRING
    rts

; A = argv index → copy string into SHELL_APP_ARG, set SHELL_APP_ARGC=1.
shell_app_arg_stash:
    cmp SHELL_ARGC
    bcs .no
    jsr shell_arg_ptr
    ldx 0x00
.cp:
    lda de,x
    sta SHELL_APP_ARG,x
    beq .ok
    inx
    cpx 0x1F
    bcc .cp
    lda 0x00
    sta SHELL_APP_ARG,x
.ok:
    lda 0x01
    sta SHELL_APP_ARGC
    rts
.no:
    lda 0x00
    sta SHELL_APP_ARGC
    rts

; If argv1 has no '.', append ".BIN" in-place (input buffer).
shell_argv1_ensure_bin:
    lda 0x01
    jsr shell_arg_ptr
    ldx 0x00
    lda 0x00
    sta SHELL_WORK+0                ; saw_dot
.sc:
    lda de,x
    beq .end
    cmp 0x2E
    bne .nx
    lda 0x01
    sta SHELL_WORK+0
.nx:
    inx
    cpx 0x20
    bcc .sc
.end:
    lda SHELL_WORK+0
    bne .done
    ; need 4 bytes for .BIN + NUL
    txa
    clc
    adc 0x04
    cmp SHELL_INPUT_MAX
    bcs .done
    lda 0x2E
    sta de,x
    inx
    lda "B"
    sta de,x
    inx
    lda "I"
    sta de,x
    inx
    lda "N"
    sta de,x
    inx
    lda 0x00
    sta de,x
    ; Keep buffer count covering the new tail (offset argv1 + len).
    lda SHELL_ARGV1
    stx SHELL_WORK+0
    clc
    adc SHELL_WORK+0
    sta MAIN_MENU_INPUT_BUFFER_COUNT
.done:
    rts

; ============================================================
; type file — print text to serial (read until EOF / 4KB cap)
; ============================================================
shell_cmd_type:
    lda SHELL_ARGC
    cmp 0x02
    bcc .bad
    jsr shell_require_usb
    bcc .done
    jsr shell_sync_cwd
    bcc .ufail
    lda 0x01
    jsr shell_argv_hash_fnbuf
    bcs .open
    lda 0x01
    jsr shell_build_fname
.open:
    jsr storage_set_name_fnbuf
    jsr STORAGE_OPEN
    bcc .ufail
    ; Cap total bytes printed
    lda 0x00
    sta SHELL_WORK+0              ; lo count
    lda 0x10
    sta SHELL_WORK+1              ; hi = 0x1000 max
.rd:
    lda SHELL_WORK+0
    ora SHELL_WORK+1
    beq .close
    lda 0x20
    sta CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd CH376_BUF[15:8]
    lde CH376_BUF[7:0]
    jsr STORAGE_READ
    bcc .close
    lda CH376_LOADED_LO
    beq .close
    ldx 0x00
.pr:
    cpx CH376_LOADED_LO
    bcs .dec
    lda CH376_BUF,x
    cmp 0x0A
    beq .nl
    cmp 0x0D
    beq .nx
    cmp 0x20
    bcc .dot
    cmp 0x7F
    bcs .dot
    jsr ACIA_SEND_CHAR
    jmp .nx
.nl:
    jsr ACIA_SEND_NEWLINE
    jmp .nx
.dot:
    lda 0x2E
    jsr ACIA_SEND_CHAR
.nx:
    inx
    jmp .pr
.dec:
    lda SHELL_WORK+0
    sec
    sbc CH376_LOADED_LO
    sta SHELL_WORK+0
    lda SHELL_WORK+1
    sbc 0x00
    sta SHELL_WORK+1
    ; if short read, EOF
    lda CH376_LOADED_LO
    cmp 0x20
    bcc .close
    jmp .rd
.close:
    lda 0x00
    jsr STORAGE_CLOSE
    jsr ACIA_SEND_NEWLINE
    ; clear USB err on success path
    lda SHELL_FLAGS
    and 0xFE
    sta SHELL_FLAGS
    sec
    rts
.bad:
    jmp shell_err_arg
.ufail:
    jsr shell_usb_fail
.done:
    sec
    rts

; ============================================================
; Errors
; ============================================================
shell_err_arg:
    ldd sh_err_arg[15:8]
    lde sh_err_arg[7:0]
    jsr ACIA_SEND_STRING
    sec
    rts

shell_err_path:
    ldd sh_err_path[15:8]
    lde sh_err_path[7:0]
    jsr ACIA_SEND_STRING
    sec
    rts

shell_usb_fail:
    lda SHELL_FLAGS
    ora SHELL_F_USB_ERR
    sta SHELL_FLAGS
    ldd sh_err_usb[15:8]
    lde sh_err_usb[7:0]
    jsr ACIA_SEND_STRING
    rts

; ============================================================
; Tab-complete: last token vs CWD filenames (quiet STORAGE_NAMES).
; 0 matches → BEL; 1 → fill name (+ '/' if dir); 2+ → common prefix.
; ============================================================
SHELL_TAB_COMPLETE:
    ; Complete at end of line
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    sta MAIN_MENU_INPUT_CURSOR
    ; Token start = after last space (or 0)
    tax
    beq .beep
.find:
    dex
    lda MAIN_MENU_INPUT_BUFFER,x
    cmp 0x20
    beq .tok
    cpx 0x00
    bne .find
    jmp .tok0
.tok:
    inx
.tok0:
    stx SHELL_TAB_TOK
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    sec
    sbc SHELL_TAB_TOK
    sta SHELL_TAB_PLEN
    beq .beep

    jsr STORAGE_ENSURE_MOUNTED
    bcc .beep
    jsr shell_sync_cwd
    bcc .beep
    lda 0x02
    sta CH376_LIST_STYLE
    jsr storage_list_dir
    lda 0x00
    sta CH376_LIST_STYLE
    bcc .beep

    lda 0x00
    sta SHELL_TAB_N
    sta SHELL_TAB_DIR
    sta CH376_SELECT
.scan:
    inc CH376_SELECT
    lda CH376_SELECT
    cmp CH376_FILE_COUNT
    beq .try
    bcc .try
    jmp .done_scan
.try:
    jsr shell_entry_to_work
    jsr shell_tab_prefix_ok
    bcc .scan
    lda SHELL_TAB_N
    bne .common
    ; first match → draft + dir flag
    ldx 0x00
.cp1:
    lda SHELL_WORK+0,x
    sta SHELL_HIST_DRAFT,x
    beq .cp1d
    inx
    cpx 0x28
    bcc .cp1
    lda 0x00
    sta SHELL_HIST_DRAFT,x
.cp1d:
    jsr storage_entry_is_dir
    lda 0x00
    rol a                         ; C → A (1 if dir)
    sta SHELL_TAB_DIR
    inc SHELL_TAB_N
    jmp .scan
.common:
    ; shorten DRAFT to common prefix with WORK
    ldx 0x00
.cml:
    lda SHELL_HIST_DRAFT,x
    beq .cmd
    cmp SHELL_WORK+0,x
    bne .cmt
    inx
    jmp .cml
.cmt:
    lda 0x00
    sta SHELL_HIST_DRAFT,x
.cmd:
    lda 0x00
    sta SHELL_TAB_DIR             ; ambiguous → no auto '/'
    inc SHELL_TAB_N
    jmp .scan

.done_scan:
    lda SHELL_TAB_N
    beq .beep
    cmp 0x01
    bne .apply
    ; sole match: append '/' for directories
    lda SHELL_TAB_DIR
    beq .apply
    ldx 0x00
.slen:
    lda SHELL_HIST_DRAFT,x
    beq .addsl
    inx
    jmp .slen
.addsl:
    cpx 0x00
    beq .apply
    dex
    lda SHELL_HIST_DRAFT,x
    cmp 0x2F
    beq .apply
    inx
    lda 0x2F
    sta SHELL_HIST_DRAFT,x
    inx
    lda 0x00
    sta SHELL_HIST_DRAFT,x

.apply:
    ; no progress?
    ldx 0x00
.alen:
    lda SHELL_HIST_DRAFT,x
    beq .alen_d
    inx
    jmp .alen
.alen_d:
    cpx SHELL_TAB_PLEN
    bcc .beep
    beq .beep
    ; fit in buffer?
    txa
    clc
    adc SHELL_TAB_TOK
    cmp SHELL_INPUT_MAX
    beq .fit
    bcs .beep
.fit:
    ldx SHELL_TAB_TOK
    ldy 0x00
.ins:
    lda SHELL_HIST_DRAFT,y
    beq .insd
    sta MAIN_MENU_INPUT_BUFFER,x
    inx
    iny
    jmp .ins
.insd:
    stx MAIN_MENU_INPUT_BUFFER_COUNT
    jmp shell_redraw_input

.beep:
    lda 0x07
    jmp ACIA_SEND_CHAR

; C=1 if SHELL_WORK starts with input token (case-insensitive).
shell_tab_prefix_ok:
    ldx 0x00
.p:
    cpx SHELL_TAB_PLEN
    bcs .yes
    txa
    clc
    adc SHELL_TAB_TOK
    tay
    lda MAIN_MENU_INPUT_BUFFER,y
    jsr shell_upcase
    cmp SHELL_WORK+0,x
    bne .no
    inx
    jmp .p
.yes:
    sec
    rts
.no:
    clc
    rts

; ============================================================
; Command history (5 slots) — Up/Down arrows
; ============================================================

; A = physical slot 0..4 → D:E = SHELL_HIST + A*40
shell_hist_slot_de:
    sta SHELL_WORK+0
    asl a
    asl a
    asl a                     ; *8
    sta SHELL_WORK+1
    lda SHELL_WORK+0
    asl a
    asl a
    asl a
    asl a
    asl a                     ; *32
    clc
    adc SHELL_WORK+1          ; *40
    clc
    adc SHELL_HIST[7:0]
    tae
    lda SHELL_HIST[15:8]
    adc 0x00
    tad
    rts

; A = age (0=newest) → A = physical slot
shell_hist_age_phys:
    sta SHELL_WORK+0
    lda SHELL_HIST_HEAD
    clc
    adc 0x04
    sec
    sbc SHELL_WORK+0
    cmp SHELL_HIST_MAX
    bcc .ok
    sec
    sbc SHELL_HIST_MAX
.ok:
    rts

; Echo buffer after the prompt already on screen (same as typing).
; SHELL_HIST_PAINTED = how many chars are currently shown after the prompt;
; erase those with BS-SP-BS, then print the new buffer. No CR/NL/re-prompt.
shell_redraw_input:
    ldx SHELL_HIST_PAINTED
    beq .paint
.erase:
    lda 0x08
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda 0x08
    jsr ACIA_SEND_CHAR
    dex
    bne .erase
.paint:
    lda 0x00
    sta MAIN_MENU_INPUT_CURSOR
.pr:
    lda MAIN_MENU_INPUT_CURSOR
    cmp MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .done
    tax
    lda MAIN_MENU_INPUT_BUFFER,x
    jsr ACIA_SEND_CHAR
    inc MAIN_MENU_INPUT_CURSOR
    jmp .pr
.done:
    lda MAIN_MENU_INPUT_CURSOR
    sta SHELL_HIST_PAINTED
    rts

; Copy current input → draft.
shell_hist_save_draft:
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    sta SHELL_HIST_DRAFT_LEN
    ldx 0x00
.cp:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .done
    lda MAIN_MENU_INPUT_BUFFER,x
    sta SHELL_HIST_DRAFT,x
    inx
    jmp .cp
.done:
    rts

; Load SHELL_HIST_POS (age) into input buffer + redraw.
shell_hist_load_age:
    lda SHELL_HIST_POS
    jsr shell_hist_age_phys
    tax
    lda SHELL_HIST_SLEN,x
    sta MAIN_MENU_INPUT_BUFFER_COUNT
    txa
    jsr shell_hist_slot_de
    ldx 0x00
.cp:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .redraw
    lda de,x
    sta MAIN_MENU_INPUT_BUFFER,x
    inx
    jmp .cp
.redraw:
    jmp shell_redraw_input

; Load draft into input + redraw.
shell_hist_load_draft:
    lda SHELL_HIST_DRAFT_LEN
    sta MAIN_MENU_INPUT_BUFFER_COUNT
    ldx 0x00
.cp:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .redraw
    lda SHELL_HIST_DRAFT,x
    sta MAIN_MENU_INPUT_BUFFER,x
    inx
    jmp .cp
.redraw:
    jmp shell_redraw_input

; Push current line into history (call before DISPATCH).
; Skips empty / whitespace-only lines and exact duplicates of newest.
SHELL_HIST_PUSH:
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    beq .done
    ; Skip whitespace-only (plain Enter / spaces)
    ldx 0x00
.ws:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .done
    lda MAIN_MENU_INPUT_BUFFER,x
    cmp 0x21                      ; < '!' → space/control
    bcs .dup
    inx
    jmp .ws
.dup:
    lda SHELL_HIST_LEN
    beq .store
    lda 0x00
    jsr shell_hist_age_phys
    tax
    lda SHELL_HIST_SLEN,x
    cmp MAIN_MENU_INPUT_BUFFER_COUNT
    bne .store
    txa
    jsr shell_hist_slot_de
    ldx 0x00
.cmp:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .done                   ; equal
    lda de,x
    cmp MAIN_MENU_INPUT_BUFFER,x
    bne .store
    inx
    jmp .cmp
.store:
    lda SHELL_HIST_HEAD
    tax
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    sta SHELL_HIST_SLEN,x
    txa
    jsr shell_hist_slot_de
    ldx 0x00
.cp:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .advance
    lda MAIN_MENU_INPUT_BUFFER,x
    sta de,x
    inx
    jmp .cp
.advance:
    inc SHELL_HIST_HEAD
    lda SHELL_HIST_HEAD
    cmp SHELL_HIST_MAX
    bcc .len
    lda 0x00
    sta SHELL_HIST_HEAD
.len:
    lda SHELL_HIST_LEN
    cmp SHELL_HIST_MAX
    bcs .done
    inc SHELL_HIST_LEN
.done:
    lda 0xFF
    sta SHELL_HIST_POS
    rts

; Arrow Up — older command.
SHELL_HIST_UP:
    lda SHELL_HIST_LEN
    beq .ret
    lda SHELL_HIST_POS
    cmp 0xFF
    bne .older
    jsr shell_hist_save_draft
    lda 0x00
    sta SHELL_HIST_POS
    jmp shell_hist_load_age
.older:
    clc
    adc 0x01
    cmp SHELL_HIST_LEN
    bcs .ret                    ; already oldest
    sta SHELL_HIST_POS
    jmp shell_hist_load_age
.ret:
    rts

; Arrow Down — newer command / back to draft.
SHELL_HIST_DOWN:
    lda SHELL_HIST_POS
    cmp 0xFF
    beq .ret
    cmp 0x00
    beq .todraft
    dec SHELL_HIST_POS
    lda SHELL_HIST_POS
    jmp shell_hist_load_age
.todraft:
    lda 0xFF
    sta SHELL_HIST_POS
    jmp shell_hist_load_draft
.ret:
    rts

; ============================================================
; Strings
; ============================================================
sh_s_help:   #d "HELP", 0x00
sh_s_qm:     #d "?", 0x00
sh_s_dump:   #d "DUMP", 0x00
sh_s_call:   #d "CALL", 0x00
sh_s_upload: #d "UPLOAD", 0x00
sh_s_load:   #d "LOAD", 0x00
sh_s_save:   #d "SAVE", 0x00
sh_s_addr:   #d "ADDR", 0x00
sh_s_cls:    #d "CLS", 0x00
sh_s_ver:    #d "VER", 0x00
sh_s_exec:   #d "EXEC", 0x00
sh_s_peek:   #d "PEEK", 0x00
sh_s_poke:   #d "POKE", 0x00
sh_s_fill:   #d "FILL", 0x00
sh_s_copy:   #d "COPY", 0x00
sh_s_dir:    #d "DIR", 0x00
sh_s_cd:     #d "CD", 0x00
sh_s_type:   #d "TYPE", 0x00
sh_s_mount:  #d "MOUNT", 0x00
sh_s_umount: #d "UMOUNT", 0x00
sh_s_mkdir:  #d "MKDIR", 0x00
sh_s_del:    #d "DEL", 0x00
sh_s_rmdir:  #d "RMDIR", 0x00

; name(MSB,LSB) + handler(MSB,LSB) — JMP (zp,X) is MSB-first.
; MUST stay within one page: LDD/LDE tab,X and JMP (tab+2,X) do not carry
; lo+X into the high byte (92-byte table → fits if page-aligned).
; customasm #align is in bits: 2048 bits = 256 bytes.
#align 2048
shell_builtin_tab:
    #d sh_s_help[15:8],   sh_s_help[7:0],   shell_cmd_help[15:8],   shell_cmd_help[7:0]
    #d sh_s_qm[15:8],     sh_s_qm[7:0],     shell_cmd_help[15:8],   shell_cmd_help[7:0]
    #d sh_s_dump[15:8],   sh_s_dump[7:0],   shell_cmd_dump[15:8],   shell_cmd_dump[7:0]
    #d sh_s_call[15:8],   sh_s_call[7:0],   shell_cmd_call[15:8],   shell_cmd_call[7:0]
    #d sh_s_upload[15:8], sh_s_upload[7:0], shell_cmd_upload[15:8], shell_cmd_upload[7:0]
    #d sh_s_load[15:8],   sh_s_load[7:0],   shell_cmd_load[15:8],   shell_cmd_load[7:0]
    #d sh_s_save[15:8],   sh_s_save[7:0],   shell_cmd_save[15:8],   shell_cmd_save[7:0]
    #d sh_s_addr[15:8],   sh_s_addr[7:0],   shell_cmd_addr[15:8],   shell_cmd_addr[7:0]
    #d sh_s_cls[15:8],    sh_s_cls[7:0],    shell_cmd_cls[15:8],    shell_cmd_cls[7:0]
    #d sh_s_ver[15:8],    sh_s_ver[7:0],    shell_cmd_ver[15:8],    shell_cmd_ver[7:0]
    #d sh_s_exec[15:8],   sh_s_exec[7:0],   shell_cmd_exec[15:8],   shell_cmd_exec[7:0]
    #d sh_s_peek[15:8],   sh_s_peek[7:0],   shell_cmd_peek[15:8],   shell_cmd_peek[7:0]
    #d sh_s_poke[15:8],   sh_s_poke[7:0],   shell_cmd_poke[15:8],   shell_cmd_poke[7:0]
    #d sh_s_fill[15:8],   sh_s_fill[7:0],   shell_cmd_fill[15:8],   shell_cmd_fill[7:0]
    #d sh_s_copy[15:8],   sh_s_copy[7:0],   shell_cmd_copy[15:8],   shell_cmd_copy[7:0]
    #d sh_s_dir[15:8],    sh_s_dir[7:0],    shell_cmd_dir[15:8],    shell_cmd_dir[7:0]
    #d sh_s_cd[15:8],     sh_s_cd[7:0],     shell_cmd_cd[15:8],     shell_cmd_cd[7:0]
    #d sh_s_type[15:8],   sh_s_type[7:0],   shell_cmd_type[15:8],   shell_cmd_type[7:0]
    #d sh_s_mount[15:8],  sh_s_mount[7:0],  shell_cmd_mount[15:8],  shell_cmd_mount[7:0]
    #d sh_s_umount[15:8], sh_s_umount[7:0], shell_cmd_umount[15:8], shell_cmd_umount[7:0]
    #d sh_s_mkdir[15:8],  sh_s_mkdir[7:0],  shell_cmd_mkdir[15:8],  shell_cmd_mkdir[7:0]
    #d sh_s_del[15:8],    sh_s_del[7:0],    shell_cmd_del[15:8],    shell_cmd_del[7:0]
    #d sh_s_rmdir[15:8],  sh_s_rmdir[7:0],  shell_cmd_rmdir[15:8],  shell_cmd_rmdir[7:0]

sh_msg_ver:
    #d "Otto Kernel ", KERNEL_VERSION, " (", KERNEL_BUILDDATE, ")", 0x0A, 0x0D, 0x00
sh_msg_addr:
    #d "addr 0x", 0x00
sh_msg_umount:
    #d "unmounted", 0x0A, 0x0D, 0x00
sh_err_arg:
    #d "?arg", 0x0A, 0x0D, 0x00
sh_err_path:
    #d "?path", 0x0A, 0x0D, 0x00
sh_err_nousb:
    #d "?no usb", 0x0A, 0x0D, 0x00
sh_err_nodisk:
    #d "?no disk", 0x0A, 0x0D, 0x00
sh_err_usb:
    #d "?usb", 0x0A, 0x0D, 0x00
sh_err_unk:
    #d "?unknown", 0x0A, 0x0D, 0x00
