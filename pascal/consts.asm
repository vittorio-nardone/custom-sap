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

; --- Eval stack (0xB100-0xB1FF, 256 bytes, grows upward) ----
;     Each value is 16-bit (2 bytes: LSB at lower offset, MSB at higher).
;     Max 128 values.
#const PM_EVAL_STACK = 0xB100

; --- Variable frame (0xB200-0xB2FF, 256 bytes) ---------------
;     2 bytes per variable (16-bit signed), max 128 variables.
;     Indexed by byte offset (0, 2, 4, ...).
#const PM_VAR_FRAME = 0xB200

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

; ============================================================
; CSP STANDARD PROCEDURE NUMBERS
; ============================================================
#const PM_CSP_WRITE         = 0x00  ; write(string)
#const PM_CSP_WRITELN       = 0x01  ; writeln(string)
#const PM_CSP_WRITELN_NOARG = 0x02  ; writeln()
#const PM_CSP_WRITE_INT     = 0x03  ; write(integer) — decimal output
#const PM_CSP_WRITELN_INT   = 0x04  ; writeln(integer) — decimal + newline
#const PM_CSP_READLN_INT    = 0x05  ; readln(integer) — read decimal, push on eval stack
