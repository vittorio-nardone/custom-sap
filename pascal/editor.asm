; =========================================================
; On-board Pascal Editor for Project Otto
;
; Line editor for creating/editing Pascal source code.
; Source is stored in Expansion RAM page 1 (0x010000+).
;
; Entry: JSR to EDITOR_ENTRY (via jump table at 0x4003)
; Exit:  Returns via RTS. All registers restored.
; =========================================================

#const TINYPASCAL_VERSION = "v0.2"

EDITOR_ENTRY:
    pha
    phd
    phe
    phx
    phy

    jsr ACIA_SEND_NEWLINE
    ldd .ed_welcome[15:8]
    lde .ed_welcome[7:0]
    jsr ACIA_SEND_STRING

; ── Main loop ────────────────────────────────────────────

.ed_main_loop:
    ldd .ed_prompt[15:8]
    lde .ed_prompt[7:0]
    jsr ACIA_SEND_STRING

    ldd ED_CMD_BUF[15:8]
    lde ED_CMD_BUF[7:0]
    lda 0x14
    jsr .ed_read_line

    lda ED_RL_LEN
    beq .ed_main_loop

    sta ED_CMD_LEN

    ; lowercase the first character
    lda ED_CMD_BUF
    cmp 0x41
    bcc .ed_dispatch
    cmp 0x5B
    bcs .ed_dispatch
    clc
    adc 0x20

.ed_dispatch:
    cmp "n"
    beq .ed_cmd_new
    cmp "i"
    beq .ed_cmd_insert
    cmp "d"
    beq .ed_cmd_delete
    cmp "e"
    beq .ed_cmd_edit
    cmp "r"
    beq .ed_cmd_run
    cmp "h"
    beq .ed_cmd_help
    cmp "q"
    beq .ed_cmd_quit
    cmp "l"
    beq .ed_l_check
    jmp .ed_cmd_error

.ed_l_check:
    lda ED_CMD_LEN
    cmp 0x02
    bcc .ed_cmd_list
    lda ED_CMD_BUF + 1
    cmp "o"
    beq .ed_cmd_load
    cmp "O"
    beq .ed_cmd_load
    jmp .ed_cmd_list

; ── QUIT ─────────────────────────────────────────────────

.ed_cmd_quit:
    jsr ACIA_SEND_NEWLINE
    ply
    plx
    ple
    pld
    pla
    rts

; ── HELP ─────────────────────────────────────────────────

.ed_cmd_help:
    ldd .ed_help_msg[15:8]
    lde .ed_help_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .ed_main_loop

; ── ERROR ────────────────────────────────────────────────

.ed_cmd_error:
    ldd .ed_error_msg[15:8]
    lde .ed_error_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .ed_main_loop

; ── NEW ──────────────────────────────────────────────────

.ed_cmd_new:
    lda 0x00
    jsr .ed_set_line_count
    ldd .ed_new_msg[15:8]
    lde .ed_new_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .ed_main_loop

; ── RUN (placeholder for Phase 2) ───────────────────────

.ed_cmd_run:
    jsr ACIA_SEND_NEWLINE
    ldd .ed_compiling_msg[15:8]
    lde .ed_compiling_msg[7:0]
    jsr ACIA_SEND_STRING
    jsr .cc_compile
    bne .ed_run_err

    ; Print "OK (N bytes)"
    ldd .ed_comp_ok_msg[15:8]
    lde .ed_comp_ok_msg[7:0]
    jsr ACIA_SEND_STRING
    lda CC_CODE_LO
    sta MATH16_A
    lda CC_CODE_HI
    sta MATH16_A+1
    jsr ACIA_SEND_DECIMAL16S
    ldd .ed_comp_bytes_msg[15:8]
    lde .ed_comp_bytes_msg[7:0]
    jsr ACIA_SEND_STRING
    jsr ACIA_SEND_NEWLINE

    ; Execute P-code
    ldd PM_PCODE_BASE[15:8]
    lde PM_PCODE_BASE[7:0]
    jsr PM_ENTRY
    jmp .ed_main_loop

.ed_run_err:
    jmp .ed_main_loop

; ── LIST ─────────────────────────────────────────────────

.ed_cmd_list:
    jsr .ed_parse_args
    jsr .ed_get_line_count
    sta ED_LINE_COUNT
    cmp 0x00
    beq .ed_list_empty

    lda ED_HAS_NUM1
    beq .ed_list_all

    lda ED_NUM1
    sta ED_CUR_LINE
    lda ED_HAS_NUM2
    beq .ed_list_single
    lda ED_NUM2
    sta ED_INS_COUNT
    jmp .ed_list_validate

.ed_list_all:
    lda 0x01
    sta ED_CUR_LINE
    lda ED_LINE_COUNT
    sta ED_INS_COUNT
    jmp .ed_list_loop

.ed_list_single:
    lda ED_NUM1
    sta ED_INS_COUNT

.ed_list_validate:
    lda ED_CUR_LINE
    beq .ed_cmd_error
    cmp ED_LINE_COUNT
    beq .ed_list_clamp
    bcs .ed_cmd_error
.ed_list_clamp:
    lda ED_INS_COUNT
    cmp ED_LINE_COUNT
    bcc .ed_list_loop
    beq .ed_list_loop
    lda ED_LINE_COUNT
    sta ED_INS_COUNT

.ed_list_loop:
    jsr ACIA_SEND_NEWLINE
    lda ED_CUR_LINE
    jsr .ed_print_line_num

    lda ED_CUR_LINE
    jsr .ed_read_line_to_buf

    ldd ED_LINE_BUF[15:8]
    lde ED_LINE_BUF[7:0]
    jsr ACIA_SEND_STRING

    lda ED_CUR_LINE
    cmp ED_INS_COUNT
    beq .ed_list_end
    inc ED_CUR_LINE
    jmp .ed_list_loop

.ed_list_end:
    jsr ACIA_SEND_NEWLINE
    jmp .ed_main_loop

.ed_list_empty:
    ldd .ed_empty_msg[15:8]
    lde .ed_empty_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .ed_main_loop

; ── INSERT ───────────────────────────────────────────────

.ed_cmd_insert:
    jsr .ed_parse_args
    jsr .ed_get_line_count
    sta ED_LINE_COUNT

    lda ED_HAS_NUM1
    bne .ed_ins_has_num
    lda ED_LINE_COUNT
    clc
    adc 0x01
    sta ED_NUM1
    jmp .ed_ins_start

.ed_ins_has_num:
    lda ED_NUM1
    beq .ed_cmd_error
    lda ED_LINE_COUNT
    clc
    adc 0x01
    cmp ED_NUM1
    bcc .ed_cmd_error

.ed_ins_start:
    lda ED_NUM1
    sta ED_CUR_LINE

.ed_ins_loop:
    lda ED_CUR_LINE
    jsr .ed_print_line_num

    ldd ED_LINE_BUF2[15:8]
    lde ED_LINE_BUF2[7:0]
    lda ED_LINE_SIZE
    jsr .ed_read_line

    lda ED_RL_LEN
    beq .ed_ins_done

    ; Shift lines CUR_LINE..LINE_COUNT down by 1 (if needed)
    lda ED_CUR_LINE
    cmp ED_LINE_COUNT
    bcs .ed_ins_no_shift
    beq .ed_ins_no_shift
    lda ED_CUR_LINE
    jsr .ed_shift_down
.ed_ins_no_shift:

    ; Store new line from ED_LINE_BUF2
    lda ED_CUR_LINE
    jsr .ed_store_from_buf2

    inc ED_LINE_COUNT
    lda ED_LINE_COUNT
    jsr .ed_set_line_count

    inc ED_CUR_LINE
    jmp .ed_ins_loop

.ed_ins_done:
    jmp .ed_main_loop

; ── DELETE ───────────────────────────────────────────────

.ed_cmd_delete:
    jsr .ed_parse_args
    lda ED_HAS_NUM1
    beq .ed_cmd_error

    jsr .ed_get_line_count
    sta ED_LINE_COUNT

    lda ED_NUM1
    beq .ed_cmd_error
    cmp ED_LINE_COUNT
    beq .ed_del_valid
    bcs .ed_cmd_error

.ed_del_valid:
    lda ED_HAS_NUM2
    bne .ed_del_range
    lda ED_NUM1
    sta ED_NUM2
.ed_del_range:
    lda ED_NUM2
    cmp ED_NUM1
    bcc .ed_cmd_error
    cmp ED_LINE_COUNT
    beq .ed_del_count
    bcs .ed_cmd_error

.ed_del_count:
    lda ED_NUM2
    sec
    sbc ED_NUM1
    clc
    adc 0x01
    sta ED_INS_COUNT

.ed_del_repeat:
    lda ED_INS_COUNT
    beq .ed_del_done

    lda ED_NUM1
    sta ED_CUR_LINE
.ed_del_shift:
    lda ED_CUR_LINE
    cmp ED_LINE_COUNT
    bcs .ed_del_shifted

    lda ED_CUR_LINE
    clc
    adc 0x01
    jsr .ed_read_line_to_buf
    lda ED_CUR_LINE
    jsr .ed_store_from_buf

    inc ED_CUR_LINE
    jmp .ed_del_shift

.ed_del_shifted:
    dec ED_LINE_COUNT
    dec ED_INS_COUNT
    jmp .ed_del_repeat

.ed_del_done:
    lda ED_LINE_COUNT
    jsr .ed_set_line_count
    jmp .ed_main_loop

; ── EDIT ─────────────────────────────────────────────────

.ed_cmd_edit:
    jsr .ed_parse_args
    lda ED_HAS_NUM1
    beq .ed_cmd_error

    jsr .ed_get_line_count
    sta ED_LINE_COUNT
    lda ED_NUM1
    beq .ed_cmd_error
    cmp ED_LINE_COUNT
    beq .ed_edit_ok
    bcs .ed_cmd_error

.ed_edit_ok:
    ; Show current content
    lda ED_NUM1
    jsr .ed_read_line_to_buf
    jsr ACIA_SEND_NEWLINE
    lda ED_NUM1
    jsr .ed_print_line_num
    ldd ED_LINE_BUF[15:8]
    lde ED_LINE_BUF[7:0]
    jsr ACIA_SEND_STRING

    ; Prompt for new content
    jsr ACIA_SEND_NEWLINE
    lda ED_NUM1
    jsr .ed_print_line_num

    ldd ED_LINE_BUF[15:8]
    lde ED_LINE_BUF[7:0]
    lda ED_LINE_SIZE
    jsr .ed_read_line

    lda ED_RL_LEN
    beq .ed_main_loop

    lda ED_NUM1
    jsr .ed_store_from_buf
    jmp .ed_main_loop

; ── LOAD ─────────────────────────────────────────────────

.ed_cmd_load:
    ldd .ed_load_msg[15:8]
    lde .ed_load_msg[7:0]
    jsr ACIA_SEND_STRING

    lda 0x00
    jsr .ed_set_line_count
    sta ED_LINE_COUNT

.ed_load_loop:
    ldd ED_LINE_BUF[15:8]
    lde ED_LINE_BUF[7:0]
    lda ED_LINE_SIZE
    jsr .ed_read_line

    lda ED_RL_LEN
    beq .ed_load_done

    lda ED_LINE_COUNT
    cmp ED_MAX_LINES
    bcs .ed_load_done

    inc ED_LINE_COUNT
    lda ED_LINE_COUNT
    jsr .ed_store_from_buf

    lda ED_LINE_COUNT
    jsr .ed_set_line_count

    jmp .ed_load_loop

.ed_load_done:
    lda ED_LINE_COUNT
    jsr ACIA_SEND_DECIMAL
    ldd .ed_loaded_msg[15:8]
    lde .ed_loaded_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .ed_main_loop

; ── Helper: read_line ────────────────────────────────────
; Read a line from serial into buffer at D:E, max length A.
; Output: ED_RL_LEN = length, buffer null-terminated.
; Clobbers: A, D, E, X, Y.

.ed_read_line:
    std ED_RL_BUF_H
    ste ED_RL_BUF_L
    sta ED_RL_MAX
    lda 0x00
    sta ED_RL_LEN

.ed_rl_loop:
    jsr ACIA_READ_CHAR
    cmp 0x0D
    beq .ed_rl_done
    cmp 0x0A
    beq .ed_rl_done
    cmp 0x7F
    beq .ed_rl_bs
    cmp 0x08
    beq .ed_rl_bs
    cmp 0x04
    beq .ed_rl_eot

    ldx ED_RL_LEN
    cpx ED_RL_MAX
    bcs .ed_rl_loop

    ldd ED_RL_BUF_H
    lde ED_RL_BUF_L
    sta de,x
    inc ED_RL_LEN
    jsr ACIA_SEND_CHAR
    jmp .ed_rl_loop

.ed_rl_bs:
    lda ED_RL_LEN
    beq .ed_rl_loop
    dec ED_RL_LEN
    jsr VT100_CURSOR_LEFT
    jsr VT100_CLEAR_LINE_END
    jmp .ed_rl_loop

.ed_rl_eot:
    lda 0x00
    sta ED_RL_LEN

.ed_rl_done:
    ldx ED_RL_LEN
    ldd ED_RL_BUF_H
    lde ED_RL_BUF_L
    lda 0x00
    sta de,x
    jsr ACIA_SEND_NEWLINE
    rts

; ── Helper: parse_args ───────────────────────────────────
; Parse [n] or [n-m] from the command buffer.
; Sets ED_NUM1, ED_NUM2, ED_HAS_NUM1, ED_HAS_NUM2.
; Clobbers: A, X.

.ed_parse_args:
    lda 0x00
    sta ED_HAS_NUM1
    sta ED_HAS_NUM2
    sta ED_PARSE_POS

.ed_pa_skip_cmd:
    ldx ED_PARSE_POS
    cpx ED_CMD_LEN
    bcs .ed_pa_done
    lda ED_CMD_BUF,x
    cmp 0x20
    beq .ed_pa_skip_sp
    cmp 0x30
    bcc .ed_pa_next
    cmp 0x3A
    bcc .ed_pa_num1
.ed_pa_next:
    inc ED_PARSE_POS
    jmp .ed_pa_skip_cmd

.ed_pa_skip_sp:
    inc ED_PARSE_POS
    ldx ED_PARSE_POS
    cpx ED_CMD_LEN
    bcs .ed_pa_done
    lda ED_CMD_BUF,x
    cmp 0x20
    beq .ed_pa_skip_sp

.ed_pa_num1:
    jsr .ed_parse_dec
    bcs .ed_pa_done
    sta ED_NUM1
    lda 0x01
    sta ED_HAS_NUM1

    ldx ED_PARSE_POS
    cpx ED_CMD_LEN
    bcs .ed_pa_done
    lda ED_CMD_BUF,x
    cmp 0x2D
    bne .ed_pa_done
    inc ED_PARSE_POS

    jsr .ed_parse_dec
    bcs .ed_pa_done
    sta ED_NUM2
    lda 0x01
    sta ED_HAS_NUM2

.ed_pa_done:
    rts

; ── Helper: parse_dec ────────────────────────────────────
; Parse decimal number at ED_PARSE_POS. Result in A.
; Carry clear = OK, carry set = no number.
; Clobbers: A, X.

.ed_parse_dec:
    lda 0x00
    sta ED_PARSE_TMP
    sta ED_PARSE_FLAG

.ed_pd_loop:
    ldx ED_PARSE_POS
    cpx ED_CMD_LEN
    bcs .ed_pd_end
    lda ED_CMD_BUF,x
    cmp 0x30
    bcc .ed_pd_end
    cmp 0x3A
    bcs .ed_pd_end

    sec
    sbc 0x30
    pha
    lda ED_PARSE_TMP
    ldx 0x0A
    jsr MULTIPLY_INT
    clc
    txa
    sta ED_PARSE_TMP
    pla
    clc
    adc ED_PARSE_TMP
    sta ED_PARSE_TMP

    lda 0x01
    sta ED_PARSE_FLAG
    inc ED_PARSE_POS
    jmp .ed_pd_loop

.ed_pd_end:
    lda ED_PARSE_FLAG
    beq .ed_pd_nonum
    lda ED_PARSE_TMP
    clc
    rts
.ed_pd_nonum:
    sec
    rts

; ── Helper: line count get/set ───────────────────────────

.ed_get_line_count:
    ldy ED_SRC_PAGE
    ldd 0x00
    lde 0x00
    ldx 0x00
    lda yde,x
    rts

.ed_set_line_count:
    pha
    ldy ED_SRC_PAGE
    ldd 0x00
    lde 0x00
    ldx 0x00
    pla
    sta yde,x
    pha
    inx
    lda 0x00
    sta yde,x
    pla
    rts

; ── Helper: compute line address ─────────────────────────
; Input: A = line number (1-based)
; Output: D:E = offset within expansion RAM page
; Clobbers: A, D, E, MATH16_A, MATH16_B.

.ed_compute_line_addr:
    sec
    sbc 0x01
    sta MATH16_A
    lda 0x00
    sta MATH16_A+1
    lda ED_LINE_SIZE
    sta MATH16_B
    lda 0x00
    sta MATH16_B+1
    jsr MUL16S
    lda MATH16_A
    clc
    adc 0x04
    tae
    lda MATH16_A+1
    adc 0x00
    tad
    rts

; ── Helper: read/write expansion RAM lines ───────────────

.ed_read_line_to_buf:
    ; Read line A from expansion RAM into ED_LINE_BUF
    jsr .ed_compute_line_addr
    ldy ED_SRC_PAGE
    ldx 0x00
.ed_rltb_loop:
    lda yde,x
    sta ED_LINE_BUF,x
    inx
    cpx ED_LINE_SIZE
    bne .ed_rltb_loop
    rts

.ed_store_from_buf:
    ; Write ED_LINE_BUF to line A in expansion RAM
    jsr .ed_compute_line_addr
    ldy ED_SRC_PAGE
    ldx 0x00
.ed_sfb_loop:
    lda ED_LINE_BUF,x
    sta yde,x
    inx
    cpx ED_LINE_SIZE
    bne .ed_sfb_loop
    rts

.ed_store_from_buf2:
    ; Write ED_LINE_BUF2 to line A in expansion RAM
    jsr .ed_compute_line_addr
    ldy ED_SRC_PAGE
    ldx 0x00
.ed_sfb2_loop:
    lda ED_LINE_BUF2,x
    sta yde,x
    inx
    cpx ED_LINE_SIZE
    bne .ed_sfb2_loop
    rts

; ── Helper: shift lines ─────────────────────────────────

.ed_shift_down:
    ; Shift lines A..LINE_COUNT down by 1 (make room at A).
    ; Clobbers: A, D, E, X, Y, ED_SHIFT_ITER, ED_SHIFT_FROM.
    sta ED_SHIFT_FROM
    lda ED_LINE_COUNT
    sta ED_SHIFT_ITER

.ed_sd_loop:
    lda ED_SHIFT_ITER
    cmp ED_SHIFT_FROM
    bcc .ed_sd_done

    lda ED_SHIFT_ITER
    jsr .ed_read_line_to_buf
    lda ED_SHIFT_ITER
    clc
    adc 0x01
    jsr .ed_store_from_buf

    dec ED_SHIFT_ITER
    jmp .ed_sd_loop

.ed_sd_done:
    rts

; ── Helper: print line number ────────────────────────────

.ed_print_line_num:
    ; Print "N: " where N is line number in A
    jsr ACIA_SEND_DECIMAL
    lda 0x3A
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    rts

; ── On-board compiler ────────────────────────────────────

#include "compiler.asm"

; ── Strings ──────────────────────────────────────────────

.ed_prompt:
    #d "P>", 0x00

.ed_welcome:
    #d "Project OTTO TinyPascal editor/compiler - ", TINYPASCAL_VERSION, 0x0A, 0x0D
    #d "Type H for help.", 0x0A, 0x0D, 0x00

.ed_help_msg:
    #d 0x0A, 0x0D
    #d "Editor commands:", 0x0A, 0x0D
    #d "   n        - New (clear source)", 0x0A, 0x0D
    #d "   l [n-m]  - List lines", 0x0A, 0x0D
    #d "   i [n]    - Insert at line", 0x0A, 0x0D
    #d "   d n[-m]  - Delete line(s)", 0x0A, 0x0D
    #d "   e n      - Edit line", 0x0A, 0x0D
    #d "   lo       - Load (paste source)", 0x0A, 0x0D
    #d "   r        - Run (compile & execute)", 0x0A, 0x0D
    #d "   q        - Quit to kernel", 0x0A, 0x0D
    #d 0x00

.ed_error_msg:
    #d "Unknown command.", 0x0A, 0x0D, 0x00

.ed_new_msg:
    #d "Source cleared.", 0x0A, 0x0D, 0x00

.ed_empty_msg:
    #d "No source loaded.", 0x0A, 0x0D, 0x00

.ed_compiling_msg:
    #d "Compiling... ", 0x00

.ed_comp_ok_msg:
    #d "OK (", 0x00

.ed_comp_bytes_msg:
    #d " bytes)", 0x00

.ed_load_msg:
    #d "Paste source, end with empty line:", 0x0A, 0x0D, 0x00

.ed_loaded_msg:
    #d " lines loaded.", 0x0A, 0x0D, 0x00
