; =========================================================
; On-board Pascal Compiler for Project Otto
;
; Single-pass recursive descent compiler.
; Source: expansion RAM page 1 (line-based, via editor)
; Output: P-code at 0x8400 (PM_PCODE_BASE)
; Workspace: expansion RAM page 1 (symbol/fixup/string tables, CC_SYM_BASE+)
;
; Included from editor.asm (shares EDITOR_ENTRY label scope).
; =========================================================

; ── Compiler entry ───────────────────────────────────────

.cc_compile:
    ; Initialize state
    lda 0x00
    sta CC_ERROR
    sta CC_SYM_COUNT
    sta CC_SCOPE_LEVEL
    sta CC_FIX_SP
    sta CC_STR_OFF_LO
    sta CC_STR_OFF_HI
    sta CC_SUB_COUNT
    sta CC_SRC_COL
    sta CC_STR_FIX_SP
    sta CC_IS_FUNC
    sta CC_PARAM_VAR
    sta CC_VAR_TYPE
    sta CC_FUNC_RET
    sta CC_EXPR_TYPE
    jsr .cc_str_rel_clear    ; avoid garbage RAM breaking string assign / compare
    sta CC_STR_EQ_TMP_LO
    sta CC_STR_EQ_TMP_HI
    sta CC_FOUND_SYM_IDX
    ; Frame offset starts at 2 (bytes 0-1 reserved for static link)
    lda 0x02
    sta CC_FRAME_OFF
    lda 0x00
    sta CC_FRAME_OFF_HI

    ; P-code header is 7 bytes: "PM" + version + code_off(2) + data_off(2)
    lda 0x07
    sta CC_CODE_LO
    lda 0x00
    sta CC_CODE_HI

    ; Get total line count
    jsr .ed_get_line_count
    sta CC_TOTAL_LINES
    beq .cc_err_empty

    ; Load first source line
    lda 0x01
    sta CC_SRC_LINE
    jsr .ed_read_line_to_buf

    ; Get first token
    jsr .cc_next_token

    ; Parse: program Name ;
    lda CC_TOKEN_TYPE
    cmp CC_TK_PROGRAM
    bne .cc_err_program
    jsr .cc_next_token
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_err_program
    jsr .cc_next_token
    lda CC_TK_SEMI
    jsr .cc_expect

    ; Parse optional const block
    lda CC_ERROR
    bne .cc_compile_end
    lda CC_TOKEN_TYPE
    cmp CC_TK_CONST
    bne .cc_no_const
    jsr .cc_parse_const
.cc_no_const:

    ; Parse optional var block
    lda CC_ERROR
    bne .cc_compile_end
    lda CC_TOKEN_TYPE
    cmp CC_TK_VAR
    bne .cc_no_var
    jsr .cc_parse_var
.cc_no_var:

    ; Parse procedure/function declarations (emits JMP over bodies)
    lda CC_ERROR
    bne .cc_compile_end
    jsr .cc_parse_subs

    ; Emit ENTER16 for main program (frame_size 16-bit patched later)
    ; Operands: frame_lo, frame_hi, nparams, is_function
    lda CC_ERROR
    bne .cc_compile_end
    lda PM_OP_ENTER16
    jsr .cc_emit
    ; save position of frame_size word for patching
    lda CC_CODE_LO
    sta CC_ENTER_LO
    lda CC_CODE_HI
    sta CC_ENTER_HI
    lda 0x00
    jsr .cc_emit         ; frame_size lo placeholder
    lda 0x00
    jsr .cc_emit         ; frame_size hi placeholder
    lda 0x00
    jsr .cc_emit         ; nparams = 0
    lda 0x00
    jsr .cc_emit         ; is_function = 0

    ; Parse begin..end.
    lda CC_TK_BEGIN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_compile_end
    jsr .cc_parse_block

    lda CC_ERROR
    bne .cc_compile_end
    lda CC_TOKEN_TYPE
    cmp CC_TK_DOT
    bne .cc_err_dot

    ; Emit HALT
    lda PM_OP_HALT
    jsr .cc_emit

    jsr .cc_patch_enter

    ; Finalize: append string pool, write P-code header
    jsr .cc_finalize

.cc_compile_end:
    lda CC_ERROR
    rts

.cc_err_empty:
    lda 0x01
    sta CC_SRC_LINE
    lda .cc_e_no_src
    jmp .cc_error_a
.cc_err_program:
    lda .cc_e_program
    jmp .cc_error_a
.cc_err_dot:
    lda .cc_e_dot
    jmp .cc_error_a

; ── const block parser ───────────────────────────────────

.cc_parse_const:
    jsr .cc_next_token       ; consume 'const'

.cc_pc_loop:
    lda CC_ERROR
    bne .cc_pc_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_pc_done

    ; Save name in symbol table (cc_add_const reads CC_TOKEN_BUF)
    ; First, get the value: consume ident, expect '=', parse number
    jsr .cc_add_const_name   ; write name+scope+kind, leave entry open
    jsr .cc_next_token       ; consume ident
    lda CC_TK_EQ
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_pc_done

    ; Parse optional '-' and number
    lda 0x00
    sta CC_TEMP3             ; sign flag (0=positive)
    lda CC_TOKEN_TYPE
    cmp CC_TK_MINUS
    bne .cc_pc_no_neg
    lda 0x01
    sta CC_TEMP3
    jsr .cc_next_token       ; consume '-'
.cc_pc_no_neg:
    lda CC_TOKEN_TYPE
    cmp CC_TK_NUMBER
    bne .cc_pc_err

    ; Store value in the last symbol entry (bytes 10-11)
    lda CC_SYM_COUNT
    sec
    sbc 0x01
    jsr .cc_sym_addr
    ldx 0x0A
    lda CC_TEMP3
    beq .cc_pc_store_pos
    ; Negate: two's complement of CC_TOKEN_NUM
    lda CC_TOKEN_NUM_LO
    eor 0xFF
    clc
    adc 0x01
    sta yde,x
    inx
    lda CC_TOKEN_NUM_HI
    eor 0xFF
    adc 0x00
    sta yde,x
    jmp .cc_pc_next
.cc_pc_store_pos:
    lda CC_TOKEN_NUM_LO
    sta yde,x
    inx
    lda CC_TOKEN_NUM_HI
    sta yde,x

.cc_pc_next:
    jsr .cc_next_token       ; consume number
    lda CC_TK_SEMI
    jsr .cc_expect
    jmp .cc_pc_loop

.cc_pc_err:
    lda .cc_e_syntax
    jmp .cc_error_a

.cc_pc_done:
    rts

.cc_add_const_name:
    ; Add constant entry to symbol table (name+scope+kind only, value patched later)
    lda CC_SYM_COUNT
    jsr .cc_sym_addr
    jsr .cc_sym_write_name   ; X=8
    lda CC_SCOPE_LEVEL
    sta yde,x                ; byte 8: scope
    inx
    lda CC_KIND_CONST
    sta yde,x                ; byte 9: kind=CONST
    inc CC_SYM_COUNT
    rts

; ── var block parser ─────────────────────────────────────

.cc_parse_var:
    jsr .cc_next_token       ; consume 'var'

.cc_pv_loop:
    lda CC_ERROR
    bne .cc_pv_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_pv_done

    ; Save sym count before adding this group (for real re-patching)
    lda CC_SYM_COUNT
    sta CC_TEMP4

.cc_pv_names:
    jsr .cc_add_var
    jsr .cc_next_token       ; consume ident
    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    bne .cc_pv_colon
    jsr .cc_next_token       ; consume ','
    jmp .cc_pv_names

.cc_pv_colon:
    lda CC_TK_COLON
    jsr .cc_expect
    lda CC_TOKEN_TYPE
    cmp CC_TK_ARRAY
    beq .cc_pv_array
    cmp CC_TK_REAL
    beq .cc_pv_real
    cmp CC_TK_STRING_TYPE
    beq .cc_pv_string
    lda CC_TK_INTEGER
    jsr .cc_expect
    jmp .cc_pv_after_type
.cc_pv_real:
    lda CC_TEMP4
    jsr .cc_repatch_real
    jsr .cc_next_token       ; consume 'real'
    jmp .cc_pv_after_type
.cc_pv_string:
    lda CC_TEMP4
    jsr .cc_repatch_string
    jsr .cc_next_token       ; consume 'string'
.cc_pv_after_type:
    lda CC_TK_SEMI
    jsr .cc_expect
    jmp .cc_pv_loop

.cc_pv_array:
    ; array[low..high] of integer
    ; The LAST added variable becomes the array.
    ; First, undo cc_add_var's 2-byte allocation
    lda CC_FRAME_OFF
    sec
    sbc 0x02
    sta CC_FRAME_OFF
    dec CC_SYM_COUNT
    jsr .cc_next_token       ; consume 'array'
    lda CC_TK_LBRACKET
    jsr .cc_expect
    ; Parse low bound (number or constant ident)
    jsr .cc_pv_arr_bound
    bcs .cc_pv_arr_err
    sta CC_FOUND_ARG1        ; low bound
    lda CC_TK_DOTDOT
    jsr .cc_expect
    ; Parse high bound (number or constant ident)
    jsr .cc_pv_arr_bound
    bcs .cc_pv_arr_err
    sta CC_FOUND_ARG2        ; high bound
    lda CC_TK_RBRACKET
    jsr .cc_expect
    lda CC_TK_OF
    jsr .cc_expect
    lda CC_TK_INTEGER
    jsr .cc_expect
    ; Re-add as array (name is still in CC_TOKEN_BUF from the ident)
    ; Wait - we consumed the ident already. We need the name.
    ; The ident was consumed by cc_pv_names. But we only support
    ; single-name array decls. The token buf was overwritten.
    ; Fix: save the name before consuming the colon.
    ; For now, abort - we need to restructure cc_pv_names.
    ; Actually: cc_add_var already wrote the name to the sym table.
    ; We decremented CC_SYM_COUNT, but the data is still there.
    ; We can re-read the name from the sym table entry.
    ; But cc_add_arr writes from CC_TOKEN_BUF... which now has 'integer'.
    ; Workaround: just directly write kind=ARRAY into the existing entry.
    ; Re-increment SYM_COUNT and patch the entry in-place.
    lda CC_SYM_COUNT
    jsr .cc_sym_addr         ; D:E:Y point to the NEXT (empty) slot
    ; Actually we need the PREVIOUS entry. Re-read from count-1? No,
    ; SYM_COUNT was decremented, so entry at SYM_COUNT is the one we want.
    jsr .cc_sym_write_arr_fields
    inc CC_SYM_COUNT
    lda CC_TK_SEMI
    jsr .cc_expect
    jmp .cc_pv_loop

; Resolve an array bound: number literal or constant identifier.
; Returns value in A (lo byte), carry clear = ok, carry set = error.
.cc_pv_arr_bound:
    lda CC_TOKEN_TYPE
    cmp CC_TK_NUMBER
    bne .cc_pv_ab_try_const
    lda CC_TOKEN_NUM_LO
    pha
    jsr .cc_next_token
    pla
    clc
    rts
.cc_pv_ab_try_const:
    cmp CC_TK_IDENT
    bne .cc_pv_ab_err
    jsr .cc_find_sym
    bcs .cc_pv_ab_err
    ; Must be a constant (kind = SCALAR, scope-level special or byte 15 marks)
    lda CC_FOUND_KIND
    cmp CC_KIND_CONST
    bne .cc_pv_ab_err
    lda CC_FOUND_B10         ; constant value lo
    pha
    jsr .cc_next_token
    pla
    clc
    rts
.cc_pv_ab_err:
    sec
    rts

.cc_pv_arr_err:
    lda .cc_e_syntax
    jmp .cc_error_a

.cc_pv_done:
    rts

; ── Block parser (begin..end) ────────────────────────────

.cc_parse_block:
    lda CC_ERROR
    bne .cc_pb_done

    jsr .cc_parse_statement

.cc_pb_loop:
    lda CC_ERROR
    bne .cc_pb_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_SEMI
    bne .cc_pb_end
    jsr .cc_next_token       ; consume ';'
    ; Check for 'end' (allow trailing semicolons)
    lda CC_TOKEN_TYPE
    cmp CC_TK_END
    beq .cc_pb_end
    jsr .cc_parse_statement
    jmp .cc_pb_loop

.cc_pb_end:
    lda CC_TK_END
    jsr .cc_expect
.cc_pb_done:
    rts

; ── Statement dispatcher ────────────────────────────────

.cc_parse_statement:
    lda CC_ERROR
    bne .cc_ps_done
    lda CC_TOKEN_TYPE

    cmp CC_TK_IDENT
    beq .cc_ps_ident
    cmp CC_TK_BEGIN
    beq .cc_parse_compound
    cmp CC_TK_IF
    beq .cc_parse_if
    cmp CC_TK_WHILE
    beq .cc_parse_while
    cmp CC_TK_FOR
    beq .cc_parse_for
    cmp CC_TK_WRITE
    beq .cc_parse_write
    cmp CC_TK_WRITELN
    beq .cc_parse_writeln
    cmp CC_TK_READLN
    beq .cc_parse_readln
    cmp CC_TK_REPEAT
    beq .cc_parse_repeat
    cmp CC_TK_POKE
    beq .cc_parse_poke
    cmp CC_TK_DELAY
    beq .cc_parse_delay
    cmp CC_TK_VT100
    beq .cc_parse_vt100_kw
    cmp CC_TK_VT100_POS
    beq .cc_parse_vt100_pos
    cmp CC_TK_VT100_SCROLL
    beq .cc_parse_vt100_scroll

.cc_ps_done:
    rts

.cc_ps_ident:
    jsr .cc_find_sym
    bcs .cc_ps_undef
    lda CC_FOUND_KIND
    cmp CC_KIND_PROC
    beq .cc_ps_call
    cmp CC_KIND_FUNC
    beq .cc_ps_func_stmt
    jmp .cc_parse_assign     ; scalar or array

.cc_ps_func_stmt:
    ; Function in statement: ':=' → return value, else → call
    lda CC_IS_FUNC
    beq .cc_ps_call          ; not inside function → call
    ; Check if this is the current function (scope = CC_SCOPE_LEVEL - 1)
    lda CC_SCOPE_LEVEL
    sec
    sbc 0x01
    cmp CC_FOUND_SCOPE
    bne .cc_ps_call
    ; Might be return value assignment. Consume ident, check for ':='
    jsr .cc_next_token
    lda CC_TOKEN_TYPE
    cmp CC_TK_ASSIGN
    bne .cc_ps_func_call_after
    ; Return value assignment: funcname := expr
    jsr .cc_next_token       ; consume ':='
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_ps_done
    lda CC_FUNC_RET
    bne .cc_ps_fret_real
    jsr .cc_ensure_int
    lda PM_OP_STORE
    jsr .cc_emit
    lda 0x02                 ; return value at offset 2
    jsr .cc_emit
    rts
.cc_ps_fret_real:
    jsr .cc_ensure_real
    lda PM_OP_FSTORE
    jsr .cc_emit
    lda 0x02                 ; return value at offset 2
    jsr .cc_emit
    rts

.cc_ps_func_call_after:
    ; Already consumed ident, now parse call args
    jmp .cc_call_args

.cc_ps_call:
    ; Procedure/function call as statement
    jsr .cc_next_token       ; consume identifier
    jmp .cc_call_args

.cc_ps_undef:
    lda .cc_e_undef
    jmp .cc_error_a

; ── Assignment: ident := expr ────────────────────────────

.cc_parse_assign:
    lda CC_FOUND_KIND
    cmp CC_KIND_CONST
    beq .cc_pa_const_err
    cmp CC_KIND_ARRAY
    beq .cc_pa_array
    ; Check if var param
    lda CC_FOUND_B14
    bne .cc_pa_var_param
    lda CC_FOUND_B15
    cmp 0x02
    beq .cc_pa_string
    lda CC_FOUND_B15         ; variable type (0=int, 1=real)
    pha                      ; save var type on stack
    lda CC_FOUND_ARG1
    sta CC_ES_ARG1_SAVE      ; preserve offset hi for .cc_emit_scoped
    lda CC_FOUND_B10         ; offset
    pha
    lda CC_SCOPE_LEVEL
    sec
    sbc CC_FOUND_SCOPE
    pha                      ; [stack: var_type, offset, level_diff]
    jsr .cc_next_token       ; consume ident
    lda CC_TK_ASSIGN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_pa_done_pop3
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_pa_done_pop3
    ; Check types: stack has [var_type, offset, level_diff]
    ; We need to peek at var_type to decide coercion
    ; Pop level_diff and offset temporarily
    pla
    sta CC_TEMP3             ; level_diff
    pla
    sta CC_TEMP4             ; offset
    pla                      ; var_type
    ; A = var_type, CC_EXPR_TYPE = expr_type
    cmp 0x01
    beq .cc_pa_store_real
    ; Integer var: coerce expr to int if needed
    jsr .cc_ensure_int
    lda CC_TEMP4
    pha                      ; push offset back
    lda CC_TEMP3
    pha                      ; push level_diff back
    lda PM_OP_STORE_L
    sta CC_TEMP2
    lda PM_OP_STORE
    jmp .cc_emit_scoped
.cc_pa_store_real:
    ; Real var: coerce expr to real if needed
    jsr .cc_ensure_real
    lda CC_TEMP4
    pha
    lda CC_TEMP3
    pha
    lda PM_OP_FSTORE_L
    sta CC_TEMP2
    lda PM_OP_FSTORE
    jmp .cc_emit_scoped

.cc_pa_string:
    ; string var := literal | string var
    jsr .cc_next_token       ; consume lhs ident
    lda CC_FOUND_B10
    sta CC_TEMP3
    lda CC_FOUND_ARG1
    sta CC_TEMP4
    lda CC_TK_ASSIGN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_pa_str_err
    ; cc_expect already advanced past ':='; current token is RHS (literal or ident).
    lda CC_TOKEN_TYPE
    cmp CC_TK_STRING
    beq .cc_pa_str_lit
    cmp CC_TK_IDENT
    beq .cc_pa_str_copy
    lda .cc_e_syntax
    jmp .cc_error_a
.cc_pa_str_lit:
    jsr .cc_add_string_token
    jsr .cc_next_token
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_STR_ASSIGN_LIT
    jsr .cc_emit
    lda CC_TEMP3
    jsr .cc_emit
    lda CC_TEMP4
    jsr .cc_emit
    jsr .cc_push_str_fixup
    rts
.cc_pa_str_copy:
    jsr .cc_find_sym
    bcs .cc_pa_undef
    lda CC_FOUND_B15
    cmp 0x02
    bne .cc_pa_undef
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_STR_COPY
    jsr .cc_emit
    lda CC_TEMP3
    jsr .cc_emit
    lda CC_TEMP4
    jsr .cc_emit
    lda CC_FOUND_B10
    jsr .cc_emit
    lda CC_FOUND_ARG1
    jsr .cc_emit
    jsr .cc_next_token
    rts
.cc_pa_str_err:
    rts

.cc_pa_var_param:
    lda CC_FOUND_B10         ; offset
    pha
    jsr .cc_next_token       ; consume ident
    lda CC_TK_ASSIGN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_pa_done_pop1
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_pa_done_pop1
    lda PM_OP_STORE_REF
    jsr .cc_emit
    pla
    jsr .cc_emit
    rts
.cc_pa_done_pop1:
    pla
    rts
.cc_pa_done_pop3:
    pla
    pla
    pla
    rts
.cc_pa_array:
    lda CC_FOUND_ARG1
    sta CC_ES_ARG1_SAVE      ; preserve offset hi for .cc_emit_scoped
    lda CC_FOUND_B10         ; adjusted_base (saved by cc_ps_ident)
    pha                      ; save adjusted_base
    lda CC_SCOPE_LEVEL
    sec
    sbc CC_FOUND_SCOPE
    pha                      ; save level_diff
    jsr .cc_next_token       ; consume ident
    lda CC_TK_LBRACKET
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_pa_done_pop2
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression ; index
    lda CC_ERROR
    bne .cc_pa_done_pop2
    lda CC_TK_RBRACKET
    jsr .cc_expect
    lda CC_TK_ASSIGN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_pa_done_pop2
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression ; value
    lda CC_ERROR
    bne .cc_pa_done_pop2
    lda PM_OP_STORE_AL
    sta CC_TEMP2
    lda PM_OP_STORE_A
    jmp .cc_emit_scoped
.cc_pa_done_pop2:
    pla
    pla
.cc_pa_done:
    rts
.cc_pa_const_err:
    lda .cc_e_const
    jmp .cc_error_a
.cc_pa_undef:
    lda .cc_e_undef
    jmp .cc_error_a

; ── Compound: begin stmts end ────────────────────────────

.cc_parse_compound:
    jsr .cc_next_token       ; consume 'begin'
    jsr .cc_parse_block
    rts

; ── If: if expr then stmt [else stmt] ───────────────────

.cc_parse_if:
    jsr .cc_next_token       ; consume 'if'
    jsr .cc_parse_expr_cond
    lda CC_ERROR
    bne .cc_if_done
    jsr .cc_ensure_int       ; FTOI if needed for JPC
    lda CC_TK_THEN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_if_done

    lda PM_OP_JPC
    jsr .cc_emit
    jsr .cc_push_fixup       ; save fixup position

    jsr .cc_parse_statement
    lda CC_ERROR
    bne .cc_if_done

    ; Check for else
    lda CC_TOKEN_TYPE
    cmp CC_TK_ELSE
    bne .cc_if_no_else

    ; Emit JMP past else, patch JPC to here
    lda PM_OP_JMP
    jsr .cc_emit
    ; swap fixup: pop JPC fixup, push JMP fixup
    jsr .cc_swap_fixup

    jsr .cc_next_token       ; consume 'else'
    jsr .cc_parse_statement

.cc_if_no_else:
    ; Patch the pending fixup
    jsr .cc_pop_fixup_patch
.cc_if_done:
    rts

; ── While: while expr do stmt ────────────────────────────

.cc_parse_while:
    jsr .cc_next_token       ; consume 'while'

    ; Save loop top address
    lda CC_CODE_LO
    pha
    lda CC_CODE_HI
    pha

    jsr .cc_parse_expr_cond
    lda CC_ERROR
    bne .cc_wh_done
    jsr .cc_ensure_int       ; FTOI if needed for JPC
    lda CC_TK_DO
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_wh_done

    lda PM_OP_JPC
    jsr .cc_emit
    jsr .cc_push_fixup

    jsr .cc_parse_statement
    lda CC_ERROR
    bne .cc_wh_done

    ; Emit JMP back to loop top
    lda PM_OP_JMP
    jsr .cc_emit
    pla
    sta CC_TEMP2             ; loop_top high
    pla
    sta CC_TEMP1             ; loop_top low
    lda CC_TEMP1
    jsr .cc_emit             ; addr low
    lda CC_TEMP2
    jsr .cc_emit             ; addr high

    ; Patch JPC exit
    jsr .cc_pop_fixup_patch
    rts

.cc_wh_done:
    pla
    pla
    rts

; ── For: for var := start to/downto end do stmt ──────────

.cc_parse_for:
    jsr .cc_next_token       ; consume 'for'

    ; Get loop variable
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_for_err
    jsr .cc_find_sym
    bcs .cc_for_undef
    sta CC_FOR_VAR           ; save var offset

    jsr .cc_next_token       ; consume ident
    lda CC_TK_ASSIGN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_for_done

    ; Emit start value and store to var
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_for_done
    lda PM_OP_STORE
    jsr .cc_emit
    lda CC_FOR_VAR
    jsr .cc_emit

    ; Allocate temp for limit value
    lda CC_FRAME_OFF
    sta CC_FOR_LIMIT         ; temp offset for limit
    lda CC_FRAME_OFF
    clc
    adc 0x02
    sta CC_FRAME_OFF

    ; Check direction (to/downto)
    lda CC_TOKEN_TYPE
    cmp CC_TK_TO
    beq .cc_for_to
    cmp CC_TK_DOWNTO
    beq .cc_for_downto
    jmp .cc_for_err

.cc_for_to:
    lda 0x00                 ; 0 = ascending
    sta CC_FOR_DIR
    jsr .cc_next_token
    jmp .cc_for_limit
.cc_for_downto:
    lda 0x01                 ; 1 = descending
    sta CC_FOR_DIR
    jsr .cc_next_token

.cc_for_limit:
    ; Parse limit expression, store to temp
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_for_done
    lda PM_OP_STORE
    jsr .cc_emit
    lda CC_FOR_LIMIT         ; temp offset
    jsr .cc_emit

    lda CC_TK_DO
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_for_done

    ; Loop top: compare var with limit
    lda CC_CODE_LO
    pha
    lda CC_CODE_HI
    pha

    ; LOAD var
    lda PM_OP_LOAD
    jsr .cc_emit
    lda CC_FOR_VAR
    jsr .cc_emit
    ; LOAD limit
    lda PM_OP_LOAD
    jsr .cc_emit
    lda CC_FOR_LIMIT
    jsr .cc_emit

    ; Emit comparison (LE for to, GE for downto)
    lda PM_OP_LE
    ldx CC_FOR_DIR
    beq .cc_for_cmp
    lda PM_OP_GE
.cc_for_cmp:
    jsr .cc_emit

    ; JPC exit
    lda PM_OP_JPC
    jsr .cc_emit
    jsr .cc_push_fixup

    ; Save for state for nested loops
    lda CC_FOR_VAR
    pha
    lda CC_FOR_LIMIT
    pha
    lda CC_FOR_DIR
    pha

    ; Parse body
    jsr .cc_parse_statement
    lda CC_ERROR
    bne .cc_for_cleanup

    ; Restore for state
    pla
    sta CC_FOR_DIR
    pla
    sta CC_FOR_LIMIT
    pla
    sta CC_FOR_VAR

    ; Increment/decrement loop var
    lda PM_OP_LOAD
    jsr .cc_emit
    lda CC_FOR_VAR
    jsr .cc_emit
    lda PM_OP_LIT16
    jsr .cc_emit
    lda 0x01
    jsr .cc_emit
    lda 0x00
    jsr .cc_emit

    lda PM_OP_ADD
    ldx CC_FOR_DIR
    beq .cc_for_upd
    lda PM_OP_SUB
.cc_for_upd:
    jsr .cc_emit
    lda PM_OP_STORE
    jsr .cc_emit
    lda CC_FOR_VAR
    jsr .cc_emit

    ; JMP loop top
    lda PM_OP_JMP
    jsr .cc_emit
    pla
    tay
    pla
    jsr .cc_emit
    tya
    jsr .cc_emit

    ; Patch JPC exit
    jsr .cc_pop_fixup_patch
    rts

.cc_for_cleanup:
    pla
    pla
    pla
    pla
    pla
.cc_for_done:
    rts
.cc_for_err:
    lda .cc_e_syntax
    jmp .cc_error_a
.cc_for_undef:
    lda .cc_e_undef
    jmp .cc_error_a

; ── Repeat: repeat stmts until expr ──────────────────────

.cc_parse_repeat:
    jsr .cc_next_token       ; consume 'repeat'

    ; Save loop top address
    lda CC_CODE_LO
    pha
    lda CC_CODE_HI
    pha

    ; Parse statements until 'until' keyword
.cc_rpt_loop:
    lda CC_ERROR
    bne .cc_rpt_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_UNTIL
    beq .cc_rpt_until
    jsr .cc_parse_statement
    lda CC_ERROR
    bne .cc_rpt_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_SEMI
    bne .cc_rpt_check_until
    jsr .cc_next_token       ; consume ';'
.cc_rpt_check_until:
    jmp .cc_rpt_loop

.cc_rpt_until:
    jsr .cc_next_token       ; consume 'until'
    jsr .cc_parse_expr_cond
    lda CC_ERROR
    bne .cc_rpt_done
    jsr .cc_ensure_int       ; FTOI if needed for JPC

    lda PM_OP_JPC
    jsr .cc_emit
    pla
    sta CC_TEMP2             ; loop_top high
    pla
    sta CC_TEMP1             ; loop_top low
    lda CC_TEMP1
    jsr .cc_emit
    lda CC_TEMP2
    jsr .cc_emit
    rts

.cc_rpt_done:
    pla
    pla
    rts

; ── Write/Writeln ────────────────────────────────────────

.cc_parse_write:
    lda 0x00                 ; no newline
    sta CC_TEMP1
    jmp .cc_write_common
.cc_parse_writeln:
    lda 0x01                 ; with newline
    sta CC_TEMP1

.cc_write_common:
    ; CC_TEMP1 = newline flag. Save on stack since cc_find_sym clobbers it.
    lda CC_TEMP1
    pha

    jsr .cc_next_token       ; consume write/writeln

    ; Check for '(' — arguments
    lda CC_TOKEN_TYPE
    cmp CC_TK_LPAREN
    bne .cc_write_bare

    jsr .cc_next_token       ; consume '('

.cc_write_args:
    lda CC_ERROR
    bne .cc_write_err_pop

    ; Check argument type: string literal, chr(expr), or expression
    lda CC_TOKEN_TYPE
    cmp CC_TK_STRING
    beq .cc_write_str
    cmp CC_TK_CHR
    beq .cc_write_chr
    cmp CC_TK_IDENT
    bne .cc_write_expr
    jsr .cc_find_sym
    bcs .cc_write_expr
    ; String var uses B15=2, same as real function return type — require scalar.
    lda CC_FOUND_KIND
    cmp CC_KIND_SCALAR
    bne .cc_write_expr_pop
    lda CC_FOUND_B15
    cmp 0x02
    bne .cc_write_expr_pop
    lda PM_OP_CSP
    jsr .cc_emit
    pla
    pha
    bne .cc_wstr_nl
    lda PM_CSP_WRITE_STR
    jmp .cc_wstr_emit
.cc_wstr_nl:
    lda PM_CSP_WRITELN_STR
.cc_wstr_emit:
    jsr .cc_emit
    lda CC_FOUND_B10
    jsr .cc_emit
    lda CC_FOUND_ARG1
    jsr .cc_emit
    jsr .cc_next_token
    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    beq .cc_write_str_cont
    pla                      ; balance pha from .cc_write_common
    jmp .cc_write_close
.cc_write_expr_pop:
    ; Not a string var: put ident token back — fall through to expression
.cc_write_expr:
    ; Expression (integer or real)
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_write_err_pop
    lda CC_EXPR_TYPE
    bne .cc_write_real_expr
    ; Integer expression
    lda PM_OP_CSP
    jsr .cc_emit
    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    beq .cc_write_int_cont
    pla
    bne .cc_write_int_nl
    lda PM_CSP_WRITE_INT
    jmp .cc_write_int_emit
.cc_write_int_nl:
    lda PM_CSP_WRITELN_INT
.cc_write_int_emit:
    jsr .cc_emit
    jmp .cc_write_close

.cc_write_int_cont:
    lda PM_CSP_WRITE_INT
    jsr .cc_emit
    jsr .cc_next_token       ; consume ','
    jmp .cc_write_args

.cc_write_real_expr:
    lda PM_OP_CSP
    jsr .cc_emit
    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    beq .cc_write_real_cont
    pla
    bne .cc_write_real_nl
    lda PM_CSP_WRITE_REAL
    jmp .cc_write_real_emit
.cc_write_real_nl:
    lda PM_CSP_WRITELN_REAL
.cc_write_real_emit:
    jsr .cc_emit
    jmp .cc_write_close
.cc_write_real_cont:
    lda PM_CSP_WRITE_REAL
    jsr .cc_emit
    jsr .cc_next_token       ; consume ','
    jmp .cc_write_args

.cc_write_str:
    ; String literal: add to string pool, emit LIT16 + CSP
    jsr .cc_add_string_token
    lda PM_OP_LIT16
    jsr .cc_emit
    ; cc_push_str_fixup already emits 2 placeholder bytes
    jsr .cc_push_str_fixup

    jsr .cc_next_token       ; consume string token

    lda PM_OP_CSP
    jsr .cc_emit

    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    beq .cc_write_str_cont
    ; Last arg — check newline flag on stack
    pla
    bne .cc_write_str_nl
    lda PM_CSP_WRITE
    jmp .cc_write_str_emit
.cc_write_str_nl:
    lda PM_CSP_WRITELN
.cc_write_str_emit:
    jsr .cc_emit
    jmp .cc_write_close

.cc_write_str_cont:
    lda PM_CSP_WRITE
    jsr .cc_emit
    jsr .cc_next_token       ; consume ','
    jmp .cc_write_args

.cc_write_chr:
    ; chr(expr) as write argument: emit expr + CSP_WRITE_CHAR
    jsr .cc_next_token       ; consume 'chr'
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_write_err_pop
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_write_err_pop
    lda CC_TK_RPAREN
    jsr .cc_expect

    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_WRITE_CHAR
    jsr .cc_emit

    ; Check if more args or end
    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    bne .cc_write_chr_last
    jsr .cc_next_token       ; consume ','
    jmp .cc_write_args
.cc_write_chr_last:
    ; Last arg: check newline flag
    pla
    beq .cc_write_close
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_WRITELN_NOARG
    jsr .cc_emit
    jmp .cc_write_close

.cc_write_close:
    lda CC_TK_RPAREN
    jsr .cc_expect
    rts

.cc_write_bare:
    ; writeln with no args → just emit newline
    pla                      ; get newline flag
    beq .cc_write_done       ; write() with no args: do nothing
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_WRITELN_NOARG
    jsr .cc_emit
    rts

.cc_write_err_pop:
    pla                      ; pop newline flag pushed at .cc_write_common
.cc_write_done:
    rts

; ── Readln ───────────────────────────────────────────────

.cc_parse_readln:
    jsr .cc_next_token       ; consume 'readln'
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_rdln_done

    ; Get variable
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_rdln_err
    jsr .cc_find_sym
    bcs .cc_rdln_undef
    sta CC_TEMP4             ; offset lo (CC_TEMP1 clobbered by lexer keyword scan)
    lda CC_FOUND_B15
    sta CC_TEMP2             ; var type
    lda CC_FOUND_ARG1
    sta CC_TEMP3             ; offset hi (for string readln)

    jsr .cc_next_token       ; consume ident

    lda CC_TEMP2
    beq .cc_rdln_int
    cmp 0x01
    beq .cc_rdln_real
    cmp 0x02
    beq .cc_rdln_str
    jmp .cc_rdln_err
.cc_rdln_int:
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_READLN_INT
    jsr .cc_emit
    lda PM_OP_STORE
    jsr .cc_emit
    lda CC_TEMP4
    jsr .cc_emit
    jmp .cc_rdln_close
.cc_rdln_str:
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_READLN_STR
    jsr .cc_emit
    lda CC_TEMP4
    jsr .cc_emit
    lda CC_TEMP3
    jsr .cc_emit
    jmp .cc_rdln_close
.cc_rdln_real:
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_READLN_REAL
    jsr .cc_emit
    lda PM_OP_FSTORE
    jsr .cc_emit
    lda CC_TEMP4
    jsr .cc_emit
.cc_rdln_close:
    lda CC_TK_RPAREN
    jsr .cc_expect
.cc_rdln_done:
    rts
.cc_rdln_err:
    lda .cc_e_syntax
    jmp .cc_error_a
.cc_rdln_undef:
    lda .cc_e_undef
    jmp .cc_error_a

; ── Poke: poke(page, addr, value) ────────────────────────

.cc_parse_poke:
    jsr .cc_next_token       ; consume 'poke'
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_poke_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression ; page
    lda CC_ERROR
    bne .cc_poke_done
    jsr .cc_ensure_int
    lda CC_TK_COMMA
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_poke_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression ; address
    lda CC_ERROR
    bne .cc_poke_done
    jsr .cc_ensure_int
    lda CC_TK_COMMA
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_poke_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression ; value
    lda CC_ERROR
    bne .cc_poke_done
    jsr .cc_ensure_int
    lda CC_TK_RPAREN
    jsr .cc_expect
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_POKE
    jsr .cc_emit
.cc_poke_done:
    rts

; ── delay(ms) ───────────────────────────────────────────

.cc_parse_delay:
    jsr .cc_next_token
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_del_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_del_done
    jsr .cc_ensure_int
    lda CC_TK_RPAREN
    jsr .cc_expect
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_WAIT_MS
    jsr .cc_emit
.cc_del_done:
    rts

; ── vt100(subcode) — subcode must be numeric literal ────

.cc_parse_vt100_kw:
    jsr .cc_next_token
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_vt_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_NUMBER
    bne .cc_vt_err
    lda CC_TOKEN_NUM_LO
    pha
    jsr .cc_next_token
    lda CC_TK_RPAREN
    jsr .cc_expect
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_VT100
    jsr .cc_emit
    pla
    jsr .cc_emit
.cc_vt_done:
    rts
.cc_vt_err:
    lda .cc_e_syntax
    jmp .cc_error_a

; ── vt100_pos(row, col) ─────────────────────────────────

.cc_parse_vt100_pos:
    jsr .cc_next_token
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_vp_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_vp_done
    jsr .cc_ensure_int
    lda CC_TK_COMMA
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_vp_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_vp_done
    jsr .cc_ensure_int
    lda CC_TK_RPAREN
    jsr .cc_expect
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_VT100
    jsr .cc_emit
    lda 0x02
    jsr .cc_emit
.cc_vp_done:
    rts

; ── vt100_scroll(top, bottom) ───────────────────────────

.cc_parse_vt100_scroll:
    jsr .cc_next_token
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_vs_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_vs_done
    jsr .cc_ensure_int
    lda CC_TK_COMMA
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_vs_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_vs_done
    jsr .cc_ensure_int
    lda CC_TK_RPAREN
    jsr .cc_expect
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_VT100
    jsr .cc_emit
    lda 0x20
    jsr .cc_emit
.cc_vs_done:
    rts

; ── Call arguments and CALL emission ────────────────────
; CC_FOUND_B10=code_lo, CC_FOUND_ARG1=code_hi,
; CC_FOUND_ARG2=param_count, CC_FOUND_ARG3=def_level.
; Identifier already consumed.

.cc_call_args:
    lda CC_FOUND_SYM_IDX
    sta CC_CALLEE_SYM_IDX
    lda CC_FOUND_ARG2
    sta CC_CALLEE_NPARAM
    lda 0x00
    sta CC_CALL_ARG_IDX
    ; Save callee info on stack (4 bytes: code_lo, code_hi, def_level, var_mask)
    lda CC_FOUND_B10
    pha
    lda CC_FOUND_ARG1
    pha
    lda CC_FOUND_ARG3
    pha
    lda CC_FOUND_B14         ; var param bitmask
    pha
    ; Parse arguments
    lda CC_TOKEN_TYPE
    cmp CC_TK_LPAREN
    beq .cc_ca_has_lparen
    pla                      ; pop var_mask (no parens, no args)
    jmp .cc_ca_no_args
.cc_ca_has_lparen:
    jsr .cc_next_token       ; consume '('
    lda CC_TOKEN_TYPE
    cmp CC_TK_RPAREN
    beq .cc_ca_close
.cc_ca_arg_loop:
    ; Check if current arg is a var param (test bit 0 of mask)
    pla                      ; get var_mask
    pha                      ; keep it on stack
    and 0x01
    beq .cc_ca_val_arg
    ; Var param: emit PUSH_ADDR for the argument variable
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_ca_var_err
    jsr .cc_find_sym
    bcs .cc_ca_var_err
    ; If the arg itself is a var param, emit LOAD (pass the pointer through)
    lda CC_FOUND_B14
    bne .cc_ca_var_pass_ref
    ; Regular variable: emit PUSH_ADDR
    lda CC_FOUND_B10         ; offset
    pha
    lda CC_SCOPE_LEVEL
    sec
    sbc CC_FOUND_SCOPE
    beq .cc_ca_push_local
    ; Non-local: PUSH_ADDR_L
    pha
    lda PM_OP_PUSH_ADDR_L
    jsr .cc_emit
    pla
    jsr .cc_emit             ; depth
    pla
    jsr .cc_emit             ; offset
    jmp .cc_ca_var_done
.cc_ca_push_local:
    lda PM_OP_PUSH_ADDR
    jsr .cc_emit
    pla
    jsr .cc_emit             ; offset
    jmp .cc_ca_var_done
.cc_ca_var_pass_ref:
    ; Arg is already a var param (holds an address) — just load the pointer value
    lda CC_FOUND_B10
    pha
    lda CC_SCOPE_LEVEL
    sec
    sbc CC_FOUND_SCOPE
    pha
    jsr .cc_next_token
    lda PM_OP_LOAD_L
    sta CC_TEMP2
    lda PM_OP_LOAD
    jmp .cc_ca_var_scoped
.cc_ca_var_scoped:
    ; Reuse cc_emit_scoped logic inline
    sta CC_TEMP1
    pla                      ; level_diff
    beq .cc_ca_vs_local
    pha
    lda CC_TEMP2
    jsr .cc_emit
    pla
    jsr .cc_emit
    pla
    jsr .cc_emit
    jmp .cc_ca_var_done2
.cc_ca_vs_local:
    lda CC_TEMP1
    jsr .cc_emit
    pla
    jsr .cc_emit
    jmp .cc_ca_var_done2
.cc_ca_var_done:
    jsr .cc_next_token       ; consume ident
.cc_ca_var_done2:
    lda CC_ERROR
    bne .cc_ca_vd2_nomask
    inc CC_CALL_ARG_IDX
.cc_ca_vd2_nomask:
    ; Shift mask right for next arg
    pla                      ; var_mask
    lsr a
    pha
    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    bne .cc_ca_close
    jsr .cc_next_token
    jmp .cc_ca_arg_loop

.cc_ca_var_err:
    lda .cc_e_syntax
    jmp .cc_error_a

.cc_ca_val_arg:
    jsr .cc_get_callee_param_type
    sta CC_TEMP3
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_ca_val_no_inc
    lda CC_TEMP3
    cmp 0x01                 ; formal real?
    bne .cc_ca_val_no_itof
    lda CC_EXPR_TYPE
    bne .cc_ca_val_no_itof
    lda PM_OP_ITOF
    jsr .cc_emit
    lda 0x01
    sta CC_EXPR_TYPE
.cc_ca_val_no_itof:
    inc CC_CALL_ARG_IDX
.cc_ca_val_no_inc:
    lda CC_ERROR
    bne .cc_ca_err
    ; Shift mask right for next arg
    pla                      ; var_mask
    lsr a
    pha
    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    bne .cc_ca_close
    jsr .cc_next_token
    jmp .cc_ca_arg_loop
.cc_ca_close:
    pla                      ; pop var_mask
    lda CC_TK_RPAREN
    jsr .cc_expect
.cc_ca_no_args:
    lda CC_ERROR
    bne .cc_ca_err
    ; Emit CALL addr_lo addr_hi static_depth
    lda PM_OP_CALL
    jsr .cc_emit
    pla                      ; def_level
    sta CC_TEMP1
    pla                      ; code_hi
    sta CC_TEMP2
    pla                      ; code_lo
    jsr .cc_emit
    lda CC_TEMP2
    jsr .cc_emit
    lda CC_SCOPE_LEVEL
    sec
    sbc CC_TEMP1
    jsr .cc_emit
    rts
.cc_ca_err:
    pla                      ; pop var_mask (or whatever is on top)
    pla
    pla
    pla
    rts

; ── Subroutine declarations ────────────────────────────

.cc_parse_subs:
    ; Parse zero or more procedure/function declarations.
    ; Emits JMP over all subroutine bodies if any found.
    lda CC_TOKEN_TYPE
    cmp CC_TK_PROCEDURE
    beq .cc_pss_has_subs
    cmp CC_TK_FUNCTION
    beq .cc_pss_has_subs
    rts

.cc_pss_has_subs:
    ; Emit JMP to skip over subroutine code
    lda PM_OP_JMP
    jsr .cc_emit
    jsr .cc_push_fixup       ; save JMP target for patching

.cc_pss_loop:
    lda CC_TOKEN_TYPE
    cmp CC_TK_PROCEDURE
    beq .cc_pss_parse
    cmp CC_TK_FUNCTION
    beq .cc_pss_parse
    ; No more subs — patch JMP to land here
    jsr .cc_pop_fixup_patch
    rts

.cc_pss_parse:
    jsr .cc_parse_sub
    lda CC_ERROR
    bne .cc_pss_err
    jmp .cc_pss_loop
.cc_pss_err:
    jsr .cc_pop_fixup_patch
    rts

.cc_parse_sub:
    lda CC_TOKEN_TYPE
    cmp CC_TK_FUNCTION
    beq .cc_sub_func

    ; Procedure
    lda CC_KIND_PROC
    sta CC_FOUND_KIND
    lda 0x00
    sta CC_IS_FUNC
    sta CC_FUNC_RET
    jmp .cc_sub_common

.cc_sub_func:
    lda CC_KIND_FUNC
    sta CC_FOUND_KIND
    lda 0x01
    sta CC_IS_FUNC           ; default int func; patched after seeing ': real'
    lda 0x00
    sta CC_FUNC_RET          ; default int return

.cc_sub_common:
    ; Save compiler state on stack
    lda CC_SYM_COUNT
    pha
    lda CC_FRAME_OFF
    pha
    lda CC_FRAME_OFF_HI
    pha
    lda CC_ENTER_LO
    pha
    lda CC_ENTER_HI
    pha
    lda CC_FUNC_RET
    pha                      ; save outer CC_FUNC_RET

    jsr .cc_next_token       ; consume 'procedure'/'function'

    ; Expect name
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_sub_err

    ; Register subroutine in symbol table (code_addr = current CC_CODE)
    jsr .cc_add_sub          ; adds with current CC_CODE position
    ; Save symbol index for patching param_count later
    lda CC_SYM_COUNT
    sec
    sbc 0x01
    sta CC_SAVED_SYMCNT

    ; Enter new scope
    inc CC_SCOPE_LEVEL

    ; Frame offset: 2 for proc, 4 for int func, set later for real func
    lda CC_IS_FUNC
    beq .cc_sub_frame_proc
    lda 0x04                 ; 2 static link + 2 int return value
    jmp .cc_sub_frame_set
.cc_sub_frame_proc:
    lda 0x02                 ; 2 static link only
.cc_sub_frame_set:
    sta CC_FRAME_OFF
    lda 0x00
    sta CC_FRAME_OFF_HI

    jsr .cc_next_token       ; consume name

    ; Parse parameters: (a: integer; var b: integer)
    lda 0x00
    sta CC_FOUND_ARG2        ; param counter
    sta CC_FOUND_B14         ; var param bitmask accumulator
    sta CC_PARAM_TYPE_MASK   ; param type bitmask (bit N=1 → real)
    lda CC_TOKEN_TYPE
    cmp CC_TK_LPAREN
    bne .cc_sub_no_params
    jsr .cc_next_token       ; consume '('
.cc_sub_param_loop:
    lda CC_TOKEN_TYPE
    cmp CC_TK_RPAREN
    beq .cc_sub_params_done
    cmp CC_TK_VAR
    bne .cc_sub_param_novar
    lda 0x01
    sta CC_PARAM_VAR
    jsr .cc_next_token       ; consume 'var'
.cc_sub_param_novar:
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_sub_err
    ; Collect one or more comma-separated idents into CC_PARAM_NAME_TMP slots
    lda 0x00
    sta CC_PARAM_NAME_CNT
.cc_spa_collect:
    ; Save current ident name to slot [CC_PARAM_NAME_CNT * 8]
    lda CC_PARAM_NAME_CNT
    asl a
    asl a
    asl a                    ; A = slot * 8
    tax
    ldy 0x00
.cc_spa_save:
    lda CC_TOKEN_BUF,y
    sta CC_PARAM_NAME_TMP,x
    inx
    iny
    cpy 0x08
    bne .cc_spa_save
    inc CC_PARAM_NAME_CNT
    jsr .cc_next_token       ; consume ident
    lda CC_TOKEN_TYPE
    cmp CC_TK_COMMA
    bne .cc_spa_colon
    jsr .cc_next_token       ; consume ','
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_sub_err
    jmp .cc_spa_collect
.cc_spa_colon:
    lda CC_TK_COLON
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_sub_param_skip
    lda CC_TOKEN_TYPE
    cmp CC_TK_INTEGER
    beq .cc_spa_t_int
    cmp CC_TK_REAL
    beq .cc_spa_t_real
    cmp CC_TK_STRING_TYPE
    beq .cc_spa_t_str
    jmp .cc_sub_err
.cc_spa_t_int:
    lda 0x00
    sta CC_VAR_TYPE
    jmp .cc_spa_type_consume
.cc_spa_t_real:
    lda 0x01
    sta CC_VAR_TYPE
    jmp .cc_spa_type_consume
.cc_spa_t_str:
    lda 0x02
    sta CC_VAR_TYPE
.cc_spa_type_consume:
    jsr .cc_next_token       ; consume type keyword
    ; Replay each saved name: restore to CC_TOKEN_BUF, set bitmask, cc_add_var
    lda 0x00
    sta CC_TEMP1             ; replay index
.cc_spa_replay:
    ; Build var param bitmask for this param
    lda CC_PARAM_VAR
    beq .cc_spa_no_bit
    lda 0x01
    ldx CC_FOUND_ARG2
    beq .cc_spa_bit_done
.cc_spa_bit_shift:
    asl a
    dex
    bne .cc_spa_bit_shift
.cc_spa_bit_done:
    ora CC_FOUND_B14
    sta CC_FOUND_B14
.cc_spa_no_bit:
    ; Build param type bitmask (bit N=1 if param N is real)
    lda CC_VAR_TYPE
    cmp 0x01
    bne .cc_spa_no_tbit
    lda 0x01
    ldx CC_FOUND_ARG2
    beq .cc_spa_tbit_done
.cc_spa_tbit_shift:
    asl a
    dex
    bne .cc_spa_tbit_shift
.cc_spa_tbit_done:
    ora CC_PARAM_TYPE_MASK
    sta CC_PARAM_TYPE_MASK
.cc_spa_no_tbit:
    ; Restore name from slot [CC_TEMP1 * 8]
    lda CC_TEMP1
    asl a
    asl a
    asl a
    tax
    ldy 0x00
.cc_spa_rest:
    lda CC_PARAM_NAME_TMP,x
    sta CC_TOKEN_BUF,y
    inx
    iny
    cpy 0x08
    bne .cc_spa_rest
    jsr .cc_add_var
    inc CC_FOUND_ARG2
    inc CC_TEMP1
    lda CC_TEMP1
    cmp CC_PARAM_NAME_CNT
    bne .cc_spa_replay
    jmp .cc_sub_param_skip
    ; Skip separators (;/,) until next param or ')'
.cc_sub_param_skip:
    lda CC_ERROR
    bne .cc_sub_restore
    lda CC_TOKEN_TYPE
    cmp CC_TK_RPAREN
    beq .cc_sub_params_done
    cmp CC_TK_VAR
    bne .cc_sub_ps_no_var
    lda 0x01
    sta CC_PARAM_VAR         ; next param group is var
    jsr .cc_next_token       ; consume 'var'
    jmp .cc_sub_param_skip
.cc_sub_ps_no_var:
    cmp CC_TK_IDENT
    beq .cc_sub_param_loop
    cmp CC_TK_SEMI
    bne .cc_sub_ps_no_semi
    lda 0x00
    sta CC_PARAM_VAR         ; reset var flag for next param group
.cc_sub_ps_no_semi:
    jsr .cc_next_token
    jmp .cc_sub_param_skip
.cc_sub_params_done:
    lda 0x00
    sta CC_PARAM_VAR         ; reset var flag
    lda CC_TK_RPAREN
    jsr .cc_expect
.cc_sub_no_params:
    lda CC_SAVED_SYMCNT
    jsr .cc_patch_sub_params

    ; For functions, expect ': integer' or ': real'
    lda CC_IS_FUNC
    beq .cc_sub_expect_semi
    lda CC_TK_COLON
    jsr .cc_expect
    lda CC_TOKEN_TYPE
    cmp CC_TK_REAL
    bne .cc_sub_ret_int
    ; Real return type
    lda 0x02
    sta CC_IS_FUNC           ; 2 = real function
    sta CC_FUNC_RET
    ; Adjust frame: need 6 bytes (2 static + 4 real return) instead of 4
    ; Add 2 more to frame offset, and adjust all param offsets
    lda CC_FRAME_OFF
    clc
    adc 0x02
    sta CC_FRAME_OFF
    lda CC_FRAME_OFF_HI
    adc 0x00
    sta CC_FRAME_OFF_HI
    ; Patch the symbol table entry byte 15 for this function
    lda CC_SAVED_SYMCNT
    jsr .cc_sym_addr
    ldx 0x0F
    lda 0x02
    sta yde,x                ; byte 15 = 2 (real return)
    ; Also need to shift all param offsets by +2
    jsr .cc_shift_param_offsets
    jsr .cc_next_token       ; consume 'real'
    jmp .cc_sub_expect_semi
.cc_sub_ret_int:
    lda CC_TK_INTEGER
    jsr .cc_expect
.cc_sub_expect_semi:
    lda CC_TK_SEMI
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_sub_restore

    ; Parse optional local const block
    lda CC_TOKEN_TYPE
    cmp CC_TK_CONST
    bne .cc_sub_no_lconst
    jsr .cc_parse_const
.cc_sub_no_lconst:

    ; Parse optional local var block
    lda CC_TOKEN_TYPE
    cmp CC_TK_VAR
    bne .cc_sub_no_lvar
    jsr .cc_parse_var
.cc_sub_no_lvar:

    ; Emit ENTER16
    lda PM_OP_ENTER16
    jsr .cc_emit
    lda CC_CODE_LO
    sta CC_ENTER_LO
    lda CC_CODE_HI
    sta CC_ENTER_HI
    lda 0x00
    jsr .cc_emit             ; frame_size lo placeholder
    lda 0x00
    jsr .cc_emit             ; frame_size hi placeholder
    jsr .cc_count_enter_slots ; nparams = 16-bit stack slots (real uses 2)
    jsr .cc_emit
    lda CC_IS_FUNC
    jsr .cc_emit             ; is_function

    ; Parse nested subroutines (recursive)
    jsr .cc_parse_subs

    ; Parse body: begin..end;
    lda CC_TK_BEGIN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_sub_restore
    jsr .cc_parse_block

    ; Emit RET
    lda PM_OP_RET
    jsr .cc_emit
    lda CC_IS_FUNC
    jsr .cc_emit

    jsr .cc_patch_enter

    lda CC_TK_SEMI
    jsr .cc_expect

.cc_sub_restore:
    dec CC_SCOPE_LEVEL
    pla
    sta CC_FUNC_RET          ; restore outer CC_FUNC_RET
    pla
    sta CC_ENTER_HI
    pla
    sta CC_ENTER_LO
    pla
    sta CC_FRAME_OFF_HI
    pla
    sta CC_FRAME_OFF
    pla
    sta CC_SYM_COUNT
    inc CC_SYM_COUNT

    lda 0x00
    sta CC_IS_FUNC
    rts

.cc_sub_err:
    lda .cc_e_syntax
    jmp .cc_error_a

; ── Expression parser (relational level) ─────────────────

; Clear string-compare pass (0 = normal expr; 1 = cond; 2 = RHS of str rel).
.cc_str_rel_clear:
    lda 0x00
    sta CC_STR_REL_PASS
    rts

; Normal expression (assignments, args, etc.): string vars not allowed as factors.
.cc_parse_expression:
    jmp .cc_pe_shared

; Boolean condition (if / while / until): allow s = 'x' string compare (not in parens).
.cc_parse_expr_cond:
    lda 0x01
    sta CC_STR_REL_PASS

.cc_pe_shared:
    lda CC_ERROR
    bne .cc_expr_done
    jsr .cc_parse_simple_expr
    lda CC_ERROR
    bne .cc_expr_done
    jsr .cc_str_rel_clear

    ; Check for relational operator
    lda CC_TOKEN_TYPE
    cmp CC_TK_EQ
    beq .cc_expr_rel
    cmp CC_TK_NE
    beq .cc_expr_rel
    cmp CC_TK_LT
    beq .cc_expr_rel
    cmp CC_TK_GT
    beq .cc_expr_rel
    cmp CC_TK_LE
    beq .cc_expr_rel
    cmp CC_TK_GE
    beq .cc_expr_rel
    rts

.cc_expr_rel:
    lda CC_EXPR_TYPE
    cmp 0x02                 ; string from factor (var or literal)
    bne .cc_expr_rel_non_str
    lda CC_TOKEN_TYPE
    sta CC_SREL_OP           ; EQ or NE
    jsr .cc_next_token       ; consume operator
    lda CC_EXPR_TYPE
    cmp 0x02
    bne .cc_esr_type_err2
    lda CC_TOKEN_TYPE
    cmp CC_TK_STRING
    beq .cc_esr_rhs_lit_common
    cmp CC_TK_IDENT
    bne .cc_esr_type_err2
    jsr .cc_find_sym
    bcs .cc_esr_undef
    lda CC_FOUND_B15
    cmp 0x02
    bne .cc_esr_type_err2
    lda CC_FOUND_B10
    sta CC_SREL_O1_LO
    lda CC_FOUND_ARG1
    sta CC_SREL_O1_HI
    jsr .cc_next_token
    jmp .cc_expr_str_rel_after_rhs

.cc_esr_rhs_lit_common:
    jsr .cc_alloc_str_temp
    lda CC_ERROR
    bne .cc_esr_alloc_err
    lda CC_TEMP1
    sta CC_STR_EQ_TMP_LO
    lda CC_TEMP2
    sta CC_STR_EQ_TMP_HI
    jsr .cc_add_string_token
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_STR_ASSIGN_LIT
    jsr .cc_emit
    lda CC_TEMP1
    jsr .cc_emit
    lda CC_TEMP2
    jsr .cc_emit
    jsr .cc_push_str_fixup
    jsr .cc_next_token
    lda CC_TEMP1
    sta CC_SREL_O2_LO
    lda CC_TEMP2
    sta CC_SREL_O2_HI
    jmp .cc_expr_str_rel_after_rhs

.cc_esr_undef:
    lda .cc_e_undef
    jmp .cc_error_a
.cc_esr_alloc_err:
    lda .cc_e_syntax
    jmp .cc_error_a
.cc_esr_type_err2:
    lda .cc_e_expr
    jmp .cc_error_a
.cc_expr_rel_non_str:
    lda CC_EXPR_TYPE
    pha                      ; save left type
    lda CC_TOKEN_TYPE
    pha                      ; save operator
    jsr .cc_next_token       ; consume operator
    jsr .cc_str_rel_clear    ; RHS of int/real rel is never string-compare mode
    jsr .cc_parse_simple_expr
    pla                      ; operator
    sta CC_TEMP3
    lda CC_ERROR
    bne .cc_expr_rel_pop1

    lda CC_EXPR_TYPE
    cmp 0x02                 ; string on RHS without string LHS
    beq .cc_expr_rel_str_mix
    pla                      ; left type → A
    cmp CC_EXPR_TYPE
    bne .cc_expr_fcmp_mixed
    cmp 0x01
    beq .cc_expr_fcmp        ; both real
    jmp .cc_expr_int_cmp     ; both int

; ── String relational (= or <> only), STR_EQ + optional NOT ─
; Entry: operator on stack (pha), RHS parsed, CC_SREL_O1 from left, O2 from right.

.cc_expr_str_rel_after_rhs:
    lda CC_ERROR
    bne .cc_esr_err_op
    lda CC_SREL_OP
    cmp CC_TK_EQ
    beq .cc_esr_op_ok
    cmp CC_TK_NE
    beq .cc_esr_op_ok
    lda .cc_e_expr
    jmp .cc_error_a
.cc_esr_err_op:
    lda .cc_e_expr
    jmp .cc_error_a
.cc_esr_op_ok:
    lda CC_EXPR_TYPE
    cmp 0x02
    bne .cc_esr_type_err
    lda CC_STR_EQ_TMP_LO
    sta CC_SREL_O2_LO
    lda CC_STR_EQ_TMP_HI
    sta CC_SREL_O2_HI
    ; cc_emit uses PHA — cannot stash operands on CPU stack
    lda CC_SREL_O1_LO
    sta CC_TEMP3
    lda CC_SREL_O1_HI
    sta CC_TEMP4
    lda CC_SREL_O2_LO
    sta CC_SREL_EMIT_LO
    lda CC_SREL_O2_HI
    sta CC_SREL_EMIT_HI
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_STR_EQ
    jsr .cc_emit
    lda CC_TEMP3
    jsr .cc_emit
    lda CC_TEMP4
    jsr .cc_emit
    lda CC_SREL_EMIT_LO
    jsr .cc_emit
    lda CC_SREL_EMIT_HI
    jsr .cc_emit
    lda CC_SREL_OP
    cmp CC_TK_NE
    bne .cc_esr_not_done
    lda PM_OP_NOT
    jsr .cc_emit
.cc_esr_not_done:
    lda 0x00
    sta CC_EXPR_TYPE
    jsr .cc_str_rel_clear
    rts
.cc_esr_type_err:
    lda .cc_e_expr
    jmp .cc_error_a
.cc_esr_pop_op:
    jmp .cc_expr_done

.cc_expr_fcmp_mixed:
    jsr .cc_coerce_binop     ; make both real
.cc_expr_fcmp:
    lda PM_OP_FCMP
    jsr .cc_emit
    lda PM_OP_LIT16
    jsr .cc_emit
    lda 0x00
    jsr .cc_emit
    lda 0x00
    jsr .cc_emit
    ; FCMP result is integer, compared with 0

.cc_expr_int_cmp:
    lda CC_TEMP3
    sec
    sbc CC_TK_EQ
    tax
    ; 24-bit table base (IDE in expansion RAM); plain LDA label,x can miss page 0x02.
    ldy .cc_relop_table[23:16]
    ldd .cc_relop_table[15:8]
    lde .cc_relop_table[7:0]
    lda yde,x
    jsr .cc_emit
    lda 0x00
    sta CC_EXPR_TYPE         ; comparisons always produce integer
    rts

.cc_expr_rel_pop1:
    pla
.cc_expr_done:
    rts

.cc_expr_rel_str_mix:
    pla                      ; drop saved left type
    lda .cc_e_expr
    jmp .cc_error_a

.cc_relop_table:
    ; P-code opcodes for EQ..GE (see .cc_expr_int_cmp: index = CC_TEMP3 - CC_TK_EQ).
    ; Explicit bytes (#d PM_OP_* does not emit const values reliably in customasm).
    #d 0x0D
    #d 0x0E
    #d 0x0F
    #d 0x12
    #d 0x13
    #d 0x11

; Pad so the next routine is 16-byte aligned (required when this file is the
; first bank at 0x020000; kernel at 0x0200 happened to satisfy alignment).
#align 128

; ── Simple expression (+, -, or) ─────────────────────────

.cc_parse_simple_expr:
    lda CC_ERROR
    bne .cc_se_done

    lda CC_TOKEN_TYPE
    cmp CC_TK_MINUS
    beq .cc_se_neg
    cmp CC_TK_PLUS
    beq .cc_se_pos

    jsr .cc_parse_term
    jmp .cc_se_loop

.cc_se_neg:
    jsr .cc_next_token       ; consume '-'
    jsr .cc_parse_term
    lda CC_ERROR
    bne .cc_se_done
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    lda CC_EXPR_TYPE
    bne .cc_se_fneg
    lda PM_OP_NEG
    jsr .cc_emit
    jmp .cc_se_loop
.cc_se_fneg:
    lda PM_OP_FNEG
    jsr .cc_emit
    jmp .cc_se_loop

.cc_se_pos:
    jsr .cc_next_token       ; consume '+'
    jsr .cc_parse_term

.cc_se_loop:
    lda CC_ERROR
    bne .cc_se_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_PLUS
    beq .cc_se_add
    cmp CC_TK_MINUS
    beq .cc_se_sub
    cmp CC_TK_OR
    beq .cc_se_or
    rts

.cc_se_add:
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    pha                      ; save left type
    jsr .cc_next_token
    jsr .cc_parse_term
    lda CC_ERROR
    bne .cc_se_pop_done
    pla                      ; left type
    jsr .cc_coerce_binop
    lda CC_EXPR_TYPE
    bne .cc_se_fadd
    lda PM_OP_ADD
    jsr .cc_emit
    jmp .cc_se_loop
.cc_se_fadd:
    lda PM_OP_FADD
    jsr .cc_emit
    jmp .cc_se_loop

.cc_se_sub:
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    pha
    jsr .cc_next_token
    jsr .cc_parse_term
    lda CC_ERROR
    bne .cc_se_pop_done
    pla
    jsr .cc_coerce_binop
    lda CC_EXPR_TYPE
    bne .cc_se_fsub
    lda PM_OP_SUB
    jsr .cc_emit
    jmp .cc_se_loop
.cc_se_fsub:
    lda PM_OP_FSUB
    jsr .cc_emit
    jmp .cc_se_loop

.cc_se_or:
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    jsr .cc_ensure_int       ; left → int before parsing right
    jsr .cc_next_token
    jsr .cc_parse_term
    lda CC_ERROR
    bne .cc_se_done
    jsr .cc_ensure_int       ; right → int
    lda PM_OP_OR
    jsr .cc_emit
    jmp .cc_se_loop

.cc_se_pop_done:
    pla
.cc_se_done:
    rts

.cc_se_str_op_err:
    lda .cc_e_expr
    jmp .cc_error_a

; ── Term (*, /, div, mod, and) ───────────────────────────

.cc_parse_term:
    lda CC_ERROR
    bne .cc_tm_done
    jsr .cc_parse_factor

.cc_tm_loop:
    lda CC_ERROR
    bne .cc_tm_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_STAR
    beq .cc_tm_mul
    cmp CC_TK_SLASH
    beq .cc_tm_slash
    cmp CC_TK_DIV
    beq .cc_tm_div
    cmp CC_TK_MOD
    beq .cc_tm_mod
    cmp CC_TK_AND
    beq .cc_tm_and
    rts

.cc_tm_mul:
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    pha
    jsr .cc_next_token
    jsr .cc_parse_factor
    lda CC_ERROR
    bne .cc_tm_pop_done
    pla
    jsr .cc_coerce_binop
    lda CC_EXPR_TYPE
    bne .cc_tm_fmul
    lda PM_OP_MUL
    jsr .cc_emit
    jmp .cc_tm_loop
.cc_tm_fmul:
    lda PM_OP_FMUL
    jsr .cc_emit
    jmp .cc_tm_loop

.cc_tm_slash:
    ; '/' always produces real result
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    pha
    jsr .cc_next_token
    jsr .cc_parse_factor
    lda CC_ERROR
    bne .cc_tm_pop_done
    pla
    jsr .cc_coerce_both_real
    lda PM_OP_FDIV
    jsr .cc_emit
    lda 0x01
    sta CC_EXPR_TYPE
    jmp .cc_tm_loop

.cc_tm_div:
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    jsr .cc_ensure_int       ; left → int
    jsr .cc_next_token
    jsr .cc_parse_factor
    lda CC_ERROR
    bne .cc_tm_done
    jsr .cc_ensure_int       ; right → int
    lda PM_OP_DIV
    jsr .cc_emit
    jmp .cc_tm_loop

.cc_tm_mod:
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    jsr .cc_ensure_int
    jsr .cc_next_token
    jsr .cc_parse_factor
    lda CC_ERROR
    bne .cc_tm_done
    jsr .cc_ensure_int
    lda PM_OP_MOD
    jsr .cc_emit
    jmp .cc_tm_loop

.cc_tm_and:
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_se_str_op_err
    jsr .cc_ensure_int
    jsr .cc_next_token
    jsr .cc_parse_factor
    lda CC_ERROR
    bne .cc_tm_done
    jsr .cc_ensure_int
    lda PM_OP_AND
    jsr .cc_emit
    jmp .cc_tm_loop

.cc_tm_pop_done:
    pla
.cc_tm_done:
    rts

; ── Factor ───────────────────────────────────────────────

.cc_parse_factor:
    lda CC_ERROR
    bne .cc_fc_done
    lda CC_TOKEN_TYPE

    cmp CC_TK_NUMBER
    beq .cc_fc_number
    cmp CC_TK_FLOAT_LIT
    beq .cc_fc_float
    cmp CC_TK_IDENT
    beq .cc_fc_ident
    cmp CC_TK_LPAREN
    beq .cc_fc_paren
    cmp CC_TK_NOT
    beq .cc_fc_not
    cmp CC_TK_ORD
    beq .cc_fc_ord
    cmp CC_TK_CHR
    beq .cc_fc_chr
    cmp CC_TK_ABS
    beq .cc_fc_abs
    cmp CC_TK_ODD
    beq .cc_fc_odd
    cmp CC_TK_RANDOM
    beq .cc_fc_random
    cmp CC_TK_PEEK
    beq .cc_fc_peek
    cmp CC_TK_LENGTH
    beq .cc_fc_length
    cmp CC_TK_STRING
    beq .cc_fc_string

    ; Unexpected token
    lda .cc_e_expr
    jmp .cc_error_a

.cc_fc_number:
    lda PM_OP_LIT16
    jsr .cc_emit
    lda CC_TOKEN_NUM_LO
    jsr .cc_emit
    lda CC_TOKEN_NUM_HI
    jsr .cc_emit
    lda 0x00
    sta CC_EXPR_TYPE         ; integer
    jsr .cc_next_token
    rts

.cc_fc_float:
    ; Emit FLIT + 4 bytes from FLOAT1 (set by lexer)
    lda PM_OP_FLIT
    jsr .cc_emit
    lda FLOAT1
    jsr .cc_emit
    lda FLOAT1+1
    jsr .cc_emit
    lda FLOAT1+2
    jsr .cc_emit
    lda FLOAT1+3
    jsr .cc_emit
    lda 0x01
    sta CC_EXPR_TYPE         ; real
    jsr .cc_next_token
    rts

.cc_fc_str_err:
    lda .cc_e_expr
    jmp .cc_error_a

; String variable as factor: only in if/while/until (CC_STR_REL_PASS 1 or 2).
.cc_fc_str_scalar_var:
    lda CC_STR_REL_PASS
    cmp 0x01
    beq .fssv_o1
    cmp 0x02
    beq .fssv_o2
    jmp .cc_fc_str_err
.fssv_o1:
    lda CC_FOUND_B10
    sta CC_SREL_O1_LO
    lda CC_FOUND_ARG1
    sta CC_SREL_O1_HI
    jmp .fssv_done
.fssv_o2:
    lda CC_FOUND_B10
    sta CC_SREL_O2_LO
    lda CC_FOUND_ARG1
    sta CC_SREL_O2_HI
.fssv_done:
    lda 0x02
    sta CC_EXPR_TYPE
    jsr .cc_next_token
    rts

.cc_fc_string:
    lda CC_STR_REL_PASS
    cmp 0x01
    beq .cfs_ok
    cmp 0x02
    beq .cfs_ok
    jmp .cc_fc_str_err
.cfs_ok:
    jsr .cc_alloc_str_temp
    lda CC_ERROR
    bne .cfs_done
    jsr .cc_add_string_token
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_STR_ASSIGN_LIT
    jsr .cc_emit
    lda CC_TEMP1
    jsr .cc_emit
    lda CC_TEMP2
    jsr .cc_emit
    jsr .cc_push_str_fixup
    jsr .cc_next_token       ; consume string token
    ; Operand slot comes from CC_STR_REL_PASS (1=left, 2=right).
    lda CC_STR_REL_PASS
    cmp 0x02
    beq .cfs_lit_o2
    lda CC_TEMP1
    sta CC_SREL_O1_LO
    lda CC_TEMP2
    sta CC_SREL_O1_HI
    jmp .cfs_done2
.cfs_lit_o2:
    lda CC_TEMP1
    sta CC_SREL_O2_LO
    lda CC_TEMP2
    sta CC_SREL_O2_HI
.cfs_done2:
    lda 0x02
    sta CC_EXPR_TYPE
.cfs_done:
    rts

; Reserve STRING_SIZE (0x51) bytes in frame; return old offset in CC_TEMP1/2.
.cc_alloc_str_temp:
    lda CC_FRAME_OFF
    sta CC_TEMP1
    lda CC_FRAME_OFF_HI
    sta CC_TEMP2
    lda CC_FRAME_OFF
    clc
    adc 0x51
    sta CC_FRAME_OFF
    lda CC_FRAME_OFF_HI
    adc 0x00
    sta CC_FRAME_OFF_HI
    rts

.cc_fc_length:
    jsr .cc_next_token
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_fc_done
    lda CC_TOKEN_TYPE
    cmp CC_TK_IDENT
    bne .cc_fc_str_err
    jsr .cc_find_sym
    bcs .cc_fc_undef
    lda CC_FOUND_B15
    cmp 0x02
    bne .cc_fc_str_err
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_LENGTH
    jsr .cc_emit
    lda CC_FOUND_B10
    jsr .cc_emit
    lda CC_FOUND_ARG1
    jsr .cc_emit
    jsr .cc_next_token
    lda CC_TK_RPAREN
    jsr .cc_expect
    lda 0x00
    sta CC_EXPR_TYPE
    rts

.cc_fc_ident:
    jsr .cc_find_sym
    bcs .cc_fc_undef
    lda CC_FOUND_KIND
    cmp CC_KIND_CONST
    beq .cc_fc_const
    cmp CC_KIND_FUNC
    beq .cc_fc_func_call
    cmp CC_KIND_ARRAY
    beq .cc_fc_arr
    lda CC_FOUND_B15
    cmp 0x02
    beq .cc_fc_str_scalar_var
    ; Check if var param (byte 14)
    lda CC_FOUND_B14
    bne .cc_fc_var_param
    lda CC_FOUND_B15
    sta CC_EXPR_TYPE         ; set expression type from variable type
    lda CC_FOUND_ARG1
    sta CC_ES_ARG1_SAVE      ; preserve offset hi for .cc_emit_scoped
    lda CC_FOUND_B10         ; offset
    pha
    lda CC_SCOPE_LEVEL
    sec
    sbc CC_FOUND_SCOPE
    pha
    jsr .cc_next_token       ; consume ident
    lda CC_EXPR_TYPE
    bne .cc_fc_real_var
    lda PM_OP_LOAD_L
    sta CC_TEMP2
    lda PM_OP_LOAD
    jmp .cc_emit_scoped
.cc_fc_real_var:
    lda PM_OP_FLOAD_L
    sta CC_TEMP2
    lda PM_OP_FLOAD
    jmp .cc_emit_scoped
.cc_fc_var_param:
    lda 0x00
    sta CC_EXPR_TYPE         ; var params are always integer
    lda CC_FOUND_ARG1
    sta CC_ES_ARG1_SAVE      ; preserve offset hi for .cc_emit_scoped
    lda CC_FOUND_B10         ; offset
    pha
    lda CC_SCOPE_LEVEL
    sec
    sbc CC_FOUND_SCOPE
    pha
    jsr .cc_next_token       ; consume ident
    pla                      ; level_diff
    beq .cc_fc_vp_local
    pha
    lda PM_OP_LOAD_L
    sta CC_TEMP2
    lda PM_OP_LOAD_REF
    jmp .cc_emit_scoped
.cc_fc_vp_local:
    lda PM_OP_LOAD_REF
    jsr .cc_emit
    pla                      ; offset
    jsr .cc_emit
    rts
.cc_fc_const:
    lda PM_OP_LIT16
    jsr .cc_emit
    lda CC_FOUND_B10         ; value low (byte 10)
    jsr .cc_emit
    lda CC_FOUND_ARG1        ; value high (byte 11)
    jsr .cc_emit
    lda 0x00
    sta CC_EXPR_TYPE         ; constants are always integer
    jsr .cc_next_token
    rts
.cc_fc_func_call:
    ; CC_FOUND_B15 has return type (0=int, 2=real)
    ; Save return type on stack — cc_call_args overwrites CC_EXPR_TYPE
    lda CC_FOUND_B15
    pha
    jsr .cc_next_token       ; consume identifier
    jsr .cc_call_args
    pla                      ; return type (0=int, 2=real)
    beq .cc_fc_func_int_ret
    lda 0x01
    sta CC_EXPR_TYPE         ; real function
    rts
.cc_fc_func_int_ret:
    lda 0x00
    sta CC_EXPR_TYPE         ; integer function
    rts
.cc_fc_arr:
    lda 0x00
    sta CC_EXPR_TYPE         ; arrays are always integer
    lda CC_FOUND_ARG1
    sta CC_ES_ARG1_SAVE      ; preserve offset hi for .cc_emit_scoped
    lda CC_FOUND_B10         ; adjusted_base
    pha
    lda CC_SCOPE_LEVEL
    sec
    sbc CC_FOUND_SCOPE
    pha
    jsr .cc_next_token       ; consume ident
    lda CC_TK_LBRACKET
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_fc_arr_err
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression ; index
    lda CC_ERROR
    bne .cc_fc_arr_err
    lda CC_TK_RBRACKET
    jsr .cc_expect
    lda PM_OP_LOAD_AL
    sta CC_TEMP2
    lda PM_OP_LOAD_A
    jmp .cc_emit_scoped
.cc_fc_arr_err:
    pla
    pla
    rts
.cc_fc_undef:
    lda .cc_e_undef
    jmp .cc_error_a

.cc_fc_paren:
    jsr .cc_next_token       ; consume '('
    lda CC_STR_REL_PASS
    pha
    jsr .cc_pe_shared        ; full cond expr inside parens
    pla
    sta CC_STR_REL_PASS
    lda CC_ERROR
    bne .cc_fc_done
    lda CC_TK_RPAREN
    jsr .cc_expect
    rts

.cc_fc_ord:
    jsr .cc_next_token       ; consume 'ord'
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_fc_done
    ; Expect a single-char string literal
    lda CC_TOKEN_TYPE
    cmp CC_TK_STRING
    bne .cc_fc_ord_expr
    lda CC_TOKEN_LEN
    cmp 0x01
    bne .cc_fc_ord_expr
    ; Single char: emit LIT16 with ASCII value
    lda PM_OP_LIT16
    jsr .cc_emit
    lda CC_TOKEN_BUF         ; first byte = ASCII value
    jsr .cc_emit
    lda 0x00
    jsr .cc_emit
    jsr .cc_next_token       ; consume string
    lda CC_TK_RPAREN
    jsr .cc_expect
    rts
.cc_fc_ord_expr:
    ; Non-string: just evaluate expression (already integer = identity)
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_TK_RPAREN
    jsr .cc_expect
    rts

.cc_fc_chr:
    ; chr(expr) as standalone expression: evaluate arg (result is integer)
    jsr .cc_next_token       ; consume 'chr'
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_fc_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_TK_RPAREN
    jsr .cc_expect
    rts

.cc_fc_abs:
    jsr .cc_next_token       ; consume 'abs'
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_fc_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_fc_done
    lda CC_TK_RPAREN
    jsr .cc_expect
    lda CC_EXPR_TYPE
    bne .cc_fc_fabs
    lda PM_OP_ABS
    jsr .cc_emit
    rts
.cc_fc_fabs:
    lda PM_OP_FABS
    jsr .cc_emit
    rts

.cc_fc_odd:
    jsr .cc_next_token       ; consume 'odd'
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_fc_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression
    lda CC_ERROR
    bne .cc_fc_done
    lda CC_TK_RPAREN
    jsr .cc_expect
    jsr .cc_ensure_int       ; FTOI if real
    lda PM_OP_LIT16
    jsr .cc_emit
    lda 0x02
    jsr .cc_emit
    lda 0x00
    jsr .cc_emit
    lda PM_OP_MOD
    jsr .cc_emit
    rts

.cc_fc_not:
    jsr .cc_next_token       ; consume 'not'
    jsr .cc_parse_factor
    lda CC_ERROR
    bne .cc_fc_done
    jsr .cc_ensure_int       ; FTOI if real
    lda PM_OP_NOT
    jsr .cc_emit
    rts
.cc_fc_random:
    jsr .cc_next_token       ; consume 'random'
    lda CC_TOKEN_TYPE
    cmp CC_TK_LPAREN
    bne .cc_fc_random_emit
    jsr .cc_next_token       ; consume '('
    lda CC_TK_RPAREN
    jsr .cc_expect
.cc_fc_random_emit:
    lda CC_ERROR
    bne .cc_fc_done
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_RANDOM
    jsr .cc_emit
    lda 0x00
    sta CC_EXPR_TYPE         ; integer
    rts

.cc_fc_peek:
    jsr .cc_next_token       ; consume 'peek'
    lda CC_TK_LPAREN
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_fc_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression ; page
    lda CC_ERROR
    bne .cc_fc_done
    jsr .cc_ensure_int
    lda CC_TK_COMMA
    jsr .cc_expect
    lda CC_ERROR
    bne .cc_fc_done
    jsr .cc_str_rel_clear
    jsr .cc_parse_expression ; addr
    lda CC_ERROR
    bne .cc_fc_done
    jsr .cc_ensure_int
    lda CC_TK_RPAREN
    jsr .cc_expect
    lda PM_OP_CSP
    jsr .cc_emit
    lda PM_CSP_PEEK
    jsr .cc_emit
    lda 0x00
    sta CC_EXPR_TYPE
    rts

.cc_fc_done:
    rts

; ── Lexer: next_token ────────────────────────────────────

.cc_next_token:
    jsr .cc_skip_ws
    jsr .cc_peek_char
    beq .cc_nt_eof

    ; '$' → hex number
    cmp 0x24
    beq .cc_nt_hex

    ; Digit → number
    cmp 0x30
    bcc .cc_nt_not_digit
    cmp 0x3A
    bcc .cc_nt_number
.cc_nt_not_digit:

    ; Letter → identifier/keyword
    jsr .cc_is_alpha
    bcs .cc_nt_ident

    ; String literal (single quote 0x27)
    cmp 0x27
    beq .cc_nt_string

    ; Operators and punctuation
    jmp .cc_nt_operator

.cc_nt_eof:
    lda CC_TK_EOF
    sta CC_TOKEN_TYPE
    rts

; ── Lexer: scan hex number ($HHHH) ───────────────────────

.cc_nt_hex:
    jsr .cc_next_char        ; consume '$'
    lda 0x00
    sta CC_TOKEN_NUM_LO
    sta CC_TOKEN_NUM_HI

.cc_nt_hex_loop:
    jsr .cc_peek_char
    ; Check 0-9
    cmp 0x30
    bcc .cc_nt_hex_done
    cmp 0x3A
    bcc .cc_nt_hex_digit09
    ; Check A-F
    cmp 0x41
    bcc .cc_nt_hex_done
    cmp 0x47
    bcc .cc_nt_hex_digitAF
    ; Check a-f
    cmp 0x61
    bcc .cc_nt_hex_done
    cmp 0x67
    bcc .cc_nt_hex_digitaf
    jmp .cc_nt_hex_done

.cc_nt_hex_digit09:
    sec
    sbc 0x30                 ; digit = ch - '0'
    jmp .cc_nt_hex_accum
.cc_nt_hex_digitAF:
    sec
    sbc 0x37                 ; digit = ch - 'A' + 10
    jmp .cc_nt_hex_accum
.cc_nt_hex_digitaf:
    sec
    sbc 0x57                 ; digit = ch - 'a' + 10

.cc_nt_hex_accum:
    pha                      ; save digit
    ; Shift CC_TOKEN_NUM left 4 bits (4x ROL pair)
    clc
    rol CC_TOKEN_NUM_LO
    rol CC_TOKEN_NUM_HI
    clc
    rol CC_TOKEN_NUM_LO
    rol CC_TOKEN_NUM_HI
    clc
    rol CC_TOKEN_NUM_LO
    rol CC_TOKEN_NUM_HI
    clc
    rol CC_TOKEN_NUM_LO
    rol CC_TOKEN_NUM_HI
    ; OR digit into low byte
    pla
    ora CC_TOKEN_NUM_LO
    sta CC_TOKEN_NUM_LO
    jsr .cc_next_char
    jmp .cc_nt_hex_loop

.cc_nt_hex_done:
    lda CC_TK_NUMBER
    sta CC_TOKEN_TYPE
    rts

; ── Lexer: scan number ───────────────────────────────────

.cc_nt_number:
    lda 0x00
    sta CC_TOKEN_NUM_LO
    sta CC_TOKEN_NUM_HI

.cc_nt_num_loop:
    jsr .cc_peek_char
    cmp 0x30
    bcc .cc_nt_num_done
    cmp 0x3A
    bcs .cc_nt_num_done

    ; num = num * 10 + digit
    sec
    sbc 0x30
    pha                      ; save digit on stack (not CC_TEMP1!)

    ; Multiply current value by 10 using MUL16S
    lda CC_TOKEN_NUM_LO
    sta MATH16_A
    lda CC_TOKEN_NUM_HI
    sta MATH16_A+1
    lda 0x0A
    sta MATH16_B
    lda 0x00
    sta MATH16_B+1
    jsr MUL16S

    ; Add digit
    pla                      ; restore digit
    clc
    adc MATH16_A
    sta CC_TOKEN_NUM_LO
    lda MATH16_A+1
    adc 0x00
    sta CC_TOKEN_NUM_HI

    jsr .cc_next_char
    jmp .cc_nt_num_loop

.cc_nt_num_done:
    jsr .cc_peek_char
    cmp 0x2E                 ; '.'
    bne .cc_nt_num_int
    ; Could be float literal or '..' range operator
    ; Save integer part, peek ahead
    jsr .cc_next_char        ; consume '.'
    jsr .cc_peek_char
    cmp 0x2E                 ; '..' → dotdot, not float
    beq .cc_nt_num_dotdot
    ; Float literal: integer part already in CC_TOKEN_NUM_LO/HI
    ; Convert integer part to float
    lda CC_TOKEN_NUM_LO
    ldx CC_TOKEN_NUM_HI
    jsr INT_TO_FLOAT         ; FLOAT1 = integer part
    ; Save integer-part float
    lda FLOAT1
    sta FR_TMP
    lda FLOAT1+1
    sta FR_TMP+1
    lda FLOAT1+2
    sta FR_TMP+2
    lda FLOAT1+3
    sta FR_TMP+3
    ; Parse fractional digits
    lda 0x00
    sta CC_TOKEN_NUM_LO
    sta CC_TOKEN_NUM_HI
    sta FR_FRAC_CNT
.cc_nt_frac_loop:
    jsr .cc_peek_char
    cmp 0x30
    bcc .cc_nt_frac_done
    cmp 0x3A
    bcs .cc_nt_frac_done
    sec
    sbc 0x30
    pha
    lda CC_TOKEN_NUM_LO
    sta MATH16_A
    lda CC_TOKEN_NUM_HI
    sta MATH16_A+1
    lda 0x0A
    sta MATH16_B
    lda 0x00
    sta MATH16_B+1
    jsr MUL16S
    pla
    clc
    adc MATH16_A
    sta CC_TOKEN_NUM_LO
    lda MATH16_A+1
    adc 0x00
    sta CC_TOKEN_NUM_HI
    inc FR_FRAC_CNT
    jsr .cc_next_char
    jmp .cc_nt_frac_loop
.cc_nt_frac_done:
    ; Convert fractional integer to float
    lda CC_TOKEN_NUM_LO
    ldx CC_TOKEN_NUM_HI
    jsr INT_TO_FLOAT         ; FLOAT1 = fractional digits
    ; Divide fractional digits by 10^n (one division, no rounding accumulation)
    lda FR_FRAC_CNT
    beq .cc_nt_frac_add
    ; Save frac digits float to stack
    lda FLOAT1
    pha
    lda FLOAT1+1
    pha
    lda FLOAT1+2
    pha
    lda FLOAT1+3
    pha
    ; Build 10^n as float (avoids 16-bit integer overflow for n >= 5)
    ; FLOAT1 = 1.0 (IEEE-754 LE: 00 00 80 3F)
    lda 0x00
    sta FLOAT1
    sta FLOAT1+1
    lda 0x80
    sta FLOAT1+2
    lda 0x3F
    sta FLOAT1+3
    lda FR_FRAC_CNT
.cc_nt_frac_pow:
    pha
    ; FLOAT2 = 10.0 (IEEE-754 LE: 00 00 20 41)
    lda 0x00
    sta FLOAT2
    sta FLOAT2+1
    lda 0x20
    sta FLOAT2+2
    lda 0x41
    sta FLOAT2+3
    jsr FLOAT_MUL             ; FLOAT1 *= 10.0
    pla
    sec
    sbc 0x01
    bne .cc_nt_frac_pow
    ; FLOAT1 = 10^n as float, move to FLOAT2
    lda FLOAT1
    sta FLOAT2
    lda FLOAT1+1
    sta FLOAT2+1
    lda FLOAT1+2
    sta FLOAT2+2
    lda FLOAT1+3
    sta FLOAT2+3
    ; Restore frac digits float to FLOAT1
    pla
    sta FLOAT1+3
    pla
    sta FLOAT1+2
    pla
    sta FLOAT1+1
    pla
    sta FLOAT1
    ; FLOAT1 = frac_digits / 10^n
    jsr FLOAT_DIV
.cc_nt_frac_add:
    ; Add integer part (in FR_TMP) + fractional part (in FLOAT1)
    lda FR_TMP
    sta FLOAT2
    lda FR_TMP+1
    sta FLOAT2+1
    lda FR_TMP+2
    sta FLOAT2+2
    lda FR_TMP+3
    sta FLOAT2+3
    jsr FLOAT_ADD            ; FLOAT1 = complete float value
    lda CC_TK_FLOAT_LIT
    sta CC_TOKEN_TYPE
    rts
.cc_nt_num_dotdot:
    ; First '.' was consumed by cc_next_char; second '.' was only peeked.
    ; Un-consume the first '.' so next token scan sees '..'
    dec CC_SRC_COL
.cc_nt_num_int:
    lda CC_TK_NUMBER
    sta CC_TOKEN_TYPE
    rts

; ── Lexer: scan identifier / keyword ─────────────────────

.cc_nt_ident:
    lda 0x00
    sta CC_TOKEN_LEN

.cc_nt_id_loop:
    jsr .cc_peek_char
    jsr .cc_is_alnum
    bcc .cc_nt_id_done

    ; Store char (lowercase) in token buffer
    jsr .cc_to_lower
    ldx CC_TOKEN_LEN
    cpx 0x1F
    bcs .cc_nt_id_skip       ; buffer full, skip
    sta CC_TOKEN_BUF,x
    inc CC_TOKEN_LEN
.cc_nt_id_skip:
    jsr .cc_next_char
    jmp .cc_nt_id_loop

.cc_nt_id_done:
    ; Null-terminate
    ldx CC_TOKEN_LEN
    lda 0x00
    sta CC_TOKEN_BUF,x

    ; Check if keyword
    jsr .cc_check_keyword
    rts

; ── Lexer: scan string literal ───────────────────────────

.cc_nt_string:
    jsr .cc_next_char        ; consume opening quote
    lda 0x00
    sta CC_TOKEN_LEN

.cc_nt_str_loop:
    jsr .cc_peek_char
    beq .cc_nt_str_err       ; EOF → unterminated
    cmp 0x27                 ; closing quote
    beq .cc_nt_str_end

    ldx CC_TOKEN_LEN
    cpx 0x1F                 ; max 31 chars + null (32-byte CC_TOKEN_BUF)
    bcs .cc_nt_str_skip
    sta CC_TOKEN_BUF,x
    inc CC_TOKEN_LEN
.cc_nt_str_skip:
    jsr .cc_next_char
    jmp .cc_nt_str_loop

.cc_nt_str_end:
    jsr .cc_next_char        ; consume closing quote
    ldx CC_TOKEN_LEN
    lda 0x00
    sta CC_TOKEN_BUF,x
    lda CC_TK_STRING
    sta CC_TOKEN_TYPE
    rts

.cc_nt_str_err:
    lda .cc_e_string
    jmp .cc_error_a

.cc_emit_scoped:
    ; Emit a scoped opcode (LOAD/STORE or LOAD_L/STORE_L).
    ; Stack: [offset, level_diff] (level_diff on top)
    ; A = local opcode. CC_TEMP2 = scoped opcode (e.g. STORE_L).
    sta CC_TEMP1
    pla                      ; level_diff
    beq .cc_es_local
    pha
    lda CC_TEMP2
    jsr .cc_emit
    pla
    jsr .cc_emit             ; level_diff
    pla
    jsr .cc_emit             ; offset
    rts
.cc_es_local:
    pla
    sta CC_TEMP3             ; offset lo
    lda CC_ES_ARG1_SAVE
    bne .cc_es_loc_16
    lda CC_TEMP1
    jsr .cc_emit
    lda CC_TEMP3
    jsr .cc_emit
    rts
.cc_es_loc_16:
    lda CC_TEMP1
    cmp PM_OP_LOAD
    bne .cc_es_stw
    lda PM_OP_LOADW
    jsr .cc_emit
    lda CC_TEMP3
    jsr .cc_emit
    lda CC_ES_ARG1_SAVE
    jsr .cc_emit
    rts
.cc_es_stw:
    lda PM_OP_STOREW
    jsr .cc_emit
    lda CC_TEMP3
    jsr .cc_emit
    lda CC_ES_ARG1_SAVE
    jsr .cc_emit
    rts

; ── Type coercion helpers ───────────────────────────────

.cc_ensure_int:
    ; If CC_EXPR_TYPE = 1 (real), emit FTOI and set to 0.
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_ei_str_err
    lda CC_EXPR_TYPE
    beq .cc_ei_done
    lda PM_OP_FTOI
    jsr .cc_emit
    lda 0x00
    sta CC_EXPR_TYPE
.cc_ei_done:
    rts
.cc_ei_str_err:
    lda .cc_e_expr
    jmp .cc_error_a

.cc_ensure_real:
    ; If CC_EXPR_TYPE = 0 (int), emit ITOF and set to 1.
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_ei_str_err
    lda CC_EXPR_TYPE
    bne .cc_er_done
    lda PM_OP_ITOF
    jsr .cc_emit
    lda 0x01
    sta CC_EXPR_TYPE
.cc_er_done:
    rts

.cc_coerce_binop:
    ; Coerce binary op operands. A = left type, CC_EXPR_TYPE = right type.
    ; Stack: left(2 or 4B), right(2 or 4B).
    ; If both same → nothing.
    ; If left=int, right=real → ITOF_SWAP (convert left under right).
    ; If left=real, right=int → ITOF (convert right on top).
    ; Sets CC_EXPR_TYPE to result type.
    cmp 0x02
    beq .cc_cb_str_err
    pha
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_cb_str_err_pop
    pla
    cmp CC_EXPR_TYPE
    beq .cc_cb_done          ; same types
    cmp 0x01
    beq .cc_cb_left_real
    ; left=int, right=real → ITOF_SWAP
    lda PM_OP_ITOF_SWAP
    jsr .cc_emit
    lda 0x01
    sta CC_EXPR_TYPE
    rts
.cc_cb_left_real:
    ; left=real, right=int → ITOF
    lda PM_OP_ITOF
    jsr .cc_emit
    lda 0x01
    sta CC_EXPR_TYPE
.cc_cb_done:
    rts

.cc_cb_str_err_pop:
    pla                      ; discard saved left type
.cc_cb_str_err:
    lda .cc_e_expr
    jmp .cc_error_a

.cc_coerce_both_real:
    ; Ensure both operands are real. A = left type, CC_EXPR_TYPE = right type.
    ; Used for '/' operator.
    cmp 0x02
    beq .cc_cb_str_err
    pha
    lda CC_EXPR_TYPE
    cmp 0x02
    beq .cc_cb_str_err_pop
    pla
    cmp CC_EXPR_TYPE
    bne .cc_cbr_mixed
    cmp 0x01
    beq .cc_cbr_done         ; both real
    ; Both int → convert right then left
    lda PM_OP_ITOF
    jsr .cc_emit
    lda PM_OP_ITOF_SWAP
    jsr .cc_emit
    lda 0x01
    sta CC_EXPR_TYPE
    rts
.cc_cbr_mixed:
    jmp .cc_coerce_binop
.cc_cbr_done:
    rts

; Expected type for param at index CC_CALL_ARG_IDX via bitmask at byte 13 of callee.
; Returns A=1 (real) or A=0 (integer). A=0 if out of range.
.cc_get_callee_param_type:
    lda CC_CALL_ARG_IDX
    cmp CC_CALLEE_NPARAM
    bcs .cc_gcpt_default
    lda CC_CALLEE_SYM_IDX
    jsr .cc_sym_addr
    ldx 0x0D
    lda yde,x              ; param type bitmask
    ldx CC_CALL_ARG_IDX
    beq .cc_gcpt_test
.cc_gcpt_shift:
    lsr a
    dex
    bne .cc_gcpt_shift
.cc_gcpt_test:
    and 0x01
    rts
.cc_gcpt_default:
    lda 0x00
    rts

.cc_patch_enter:
    ; Patch ENTER16 frame size (16-bit LE) at CC_ENTER_LO:HI
    lda CC_ENTER_LO
    clc
    adc PM_PCODE_BASE[7:0]
    tae
    lda CC_ENTER_HI
    adc PM_PCODE_BASE[15:8]
    tad
    lda CC_FRAME_OFF
    ldx 0x00
    sta de,x
    inx
    lda CC_FRAME_OFF_HI
    sta de,x
    rts

; ── Lexer: operators and punctuation ─────────────────────

.cc_nt_operator:
    jsr .cc_next_char        ; consume the character

    cmp 0x2B                 ; '+'
    beq .cc_op_plus
    cmp 0x2D                 ; '-'
    beq .cc_op_minus
    cmp 0x2A                 ; '*'
    beq .cc_op_star
    cmp 0x2F                 ; '/'
    beq .cc_op_slash
    cmp 0x28                 ; '('
    beq .cc_op_lparen
    cmp 0x29                 ; ')'
    beq .cc_op_rparen
    cmp 0x3B                 ; ';'
    beq .cc_op_semi
    cmp 0x2C                 ; ','
    beq .cc_op_comma
    cmp 0x3D                 ; '='
    beq .cc_op_eq
    cmp 0x3C                 ; '<'
    beq .cc_op_lt
    cmp 0x3E                 ; '>'
    beq .cc_op_gt
    cmp 0x3A                 ; ':'
    beq .cc_op_colon
    cmp 0x2E                 ; '.'
    beq .cc_op_dot
    cmp 0x5B                 ; '['
    beq .cc_op_lbracket
    cmp 0x5D                 ; ']'
    beq .cc_op_rbracket

    ; Unknown character
    lda .cc_e_syntax
    jmp .cc_error_a

.cc_op_plus:
    lda CC_TK_PLUS
    sta CC_TOKEN_TYPE
    rts
.cc_op_minus:
    lda CC_TK_MINUS
    sta CC_TOKEN_TYPE
    rts
.cc_op_star:
    lda CC_TK_STAR
    sta CC_TOKEN_TYPE
    rts
.cc_op_slash:
    lda CC_TK_SLASH
    sta CC_TOKEN_TYPE
    rts
.cc_op_lparen:
    lda CC_TK_LPAREN
    sta CC_TOKEN_TYPE
    rts
.cc_op_rparen:
    lda CC_TK_RPAREN
    sta CC_TOKEN_TYPE
    rts
.cc_op_semi:
    lda CC_TK_SEMI
    sta CC_TOKEN_TYPE
    rts
.cc_op_comma:
    lda CC_TK_COMMA
    sta CC_TOKEN_TYPE
    rts
.cc_op_eq:
    lda CC_TK_EQ
    sta CC_TOKEN_TYPE
    rts
.cc_op_lbracket:
    lda CC_TK_LBRACKET
    sta CC_TOKEN_TYPE
    rts
.cc_op_rbracket:
    lda CC_TK_RBRACKET
    sta CC_TOKEN_TYPE
    rts
.cc_op_lt:
    ; Could be <, <=, <>
    jsr .cc_peek_char
    cmp 0x3D                 ; '='
    beq .cc_op_le
    cmp 0x3E                 ; '>'
    beq .cc_op_ne
    lda CC_TK_LT
    sta CC_TOKEN_TYPE
    rts
.cc_op_le:
    jsr .cc_next_char
    lda CC_TK_LE
    sta CC_TOKEN_TYPE
    rts
.cc_op_ne:
    jsr .cc_next_char
    lda CC_TK_NE
    sta CC_TOKEN_TYPE
    rts
.cc_op_gt:
    ; Could be > or >=
    jsr .cc_peek_char
    cmp 0x3D
    beq .cc_op_ge
    lda CC_TK_GT
    sta CC_TOKEN_TYPE
    rts
.cc_op_ge:
    jsr .cc_next_char
    lda CC_TK_GE
    sta CC_TOKEN_TYPE
    rts
.cc_op_colon:
    ; Could be : or := (allow spaces between ':' and '=' e.g. "a : = x")
.cc_colon_maybe_assign:
    jsr .cc_peek_char
    beq .cc_colon_plain      ; EOL → ':'
    cmp 0x20
    beq .cc_colon_eat_ws
    cmp 0x09
    beq .cc_colon_eat_ws
    cmp 0x3D                 ; '='
    beq .cc_op_assign
.cc_colon_plain:
    lda CC_TK_COLON
    sta CC_TOKEN_TYPE
    rts
.cc_colon_eat_ws:
    jsr .cc_next_char
    jmp .cc_colon_maybe_assign
.cc_op_assign:
    jsr .cc_next_char        ; consume '='
    lda CC_TK_ASSIGN
    sta CC_TOKEN_TYPE
    rts
.cc_op_dot:
    ; Could be . or ..
    jsr .cc_peek_char
    cmp 0x2E                 ; '.'
    beq .cc_op_dotdot
    lda CC_TK_DOT
    sta CC_TOKEN_TYPE
    rts
.cc_op_dotdot:
    jsr .cc_next_char
    lda CC_TK_DOTDOT
    sta CC_TOKEN_TYPE
    rts

; ── Lexer: character helpers ─────────────────────────────

.cc_peek_char:
    ldx CC_SRC_COL
    lda ED_LINE_BUF,x
    rts

.cc_next_char:
    ldx CC_SRC_COL
    lda ED_LINE_BUF,x
    beq .cc_nc_eol
    inc CC_SRC_COL
    rts

.cc_nc_eol:
    lda CC_SRC_LINE
    cmp CC_TOTAL_LINES
    bcs .cc_nc_eof
    inc CC_SRC_LINE
    lda CC_SRC_LINE
    jsr .ed_read_line_to_buf
    lda 0x00
    sta CC_SRC_COL
    lda 0x20                 ; space for line boundary
    rts
.cc_nc_eof:
    lda 0x00
    rts

.cc_is_alpha:
    ; Input: A = char. Output: carry set if alpha.
    cmp 0x41
    bcc .cc_ia_no
    cmp 0x5B
    bcc .cc_ia_yes
    cmp 0x61
    bcc .cc_ia_no
    cmp 0x7B
    bcc .cc_ia_yes
.cc_ia_no:
    clc
    rts
.cc_ia_yes:
    sec
    rts

.cc_is_alnum:
    ; Input: A = char. Output: carry set if alpha or digit or '_'.
    cmp 0x5F                 ; '_'
    beq .cc_ian_yes
    cmp 0x30
    bcc .cc_ian_no
    cmp 0x3A
    bcc .cc_ian_yes
    jmp .cc_is_alpha
.cc_ian_no:
    clc
    rts
.cc_ian_yes:
    sec
    rts

.cc_to_lower:
    ; Input/Output: A = char (lowercased if uppercase)
    cmp 0x41
    bcc .cc_tl_done
    cmp 0x5B
    bcs .cc_tl_done
    clc
    adc 0x20
.cc_tl_done:
    rts

; ── Lexer: skip whitespace and comments ──────────────────

.cc_skip_ws:
    jsr .cc_peek_char
    beq .cc_sw_eol
    cmp 0x20
    beq .cc_sw_skip
    cmp 0x09
    beq .cc_sw_skip
    cmp 0x7B                 ; '{'
    beq .cc_sw_comment
    rts

.cc_sw_skip:
    jsr .cc_next_char
    jmp .cc_skip_ws

.cc_sw_eol:
    lda CC_SRC_LINE
    cmp CC_TOTAL_LINES
    bcs .cc_sw_eof
    jsr .cc_next_char
    jmp .cc_skip_ws
.cc_sw_eof:
    rts

.cc_sw_comment:
    jsr .cc_next_char        ; consume '{'
.cc_sw_cmt_loop:
    jsr .cc_peek_char
    beq .cc_sw_cmt_eol
    cmp 0x7D                 ; '}'
    beq .cc_sw_cmt_end
    jsr .cc_next_char
    jmp .cc_sw_cmt_loop
.cc_sw_cmt_eol:
    lda CC_SRC_LINE
    cmp CC_TOTAL_LINES
    bcs .cc_sw_eof
    jsr .cc_next_char
    jmp .cc_sw_cmt_loop
.cc_sw_cmt_end:
    jsr .cc_next_char        ; consume '}'
    jmp .cc_skip_ws

; ── Lexer: keyword lookup ────────────────────────────────

.cc_check_keyword:
    ; Compare CC_TOKEN_BUF against keyword table.
    ; If match, set CC_TOKEN_TYPE to keyword code.
    ; Otherwise set CC_TOKEN_TYPE to CC_TK_IDENT.
    ; Uses CC_TOKEN_NUM_HI as temp for table page (bits 23:16); refilled when a number token is lexed.
    lda .cc_kw_table[23:16]
    sta CC_TOKEN_NUM_HI
    lda .cc_kw_table[7:0]
    sta CC_KW_PTR_LO
    lda .cc_kw_table[15:8]
    sta CC_KW_PTR_HI

.cc_ck_next:
    ; Read first byte of keyword entry (24-bit ptr: Y + D:E)
    ldy CC_TOKEN_NUM_HI
    ldd CC_KW_PTR_HI
    lde CC_KW_PTR_LO
    ldx 0x00
    lda yde,x
    beq .cc_ck_no_match      ; sentinel: end of table

    ; Compare keyword string with CC_TOKEN_BUF
    ldy 0x00
.cc_ck_cmp:
    phy
    ldy CC_TOKEN_NUM_HI
    lda yde,x
    sta CC_TEMP1
    ply
    lda CC_TEMP1
    beq .cc_ck_check_end     ; end of keyword string
    cmp CC_TOKEN_BUF,y
    bne .cc_ck_skip

    inx
    iny
    jmp .cc_ck_cmp

.cc_ck_check_end:
    ; Keyword ended, check if token also ended
    lda CC_TOKEN_BUF,y
    bne .cc_ck_skip          ; token has more chars → not a match

    ; Match! Read token type byte (right after null terminator)
    inx
    ldy CC_TOKEN_NUM_HI
    lda yde,x
    sta CC_TOKEN_TYPE
    rts

.cc_ck_skip:
    ; Skip to next keyword entry (reset scan from table pointer)
    ldd CC_KW_PTR_HI
    lde CC_KW_PTR_LO
    ldx 0x00
.cc_ck_skip_str:
    ldy CC_TOKEN_NUM_HI
    lda yde,x
    beq .cc_ck_skip_found
    inx
    jmp .cc_ck_skip_str
.cc_ck_skip_found:
    inx                      ; skip null
    inx                      ; skip token type byte

    ; Advance pointer (16-bit; table stays within same 64K bank as .cc_kw_table)
    txa
    clc
    adc CC_KW_PTR_LO
    sta CC_KW_PTR_LO
    lda 0x00
    adc CC_KW_PTR_HI
    sta CC_KW_PTR_HI
    jmp .cc_ck_next

.cc_ck_no_match:
    lda CC_TK_IDENT
    sta CC_TOKEN_TYPE
    rts

; ── Parser: expect token ─────────────────────────────────

.cc_expect:
    ; Input: A = expected token type
    ; If current token matches, advance. Otherwise error.
    cmp CC_TOKEN_TYPE
    bne .cc_exp_err
    jsr .cc_next_token
    rts
.cc_exp_err:
    lda .cc_e_expect
    jmp .cc_error_a

; ── Codegen: emit byte ───────────────────────────────────

.cc_emit:
    ; Emit byte A to P-code output at PM_PCODE_BASE + CC_CODE
    pha
    lda CC_CODE_LO
    clc
    adc PM_PCODE_BASE[7:0]
    tae
    lda CC_CODE_HI
    adc PM_PCODE_BASE[15:8]
    tad
    pla
    ldx 0x00
    sta de,x

    ; Increment code pointer
    inc CC_CODE_LO
    bne .cc_emit_done
    inc CC_CODE_HI
.cc_emit_done:
    rts

; ── Symbol table ─────────────────────────────────────────

.cc_sym_addr:
    ; Compute address of symbol entry A in expansion RAM (CC_WS_PAGE).
    ; Input: A = symbol index
    ; Output: D:E = base address, Y = CC_WS_PAGE
    sta MATH16_A
    lda 0x00
    sta MATH16_A+1
    lda CC_SYM_ENTRY
    sta MATH16_B
    lda 0x00
    sta MATH16_B+1
    jsr MUL16S
    lda MATH16_A
    clc
    adc CC_SYM_BASE[7:0]
    tae
    lda MATH16_A+1
    adc CC_SYM_BASE[15:8]
    tad
    ldy CC_WS_PAGE
    rts

.cc_sym_write_name:
    ; Write name from CC_TOKEN_BUF into symbol entry at D:E:Y.
    ; Returns with X=8 (after name field).
    ldx 0x00
.cc_swn_loop:
    cpx 0x07
    bcs .cc_swn_pad
    lda CC_TOKEN_BUF,x
    beq .cc_swn_pad
    sta yde,x
    inx
    jmp .cc_swn_loop
.cc_swn_pad:
    lda 0x00
    sta yde,x
    inx
    cpx 0x08
    bne .cc_swn_pad
    rts

.cc_add_var:
    ; Add scalar variable to symbol table from CC_TOKEN_BUF.
    ; CC_VAR_TYPE: 0=integer (2 bytes), 1=real (4 bytes).
    ; CC_PARAM_VAR = var param flag.
    lda CC_SYM_COUNT
    jsr .cc_sym_addr
    jsr .cc_sym_write_name   ; X=8
    lda CC_SCOPE_LEVEL
    sta yde,x                ; byte 8: scope
    inx
    lda CC_KIND_SCALAR
    sta yde,x                ; byte 9: kind
    inx
    lda CC_FRAME_OFF
    sta yde,x                ; byte 10: offset lo
    inx
    lda CC_FRAME_OFF_HI
    sta yde,x                ; byte 11: offset hi
    inx
    sta yde,x                ; byte 12: unused
    inx
    sta yde,x                ; byte 13: unused
    inx
    lda CC_PARAM_VAR
    sta yde,x                ; byte 14: var param flag
    inx
    lda CC_VAR_TYPE
    sta yde,x                ; byte 15: var type (0=int, 1=real)
    ; Allocate frame space: 2 for int, 4 for real (var params always 2)
    lda CC_PARAM_VAR
    bne .cc_av_ptr
    lda CC_VAR_TYPE
    cmp 0x01
    beq .cc_av_real
    cmp 0x02
    beq .cc_av_string
.cc_av_ptr:
    lda CC_FRAME_OFF
    clc
    adc 0x02
    sta CC_FRAME_OFF
    lda CC_FRAME_OFF_HI
    adc 0x00
    sta CC_FRAME_OFF_HI
    jmp .cc_av_done
.cc_av_real:
    lda CC_FRAME_OFF
    clc
    adc 0x04
    sta CC_FRAME_OFF
    lda CC_FRAME_OFF_HI
    adc 0x00
    sta CC_FRAME_OFF_HI
    jmp .cc_av_done
.cc_av_string:
    lda CC_FRAME_OFF
    clc
    adc 0x51
    sta CC_FRAME_OFF
    lda CC_FRAME_OFF_HI
    adc 0x00
    sta CC_FRAME_OFF_HI
.cc_av_done:
    inc CC_SYM_COUNT
    rts

.cc_add_sub:
    ; Add procedure/function to symbol table.
    ; CC_FOUND_KIND = CC_KIND_PROC or CC_KIND_FUNC
    ; Code address = current CC_CODE position.
    lda CC_SYM_COUNT
    jsr .cc_sym_addr
    jsr .cc_sym_write_name   ; X=8
    lda CC_SCOPE_LEVEL
    sta yde,x                ; byte 8: scope (definition level)
    inx
    lda CC_FOUND_KIND
    sta yde,x                ; byte 9: kind
    inx
    lda CC_CODE_LO
    sta yde,x                ; byte 10: code_addr_lo
    inx
    lda CC_CODE_HI
    sta yde,x                ; byte 11: code_addr_hi
    inx
    lda 0x00
    sta yde,x                ; byte 12: param_count (patched later)
    inx
    lda CC_SCOPE_LEVEL
    sta yde,x                ; byte 13: definition_level
    inx
    lda 0x00
    sta yde,x                ; byte 14: var_param_mask (patched later)
    inx
    lda CC_FUNC_RET
    sta yde,x                ; byte 15: return type (0=int proc, 0=int func, 2=real func)
    inc CC_SYM_COUNT
    rts

.cc_sym_write_arr_fields:
    ; Patch existing entry at D:E:Y to be an array.
    ; Bytes 0-8 (name + scope) already correct from cc_add_var.
    ; CC_FOUND_ARG1 = low bound, CC_FOUND_ARG2 = high bound.
    ldx 0x09
    lda CC_KIND_ARRAY
    sta yde,x                ; byte 9: kind=ARRAY
    inx
    lda CC_FOUND_ARG1
    asl a
    sta CC_TEMP1
    lda CC_FRAME_OFF
    sec
    sbc CC_TEMP1
    sta yde,x                ; byte 10: adjusted_base
    inx
    lda CC_FOUND_ARG1
    sta yde,x                ; byte 11: low
    inx
    lda CC_FOUND_ARG2
    sta yde,x                ; byte 12: high
    ; Allocate (high-low+1)*2 bytes in frame
    lda CC_FOUND_ARG2
    sec
    sbc CC_FOUND_ARG1
    clc
    adc 0x01
    asl a
    clc
    adc CC_FRAME_OFF
    sta CC_FRAME_OFF
    rts

; ENTER16 nparams = eval-stack slots (real value param = 2, others = 1).
; Uses bitmasks at byte 13/14 of callee entry (CC_SAVED_SYMCNT). Returns A.
.cc_count_enter_slots:
    lda 0x00
    sta CC_TEMP1             ; slot counter
    lda CC_FOUND_ARG2
    beq .cc_ces_done
    lda CC_SAVED_SYMCNT
    jsr .cc_sym_addr
    ldx 0x0D
    lda yde,x               ; param type mask (bit=1 → real)
    sta CC_TEMP2
    inx
    lda yde,x               ; var param mask (bit=1 → var)
    sta CC_TEMP3
    ldx CC_FOUND_ARG2
.cc_ces_loop:
    lda CC_TEMP3
    and 0x01
    bne .cc_ces_one_slot     ; var params always 1 slot
    lda CC_TEMP2
    and 0x01
    bne .cc_ces_two_slots    ; non-var real param = 2 slots
.cc_ces_one_slot:
    inc CC_TEMP1
    jmp .cc_ces_next
.cc_ces_two_slots:
    lda CC_TEMP1
    clc
    adc 0x02
    sta CC_TEMP1
.cc_ces_next:
    lsr CC_TEMP2
    lsr CC_TEMP3
    dex
    bne .cc_ces_loop
.cc_ces_done:
    lda CC_TEMP1
    rts

.cc_patch_sub_params:
    ; Patch param_count, param_type_mask, and var_param_mask for the subroutine.
    ; Input: A = symbol index, CC_FOUND_ARG2 = param count,
    ;        CC_PARAM_TYPE_MASK = type bitmask, CC_FOUND_B14 = var mask
    jsr .cc_sym_addr
    ldx 0x0C                 ; byte 12: param count
    lda CC_FOUND_ARG2
    sta yde,x
    inx                      ; byte 13: param type bitmask
    lda CC_PARAM_TYPE_MASK
    sta yde,x
    inx                      ; byte 14: var param bitmask
    lda CC_FOUND_B14
    sta yde,x
    rts

.cc_shift_param_offsets:
    ; Shift all parameter offsets by +2 (from CC_SAVED_SYMCNT+1 to CC_SYM_COUNT-1)
    lda CC_SAVED_SYMCNT
    clc
    adc 0x01
.cc_spo_loop:
    cmp CC_SYM_COUNT
    bcs .cc_spo_done
    pha
    jsr .cc_sym_addr
    ldx 0x0A
    lda yde,x
    clc
    adc 0x02
    sta yde,x                ; byte 10: offset += 2
    pla
    clc
    adc 0x01
    jmp .cc_spo_loop
.cc_spo_done:
    rts

.cc_repatch_real:
    ; Re-patch variables from index A to CC_SYM_COUNT-1 as real type.
    ; Fixes byte 15 (type=1) and recalculates offsets (4 bytes each).
    sta CC_TEMP3             ; start index
    ; Compute original frame base = current frame - n*2
    lda CC_SYM_COUNT
    sec
    sbc CC_TEMP3             ; n = number of vars in batch
    asl a                    ; n * 2
    sta CC_TEMP1
    lda CC_FRAME_OFF
    sec
    sbc CC_TEMP1             ; base_off = frame_off - n*2
    sta CC_TEMP1             ; CC_TEMP1 = running offset
    lda CC_TEMP3             ; current index
.cc_rpr_loop:
    cmp CC_SYM_COUNT
    bcs .cc_rpr_done
    pha
    jsr .cc_sym_addr
    ldx 0x0A
    lda CC_TEMP1
    sta yde,x                ; byte 10: new offset lo
    inx
    lda 0x00
    sta yde,x                ; byte 11: offset hi
    ldx 0x0F
    lda 0x01
    sta yde,x                ; byte 15: type = real
    lda CC_TEMP1
    clc
    adc 0x04
    sta CC_TEMP1
    pla
    clc
    adc 0x01
    jmp .cc_rpr_loop
.cc_rpr_done:
    lda CC_TEMP1
    sta CC_FRAME_OFF
    lda 0x00
    sta CC_FRAME_OFF_HI
    rts

; Re-patch a batch of variables (from index A) as string: 81 bytes each, type=2

.cc_repatch_string:
    sta CC_TEMP3
    lda CC_SYM_COUNT
    sec
    sbc CC_TEMP3
    asl a
    sta CC_TEMP1
    lda CC_FRAME_OFF
    sec
    sbc CC_TEMP1
    sta CC_TEMP1
    lda CC_FRAME_OFF_HI
    sbc 0x00
    sta CC_TEMP2
    lda CC_TEMP3
.cc_rps_loop:
    cmp CC_SYM_COUNT
    bcs .cc_rps_done
    pha
    jsr .cc_sym_addr
    ldx 0x0A
    lda CC_TEMP1
    sta yde,x
    inx
    lda CC_TEMP2
    sta yde,x
    ldx 0x0F
    lda 0x02
    sta yde,x
    lda CC_TEMP1
    clc
    adc 0x51
    sta CC_TEMP1
    lda CC_TEMP2
    adc 0x00
    sta CC_TEMP2
    pla
    clc
    adc 0x01
    jmp .cc_rps_loop
.cc_rps_done:
    lda CC_TEMP1
    sta CC_FRAME_OFF
    lda CC_TEMP2
    sta CC_FRAME_OFF_HI
    rts

.cc_find_sym:
    ; Find symbol by CC_TOKEN_BUF name.
    ; Returns: A = byte 10 (offset/code_lo), carry clear if found.
    ; Sets CC_FOUND_KIND, CC_FOUND_SCOPE, CC_FOUND_ARG1..3.
    ; Carry set if not found.
    lda CC_SYM_COUNT
    beq .cc_fs_notfound

    lda CC_SYM_COUNT
    sec
    sbc 0x01

.cc_fs_loop:
    pha
    jsr .cc_sym_addr

    ; Compare name
    ldx 0x00
.cc_fs_cmp:
    lda yde,x
    cmp CC_TOKEN_BUF,x
    bne .cc_fs_next
    cmp 0x00
    beq .cc_fs_found
    inx
    cpx 0x07
    bcc .cc_fs_cmp
    jmp .cc_fs_found

.cc_fs_next:
    pla
    beq .cc_fs_notfound
    sec
    sbc 0x01
    jmp .cc_fs_loop

.cc_fs_found:
    pla                      ; clean index
    sta CC_FOUND_SYM_IDX
    ; Read all fields (D:E:Y still valid)
    ldx 0x08
    lda yde,x
    sta CC_FOUND_SCOPE       ; byte 8: scope
    inx
    lda yde,x
    sta CC_FOUND_KIND        ; byte 9: kind
    inx
    lda yde,x
    sta CC_FOUND_B10         ; byte 10: save for later
    inx
    lda yde,x
    sta CC_FOUND_ARG1        ; byte 11
    inx
    lda yde,x
    sta CC_FOUND_ARG2        ; byte 12
    inx
    lda yde,x
    sta CC_FOUND_ARG3        ; byte 13
    inx
    lda yde,x
    sta CC_FOUND_B14         ; byte 14: var param flag
    inx
    lda yde,x
    sta CC_FOUND_B15         ; byte 15: type (0=int, 1=real; func: 0/2)
    lda CC_FOUND_B10         ; A = byte 10
    clc
    rts

.cc_fs_notfound:
    sec
    rts

; ── Fixup table ──────────────────────────────────────────

.cc_push_fixup:
    ; Push current code position to fixup stack, emit 2 placeholder bytes.
    lda CC_FIX_SP
    asl a                    ; * 2 (each entry is 2 bytes)
    clc
    adc CC_FIX_BASE[7:0]
    tae
    lda 0x00
    adc CC_FIX_BASE[15:8]
    tad
    ldy CC_WS_PAGE

    ; Store current code position
    lda CC_CODE_LO
    ldx 0x00
    sta yde,x
    lda CC_CODE_HI
    inx
    sta yde,x

    inc CC_FIX_SP

    ; Emit 2 placeholder bytes for the address
    lda 0x00
    jsr .cc_emit
    lda 0x00
    jsr .cc_emit
    rts

.cc_pop_fixup_patch:
    ; Pop fixup from stack, patch with current code position.
    dec CC_FIX_SP
    lda CC_FIX_SP
    asl a
    clc
    adc CC_FIX_BASE[7:0]
    tae
    lda 0x00
    adc CC_FIX_BASE[15:8]
    tad
    ldy CC_WS_PAGE

    ; Read saved code position
    ldx 0x00
    lda yde,x
    sta CC_TEMP1
    inx
    lda yde,x
    sta CC_TEMP2

    ; Patch: write current code position at the saved location
    lda CC_TEMP1
    clc
    adc PM_PCODE_BASE[7:0]
    tae
    lda CC_TEMP2
    adc PM_PCODE_BASE[15:8]
    tad
    ldx 0x00
    lda CC_CODE_LO
    sta de,x
    inx
    lda CC_CODE_HI
    sta de,x
    rts

.cc_swap_fixup:
    ; For if/else: after emitting JMP opcode, we need to:
    ; 1. Emit 2 placeholder bytes for JMP's target address
    ; 2. Patch the old JPC fixup to point HERE (past the JMP instruction)
    ; 3. Push the JMP's address bytes position as a new fixup

    ; Save position of JMP's address bytes
    lda CC_CODE_LO
    sta CC_TEMP3
    lda CC_CODE_HI
    sta CC_TEMP4

    ; Emit 2 placeholder bytes for JMP address
    lda 0x00
    jsr .cc_emit
    lda 0x00
    jsr .cc_emit

    ; Patch old (JPC) fixup with current CC_CODE (after the JMP instruction)
    jsr .cc_pop_fixup_patch

    ; Push JMP fixup manually (without emitting placeholder bytes)
    lda CC_FIX_SP
    asl a
    clc
    adc CC_FIX_BASE[7:0]
    tae
    lda 0x00
    adc CC_FIX_BASE[15:8]
    tad
    ldy CC_WS_PAGE
    lda CC_TEMP3
    ldx 0x00
    sta yde,x
    lda CC_TEMP4
    inx
    sta yde,x
    inc CC_FIX_SP
    rts

; ── String pool ──────────────────────────────────────────

.cc_add_string_token:
    ; Copy CC_TOKEN_BUF (null-terminated) to string pool in exp RAM (CC_WS_PAGE).
    ; Save pool start offset for the fixup that follows this add.
    lda CC_STR_OFF_LO
    sta CC_STR_POOL_START_LO
    lda CC_STR_OFF_HI
    sta CC_STR_POOL_START_HI

    lda CC_STR_OFF_LO
    clc
    adc CC_STR_BASE[7:0]
    tae
    lda CC_STR_OFF_HI
    adc CC_STR_BASE[15:8]
    tad
    ldy CC_WS_PAGE
    ldx 0x00

.cc_ast_loop:
    lda CC_TOKEN_BUF,x
    sta yde,x
    beq .cc_ast_end
    inx
    jmp .cc_ast_loop

.cc_ast_end:
    ; Update string offset (length + 1 for null)
    inx
    txa
    clc
    adc CC_STR_OFF_LO
    sta CC_STR_OFF_LO
    lda 0x00
    adc CC_STR_OFF_HI
    sta CC_STR_OFF_HI
    rts

.cc_push_str_fixup:
    ; Bounds check: max CC_STR_FIX_MAX entries
    lda CC_STR_FIX_SP
    cmp CC_STR_FIX_MAX
    bcc .cc_psf_ok
    lda 0x01
    sta CC_ERROR
    rts
.cc_psf_ok:
    ; Record code position + pool byte offset of this literal (4 bytes / entry).
    ; 16-bit address: CC_STR_FIX_BASE + CC_STR_FIX_SP * 4
    lda CC_STR_FIX_SP
    ldx 0x00                 ; X = high byte of SP*4
    asl a
    bcc .cc_psf_nc1
    inx
.cc_psf_nc1:
    asl a
    bcc .cc_psf_nc2
    inx
.cc_psf_nc2:
    clc
    adc CC_STR_FIX_BASE[7:0]
    tae
    txa
    adc CC_STR_FIX_BASE[15:8]
    tad
    ldy CC_WS_PAGE

    lda CC_CODE_LO
    ldx 0x00
    sta yde,x
    lda CC_CODE_HI
    inx
    sta yde,x
    lda CC_STR_POOL_START_LO
    inx
    sta yde,x
    lda CC_STR_POOL_START_HI
    inx
    sta yde,x

    inc CC_STR_FIX_SP

    ; Emit 2 placeholder bytes for the string address
    lda 0x00
    jsr .cc_emit
    lda 0x00
    jsr .cc_emit
    rts

; ── Finalize: append strings, patch fixups, write header ─

.cc_finalize:
    ; 1. Save code-end position (= where string data will start in P-code)
    lda CC_CODE_LO
    sta CC_TEMP1             ; data_off low
    lda CC_CODE_HI
    sta CC_TEMP2             ; data_off high

    ; 2. Copy string pool from expansion RAM (CC_WS_PAGE) to P-code output
    lda CC_STR_OFF_LO
    ora CC_STR_OFF_HI
    beq .cc_fin_no_strings

    ; Use CC_FOR_VAR:CC_FOR_VAR_HI as 16-bit byte counter
    lda 0x00
    sta CC_FOR_VAR
    sta CC_FOR_VAR_HI

.cc_fin_str_copy:
    lda CC_FOR_VAR
    cmp CC_STR_OFF_LO
    bne .cc_fin_str_byte
    lda CC_FOR_VAR_HI
    cmp CC_STR_OFF_HI
    beq .cc_fin_str_done

.cc_fin_str_byte:
    ; Read from expansion RAM at CC_STR_BASE + CC_FOR_VAR:CC_FOR_VAR_HI
    lda CC_FOR_VAR
    clc
    adc CC_STR_BASE[7:0]
    tae
    lda CC_FOR_VAR_HI
    adc CC_STR_BASE[15:8]
    tad
    ldy CC_WS_PAGE
    ldx 0x00
    lda yde,x
    jsr .cc_emit
    inc CC_FOR_VAR
    bne .cc_fin_str_copy
    inc CC_FOR_VAR_HI
    jmp .cc_fin_str_copy

.cc_fin_str_done:
.cc_fin_no_strings:

    ; 3. Patch string fixups (from separate string fixup stack)
    lda CC_STR_FIX_SP
    beq .cc_fin_header

    lda 0x00
    sta CC_FOR_VAR           ; fixup index

.cc_fin_patch_loop:
    lda CC_FOR_VAR
    cmp CC_STR_FIX_SP
    bcs .cc_fin_header

    ; Read fixup entry: code_lo, code_hi, pool_off_lo, pool_off_hi
    lda CC_FOR_VAR
    ldx 0x00
    asl a
    bcc .cc_fpatch_nc1
    inx
.cc_fpatch_nc1:
    asl a
    bcc .cc_fpatch_nc2
    inx
.cc_fpatch_nc2:
    clc
    adc CC_STR_FIX_BASE[7:0]
    tae
    txa
    adc CC_STR_FIX_BASE[15:8]
    tad
    ldy CC_WS_PAGE
    ldx 0x00
    lda yde,x
    pha                      ; push code_pos_lo
    inx
    lda yde,x
    pha                      ; push code_pos_hi
    inx
    lda yde,x
    sta CC_TEMP3             ; pool start offset low
    inx
    lda yde,x
    sta CC_TEMP4             ; pool start offset high

    ; string abs = PM_PCODE_BASE + data_off + pool_offset (this literal)
    lda CC_TEMP1
    clc
    adc CC_TEMP3
    sta CC_SRC_COL           ; string addr low
    lda CC_TEMP2
    adc CC_TEMP4             ; carry from lo
    clc
    adc PM_PCODE_BASE[15:8]
    sta CC_SRC_LINE          ; string addr high

    ; Compute patch target = PM_PCODE_BASE + code_pos
    pla                      ; code_pos_hi
    clc
    adc PM_PCODE_BASE[15:8]
    tad
    pla                      ; code_pos_lo
    clc
    adc PM_PCODE_BASE[7:0]
    tae

    ; Write string address at patch target
    ldx 0x00
    lda CC_SRC_COL
    sta de,x
    inx
    lda CC_SRC_LINE
    sta de,x

    inc CC_FOR_VAR
    jmp .cc_fin_patch_loop

.cc_fin_header:
    ; Reset fixup stack
    lda 0x00
    sta CC_FIX_SP

    ; Write P-code header at PM_PCODE_BASE
    ldd PM_PCODE_BASE[15:8]
    lde PM_PCODE_BASE[7:0]
    ldx 0x00
    lda PM_MAGIC_P
    sta de,x                 ; offset 0: 'P'
    inx
    lda PM_MAGIC_M
    sta de,x                 ; offset 1: 'M'
    inx
    lda 0x01
    sta de,x                 ; offset 2: version
    inx
    lda 0x07
    sta de,x                 ; offset 3: code_off low
    inx
    lda 0x00
    sta de,x                 ; offset 4: code_off high
    inx
    lda CC_TEMP1
    sta de,x                 ; offset 5: data_off low
    inx
    lda CC_TEMP2
    sta de,x                 ; offset 6: data_off high
    rts

; ── Error handling ───────────────────────────────────────

.cc_error_a:
    ; Input: A = error message index (0..8). Keep index on stack until after I/O.
    pha
    lda 0x01
    sta CC_ERROR
    lda CC_SRC_LINE
    sta CC_ERR_LINE

    ; Print "Err line N: "
    jsr ACIA_SEND_NEWLINE
    ldy .cc_err_prefix[23:16]
    ldd .cc_err_prefix[15:8]
    lde .cc_err_prefix[7:0]
    jsr ACIA_SEND_STRING24
    lda CC_ERR_LINE
    jsr ACIA_SEND_DECIMAL
    lda 0x3A
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR

    ; Print error message from table (same bank as .cc_err_prefix)
    pla
    tax
    ldy .cc_errtab_hi[23:16]
    ldd .cc_errtab_hi[15:8]
    lde .cc_errtab_hi[7:0]
    lda yde,x
    tad
    ldd .cc_errtab_lo[15:8]
    lde .cc_errtab_lo[7:0]
    lda yde,x
    tae
    ldy .cc_err_prefix[23:16]
    jsr ACIA_SEND_STRING24
    jsr ACIA_SEND_NEWLINE
    rts

; Error message index constants
.cc_e_no_src  = 0
.cc_e_program = 1
.cc_e_dot     = 2
.cc_e_undef   = 3
.cc_e_syntax  = 4
.cc_e_expect  = 5
.cc_e_expr    = 6
.cc_e_string  = 7
.cc_e_const   = 8

.cc_errtab_lo:
    #d .cc_em0[7:0]
    #d .cc_em1[7:0]
    #d .cc_em2[7:0]
    #d .cc_em3[7:0]
    #d .cc_em4[7:0]
    #d .cc_em5[7:0]
    #d .cc_em6[7:0]
    #d .cc_em7[7:0]
    #d .cc_em8[7:0]

.cc_errtab_hi:
    #d .cc_em0[15:8]
    #d .cc_em1[15:8]
    #d .cc_em2[15:8]
    #d .cc_em3[15:8]
    #d .cc_em4[15:8]
    #d .cc_em5[15:8]
    #d .cc_em6[15:8]
    #d .cc_em7[15:8]
    #d .cc_em8[15:8]

; ── Keyword table ────────────────────────────────────────

.cc_kw_table:
    #d "program", 0x00, CC_TK_PROGRAM
    #d "begin", 0x00, CC_TK_BEGIN
    #d "end", 0x00, CC_TK_END
    #d "var", 0x00, CC_TK_VAR
    #d "integer", 0x00, CC_TK_INTEGER
    #d "if", 0x00, CC_TK_IF
    #d "then", 0x00, CC_TK_THEN
    #d "else", 0x00, CC_TK_ELSE
    #d "while", 0x00, CC_TK_WHILE
    #d "do", 0x00, CC_TK_DO
    #d "for", 0x00, CC_TK_FOR
    #d "to", 0x00, CC_TK_TO
    #d "downto", 0x00, CC_TK_DOWNTO
    #d "write", 0x00, CC_TK_WRITE
    #d "writeln", 0x00, CC_TK_WRITELN
    #d "readln", 0x00, CC_TK_READLN
    #d "div", 0x00, CC_TK_DIV
    #d "mod", 0x00, CC_TK_MOD
    #d "and", 0x00, CC_TK_AND
    #d "or", 0x00, CC_TK_OR
    #d "not", 0x00, CC_TK_NOT
    #d "procedure", 0x00, CC_TK_PROCEDURE
    #d "function", 0x00, CC_TK_FUNCTION
    #d "array", 0x00, CC_TK_ARRAY
    #d "of", 0x00, CC_TK_OF
    #d "const", 0x00, CC_TK_CONST
    #d "repeat", 0x00, CC_TK_REPEAT
    #d "until", 0x00, CC_TK_UNTIL
    #d "chr", 0x00, CC_TK_CHR
    #d "ord", 0x00, CC_TK_ORD
    #d "abs", 0x00, CC_TK_ABS
    #d "odd", 0x00, CC_TK_ODD
    #d "random", 0x00, CC_TK_RANDOM
    #d "real", 0x00, CC_TK_REAL
    #d "peek", 0x00, CC_TK_PEEK
    #d "poke", 0x00, CC_TK_POKE
    #d "string", 0x00, CC_TK_STRING_TYPE
    #d "delay", 0x00, CC_TK_DELAY
    #d "vt100_pos", 0x00, CC_TK_VT100_POS
    #d "vt100_scroll", 0x00, CC_TK_VT100_SCROLL
    #d "vt100", 0x00, CC_TK_VT100
    #d "length", 0x00, CC_TK_LENGTH
    #d 0x00                  ; sentinel

; ── Compiler strings ─────────────────────────────────────

.cc_err_prefix:
    #d "Err L", 0x00

.cc_em0:
    #d "no src", 0x00
.cc_em1:
    #d "exp program", 0x00
.cc_em2:
    #d "exp '.'", 0x00
.cc_em3:
    #d "undef var", 0x00
.cc_em4:
    #d "syntax", 0x00
.cc_em5:
    #d "expect", 0x00
.cc_em6:
    #d "exp expr", 0x00
.cc_em7:
    #d "bad string", 0x00
.cc_em8:
    #d "const assign", 0x00
