#once

; ============================================================
; P-MACHINE CONSTANTS AND RAM ALLOCATION
;
; RAM layout (0xB000-0xB1FF) — same area previously used by Forth
; ============================================================

; P-code base address (where P-code binaries are loaded)
#const PM_PCODE_BASE = 0x8400

; --- Internal state variables (0xB000-0xB00F) ---------------
#const PM_IP_MSB   = 0xB000  ; 1 byte - instruction pointer MSB
#const PM_IP_LSB   = 0xB001  ; 1 byte - instruction pointer LSB
#const PM_ESP      = 0xB002  ; 1 byte - eval stack offset
#const PM_TEMP     = 0xB003  ; 1 byte - temporary storage
#const PM_BASE_MSB = 0xB004  ; 1 byte - P-code base address MSB
#const PM_BASE_LSB = 0xB005  ; 1 byte - P-code base address LSB
#const PM_TEMP2    = 0xB006  ; 1 byte - second temporary (used by JPC)
#const PM_FP_MSB   = 0xB007  ; 1 byte - frame pointer MSB
#const PM_FP_LSB   = 0xB008  ; 1 byte - frame pointer LSB
#const PM_CSP_PTR  = 0xB009  ; 1 byte - call stack pointer (4 bytes/entry, max 64)
#const PM_FTOP_MSB = 0xB00A  ; 1 byte - frame top MSB (next free byte in data stack)
#const PM_FTOP_LSB = 0xB00B  ; 1 byte - frame top LSB
#const PM_TEMP3    = 0xB00C  ; 1 byte - third temporary (follow static links)
#const PM_DISPATCH = 0xB00D  ; 2 bytes - dispatch jump target (MSB, LSB)

; --- Eval stack (0xB100-0xB1FF, 256 bytes, grows upward) ----
;     Each value is 16-bit (2 bytes: LSB at lower offset, MSB at higher).
;     Max 128 values.
#const PM_EVAL_STACK = 0xB100

; --- Variable frame (0xB200-0xB3FF, 512 bytes) ---------------
;     Scalars: 2 bytes each. Strings: 81 bytes (len + 80 chars).
;     Indexed by byte offset from FP (FP points into this region).
#const PM_VAR_FRAME = 0xB200
#const PM_VAR_FRAME_SIZE = 0x0200  ; 512 bytes

; --- Call info stack (0xBA00-0xBAFF, 256 bytes) ---------------
;     Each entry = 4 bytes: IP_MSB, IP_LSB, FP_MSB, FP_LSB.
;     Max 64 call levels.
#const PM_CALL_STACK = 0xBA00

; ============================================================
; P-CODE BINARY HEADER
; ============================================================
#const PM_MAGIC_P = 0x50    ; 'P'
#const PM_MAGIC_M = 0x4D    ; 'M'

; ============================================================
; P-CODE OPCODES
; ============================================================
#const PM_OP_HALT   = 0x00  ; stop execution
#const PM_OP_LIT    = 0x01  ; push 8-bit literal
#const PM_OP_LIT16  = 0x02  ; push 16-bit literal (LE)
#const PM_OP_LOAD   = 0x03  ; push variable at byte offset
#const PM_OP_STORE  = 0x04  ; pop -> variable at byte offset
#const PM_OP_ADD    = 0x05  ; pop b16, pop a16, push a+b
#const PM_OP_SUB    = 0x06  ; pop b16, pop a16, push a-b
#const PM_OP_MUL    = 0x07  ; pop b16, pop a16, push a*b (signed)
#const PM_OP_DIV    = 0x08  ; pop b16, pop a16, push a div b (signed)
#const PM_OP_NEG    = 0x09  ; pop a16, push -a
#const PM_OP_MOD    = 0x0A  ; pop b16, pop a16, push a mod b (signed)
#const PM_OP_JMP    = 0x0B  ; JMP offset16 — unconditional jump
#const PM_OP_JPC    = 0x0C  ; JPC offset16 — jump if false (top=0)
#const PM_OP_EQ     = 0x0D  ; pop b, pop a, push (a = b)
#const PM_OP_NE     = 0x0E  ; pop b, pop a, push (a <> b)
#const PM_OP_LT     = 0x0F  ; pop b, pop a, push (a < b) signed
#const PM_OP_CSP    = 0x10  ; call standard procedure
#const PM_OP_GE     = 0x11  ; pop b, pop a, push (a >= b) signed
#const PM_OP_GT     = 0x12  ; pop b, pop a, push (a > b) signed
#const PM_OP_LE     = 0x13  ; pop b, pop a, push (a <= b) signed
#const PM_OP_AND    = 0x14  ; pop b, pop a, push (a and b) logical
#const PM_OP_OR     = 0x15  ; pop b, pop a, push (a or b) logical
#const PM_OP_NOT    = 0x16  ; pop a, push (not a) logical
#const PM_OP_CALL   = 0x17  ; addr_lo, addr_hi, static_depth — call procedure/function
#const PM_OP_ENTER  = 0x18  ; frame_size, nparams, is_function — set up activation record
#const PM_OP_RET    = 0x19  ; is_function — return from procedure/function
#const PM_OP_LOAD_L = 0x1A  ; level, offset — load via static chain
#const PM_OP_STORE_L= 0x1B  ; level, offset — store via static chain
#const PM_OP_LOAD_A = 0x1C  ; adjusted_base — load array element (FP-relative)
#const PM_OP_STORE_A= 0x1D  ; adjusted_base — store array element (FP-relative)
#const PM_OP_LOAD_AL= 0x1E  ; depth, adjusted_base — load array element via static chain
#const PM_OP_STORE_AL=0x1F  ; depth, adjusted_base — store array element via static chain
#const PM_OP_ABS    = 0x20  ; pop a16, push abs(a)
#const PM_OP_LOAD_REF  = 0x21  ; offset — load via reference (indirect through frame pointer)
#const PM_OP_STORE_REF = 0x22  ; offset — store via reference
#const PM_OP_PUSH_ADDR = 0x23  ; offset — push FP+offset as address
#const PM_OP_PUSH_ADDR_L=0x24  ; depth, offset — push target_FP+offset via static chain
#const PM_OP_ENTER16 = 0x25    ; frame_size_lo, frame_size_hi, nparams, is_function — large frames
#const PM_OP_LOADW   = 0x26    ; offset16 LE — push 16-bit variable (FP-relative)
#const PM_OP_STOREW  = 0x27    ; offset16 LE — pop 16-bit into variable (FP-relative)

; --- Float opcodes (0x30-0x3C) --------------------------------
#const PM_OP_FLIT    = 0x30  ; push 4-byte IEEE 754 float literal
#const PM_OP_FLOAD   = 0x31  ; load 4-byte float from FP+offset
#const PM_OP_FSTORE  = 0x32  ; pop and store 4-byte float to FP+offset
#const PM_OP_FADD    = 0x33  ; pop b(4B), pop a(4B), push a+b
#const PM_OP_FSUB    = 0x34  ; pop b(4B), pop a(4B), push a-b
#const PM_OP_FMUL    = 0x35  ; pop b(4B), pop a(4B), push a*b
#const PM_OP_FDIV    = 0x36  ; pop b(4B), pop a(4B), push a/b
#const PM_OP_FNEG    = 0x37  ; pop float(4B), flip sign, push
#const PM_OP_ITOF    = 0x38  ; pop int16(2B), convert to float, push float(4B)
#const PM_OP_FTOI    = 0x39  ; pop float(4B), truncate to int, push int16(2B)
#const PM_OP_FCMP    = 0x3A  ; pop b(4B), pop a(4B), push int16 (-1/0/1)
#const PM_OP_FLOAD_L = 0x3B  ; depth, offset — load float via static chain
#const PM_OP_FSTORE_L= 0x3C  ; depth, offset — store float via static chain
#const PM_OP_FABS    = 0x3D  ; pop float(4B), clear sign, push float(4B)
#const PM_OP_ITOF_SWAP = 0x3E ; swap: pop float(4B), pop int(2B), convert int→float, push both back

; ============================================================
; CSP STANDARD PROCEDURE NUMBERS
; ============================================================
#const PM_CSP_WRITE         = 0x00  ; write(string)
#const PM_CSP_WRITELN       = 0x01  ; writeln(string)
#const PM_CSP_WRITELN_NOARG = 0x02  ; writeln()
#const PM_CSP_WRITE_INT     = 0x03  ; write(integer) — decimal output
#const PM_CSP_WRITELN_INT   = 0x04  ; writeln(integer) — decimal + newline
#const PM_CSP_READLN_INT    = 0x05  ; readln(integer) — read decimal, push on eval stack
#const PM_CSP_WRITE_CHAR    = 0x06  ; write(chr(expr)) — pop 16-bit, print low byte as char
#const PM_CSP_WRITE_REAL    = 0x07  ; write(real) — pop float(4B), print decimal
#const PM_CSP_WRITELN_REAL  = 0x08  ; writeln(real) — pop float(4B), print + newline
#const PM_CSP_READLN_REAL   = 0x09  ; readln(real) — read float, push float(4B)
#const PM_CSP_RANDOM        = 0x0A  ; random — push random integer (0..32767)
#const PM_CSP_PEEK          = 0x0B  ; peek(addr) — pop addr, read byte, push 16-bit (0:byte)
#const PM_CSP_POKE          = 0x0C  ; poke(addr,val) — pop val, pop addr, write low byte
#const PM_CSP_VT100         = 0x0D  ; fetch subcode; optional pops — kernel VT100
#const PM_CSP_WAIT_MS       = 0x0E  ; pop ms(16) — busy-wait delay
#const PM_CSP_READLN_STR    = 0x0F  ; fetch FP offset — read line into string buffer
#const PM_CSP_WRITE_STR     = 0x10  ; fetch FP offset — write string var
#const PM_CSP_WRITELN_STR   = 0x11  ; fetch FP offset — writeln string var
#const PM_CSP_STR_EQ        = 0x12  ; fetch off1, off2 — push 0/1
#const PM_CSP_STR_ASSIGN_LIT= 0x13  ; fetch dst_off, src_lo, src_hi — copy from pool
#const PM_CSP_STR_COPY      = 0x14  ; fetch dst_off, src_off — copy string var
#const PM_CSP_LENGTH        = 0x15  ; fetch FP offset — push length as int

; ============================================================
; EDITOR CONSTANTS
; ============================================================

; Editor scratch RAM (reuses PM_EVAL_STACK area, unused during editing)
#const ED_CMD_BUF     = 0xB100  ; 20 bytes: command input buffer
#const ED_CMD_LEN     = 0xB114  ; 1 byte: command buffer length
#const ED_LINE_BUF    = 0xB120  ; 80 bytes: primary line buffer
#const ED_RL_LEN      = 0xB170  ; 1 byte: read_line result length
#const ED_RL_MAX      = 0xB171  ; 1 byte: read_line max length
#const ED_RL_BUF_H    = 0xB172  ; 1 byte: read_line buffer addr MSB
#const ED_RL_BUF_L    = 0xB173  ; 1 byte: read_line buffer addr LSB
#const ED_NUM1        = 0xB174  ; 1 byte: parsed argument 1
#const ED_NUM2        = 0xB175  ; 1 byte: parsed argument 2
#const ED_HAS_NUM1    = 0xB176  ; 1 byte: flag
#const ED_HAS_NUM2    = 0xB177  ; 1 byte: flag
#const ED_PARSE_POS   = 0xB178  ; 1 byte: parse position in cmd buffer
#const ED_PARSE_TMP   = 0xB179  ; 1 byte: digit accumulator
#const ED_PARSE_FLAG  = 0xB17A  ; 1 byte: has-digits flag
#const ED_LINE_COUNT  = 0xB17B  ; 1 byte: cached line count
#const ED_CUR_LINE    = 0xB17C  ; 1 byte: current line in loop
#const ED_INS_COUNT   = 0xB17D  ; 1 byte: insert/delete counter
#const ED_SHIFT_ITER  = 0xB17E  ; 1 byte: shift loop iterator
#const ED_SHIFT_FROM  = 0xB17F  ; 1 byte: shift start position

; Secondary line buffer (reuses PM_VAR_FRAME, unused during editing)
#const ED_LINE_BUF2   = 0xB200  ; 80 bytes: secondary line buffer

; Source storage parameters
#const ED_LINE_SIZE   = 80
; Max chars per .ed_read_line into ED_LINE_BUF (room for NUL before ED_RL_LEN at 0xB170)
#const ED_LINE_INPUT_MAX = 79
#const ED_MAX_LINES   = 255
#const ED_SRC_PAGE    = 0x01

; ============================================================
; COMPILER CONSTANTS
; ============================================================

; Compiler state (reuses PM_EVAL_STACK area during compilation)
#const CC_SRC_LINE    = 0xB100  ; current source line (1-based)
#const CC_SRC_COL     = 0xB101  ; current column (0-based)
#const CC_TOKEN_TYPE  = 0xB102  ; current token type
#const CC_TOKEN_LEN   = 0xB103  ; token string length
#const CC_TOKEN_NUM_LO= 0xB104  ; token numeric value low
#const CC_TOKEN_NUM_HI= 0xB105  ; token numeric value high
#const CC_ERROR       = 0xB106  ; error flag (0=ok)
#const CC_ERR_LINE    = 0xB107  ; error line number
#const CC_CODE_LO     = 0xB108  ; P-code output offset low
#const CC_CODE_HI     = 0xB109  ; P-code output offset high
#const CC_SYM_COUNT   = 0xB10A  ; symbol table entry count
#const CC_SCOPE_LEVEL = 0xB10B  ; current scope depth
#const CC_FIX_SP      = 0xB10C  ; fixup stack pointer
#const CC_STR_OFF_LO  = 0xB10D  ; string pool offset low
#const CC_STR_OFF_HI  = 0xB10E  ; string pool offset high
#const CC_FRAME_OFF   = 0xB10F  ; next free byte in frame (LSB)
#const CC_FRAME_OFF_HI = 0xB1A0 ; frame size MSB (512-byte frames; eval upper scratch)
#const CC_TOTAL_LINES = 0xB110  ; total source lines
#const CC_TEMP1       = 0xB111  ; temp
#const CC_TEMP2       = 0xB112  ; temp
#const CC_TEMP3       = 0xB113  ; temp
#const CC_TEMP4       = 0xB114  ; temp
#const CC_SUB_COUNT   = 0xB115  ; subroutine count (Phase 3)
#const CC_FOR_VAR     = 0xB116  ; for loop variable offset / str copy index lo
#const CC_FOR_VAR_HI  = 0xB1E5  ; str copy index hi (16-bit extension, finalize only)
#const CC_SCOPE_SP    = 0xB117  ; scope stack pointer (Phase 3)
#const CC_FOR_LIMIT   = 0xB118  ; for loop limit temp offset
#const CC_FOR_DIR     = 0xB119  ; for loop direction (0=to, 1=downto)
#const CC_KW_PTR_LO   = 0xB11A  ; keyword table pointer low
#const CC_KW_PTR_HI   = 0xB11B  ; keyword table pointer high
#const CC_STR_FIX_SP  = 0xB11C  ; string fixup stack pointer
#const CC_ENTER_LO    = 0xB11D  ; ENTER frame_size patch position low
#const CC_ENTER_HI    = 0xB11E  ; ENTER frame_size patch position high
; Bytes 10/15 from cc_find_sym — must not overlap ED_LINE_BUF (0xB120..0xB16F) or ED_RL_LEN (0xB170)
#const CC_FOUND_B10   = 0xB1CE
#const CC_FOUND_B15   = 0xB1CF
; Reuse editor parse vars (unused during compilation) at 0xB174+
#const CC_FOUND_KIND  = 0xB174  ; result from cc_find_sym: kind
#const CC_FOUND_SCOPE = 0xB175  ; result from cc_find_sym: scope_level
#const CC_FOUND_ARG1  = 0xB176  ; extra: code_hi/array_low / offset hi (aliases ED_HAS_NUM1)
#const CC_FOUND_ARG2  = 0xB177  ; extra: param_count/array_high
#const CC_FOUND_ARG3  = 0xB178  ; extra: definition_level
#const CC_IS_FUNC     = 0xB179  ; current subroutine is function flag
#const CC_SAVED_SYMCNT= 0xB17A  ; saved symbol count before entering sub scope
#const CC_FOUND_B14   = 0xB17B  ; byte 14 from cc_find_sym (var param flag, reuses ED_LINE_COUNT)
#const CC_PARAM_VAR   = 0xB17C  ; temp: current param is var (during param parsing, reuses ED_CUR_LINE)
#const CC_EXPR_TYPE   = 0xB17D  ; expression type: 0=integer, 1=real, 2=string (relational only)
#const CC_VAR_TYPE    = 0xB17E  ; current var block type: 0=integer, 1=real, 2=string
#const CC_FUNC_RET    = 0xB17F  ; function return type: 0=integer, 2=real (matches is_func encoding)
; String compare temps (compile-only; top of 0xB100 eval stack region, unused while PM idle)
#const CC_STR_REL_PASS = 0xB1F4 ; 0=normal expr, 1=left op of str rel, 2=right op (if/while/until)
#const CC_SREL_O1_LO  = 0xB1F5
#const CC_SREL_O1_HI  = 0xB1F6
#const CC_SREL_O2_LO  = 0xB1F7
#const CC_SREL_O2_HI  = 0xB1F8

; Saved param names while parsing (ident[,ident]: type); up to 4 names × 8 bytes
; 0xB1D0-0xB1EF: CC_PARAM_NAME_TMP slots (overlaps call-site temps, safe during decl)
#const CC_PARAM_NAME_TMP = 0xB1D0
#const CC_PARAM_NAME_CNT = 0xB1F0 ; how many names collected before ': type'
#const CC_FOUND_SYM_IDX  = 0xB1D8  ; index from last cc_find_sym
#const CC_CALLEE_SYM_IDX = 0xB1D9  ; callee proc/func symbol index during cc_call_args
#const CC_CALLEE_NPARAM  = 0xB1DA  ; callee param count (byte 12) saved at call start
#const CC_CALL_ARG_IDX   = 0xB1DB  ; which formal (0..n-1) while emitting call args
#const CC_STR_POOL_START_LO = 0xB1DC ; pool offset for literal matched to next str fixup
#const CC_STR_POOL_START_HI = 0xB1DD
#const CC_SREL_OP        = 0xB1DE ; saved EQ/NE while emitting STR_EQ (compile-only)
#const CC_SREL_EMIT_LO   = 0xB1DF ; STR_EQ operand snapshot (not CC_KW_PTR — keyword scan clobbers it)
#const CC_SREL_EMIT_HI   = 0xB1E0
#const CC_STR_EQ_TMP_LO  = 0xB1E1 ; STR_ASSIGN_LIT dst for string-compare temp (emit STR_EQ)
#const CC_STR_EQ_TMP_HI  = 0xB1E2
#const CC_ES_ARG1_SAVE   = 0xB1E3 ; saved CC_FOUND_ARG1 (offset hi) for .cc_emit_scoped
#const CC_PARAM_TYPE_MASK= 0xB1E4 ; bitmask: bit N=1 → param N is real (for callee type lookup)

; Symbol kind constants
#const CC_KIND_SCALAR = 0x00
#const CC_KIND_ARRAY  = 0x01
#const CC_KIND_PROC   = 0x02
#const CC_KIND_FUNC   = 0x03
#const CC_KIND_CONST  = 0x04

; Token string buffer (32 bytes)
#const CC_TOKEN_BUF   = 0xB180

; Token types
#const CC_TK_EOF      = 0x00
#const CC_TK_IDENT    = 0x01
#const CC_TK_NUMBER   = 0x02
#const CC_TK_STRING   = 0x03
#const CC_TK_PLUS     = 0x04
#const CC_TK_MINUS    = 0x05
#const CC_TK_STAR     = 0x06
#const CC_TK_LPAREN   = 0x07
#const CC_TK_RPAREN   = 0x08
#const CC_TK_SEMI     = 0x09
#const CC_TK_COMMA    = 0x0A
#const CC_TK_ASSIGN   = 0x0B
#const CC_TK_COLON    = 0x0C
#const CC_TK_DOT      = 0x0D
#const CC_TK_EQ       = 0x0E
#const CC_TK_NE       = 0x0F
#const CC_TK_LT       = 0x10
#const CC_TK_GT       = 0x11
#const CC_TK_LE       = 0x12
#const CC_TK_GE       = 0x13
#const CC_TK_LBRACKET = 0x14
#const CC_TK_RBRACKET = 0x15
#const CC_TK_DOTDOT   = 0x16
#const CC_TK_SLASH    = 0x17
#const CC_TK_FLOAT_LIT= 0x18
; Keywords (0x40+)
#const CC_TK_PROGRAM  = 0x40
#const CC_TK_BEGIN    = 0x41
#const CC_TK_END      = 0x42
#const CC_TK_VAR      = 0x43
#const CC_TK_INTEGER  = 0x44
#const CC_TK_IF       = 0x45
#const CC_TK_THEN     = 0x46
#const CC_TK_ELSE     = 0x47
#const CC_TK_WHILE    = 0x48
#const CC_TK_DO       = 0x49
#const CC_TK_FOR      = 0x4A
#const CC_TK_TO       = 0x4B
#const CC_TK_DOWNTO   = 0x4C
#const CC_TK_WRITE    = 0x4D
#const CC_TK_WRITELN  = 0x4E
#const CC_TK_READLN   = 0x4F
#const CC_TK_DIV      = 0x50
#const CC_TK_MOD      = 0x51
#const CC_TK_AND      = 0x52
#const CC_TK_OR       = 0x53
#const CC_TK_NOT      = 0x54
#const CC_TK_PROCEDURE= 0x55
#const CC_TK_FUNCTION = 0x56
#const CC_TK_ARRAY    = 0x57
#const CC_TK_OF       = 0x58
#const CC_TK_CONST    = 0x59
#const CC_TK_REPEAT   = 0x5A
#const CC_TK_UNTIL    = 0x5B
#const CC_TK_CHR      = 0x5C
#const CC_TK_ORD      = 0x5D
#const CC_TK_ABS      = 0x5E
#const CC_TK_ODD      = 0x5F
#const CC_TK_RANDOM   = 0x60
#const CC_TK_REAL     = 0x61
#const CC_TK_PEEK     = 0x62
#const CC_TK_POKE     = 0x63
#const CC_TK_STRING_TYPE = 0x64  ; keyword "string" (var type)
#const CC_TK_DELAY   = 0x65
#const CC_TK_VT100    = 0x66
#const CC_TK_VT100_POS = 0x67
#const CC_TK_VT100_SCROLL = 0x68
#const CC_TK_LENGTH   = 0x69

; Expansion RAM page 1 — compiler workspace (above editor source, see ED_SRC_PAGE)
; Page 2 (0x020000) reserved for TinyPascal IDE code loaded via XMODEM.
#const CC_WS_PAGE     = 0x01
#const CC_SYM_BASE    = 0x6000  ; symbol table at 0x016000
#const CC_SYM_ENTRY   = 16      ; bytes per symbol entry
#const CC_FIX_BASE    = 0x6C40  ; jump fixup table at 0x016C40 (64 entries max × 2B = 128B)
#const CC_FIX_ENTRY   = 2       ; bytes per fixup entry
#const CC_STR_FIX_BASE= 0x6CC0  ; string fixup table: 4 B/entry, 80 max (320B to 0x6E00)
#const CC_STR_FIX_MAX = 80      ; max string fixup entries
#const CC_STR_BASE    = 0x6E00  ; string pool at 0x016E00
