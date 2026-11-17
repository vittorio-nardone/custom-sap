; @load-address 0x8400
; EDIT - minimal line editor for USB text files.
;
;   edit              new buffer
;   edit NOTES.TXT    open (path via SHELL_APP_ARG)
;   exec EDIT.BIN f   same
;
; Buffer: page 1 @ 0x010000 - 96 lines x 64 bytes.
; Scratch: 0xB180+ (below TinyPascal ED_* scratch where possible).
;
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#const TE_PAGE       = 0x01
#const TE_BASE       = 0x0000
#const TE_LINE0      = 0x0001
#const TE_LINE_SIZE  = 0x40
#const TE_MAX_LINES  = 0x60
#const TE_MAX_COL    = 0x3F

; Avoid ED_* (TinyPascal exports in symbols.asm)
#const TE_CMD        = 0xB180
#const TE_CMD_MAX    = 0x14
#const TE_LINE       = 0xB1A0
#const TE_FNAME      = 0xB1E0
#const TE_DIRTY      = 0xB1F0
#const TE_N          = 0xB1F1
#const TE_N2         = 0xB1F2
#const TE_TMP        = 0xB1F3
#const TE_RL_LEN     = 0xB1F4
#const TE_HAS_NAME   = 0xB1F5

#bank ram

    jsr VT100_ERASE_SCREEN
    jsr VT100_CURSOR_HOME
    ldd te_banner[15:8]
    lde te_banner[7:0]
    jsr ACIA_SEND_STRING
    jsr te_new_buf
    jsr te_take_arg
    bcc te_main
    jsr te_do_open

te_main:
    ldd te_prompt[15:8]
    lde te_prompt[7:0]
    jsr ACIA_SEND_STRING
    ldd TE_CMD[15:8]
    lde TE_CMD[7:0]
    lda TE_CMD_MAX
    jsr te_read_line
    lda TE_RL_LEN
    beq te_main
    lda TE_CMD
    jsr te_downcase
    cmp "q"
    beq te_quit
    cmp "h"
    beq te_help
    cmp "n"
    beq te_new
    cmp "l"
    beq te_list
    cmp "i"
    beq te_ins
    cmp "d"
    beq te_del
    cmp "e"
    beq te_edit
    cmp "o"
    beq te_open
    cmp "w"
    beq te_write
    ldd te_err[15:8]
    lde te_err[7:0]
    jsr ACIA_SEND_STRING
    jmp te_main

te_quit:
    rts

te_help:
    ldd te_helpmsg[15:8]
    lde te_helpmsg[7:0]
    jsr ACIA_SEND_STRING
    jmp te_main

te_new:
    jsr te_new_buf
    ldd te_newmsg[15:8]
    lde te_newmsg[7:0]
    jsr ACIA_SEND_STRING
    jmp te_main

te_list:
    jsr te_cmd_list
    jmp te_main

te_ins:
    jsr te_cmd_insert
    jmp te_main

te_del:
    jsr te_cmd_delete
    jmp te_main

te_edit:
    jsr te_cmd_edit
    jmp te_main

te_open:
    jsr te_parse_name
    jsr te_do_open
    jmp te_main

te_write:
    jsr te_parse_name
    jsr te_do_save
    jmp te_main

; ================================================================
te_take_arg:
    lda SHELL_APP_ARGC
    beq te_take_no
    ldx 0x00
te_take_cp:
    lda SHELL_APP_ARG,x
    sta TE_FNAME,x
    beq te_take_ok
    inx
    cpx 0x0F
    bcc te_take_cp
    lda 0x00
    sta TE_FNAME,x
te_take_ok:
    lda 0x01
    sta TE_HAS_NAME
    sec
    rts
te_take_no:
    lda 0x00
    sta TE_HAS_NAME
    clc
    rts

te_parse_name:
    ldx 0x01
te_pn_sp:
    cpx TE_RL_LEN
    bcs te_pn_done
    lda TE_CMD,x
    cmp 0x20
    bne te_pn_got
    inx
    jmp te_pn_sp
te_pn_got:
    ldy 0x00
te_pn_cp:
    cpx TE_RL_LEN
    bcs te_pn_nul
    lda TE_CMD,x
    cmp 0x20
    beq te_pn_nul
    jsr te_upcase
    sta TE_FNAME,y
    inx
    iny
    cpy 0x0F
    bcc te_pn_cp
te_pn_nul:
    lda 0x00
    sta TE_FNAME,y
    lda 0x01
    sta TE_HAS_NAME
te_pn_done:
    rts

; ================================================================
; Drop the text. Keeps TE_FNAME so "o file" then "w" writes the same file.
te_clear_text:
    ldy TE_PAGE
    ldd TE_BASE[15:8]
    lde TE_BASE[7:0]
    lda 0x00
    ldx 0x00
    sta yde,x
    sta TE_DIRTY
    rts

te_new_buf:
    jsr te_clear_text
    lda 0x00
    sta TE_HAS_NAME
    sta TE_FNAME
    rts

te_nlines:
    ldy TE_PAGE
    ldd TE_BASE[15:8]
    lde TE_BASE[7:0]
    ldx 0x00
    lda yde,x
    rts

te_set_nlines:
    ldy TE_PAGE
    ldd TE_BASE[15:8]
    lde TE_BASE[7:0]
    ldx 0x00
    sta yde,x
    rts

; A = 1-based line -> Y:DE = slot
te_line_addr:
    tax
    dex
    stx TE_TMP
    lda 0x00
    sta SHELL_WORK+0
    sta SHELL_WORK+1
    ldx TE_TMP
    beq te_la_add
te_la_mul:
    clc
    lda SHELL_WORK+0
    adc TE_LINE_SIZE
    sta SHELL_WORK+0
    lda SHELL_WORK+1
    adc 0x00
    sta SHELL_WORK+1
    dex
    bne te_la_mul
te_la_add:
    clc
    lda SHELL_WORK+0
    adc TE_LINE0[7:0]
    tae
    lda SHELL_WORK+1
    adc TE_LINE0[15:8]
    tad
    ldy TE_PAGE
    rts

te_get_line:
    jsr te_line_addr
    ldx 0x00
te_gl_cp:
    lda yde,x
    sta TE_LINE,x
    beq te_gl_done
    inx
    cpx TE_LINE_SIZE
    bcc te_gl_cp
    lda 0x00
    sta TE_LINE,x
te_gl_done:
    rts

te_put_line:
    jsr te_put_line_raw
    lda 0x01
    sta TE_DIRTY
    rts

te_put_line_raw:
    jsr te_line_addr
    ldx 0x00
te_pl_cp:
    lda TE_LINE,x
    sta yde,x
    beq te_pl_done
    inx
    cpx TE_MAX_COL
    bcc te_pl_cp
    lda 0x00
    sta yde,x
te_pl_done:
    rts

; ================================================================
te_cmd_list:
    jsr te_nlines
    beq te_list_empty
    sta TE_N2
    lda 0x01
    sta TE_N
    ldx 0x01
    jsr te_skip_sp
    cpx TE_RL_LEN
    bcs te_list_show
    jsr te_parse_num
    bcs te_list_show
    sta TE_N
    jsr te_skip_sp
    cpx TE_RL_LEN
    bcs te_list_one
    lda TE_CMD,x
    cmp 0x2D
    bne te_list_one
    inx
    jsr te_parse_num
    bcs te_list_one
    sta TE_N2
    jmp te_list_show
te_list_one:
    lda TE_N
    sta TE_N2
te_list_show:
    lda TE_N
te_list_lp:
    cmp TE_N2
    beq te_list_ok
    bcc te_list_ok
    rts
te_list_ok:
    pha
    jsr te_nlines
    sta TE_TMP
    pla
    beq te_list_nx
    cmp TE_TMP
    beq te_list_pr
    bcc te_list_pr
    rts
te_list_pr:
    pha
    jsr ACIA_SEND_DECIMAL
    lda 0x3A
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    pla
    pha
    jsr te_get_line
    ldd TE_LINE[15:8]
    lde TE_LINE[7:0]
    jsr ACIA_SEND_STRING
    jsr ACIA_SEND_NEWLINE
    pla
te_list_nx:
    clc
    adc 0x01
    jmp te_list_lp
te_list_empty:
    ldd te_emptymsg[15:8]
    lde te_emptymsg[7:0]
    jmp ACIA_SEND_STRING

; ================================================================
te_cmd_insert:
    jsr te_nlines
    clc
    adc 0x01
    sta TE_N
    ldx 0x01
    jsr te_skip_sp
    cpx TE_RL_LEN
    bcs te_ins_loop
    jsr te_parse_num
    bcs te_ins_loop
    sta TE_N
te_ins_loop:
    jsr te_nlines
    cmp TE_MAX_LINES
    bcs te_ins_full
    ldd te_gt[15:8]
    lde te_gt[7:0]
    jsr ACIA_SEND_STRING
    ldd TE_LINE[15:8]
    lde TE_LINE[7:0]
    lda TE_MAX_COL
    jsr te_read_line
    lda TE_RL_LEN
    beq te_ins_done
    jsr te_insert_at
    inc TE_N
    jmp te_ins_loop
te_ins_done:
    rts
te_ins_full:
    ldd te_fullmsg[15:8]
    lde te_fullmsg[7:0]
    jmp ACIA_SEND_STRING

te_insert_at:
    ldx 0x00
te_ia_sv:
    lda TE_LINE,x
    sta SHELL_HIST_DRAFT,x
    beq te_ia_svd
    inx
    cpx TE_LINE_SIZE
    bcc te_ia_sv
te_ia_svd:
    jsr te_nlines
    sta TE_TMP
    cmp TE_MAX_LINES
    bcs te_ia_fail
    lda TE_N
    beq te_ia_fail
    sec
    sbc 0x01
    cmp TE_TMP
    beq te_ia_okn
    bcc te_ia_okn
    lda TE_TMP
    clc
    adc 0x01
    sta TE_N
te_ia_okn:
    ldx TE_TMP
te_ia_down:
    cpx TE_N
    bcc te_ia_put
    txa
    jsr te_get_line
    inx
    txa
    jsr te_put_line_raw
    dex
    dex
    jmp te_ia_down
te_ia_put:
    ldx 0x00
te_ia_rs:
    lda SHELL_HIST_DRAFT,x
    sta TE_LINE,x
    beq te_ia_rsd
    inx
    cpx TE_LINE_SIZE
    bcc te_ia_rs
te_ia_rsd:
    lda TE_N
    jsr te_put_line
    jsr te_nlines
    clc
    adc 0x01
    jsr te_set_nlines
te_ia_fail:
    rts

; ================================================================
te_cmd_delete:
    ldx 0x01
    jsr te_skip_sp
    jsr te_parse_num
    bcs te_del_bad
    sta TE_N
    beq te_del_bad
    jsr te_nlines
    cmp TE_N
    bcc te_del_bad
    sta TE_TMP
    ldx TE_N
te_del_up:
    cpx TE_TMP
    bcs te_del_shrink
    inx
    txa
    jsr te_get_line
    dex
    txa
    jsr te_put_line_raw
    inx
    jmp te_del_up
te_del_shrink:
    lda TE_TMP
    sec
    sbc 0x01
    jsr te_set_nlines
    lda 0x01
    sta TE_DIRTY
    rts
te_del_bad:
    ldd te_err[15:8]
    lde te_err[7:0]
    jmp ACIA_SEND_STRING

te_cmd_edit:
    ldx 0x01
    jsr te_skip_sp
    jsr te_parse_num
    bcs te_ed_bad
    sta TE_N
    beq te_ed_bad
    jsr te_nlines
    cmp TE_N
    bcc te_ed_bad
    lda TE_N
    jsr te_get_line
    ldd te_gt[15:8]
    lde te_gt[7:0]
    jsr ACIA_SEND_STRING
    ldd TE_LINE[15:8]
    lde TE_LINE[7:0]
    jsr ACIA_SEND_STRING
    jsr ACIA_SEND_NEWLINE
    ldd te_gt[15:8]
    lde te_gt[7:0]
    jsr ACIA_SEND_STRING
    ldd TE_LINE[15:8]
    lde TE_LINE[7:0]
    lda TE_MAX_COL
    jsr te_read_line
    lda TE_N
    jmp te_put_line
te_ed_bad:
    ldd te_err[15:8]
    lde te_err[7:0]
    jmp ACIA_SEND_STRING

; ================================================================
te_do_open:
    lda TE_HAS_NAME
    beq te_open_need
    jsr te_bind_file
    bcc te_open_fail
    jsr STORAGE_OPEN
    bcc te_open_fail
    jsr te_clear_text
    lda 0x01
    sta TE_HAS_NAME
te_open_rd:
    jsr te_nlines
    cmp TE_MAX_LINES
    bcs te_open_trunc
    ldx 0x00
    stx TE_RL_LEN
te_open_fill:
    lda 0x01
    sta CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd CH376_BUF[15:8]
    lde CH376_BUF[7:0]
    jsr STORAGE_READ
    bcc te_open_eof
    lda CH376_LOADED_LO
    beq te_open_eof
    lda CH376_BUF
    cmp 0x0A
    beq te_open_endl
    cmp 0x0D
    beq te_open_fill
    ldx TE_RL_LEN
    cpx TE_MAX_COL
    bcs te_open_fill
    sta TE_LINE,x
    inx
    stx TE_RL_LEN
    jmp te_open_fill
te_open_endl:
    ldx TE_RL_LEN
    lda 0x00
    sta TE_LINE,x
    jsr te_nlines
    clc
    adc 0x01
    sta TE_N
    jsr te_set_nlines
    lda TE_N
    jsr te_put_line_raw
    jmp te_open_rd
te_open_eof:
    lda TE_RL_LEN
    beq te_open_close
    tax
    lda 0x00
    sta TE_LINE,x
    jsr te_nlines
    clc
    adc 0x01
    sta TE_N
    jsr te_set_nlines
    lda TE_N
    jsr te_put_line_raw
te_open_close:
    lda 0x00
    jsr STORAGE_CLOSE
    lda 0x00
    sta TE_DIRTY
    ldd te_loaded[15:8]
    lde te_loaded[7:0]
    jsr ACIA_SEND_STRING
    jsr te_nlines
    jsr ACIA_SEND_DECIMAL
    ldd te_lines[15:8]
    lde te_lines[7:0]
    jmp ACIA_SEND_STRING
te_open_trunc:
    lda 0x00
    jsr STORAGE_CLOSE
    ldd te_trunc[15:8]
    lde te_trunc[7:0]
    jmp ACIA_SEND_STRING
te_open_need:
    ldd te_need[15:8]
    lde te_need[7:0]
    jmp ACIA_SEND_STRING
te_open_fail:
    ldd te_io[15:8]
    lde te_io[7:0]
    jmp ACIA_SEND_STRING

te_do_save:
    lda TE_HAS_NAME
    beq te_save_need
    jsr te_bind_file
    bcc te_save_fail
    jsr STORAGE_CREATE
    bcc te_save_fail
    lda 0x01
    sta TE_N
te_save_wr:
    jsr te_nlines
    cmp TE_N
    bcc te_save_done
    lda TE_N
    jsr te_get_line
    ldx 0x00
te_save_len:
    lda TE_LINE,x
    beq te_save_lend
    inx
    cpx TE_LINE_SIZE
    bcc te_save_len
te_save_lend:
    stx CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    cpx 0x00
    beq te_save_nl
    ldy 0x00
    ldd TE_LINE[15:8]
    lde TE_LINE[7:0]
    jsr STORAGE_WRITE
    bcc te_save_wfail
te_save_nl:
    lda 0x0A
    sta CH376_BUF
    lda 0x01
    sta CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd CH376_BUF[15:8]
    lde CH376_BUF[7:0]
    jsr STORAGE_WRITE
    bcc te_save_wfail
    inc TE_N
    jmp te_save_wr
te_save_done:
    lda 0x01
    jsr STORAGE_CLOSE
    lda 0x00
    sta TE_DIRTY
    ldd te_saved[15:8]
    lde te_saved[7:0]
    jmp ACIA_SEND_STRING
te_save_wfail:
    lda 0x00
    jsr STORAGE_CLOSE
te_save_fail:
    ldd te_io[15:8]
    lde te_io[7:0]
    jmp ACIA_SEND_STRING
te_save_need:
    ldd te_need[15:8]
    lde te_need[7:0]
    jmp ACIA_SEND_STRING

; Put the CH376 on TE_FNAME. One 8.3 component per SET_NAME: FNBUF is 16
; bytes, and FILE_CREATE while a directory is still open does not leave a
; directory entry. Relative names follow SHELL_CWD. C=1 ready for OPEN/CREATE.
te_bind_file:
    lda TE_FNAME
    beq te_bind_fail
    jsr STORAGE_ENSURE_MOUNTED
    bcc te_bind_fail
    lda 0x00
    jsr STORAGE_CLOSE
    lda TE_FNAME
    cmp 0x2F
    beq te_bind_abs
    lda 0x00
    sta TE_TMP
    jsr te_walk_cwd
    bcc te_bind_fail
    jmp te_set_leaf
te_bind_abs:
    jsr te_find_leaf
    bcc te_bind_fail
    jsr te_walk_abs
    bcc te_bind_fail
    jmp te_set_leaf
te_bind_fail:
    clc
    rts

; TE_TMP = index of the leaf in an absolute TE_FNAME. C=0 if the leaf is empty.
te_find_leaf:
    ldx 0x00
    stx TE_TMP
te_fl_lp:
    lda TE_FNAME,x
    beq te_fl_end
    cmp 0x2F
    bne te_fl_next
    inx
    stx TE_TMP
    cpx 0x0F
    bcs te_fl_end
    jmp te_fl_lp
te_fl_next:
    inx
    cpx 0x10
    bcc te_fl_lp
te_fl_end:
    ldx TE_TMP
    lda TE_FNAME,x
    beq te_fl_bad
    sec
    rts
te_fl_bad:
    clc
    rts

; Open each SHELL_CWD segment. TE_N2 = depth (0 = root). Then close the dir.
te_walk_cwd:
    lda 0x00
    sta TE_N2
    lda SHELL_CWD_LEN
    cmp 0x01
    beq te_walk_close
    ldx 0x01
te_wc_seg:
    cpx SHELL_CWD_LEN
    bcs te_walk_close
    lda TE_N2
    bne te_wc_rel
    lda 0x2F
    sta CH376_FNBUF
    ldy 0x01
    jmp te_wc_cp
te_wc_rel:
    ldy 0x00
te_wc_cp:
    lda SHELL_CWD,x
    beq te_wc_open
    cmp 0x2F
    beq te_wc_open
    sta CH376_FNBUF,y
    iny
    inx
    cpy 0x0E
    bcc te_wc_cp
te_wc_open:
    lda 0x00
    sta CH376_FNBUF,y
    phx
    jsr te_open_dir
    plx
    bcc te_bind_fail
    inc TE_N2
    lda SHELL_CWD,x
    cmp 0x2F
    bne te_wc_seg
    inx
    jmp te_wc_seg

; Open parent segments of an absolute path. Leaf starts at TE_TMP.
te_walk_abs:
    lda 0x00
    sta TE_N2
    lda TE_TMP
    cmp 0x01
    beq te_walk_close
    ldx 0x01
te_wa_seg:
    cpx TE_TMP
    bcs te_walk_close
    lda TE_N2
    bne te_wa_rel
    lda 0x2F
    sta CH376_FNBUF
    ldy 0x01
    jmp te_wa_cp
te_wa_rel:
    ldy 0x00
te_wa_cp:
    cpx TE_TMP
    bcs te_wa_open
    lda TE_FNAME,x
    cmp 0x2F
    beq te_wa_open
    sta CH376_FNBUF,y
    iny
    inx
    cpy 0x0E
    bcc te_wa_cp
te_wa_open:
    lda 0x00
    sta CH376_FNBUF,y
    phx
    jsr te_open_dir
    plx
    bcc te_bind_fail
    inc TE_N2
    cpx TE_TMP
    bcs te_walk_close
    lda TE_FNAME,x
    cmp 0x2F
    bne te_wa_seg
    inx
    jmp te_wa_seg

te_walk_close:
    lda 0x00
    jsr STORAGE_CLOSE
    sec
    rts

; FNBUF is one directory name. C=1 if the chip reports ERR_OPEN_DIR.
te_open_dir:
    ldy 0x00
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jsr STORAGE_SET_NAME
    bcc te_od_no
    jsr STORAGE_OPEN
    bcs te_od_no
    lda CH376_LAST_STATUS
    cmp CH376_ERR_OPEN_DIR
    bne te_od_no
    sec
    rts
te_od_no:
    clc
    rts

; SET_NAME the leaf. Leading '/' only when the parent is the root (TE_N2 = 0).
te_set_leaf:
    ldx TE_TMP
    lda TE_N2
    bne te_leaf_nosl
    lda 0x2F
    sta CH376_FNBUF
    ldy 0x01
    jmp te_leaf_cp
te_leaf_nosl:
    ldy 0x00
te_leaf_cp:
    lda TE_FNAME,x
    beq te_leaf_nul
    jsr te_upcase
    sta CH376_FNBUF,y
    inx
    iny
    cpy 0x0F
    bcc te_leaf_cp
te_leaf_nul:
    lda 0x00
    sta CH376_FNBUF,y
    ldy 0x00
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jmp STORAGE_SET_NAME

; ================================================================
; D:E buffer, A = max chars. Len -> TE_RL_LEN.
te_read_line:
    sta TE_TMP
    std SHELL_WORK+10
    ste SHELL_WORK+11
    lda 0x00
    sta TE_RL_LEN
te_rl_loop:
    jsr ACIA_READ_CHAR
    cmp 0x0D
    beq te_rl_done
    cmp 0x0A
    beq te_rl_done
    cmp 0x08
    beq te_rl_bs
    cmp 0x7F
    beq te_rl_bs
    cmp 0x20
    bcc te_rl_loop
    cmp 0x7F
    bcs te_rl_loop
    ldx TE_RL_LEN
    cpx TE_TMP
    bcs te_rl_loop
    pha
    jsr ACIA_SEND_CHAR
    pla
    ldx TE_RL_LEN
    ldd SHELL_WORK+10
    lde SHELL_WORK+11
    sta de,x
    inx
    stx TE_RL_LEN
    jmp te_rl_loop
te_rl_bs:
    lda TE_RL_LEN
    beq te_rl_loop
    dec TE_RL_LEN
    lda 0x08
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda 0x08
    jsr ACIA_SEND_CHAR
    jmp te_rl_loop
te_rl_done:
    jsr ACIA_SEND_NEWLINE
    ldx TE_RL_LEN
    ldd SHELL_WORK+10
    lde SHELL_WORK+11
    lda 0x00
    sta de,x
    rts

te_skip_sp:
te_sp_lp:
    cpx TE_RL_LEN
    bcs te_sp_out
    lda TE_CMD,x
    cmp 0x20
    bne te_sp_out
    inx
    jmp te_sp_lp
te_sp_out:
    rts

te_parse_num:
    lda 0x00
    sta TE_TMP
    lda TE_CMD,x
    cmp 0x30
    bcc te_num_bad
    cmp 0x3A
    bcs te_num_bad
te_num_lp:
    cpx TE_RL_LEN
    bcs te_num_ok
    lda TE_CMD,x
    cmp 0x30
    bcc te_num_ok
    cmp 0x3A
    bcs te_num_ok
    sec
    sbc 0x30
    sta SHELL_WORK+0
    lda TE_TMP
    asl a
    sta TE_TMP
    asl a
    asl a
    clc
    adc TE_TMP
    clc
    adc SHELL_WORK+0
    sta TE_TMP
    inx
    jmp te_num_lp
te_num_ok:
    lda TE_TMP
    clc
    rts
te_num_bad:
    sec
    rts

te_downcase:
    cmp 0x41
    bcc te_dc_r
    cmp 0x5B
    bcs te_dc_r
    clc
    adc 0x20
te_dc_r:
    rts

te_upcase:
    cmp 0x61
    bcc te_uc_r
    cmp 0x7B
    bcs te_uc_r
    sec
    sbc 0x20
te_uc_r:
    rts

; ================================================================
te_banner:
    #d "EDIT - line editor", 0x0A, 0x0D
    #d "h help  q quit", 0x0A, 0x0D, 0x00
te_prompt:
    #d "edit> ", 0x00
te_helpmsg:
    #d "n          new", 0x0A, 0x0D
    #d "l [N[-M]]  list", 0x0A, 0x0D
    #d "i [N]      insert (empty ends)", 0x0A, 0x0D
    #d "d N        delete", 0x0A, 0x0D
    #d "e N        edit line", 0x0A, 0x0D
    #d "o [file]   open USB", 0x0A, 0x0D
    #d "w [file]   save USB", 0x0A, 0x0D
    #d "q          quit", 0x0A, 0x0D, 0x00
te_gt:
    #d "> ", 0x00
te_newmsg:
    #d "new", 0x0A, 0x0D, 0x00
te_emptymsg:
    #d "(empty)", 0x0A, 0x0D, 0x00
te_fullmsg:
    #d "full", 0x0A, 0x0D, 0x00
te_err:
    #d "?", 0x0A, 0x0D, 0x00
te_need:
    #d "?file", 0x0A, 0x0D, 0x00
te_io:
    #d "?io", 0x0A, 0x0D, 0x00
te_loaded:
    #d "loaded ", 0x00
te_lines:
    #d " lines", 0x0A, 0x0D, 0x00
te_trunc:
    #d "truncated", 0x0A, 0x0D, 0x00
te_saved:
    #d "saved", 0x0A, 0x0D, 0x00
