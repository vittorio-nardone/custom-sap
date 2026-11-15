; Kernel USB directory helpers for the shell (dir / load / exec / cd #HH).
; Public app API is STORAGE_* in api.asm — this file is listing + path helpers.

#once
#bank kernel

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
    beq .open_root
    ; Subdirectory left open by shell_sync_cwd / cd.
    jmp .opened

.open_root:
    ; DISK_MOUNT / a prior op may leave a dir handle open — close first
    ; (same pattern as load/exec/rmdir) so FILE_OPEN "/" returns 0x41.
    lda 0x00
    jsr ch376_cmd_file_close
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
    jsr storage_list_sort
    lda CH376_LIST_STYLE
    cmp 0x01
    beq .print_all
    ; quiet (2) or other: sorted table only
    sec
    rts
.print_all:
    jsr storage_list_print_all
    ldd storage_msg_total[15:8]
    lde storage_msg_total[7:0]
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
    jsr storage_lfn_clear
    inc CH376_FILE_COUNT
    rts

.discard:
    jsr storage_lfn_clear
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
    inc CH376_FILE_COUNT
.done:
    rts

; ---- Sort STORAGE_NAMES (+ LFN): ".." first, dirs, files; alpha 8.3 ----
; Uses SHELL_WORK+8/+9 for j/limit — entry_ptr clobbers CH376_SCRATCH*.
storage_list_sort:
    lda CH376_FILE_COUNT
    cmp 0x02
    bcc .done
    ; bubble: LIST_IDX = i (0..n-2), WORK+8 = j, WORK+9 = inner limit
    lda 0x00
    sta CH376_LIST_IDX
.outer:
    lda CH376_FILE_COUNT
    sec
    sbc 0x01
    sec
    sbc CH376_LIST_IDX
    beq .done
    sta SHELL_WORK+9              ; inner limit
    lda 0x00
    sta SHELL_WORK+8              ; j
.inner:
    lda SHELL_WORK+8
    jsr storage_list_cmp_next     ; C=1 if names[j] > names[j+1]
    bcc .noswap
    jsr storage_list_swap_j
.noswap:
    inc SHELL_WORK+8
    lda SHELL_WORK+8
    cmp SHELL_WORK+9
    bcc .inner
    inc CH376_LIST_IDX
    jmp .outer
.done:
    rts

; A = j (0-based). C=1 if entry j should sort after j+1.
storage_list_cmp_next:
    sta CH376_SELECT
    jsr storage_entry_rank_a
    lda SHELL_WORK+0
    sta SHELL_WORK+1              ; rank j
    lda CH376_SELECT
    clc
    adc 0x01
    jsr storage_entry_rank_a      ; rank j+1
    lda SHELL_WORK+1
    cmp SHELL_WORK+0
    bcc .less
    bne .greater
    ; same rank: copy j name to BUF, compare to j+1
    lda CH376_SELECT
    jsr storage_entry_ptr_a
    ldx 0x00
.cpj:
    lda yde,x
    sta CH376_BUF,x
    inx
    cpx 0x0B
    bcc .cpj
    lda CH376_SELECT
    clc
    adc 0x01
    jsr storage_entry_ptr_a
    ldx 0x00
.cmp:
    lda yde,x
    sta SHELL_WORK+2              ; j+1 char
    lda CH376_BUF,x
    cmp SHELL_WORK+2
    bcc .less                     ; j < j+1
    bne .greater                  ; j > j+1
    inx
    cpx 0x0B
    bcc .cmp
.less:
    clc
    rts
.greater:
    sec
    rts

; A = 0-based index → SHELL_WORK+0 = sort rank (0=.., 1=dir, 2=file), YDE=entry
storage_entry_rank_a:
    jsr storage_entry_ptr_a
    ldx 0x00
    lda yde,x
    cmp 0x2E
    bne .not_dot
    inx
    lda yde,x
    cmp 0x2E
    bne .not_dot
    lda 0x00
    sta SHELL_WORK+0
    rts
.not_dot:
    ldx 0x0F
    lda yde,x
    and CH376_ENTRY_FLAG_DIR
    beq .file
    lda 0x01
    sta SHELL_WORK+0
    rts
.file:
    lda 0x02
    sta SHELL_WORK+0
    rts

; Swap entries j and j+1 (j in CH376_SELECT). Also swap LFN slots.
storage_list_swap_j:
    ; NAMES: 16 bytes via BUF
    lda CH376_SELECT
    jsr storage_entry_ptr_a
    ldx 0x00
.s1:
    lda yde,x
    sta CH376_BUF,x
    inx
    cpx 0x10
    bcc .s1
    lda CH376_SELECT
    clc
    adc 0x01
    jsr storage_entry_ptr_a
    ldx 0x00
.s2:
    lda yde,x
    sta CH376_BUF+0x10,x
    inx
    cpx 0x10
    bcc .s2
    ; write j ← old j+1
    lda CH376_SELECT
    jsr storage_entry_ptr_a
    ldx 0x00
.s3:
    lda CH376_BUF+0x10,x
    sta yde,x
    inx
    cpx 0x10
    bcc .s3
    ; write j+1 ← old j
    lda CH376_SELECT
    clc
    adc 0x01
    jsr storage_entry_ptr_a
    ldx 0x00
.s4:
    lda CH376_BUF,x
    sta yde,x
    inx
    cpx 0x10
    bcc .s4
    ; LFN slots (32 bytes) via LFN_TMP as half-temp — use BUF again in two passes
    lda CH376_SELECT
    jsr storage_lfn_ptr_a
    ldx 0x00
.l1:
    lda yde,x
    sta CH376_LFN_TMP,x
    inx
    cpx 0x20
    bcc .l1
    lda CH376_SELECT
    clc
    adc 0x01
    jsr storage_lfn_ptr_a
    ; copy j+1 → temp in BUF (32 bytes)
    ldx 0x00
.l2:
    lda yde,x
    sta CH376_BUF,x
    inx
    cpx 0x20
    bcc .l2
    ; j ← BUF (old j+1)
    lda CH376_SELECT
    jsr storage_lfn_ptr_a
    ldx 0x00
.l3:
    lda CH376_BUF,x
    sta yde,x
    inx
    cpx 0x20
    bcc .l3
    ; j+1 ← LFN_TMP (old j)
    lda CH376_SELECT
    clc
    adc 0x01
    jsr storage_lfn_ptr_a
    ldx 0x00
.l4:
    lda CH376_LFN_TMP,x
    sta yde,x
    inx
    cpx 0x20
    bcc .l4
    rts

; Print sorted table (style 1). Reloads each entry into BUF/LFN_TMP.
storage_list_print_all:
    lda 0x00
    sta CH376_LIST_IDX
.lp:
    lda CH376_LIST_IDX
    cmp CH376_FILE_COUNT
    bcs .done
    clc
    adc 0x01
    sta CH376_LIST_NUM
    sta CH376_SELECT
    jsr storage_entry_ptr_select
    ; name → BUF, size → BUF+0x1C, flags → ENTRY_FLAGS
    ldx 0x00
.nm:
    cpx 0x0B
    bcs .sz
    lda yde,x
    sta CH376_BUF,x
    inx
    jmp .nm
.sz:
    ldx 0x00
.szl:
    cpx 0x04
    bcs .fl
    txa
    clc
    adc 0x0B
    phx
    tax
    lda yde,x
    plx
    sta CH376_BUF+0x1C,x
    inx
    jmp .szl
.fl:
    ldx 0x0F
    lda yde,x
    sta CH376_ENTRY_FLAGS
    ; LFN
    jsr storage_lfn_ptr_select
    ldx 0x00
    lda yde,x
    beq .nolfn
    ldx 0x00
.lcpy:
    lda yde,x
    sta CH376_LFN_TMP,x
    beq .lgot
    inx
    cpx CH376_LFN_DISP_MAX
    bcc .lcpy
    lda 0x00
    sta CH376_LFN_TMP,x
.lgot:
    stx CH376_LFN_LEN
    lda 0x01
    sta CH376_LFN_READY
    jmp .pr
.nolfn:
    lda 0x00
    sta CH376_LFN_READY
    sta CH376_LFN_LEN
.pr:
    jsr storage_print_entry_tab
    inc CH376_LIST_IDX
    jmp .lp
.done:
    rts

; Print one listing line.
; CH376_LIST_STYLE=1: tabular shell dir
; CH376_LIST_STYLE=2: quiet (store only, used by load/exec)
storage_print_entry_line:
    lda CH376_LIST_STYLE
    cmp 0x01
    beq storage_print_entry_tab
    rts                             ; quiet / unknown

; Tabular: ## MODE SIZE 8.3 [LFN]
; ## = 1-based index (hex) for shell refs: type #03 / cd #01
storage_print_entry_tab:
    lda CH376_LIST_NUM
    jsr ACIA_SEND_HEX
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda CH376_ENTRY_FLAGS
    and CH376_ENTRY_FLAG_DIR
    beq .file
    lda 0x64                      ; 'd'
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    ldd storage_tag_dir8[15:8]
    lde storage_tag_dir8[7:0]
    jsr ACIA_SEND_STRING
    jmp .name
.file:
    lda 0x2D                      ; '-'
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    jsr storage_print_size_hex
.name:
    lda 0x20
    jsr ACIA_SEND_CHAR
    jsr storage_print_name83_pad
    lda CH376_LFN_READY
    beq .nl
    lda CH376_LFN_LEN
    beq .nl
    lda 0x20
    jsr ACIA_SEND_CHAR
    ldx 0x00
.lfn:
    cpx CH376_LFN_LEN
    bcs .nl
    lda CH376_LFN_TMP,x
    jsr ACIA_SEND_CHAR
    inx
    jmp .lfn
.nl:
    jmp ACIA_SEND_NEWLINE

; 8 hex digits from CH376_BUF+0x1C (LE → MSB first on wire).
storage_print_size_hex:
    lda CH376_BUF+0x1F
    jsr ACIA_SEND_HEX
    lda CH376_BUF+0x1E
    jsr ACIA_SEND_HEX
    lda CH376_BUF+0x1D
    jsr ACIA_SEND_HEX
    lda CH376_BUF+0x1C
    jmp ACIA_SEND_HEX

storage_print_name83:
    ldy 0x00                      ; chars emitted (for pad helper)
    ldx 0x00
.name:
    cpx 0x08
    bcs .ext
    lda CH376_BUF,x
    cmp 0x20
    beq .name_skip
    jsr ACIA_SEND_CHAR
    iny
.name_skip:
    inx
    jmp .name
.ext:
    lda CH376_BUF+8
    cmp 0x20
    beq .done
    lda 0x2E
    jsr ACIA_SEND_CHAR
    iny
    ldx 0x08
.ext_loop:
    cpx 0x0B
    bcs .done
    lda CH376_BUF,x
    cmp 0x20
    beq .ext_skip
    jsr ACIA_SEND_CHAR
    iny
.ext_skip:
    inx
    jmp .ext_loop
.done:
    rts

; 8.3 left-aligned in a 12-char field (max "ABCDEFGH.XYZ").
storage_print_name83_pad:
    jsr storage_print_name83
.pad:
    cpy 0x0C
    bcs .done
    lda 0x20
    jsr ACIA_SEND_CHAR
    iny
    jmp .pad
.done:
    rts

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

storage_msg_mounting:
    #d 0x0A, 0x0D, "Mounting USB... ", 0x00
storage_msg_ok:
    #d "OK", 0x0A, 0x0D, 0x00
storage_msg_mount_fail:
    #d "mount failed ST ", 0x00
storage_msg_total:
    #d "total ", 0x00
storage_fn_slash:
    #d "/", 0x00
storage_tag_dir8:
    #d "<DIR>   ", 0x00            ; exactly 8 chars (align with size hex)
