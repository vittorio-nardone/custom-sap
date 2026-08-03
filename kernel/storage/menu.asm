; Kernel USB menu: browse and load ("l"), save a memory range ("w").
;
; The entry table lives in application RAM (STORAGE_NAMES) and is only valid
; while one of these commands is running.

#once
#bank kernel

; **********************************************************
; SUBROUTINE: STORAGE_MENU_LOAD
;
; INPUTS:
;   CH376_OT_AUTO              1 = address comes from the OT header
;   STORAGE_ADDR_PAGE/MSB/LSB  destination when CH376_OT_AUTO = 0
; **********************************************************

STORAGE_MENU_LOAD:
    jsr storage_mount_verbose
    bcc .done
    lda 0x00
    sta CH376_DEPTH

.browse:
    jsr storage_list_dir
    bcc .failed
    lda CH376_FILE_COUNT
    bne .menu
    ldd storage_msg_empty[15:8]
    lde storage_msg_empty[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_DEPTH
    beq .done

.menu:
    ldd storage_msg_prompt[15:8]
    lde storage_msg_prompt[7:0]
    jsr ACIA_SEND_STRING
    jsr storage_read_selection
    lda CH376_SELECT
    beq .done
    cmp CH376_FILE_COUNT
    beq .selected
    bcc .selected
    jmp .bad

.selected:
    jsr storage_entry_is_dir
    bcs .enter
    jmp .load_selected

.enter:
    jsr storage_enter_dir
    bcc .bad
    jmp .browse

.bad:
    ldd storage_msg_bad_sel[15:8]
    lde storage_msg_bad_sel[7:0]
    jsr ACIA_SEND_STRING
    jmp .menu

.failed:
    ldd storage_msg_list_fail[15:8]
    lde storage_msg_list_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
.done:
    rts

.load_selected:
    jsr storage_entry_ptr_select
    jsr storage_build_open_name
    bcc .load_failed
    lda CH376_SIZE_3
    ora CH376_SIZE_2
    bne .too_big
    lda CH376_SIZE_0
    sta CH376_TOTAL_LO
    lda CH376_SIZE_1
    sta CH376_TOTAL_HI

    ldd storage_msg_loading[15:8]
    lde storage_msg_loading[7:0]
    jsr ACIA_SEND_STRING
    jsr storage_print_selected_name
    jsr ACIA_SEND_NEWLINE

    jsr STORAGE_LOAD_FILE
    bcc .load_failed

    ldd storage_msg_loaded[15:8]
    lde storage_msg_loaded[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LOADED_HI
    jsr ACIA_SEND_HEX
    lda CH376_LOADED_LO
    jsr ACIA_SEND_HEX
    ldd storage_msg_loaded_at[15:8]
    lde storage_msg_loaded_at[7:0]
    jsr ACIA_SEND_STRING
    lda STORAGE_LOAD_PTRP
    jsr ACIA_SEND_HEX
    lda STORAGE_LOAD_PTRH
    jsr ACIA_SEND_HEX
    lda STORAGE_LOAD_PTR
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE

    ; The loaded image becomes the default address for d/r.
    lda STORAGE_LOAD_PTRP
    sta MAIN_MENU_ADDR_PAGE
    lda STORAGE_LOAD_PTRH
    sta MAIN_MENU_ADDR_MSB
    lda STORAGE_LOAD_PTR
    sta MAIN_MENU_ADDR_LSB
    rts

.too_big:
    ldd storage_msg_too_big[15:8]
    lde storage_msg_too_big[7:0]
    jsr ACIA_SEND_STRING
    rts

.load_failed:
    ldd storage_msg_load_fail[15:8]
    lde storage_msg_load_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
    rts

; **********************************************************
; SUBROUTINE: STORAGE_MENU_SAVE
;
; INPUTS:
;   CH376_SAVE_PAGE/MSB/LSB    memory range start
; **********************************************************

STORAGE_MENU_SAVE:
    jsr storage_mount_verbose
    bcc .done

    ldd storage_msg_save_from[15:8]
    lde storage_msg_save_from[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_SAVE_PAGE
    jsr ACIA_SEND_HEX
    lda CH376_SAVE_MSB
    jsr ACIA_SEND_HEX
    lda CH376_SAVE_LSB
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE

    ldd storage_msg_save_len[15:8]
    lde storage_msg_save_len[7:0]
    jsr ACIA_SEND_STRING
    jsr storage_read_hex16
    bcc .bad
    lda CH376_TOTAL_LO
    ora CH376_TOTAL_HI
    beq .bad

    ldd storage_msg_save_name[15:8]
    lde storage_msg_save_name[7:0]
    jsr ACIA_SEND_STRING
    jsr storage_read_fname
    bcc .bad

    lda 0x01
    sta CH376_OT_FLAG
    ldd storage_msg_saving[15:8]
    lde storage_msg_saving[7:0]
    jsr ACIA_SEND_STRING
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jsr ACIA_SEND_STRING
    jsr ACIA_SEND_NEWLINE

    jsr STORAGE_SAVE_FILE
    bcc .save_failed

    ldd storage_msg_saved[15:8]
    lde storage_msg_saved[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LOADED_HI
    jsr ACIA_SEND_HEX
    lda CH376_LOADED_LO
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
.done:
    rts

.bad:
    ldd storage_msg_bad_input[15:8]
    lde storage_msg_bad_input[7:0]
    jsr ACIA_SEND_STRING
    rts

.save_failed:
    ldd storage_msg_save_fail[15:8]
    lde storage_msg_save_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
    rts

; ---- Mount with progress / error reporting ----
storage_mount_verbose:
    ldd storage_msg_mounting[15:8]
    lde storage_msg_mounting[7:0]
    jsr ACIA_SEND_STRING
    jsr STORAGE_MOUNT
    bcc .failed
    ldd storage_msg_ok[15:8]
    lde storage_msg_ok[7:0]
    jsr ACIA_SEND_STRING
    sec
    rts
.failed:
    ldd storage_msg_mount_fail[15:8]
    lde storage_msg_mount_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
    clc
    rts

; ---- Directory listing with numbered selectable entries ----
; Opens the current directory and BYTE_READs raw 32-byte FAT entries.
; Wildcard /* enum cannot see VFAT LFN slots (CH376 filters them); raw
; directory reads can, so LFN display is assembled while scanning.
storage_list_dir:
    lda 0x00
    sta CH376_FILE_COUNT
    sta CH376_WIRE_LEN
    sta CH376_RD_LEN
    sta CH376_PULL_MODE
    jsr storage_lfn_clear

    lda CH376_DEPTH
    bne .hdr_sub
    ldd storage_msg_root[15:8]
    lde storage_msg_root[7:0]
    jmp .hdr_done
.hdr_sub:
    ldd storage_msg_subdir[15:8]
    lde storage_msg_subdir[7:0]
.hdr_done:
    jsr ACIA_SEND_STRING

    lda CH376_DEPTH
    beq .open_root
    ; Subdirectory was left open by storage_enter_dir.
    jmp .opened

.open_root:
    ldy storage_fn_slash[23:16]
    ldd storage_fn_slash[15:8]
    lde storage_fn_slash[7:0]
    jsr ch376_cmd_set_file_name
    bcc .fail
    jsr ch376_set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .fail
    lda CH376_LAST_STATUS
    cmp CH376_ERR_OPEN_DIR
    bne .fail

.opened:
    lda CH376_DEPTH
    beq .no_dotdot
    jsr storage_inject_dotdot
.no_dotdot:
    jsr ch376_set_timeout_long
    lda 0xFF
    sta CH376_ENUM_LEFT

.read_loop:
    lda CH376_ENUM_LEFT
    beq .done_close
    lda 0x20
    jsr ch376_cmd_byte_read
    bcc .fail_close
    lda CH376_LAST_STATUS
    cmp CH376_INT_DISK_READ
    beq .got
    cmp CH376_INT_SUCCESS
    beq .done_close
    jmp .fail_close

.got:
    jsr ch376_rd_dir_entry
    sta CH376_RD_LEN
    lda CH376_RD_LEN
    beq .fail_close
    jsr storage_list_emit
    dec CH376_ENUM_LEFT
    lda CH376_CMD_BYTE_RD_GO
    jsr ch376_cmd_interrupt
    bcc .fail_close
    ; After a 32-byte request, GO is usually INT_SUCCESS → next BYTE_READ.
    lda CH376_LAST_STATUS
    cmp CH376_INT_DISK_READ
    beq .got
    cmp CH376_INT_SUCCESS
    beq .read_loop
    jmp .fail_close

.done_close:
    lda 0x00
    jsr ch376_cmd_file_close
    jsr ch376_set_timeout
    ldd storage_msg_entries[15:8]
    lde storage_msg_entries[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_FILE_COUNT
    jsr ACIA_SEND_DECIMAL
    jsr ACIA_SEND_NEWLINE
    sec
    rts

.fail_close:
    lda 0x00
    jsr ch376_cmd_file_close
.fail:
    jsr ch376_set_timeout
    clc
    rts

; Store a printable file/dir entry and print "N. name".
; VFAT LFN slots (attr 0x0F) are absorbed into CH376_LFN_TMP; the following
; 8.3 entry is what gets stored for open/select. Volume labels, hidden
; entries, "." / ".." and macOS "_XXXXXX~N" aliases are skipped.
storage_list_emit:
    lda CH376_BUF+11
    cmp CH376_LFN_ATTR
    bne .short
    jmp storage_lfn_absorb

.short:
    lda CH376_BUF
    beq .discard
    cmp 0xE5
    beq .discard
    cmp 0x5F
    beq .discard
    jsr storage_list_is_dot
    bcc .discard
    lda CH376_BUF+11
    and 0x08
    bne .discard
    lda CH376_BUF+11
    and CH376_DIR_ATTR_HIDDEN
    bne .discard
    lda CH376_FILE_COUNT
    cmp CH376_MAX_FILES
    bcs .discard
    lda 0x00
    sta CH376_ENTRY_FLAGS
    lda CH376_BUF+11
    and CH376_DIR_ATTR_DIRECTORY
    beq .store
    lda CH376_ENTRY_FLAG_DIR
    sta CH376_ENTRY_FLAGS
.store:
    jsr storage_lfn_bind
    jsr storage_store_entry
    jsr storage_store_lfn
    lda CH376_FILE_COUNT
    clc
    adc 0x01
    sta CH376_LIST_NUM
    jsr storage_print_entry_line
    jsr storage_lfn_clear
    inc CH376_FILE_COUNT
    rts

.discard:
    jsr storage_lfn_clear
    rts

; After enum: for each stored entry fetch LFN (EXAM11-style) and print the line.
; (Kept for reference / probe parity — listing now uses BYTE_READ + absorb.)
storage_list_finish_display:
    lda 0x00
    sta CH376_LIST_IDX
.fin_loop:
    lda CH376_LIST_IDX
    cmp CH376_FILE_COUNT
    bcs .fin_done
    clc
    adc 0x01
    sta CH376_SELECT
    sta CH376_LIST_NUM
    jsr storage_entry_ptr_select
    jsr storage_copy_entry_to_buf
    jsr storage_try_fetch_lfn
    ; fetch clobbers CH376_BUF — reload 8.3/size for the printed line.
    jsr storage_entry_ptr_select
    jsr storage_copy_entry_to_buf
    jsr storage_print_entry_line
    inc CH376_LIST_IDX
    jmp .fin_loop
.fin_done:
    rts

; Y:DE -> NAMES entry (11 name + 4 size + 1 flags).
; Copies name/size into CH376_BUF FAT layout and flags into CH376_ENTRY_FLAGS.
storage_copy_entry_to_buf:
    ldx 0x00
.name:
    cpx 0x0B
    bcs .size
    lda yde,x
    sta CH376_BUF,x
    inx
    jmp .name
.size:
    ldx 0x00
.sz:
    cpx 0x04
    bcs .flags
    txa
    clc
    adc 0x0B
    phx
    tax
    lda yde,x
    plx
    sta CH376_BUF+0x1C,x
    inx
    jmp .sz
.flags:
    ldx 0x0F
    lda yde,x
    sta CH376_ENTRY_FLAGS
    rts

; Skip "." and ".." only. C=1 keep, C=0 skip.
storage_list_is_dot:
    lda CH376_BUF
    cmp 0x2E
    bne .keep
    lda CH376_BUF+1
    cmp 0x20
    beq .drop
    cmp 0x2E
    bne .keep
    lda CH376_BUF+2
    cmp 0x20
    beq .drop
.keep:
    sec
    rts
.drop:
    clc
    rts

; Inject ".." <DIR> as the first entry when browsing a subdirectory.
storage_inject_dotdot:
    lda CH376_FILE_COUNT
    cmp CH376_MAX_FILES
    bcs .done
    jsr storage_lfn_clear
    ldx 0x00
    lda 0x2E
    sta CH376_BUF,x
    inx
    sta CH376_BUF,x
    inx
.pad:
    cpx 0x0B
    bcs .attr
    lda 0x20
    sta CH376_BUF,x
    inx
    jmp .pad
.attr:
    lda CH376_DIR_ATTR_DIRECTORY
    sta CH376_BUF+11
    lda 0x00
    sta CH376_BUF+0x1C
    sta CH376_BUF+0x1D
    sta CH376_BUF+0x1E
    sta CH376_BUF+0x1F
    lda CH376_ENTRY_FLAG_DIR
    sta CH376_ENTRY_FLAGS
    jsr storage_lfn_clear
    jsr storage_store_entry
    jsr storage_store_lfn
    lda CH376_FILE_COUNT
    clc
    adc 0x01
    sta CH376_LIST_NUM
    jsr storage_print_entry_line
    inc CH376_FILE_COUNT
.done:
    rts

storage_print_entry_line:
    lda CH376_LIST_NUM
    jsr ACIA_SEND_DECIMAL
    lda 0x2E
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    jsr storage_print_name
    lda CH376_ENTRY_FLAGS
    and CH376_ENTRY_FLAG_DIR
    bne .dir
    ; File: FAT size (32-bit LE at BUF+0x1C) as 8 hex digits, MSB first.
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda CH376_BUF+0x1F
    jsr ACIA_SEND_HEX
    lda CH376_BUF+0x1E
    jsr ACIA_SEND_HEX
    lda CH376_BUF+0x1D
    jsr ACIA_SEND_HEX
    lda CH376_BUF+0x1C
    jsr ACIA_SEND_HEX
    jmp ACIA_SEND_NEWLINE
.dir:
    ldd storage_tag_dir[15:8]
    lde storage_tag_dir[7:0]
    jsr ACIA_SEND_STRING
    jmp ACIA_SEND_NEWLINE

; Print LFN (if bound) else the 8.3 name from CH376_BUF.
storage_print_name:
    lda CH376_LFN_READY
    beq storage_print_name83
    lda CH376_LFN_LEN
    beq storage_print_name83
    ldx 0x00
.lfn:
    cpx CH376_LFN_LEN
    bcs .done
    lda CH376_LFN_TMP,x
    jsr ACIA_SEND_CHAR
    inx
    jmp .lfn
.done:
    rts

storage_print_name83:
    ldx 0x00
.name:
    cpx 0x08
    bcs .ext
    lda CH376_BUF,x
    cmp 0x20
    beq .name_skip
    jsr ACIA_SEND_CHAR
.name_skip:
    inx
    jmp .name
.ext:
    lda CH376_BUF+8
    cmp 0x20
    beq .done
    lda 0x2E
    jsr ACIA_SEND_CHAR
    ldx 0x08
.ext_loop:
    cpx 0x0B
    bcs .done
    lda CH376_BUF,x
    cmp 0x20
    beq .ext_skip
    jsr ACIA_SEND_CHAR
.ext_skip:
    inx
    jmp .ext_loop
.done:
    rts

; Print LFN for CH376_SELECT if stored, else CH376_FNBUF (open path).
storage_print_selected_name:
    jsr storage_lfn_ptr_select
    ldx 0x00
    lda yde,x
    beq .short
.lfn:
    lda yde,x
    beq .done
    jsr ACIA_SEND_CHAR
    inx
    cpx CH376_LFN_ENTRY
    bcc .lfn
.done:
    rts
.short:
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jmp ACIA_SEND_STRING

; Copy FAT 8.3 (11) + size LE (4) + flags (1) into NAMES[FILE_COUNT * 16]
storage_store_entry:
    jsr storage_entry_ptr_count
    ldx 0x00
.name:
    cpx 0x0B
    bcs .size
    lda CH376_BUF,x
    phx
    ldx 0x00
    sta yde,x
    plx
    ine
    bne .name_next
    ind
.name_next:
    inx
    jmp .name
.size:
    ldx 0x00
.size_loop:
    cpx 0x04
    bcs .flags
    lda CH376_BUF+0x1C,x
    phx
    ldx 0x00
    sta yde,x
    plx
    ine
    bne .size_next
    ind
.size_next:
    inx
    jmp .size_loop
.flags:
    lda CH376_ENTRY_FLAGS
    ldx 0x00
    sta yde,x
    rts

; Copy bound LFN into STORAGE_LFN[FILE_COUNT], or store an empty string.
storage_store_lfn:
    jsr storage_lfn_ptr_count
    jmp storage_store_lfn_at_yde

; Copy bound LFN into STORAGE_LFN[SELECT-1].
storage_store_lfn_selected:
    jsr storage_lfn_ptr_select
storage_store_lfn_at_yde:
    lda CH376_LFN_READY
    beq .empty
    lda CH376_LFN_LEN
    beq .empty
    ldx 0x00
.copy:
    cpx CH376_LFN_LEN
    bcs .nul
    cpx CH376_LFN_DISP_MAX
    bcs .nul
    lda CH376_LFN_TMP,x
    phx
    ldx 0x00
    sta yde,x
    plx
    ine
    bne .copy_next
    ind
.copy_next:
    inx
    jmp .copy
.nul:
    lda 0x00
    ldx 0x00
    sta yde,x
    rts
.empty:
    lda 0x00
    ldx 0x00
    sta yde,x
    rts

storage_lfn_clear:
    lda 0x00
    sta CH376_LFN_LEN
    sta CH376_LFN_CKSUM
    sta CH376_LFN_NEXT
    sta CH376_LFN_READY
    rts

storage_lfn_clear_buf:
    ldx 0x00
    lda 0x00
.clr:
    sta CH376_LFN_TMP,x
    inx
    cpx 0x28
    bcc .clr
    sta CH376_LFN_LEN
    sta CH376_LFN_READY
    rts

; Absorb one VFAT LFN directory slot from CH376_BUF into CH376_LFN_TMP
; (directory order: highest ordinal first).
storage_lfn_absorb:
    lda CH376_BUF
    and CH376_LFN_LAST
    beq .cont
    jsr storage_lfn_clear_buf
    lda CH376_BUF+13
    sta CH376_LFN_CKSUM
    lda CH376_BUF
    and 0x1F
    beq .bad
    sta CH376_LFN_NEXT
    jmp .place
.cont:
    lda CH376_LFN_NEXT
    beq .bad
    lda CH376_BUF
    and 0x1F
    cmp CH376_LFN_NEXT
    bne .bad
    lda CH376_BUF+13
    cmp CH376_LFN_CKSUM
    bne .bad
.place:
    lda CH376_BUF
    and 0x1F
    jsr storage_lfn_place
    dec CH376_LFN_NEXT
    rts
.bad:
    jsr storage_lfn_clear
    rts

; A = LFN ordinal (1..N). Copy up to 13 UCS-2 chars into TMP[(A-1)*13].
storage_lfn_place:
    sec
    sbc 0x01
    sta CH376_SCRATCH
    asl a
    clc
    adc CH376_SCRATCH
    asl a
    asl a
    clc
    adc CH376_SCRATCH
    sta CH376_SCRATCH2
    ldy 0x00
.loop:
    cpy 0x0D
    bcs .done
    lda storage_lfn_offs,y
    tax
    lda CH376_BUF,x
    sta CH376_SCRATCH
    inx
    lda CH376_BUF,x
    bne .non_ascii
    lda CH376_SCRATCH
    beq .done
    jmp .store
.non_ascii:
    cmp 0xFF
    bne .qmark
    lda CH376_SCRATCH
    cmp 0xFF
    beq .done
.qmark:
    lda 0x3F
.store:
    ldx CH376_SCRATCH2
    cpx CH376_LFN_DISP_MAX
    bcs .next
    sta CH376_LFN_TMP,x
    inc CH376_SCRATCH2
.next:
    iny
    jmp .loop
.done:
    rts

; If the LFN chain is complete and checksum matches CH376_BUF[0..10], mark READY.
storage_lfn_bind:
    lda CH376_LFN_NEXT
    bne .drop
    jsr storage_lfn_checksum
    cmp CH376_LFN_CKSUM
    bne .drop
    ldx 0x00
.len_scan:
    cpx CH376_LFN_DISP_MAX
    bcs .got
    lda CH376_LFN_TMP,x
    beq .got
    inx
    jmp .len_scan
.got:
    cpx 0x00
    beq .drop
    stx CH376_LFN_LEN
    lda 0x01
    sta CH376_LFN_READY
    rts
.drop:
    lda 0x00
    sta CH376_LFN_READY
    sta CH376_LFN_LEN
    rts

; Open the short name in CH376_BUF / NAMES[SELECT-1], walk preceding DIR_INFO
; slots (WCH EXAM11 / CH376GetLongName), fill TMP + STORAGE_LFN[SELECT-1].
; Does not cross directory-sector boundaries (falls back to 8.3).
storage_try_fetch_lfn:
    lda CH376_BUF
    cmp 0x2E
    bne .open
    lda CH376_BUF+1
    cmp 0x2E
    bne .open
    ; ".." — no LFN
    jmp .empty

.open:
    jsr storage_entry_ptr_select
    jsr storage_build_open_name
    bcc .empty
    ldy 0x00
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jsr ch376_cmd_set_file_name
    bcc .empty
    jsr ch376_set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .empty
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq .opened
    cmp CH376_ERR_OPEN_DIR
    bne .empty

.opened:
    lda 0xFF
    jsr ch376_cmd_dir_info_read
    bcc .close_empty
    lda CH376_LAST_STATUS
    cmp CH376_INT_DISK_READ
    bne .close_empty
    jsr ch376_rd_dir_entry
    jsr ch376_end_dir_info
    jsr storage_lfn_checksum
    sta CH376_LFN_CKSUM
    jsr storage_lfn_clear_buf
    lda CH376_VAR_FILE_DIR_IDX
    jsr ch376_read_var8
    bcc .close_empty
    sta CH376_DIR_INDEX

.walk:
    lda CH376_DIR_INDEX
    beq .close_empty
    dec CH376_DIR_INDEX
    lda CH376_DIR_INDEX
    jsr ch376_cmd_dir_info_read
    bcc .close_empty
    lda CH376_LAST_STATUS
    cmp CH376_INT_DISK_READ
    bne .close_empty
    jsr ch376_rd_dir_entry
    jsr ch376_end_dir_info
    lda CH376_BUF+11
    and 0x3F
    cmp CH376_LFN_ATTR
    bne .close_empty
    lda CH376_BUF+13
    cmp CH376_LFN_CKSUM
    bne .close_empty
    jsr storage_lfn_append_slot
    lda CH376_BUF
    and CH376_LFN_LAST
    beq .walk
    ; Complete — measure ASCII length
    ldx 0x00
.len_scan:
    cpx CH376_LFN_DISP_MAX
    bcs .got
    lda CH376_LFN_TMP,x
    beq .got
    inx
    jmp .len_scan
.got:
    cpx 0x00
    beq .close_empty
    stx CH376_LFN_LEN
    lda 0x01
    sta CH376_LFN_READY
    lda 0x00
    jsr ch376_cmd_file_close
    jsr ch376_set_timeout
    jsr storage_store_lfn_selected
    sec
    rts

.close_empty:
    lda 0x00
    jsr ch376_cmd_file_close
.empty:
    jsr ch376_set_timeout
    jsr storage_lfn_clear
    jsr storage_store_lfn_selected
    clc
    rts

; Append up to 13 UCS-2 chars from the LFN slot in CH376_BUF onto TMP.
storage_lfn_append_slot:
    ldy 0x00
.loop:
    cpy 0x0D
    bcs .done
    lda storage_lfn_offs,y
    tax
    lda CH376_BUF,x
    sta CH376_SCRATCH
    inx
    lda CH376_BUF,x
    bne .non_ascii
    lda CH376_SCRATCH
    beq .done
    jmp .store
.non_ascii:
    cmp 0xFF
    bne .qmark
    lda CH376_SCRATCH
    cmp 0xFF
    beq .done
.qmark:
    lda 0x3F
.store:
    ldx CH376_LFN_LEN
    cpx CH376_LFN_DISP_MAX
    bcs .next
    sta CH376_LFN_TMP,x
    inx
    stx CH376_LFN_LEN
.next:
    iny
    jmp .loop
.done:
    rts

storage_lfn_offs:
    #d 0x01, 0x03, 0x05, 0x07, 0x09
    #d 0x0E, 0x10, 0x12, 0x14, 0x16, 0x18
    #d 0x1C, 0x1E

; A = Microsoft LFN checksum of the 11-byte 8.3 field in CH376_BUF.
storage_lfn_checksum:
    lda 0x00
    tax
.loop:
    lsr a
    bcc .no_c
    ora 0x80
.no_c:
    clc
    adc CH376_BUF,x
    inx
    cpx 0x0B
    bcc .loop
    rts

; Y:DE = &STORAGE_LFN[FILE_COUNT * 32]
storage_lfn_ptr_count:
    lda CH376_FILE_COUNT
    jmp storage_lfn_ptr_a

; Y:DE = &STORAGE_LFN[(CH376_SELECT - 1) * 32]
storage_lfn_ptr_select:
    lda CH376_SELECT
    sec
    sbc 0x01
storage_lfn_ptr_a:
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_SCRATCH2
    ; offset = index * 32
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    ldy STORAGE_LFN[23:16]
    ldd STORAGE_LFN[15:8]
    lde STORAGE_LFN[7:0]
    clc
    tea
    adc CH376_SCRATCH
    tae
    tda
    adc CH376_SCRATCH2
    tad
    bcc .ok
    iny
.ok:
    rts

; Y:DE = &NAMES[FILE_COUNT * 16]
storage_entry_ptr_count:
    lda CH376_FILE_COUNT
    jmp storage_entry_ptr_a

; Y:DE = &NAMES[(CH376_SELECT - 1) * 16]
storage_entry_ptr_select:
    lda CH376_SELECT
    sec
    sbc 0x01
storage_entry_ptr_a:
    ; offset = index * 16 as 16-bit (index can be 0..39; 8-bit ASL wraps at 16)
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_SCRATCH2
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    asl CH376_SCRATCH
    rol CH376_SCRATCH2
    ldy STORAGE_NAMES[23:16]
    ldd STORAGE_NAMES[15:8]
    lde STORAGE_NAMES[7:0]
    clc
    tea
    adc CH376_SCRATCH
    tae
    tda
    adc CH376_SCRATCH2
    tad
    bcc .ok
    iny
.ok:
    rts

; C=1 if the selected entry is a directory.
storage_entry_is_dir:
    jsr storage_entry_ptr_select
    ldx 0x0F
    lda yde,x
    and CH376_ENTRY_FLAG_DIR
    beq .file
    sec
    rts
.file:
    clc
    rts

; Open the selected directory (or ".."). Expects ERR_OPEN_DIR (0x41).
storage_enter_dir:
    jsr storage_entry_ptr_select
    ldx 0x00
    lda yde,x
    cmp 0x2E
    bne .build
    inx
    lda yde,x
    cmp 0x2E
    bne .build
    lda 0x2E
    sta CH376_FNBUF
    sta CH376_FNBUF+1
    lda 0x00
    sta CH376_FNBUF+2
    lda 0x01
    sta CH376_DOTDOT
    jmp .open
.build:
    lda 0x00
    sta CH376_DOTDOT
    jsr storage_build_open_name
    bcc .fail
.open:
    ldd storage_msg_entering[15:8]
    lde storage_msg_entering[7:0]
    jsr ACIA_SEND_STRING
    jsr storage_print_selected_name
    jsr ACIA_SEND_NEWLINE

    ldy 0x00
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jsr ch376_cmd_set_file_name
    jsr ch376_set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .fail
    lda CH376_LAST_STATUS
    cmp CH376_ERR_OPEN_DIR
    bne .fail
    jsr ch376_set_timeout
    lda CH376_DOTDOT
    beq .down
    lda CH376_DEPTH
    beq .ok
    dec CH376_DEPTH
    jmp .ok
.down:
    inc CH376_DEPTH
.ok:
    sec
    rts
.fail:
    jsr ch376_set_timeout
    ldd storage_msg_open_fail[15:8]
    lde storage_msg_open_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
    clc
    rts

; Y:DE = entry (11 name + 4 size + flags). Build the open path in CH376_FNBUF
; ('/' prefix only at root) and copy the size into CH376_SIZE_*.
storage_build_open_name:
    lda 0x00
    sta CH376_SCRATCH2
    lda CH376_DEPTH
    bne .name
    lda 0x2F
    sta CH376_FNBUF
    lda 0x01
    sta CH376_SCRATCH2
.name:
    ldx 0x00
.name_loop:
    cpx 0x08
    bcs .ext_check
    lda yde,x
    cmp 0x20
    beq .name_next
    phx
    ldx CH376_SCRATCH2
    sta CH376_FNBUF,x
    inx
    stx CH376_SCRATCH2
    plx
.name_next:
    inx
    jmp .name_loop
.ext_check:
    lda 0x00
    sta CH376_SCRATCH
    ldx 0x08
.ext_scan:
    cpx 0x0B
    bcs .ext_maybe
    lda yde,x
    cmp 0x20
    beq .ext_scan_next
    lda 0x01
    sta CH376_SCRATCH
.ext_scan_next:
    inx
    jmp .ext_scan
.ext_maybe:
    lda CH376_SCRATCH
    beq .size
    lda 0x2E
    ldx CH376_SCRATCH2
    sta CH376_FNBUF,x
    inx
    stx CH376_SCRATCH2
    ldx 0x08
.ext_copy:
    cpx 0x0B
    bcs .size
    lda yde,x
    cmp 0x20
    beq .ext_skip
    phx
    ldx CH376_SCRATCH2
    sta CH376_FNBUF,x
    inx
    stx CH376_SCRATCH2
    plx
.ext_skip:
    inx
    jmp .ext_copy
.size:
    ldx CH376_SCRATCH2
    lda 0x00
    sta CH376_FNBUF,x
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

; Read a decimal selection (0..N) into CH376_SELECT.
storage_read_selection:
    lda 0x00
    sta CH376_SELECT
.loop:
    jsr ACIA_READ_CHAR
    cmp 0x0D
    beq .done
    cmp 0x0A
    beq .done
    cmp 0x30
    bcc .loop
    cmp 0x3A
    bcs .loop
    jsr ACIA_SEND_CHAR
    sec
    sbc 0x30
    sta CH376_SCRATCH
    lda CH376_SELECT
    asl a
    sta CH376_SELECT
    asl a
    asl a
    clc
    adc CH376_SELECT
    clc
    adc CH376_SCRATCH
    sta CH376_SELECT
    jmp .loop
.done:
    jsr ACIA_SEND_NEWLINE
    sec
    rts

; Hex nibble in A -> C=1 with A=0..15, else C=0.
storage_hex_nibble:
    cmp 0x30
    bcc .fail
    cmp 0x3A
    bcc .digit
    cmp 0x41
    bcc .fail
    cmp 0x47
    bcc .upper
    cmp 0x61
    bcc .fail
    cmp 0x67
    bcc .lower
.fail:
    clc
    rts
.digit:
    sec
    sbc 0x30
    sec
    rts
.upper:
    sec
    sbc 0x37
    sec
    rts
.lower:
    sec
    sbc 0x57
    sec
    rts

; Read 1..4 hex digits into CH376_TOTAL_HI:CH376_TOTAL_LO. C=1 ok.
storage_read_hex16:
    lda 0x00
    sta CH376_CMP_LSB
    sta CH376_CMP_MSB
    sta CH376_CMP_TMP
.loop:
    jsr ACIA_READ_CHAR
    cmp 0x0D
    beq .done
    cmp 0x0A
    beq .done
    pha
    jsr storage_hex_nibble
    bcc .ignore
    sta CH376_SCRATCH
    pla
    jsr ACIA_SEND_CHAR
    lda CH376_CMP_TMP
    cmp 0x04
    bcs .loop
    ldx 0x04
.shift:
    asl CH376_CMP_LSB
    rol CH376_CMP_MSB
    dex
    bne .shift
    lda CH376_CMP_LSB
    ora CH376_SCRATCH
    sta CH376_CMP_LSB
    inc CH376_CMP_TMP
    jmp .loop
.ignore:
    pla
    jmp .loop
.done:
    jsr ACIA_SEND_NEWLINE
    lda CH376_CMP_TMP
    beq .fail
    lda CH376_CMP_LSB
    sta CH376_TOTAL_LO
    lda CH376_CMP_MSB
    sta CH376_TOTAL_HI
    sec
    rts
.fail:
    clc
    rts

; Read an 8.3 file name into CH376_FNBUF ('/' prefix at root). C=1 ok.
storage_read_fname:
    lda 0x00
    sta CH376_SCRATCH2
    lda CH376_DEPTH
    bne .loop
    lda 0x2F
    sta CH376_FNBUF
    lda 0x01
    sta CH376_SCRATCH2
.loop:
    jsr ACIA_READ_CHAR
    cmp 0x0D
    beq .done
    cmp 0x0A
    beq .done
    cmp 0x2E
    beq .keep
    cmp 0x5F
    beq .keep
    cmp 0x30
    bcc .loop
    cmp 0x3A
    bcc .keep
    cmp 0x41
    bcc .loop
    cmp 0x5B
    bcc .keep
    cmp 0x61
    bcc .loop
    cmp 0x7B
    bcs .loop
    sec
    sbc 0x20
.keep:
    ldx CH376_SCRATCH2
    cpx 0x0C
    bcs .loop
    sta CH376_FNBUF,x
    jsr ACIA_SEND_CHAR
    inc CH376_SCRATCH2
    jmp .loop
.done:
    jsr ACIA_SEND_NEWLINE
    lda CH376_DEPTH
    bne .check_sub
    lda CH376_SCRATCH2
    cmp 0x02
    bcc .fail
    jmp .terminate
.check_sub:
    lda CH376_SCRATCH2
    beq .fail
.terminate:
    ldx CH376_SCRATCH2
    lda 0x00
    sta CH376_FNBUF,x
    sec
    rts
.fail:
    clc
    rts

storage_msg_mounting:
    #d 0x0A, 0x0D, "Mounting USB... ", 0x00
storage_msg_ok:
    #d "OK", 0x0A, 0x0D, 0x00
storage_msg_mount_fail:
    #d "mount failed ST ", 0x00
storage_msg_root:
    #d "Root:", 0x0A, 0x0D, 0x00
storage_msg_subdir:
    #d "Directory:", 0x0A, 0x0D, 0x00
storage_msg_entries:
    #d "Entries: ", 0x00
storage_msg_empty:
    #d "No files.", 0x0A, 0x0D, 0x00
storage_msg_prompt:
    #d "Select (0=quit): ", 0x00
storage_msg_bad_sel:
    #d "Bad selection.", 0x0A, 0x0D, 0x00
storage_msg_entering:
    #d "Entering ", 0x00
storage_msg_loading:
    #d "Loading ", 0x00
storage_msg_loaded:
    #d "INFO: Loaded 0x", 0x00
storage_msg_loaded_at:
    #d " bytes at 0x", 0x00
storage_msg_too_big:
    #d "File too big (>64KB).", 0x0A, 0x0D, 0x00
storage_msg_load_fail:
    #d "Load failed ST ", 0x00
storage_msg_list_fail:
    #d "List failed ST ", 0x00
storage_msg_open_fail:
    #d "Open failed ST ", 0x00
storage_msg_save_from:
    #d "Save from 0x", 0x00
storage_msg_save_len:
    #d "Length hex: ", 0x00
storage_msg_save_name:
    #d "Name 8.3: ", 0x00
storage_msg_saving:
    #d "Saving ", 0x00
storage_msg_saved:
    #d "INFO: Saved 0x", 0x00
storage_msg_save_fail:
    #d "Save failed ST ", 0x00
storage_msg_bad_input:
    #d "Bad input.", 0x0A, 0x0D, 0x00
storage_fn_slash:
    #d "/", 0x00
storage_fn_slash_star:
    #d "/*", 0x00
storage_fn_star:
    #d "*", 0x00
storage_tag_dir:
    #d " <DIR>", 0x00
