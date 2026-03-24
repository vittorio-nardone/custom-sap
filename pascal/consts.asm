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

; --- Eval stack (0xB100-0xB1FF, 256 bytes, grows upward) ----
#const PM_EVAL_STACK = 0xB100

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
#const PM_OP_CSP    = 0x10  ; call standard procedure

; ============================================================
; CSP STANDARD PROCEDURE NUMBERS
; ============================================================
#const PM_CSP_WRITE         = 0x00  ; write(string)
#const PM_CSP_WRITELN       = 0x01  ; writeln(string)
#const PM_CSP_WRITELN_NOARG = 0x02  ; writeln()
