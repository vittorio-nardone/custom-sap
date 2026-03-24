#once

; ============================================================
; KERNEL RAM ALLOCATION MAP (0x8000 - 0x83FF)
;
; All kernel modules MUST define their RAM variables here.
; Addresses are listed in ascending order.
; Each entry indicates the owning module.
; ============================================================

; --- 0x8000-0x801A: Main Menu (kernel.asm) -------------------
#const MAIN_MENU_STATUS              = 0x8000  ; 1 byte
#const MAIN_MENU_INPUT_BUFFER_COUNT  = 0x8001  ; 1 byte
#const MAIN_MENU_ADDR_PAGE           = 0x8002  ; 1 byte
#const MAIN_MENU_ADDR_MSB            = 0x8003  ; 1 byte
#const MAIN_MENU_ADDR_LSB            = 0x8004  ; 1 byte
#const MAIN_MENU_DUMP_COUNT          = 0x8005  ; 1 byte
#const MAIN_MENU_OPCODE_MSB          = 0x8006  ; 1 byte
#const MAIN_MENU_OPCODE_LSB          = 0x8007  ; 1 byte
#const MAIN_MENU_OPCODE_LENGTH       = 0x8008  ; 1 byte
#const MAIN_MENU_OPCODE_LENGTH_2     = 0x8009  ; 1 byte
#const MAIN_MENU_OPCODE_PTR          = 0x800A  ; 1 byte
#const MAIN_MENU_INPUT_BUFFER        = 0x800B  ; 16 bytes (0x800B-0x801A)

; --- 0x80C0-0x80CB: Float Read temp (float.asm) --------------
#const FR_VALUE    = 0x80C0  ; 4 bytes (0x80C0-0x80C3)
#const FR_FRAC_CNT = 0x80C4  ; 1 byte
#const FR_SIGN     = 0x80C5  ; 1 byte
#const FR_HAS_DOT  = 0x80C6  ; 1 byte
#const FR_DIGIT    = 0x80C7  ; 1 byte
#const FR_TMP      = 0x80C8  ; 4 bytes (0x80C8-0x80CB)

; --- 0x80D0-0x80D5: Float Print temp (float.asm) -------------
#const FP_DECIMALS = 0x80D0  ; 1 byte
#const FP_SAVE     = 0x80D1  ; 4 bytes (0x80D1-0x80D4)
#const FP_TEMP     = 0x80D5  ; 1 byte

; --- 0x801B-0x801C: Math16 work area (math.asm) ----------------
#const MATH16_WORK    = 0x801B  ; 2 bytes (0x801B-0x801C) - work area for MUL16S/DIV16S

; --- 0x80D6-0x80D9: Math / float conversion temp -------------
#const MUL_TMP        = 0x80D6  ; 3 bytes (0x80D6-0x80D8) - MULTIPLY_INT temp (math.asm)
#const FLOAT_SIGN_TMP = 0x80D9  ; 1 byte  - sign temp for float conversion

; --- 0x80DA-0x80DF: Math16 signed 16-bit operands (math.asm) --
#const MATH16_A       = 0x80DA  ; 2 bytes (LSB=+0, MSB=+1) — operand A / result
#const MATH16_B       = 0x80DC  ; 2 bytes (LSB=+0, MSB=+1) — operand B
#const MATH16_SIGN    = 0x80DE  ; 1 byte  — sign tracking
#const MATH16_TMP     = 0x80DF  ; 1 byte  — temporary

; --- 0x80E0-0x80EF: Float MUL/ADD/DIV shared temp (float.asm)
; WARNING: reused by MUL, ADD, SUB, DIV — never called together

; MUL layout:
#const FML_SIGN  = 0x80E0  ; 1 byte
#const FML_EXP   = 0x80E1  ; 2 bytes (L=+0, H=+1)
#const FML_M1    = 0x80E3  ; 3 bytes (H=+0, M=+1, L=+2)
#const FML_M2    = 0x80E6  ; 3 bytes (H=+0, M=+1, L=+2)
#const FML_RES   = 0x80E9  ; 4 bytes (R5=+0, R4=+1, R3=+2, R2=+3)

; ADD layout (same physical memory):
#const FAD_SIGN1 = 0x80E0  ; 1 byte
#const FAD_SIGN2 = 0x80E1  ; 1 byte
#const FAD_EXP1  = 0x80E2  ; 1 byte
#const FAD_EXP2  = 0x80E3  ; 1 byte
#const FAD_M1    = 0x80E4  ; 3 bytes (H=+0, M=+1, L=+2)
#const FAD_M2    = 0x80E7  ; 3 bytes (H=+0, M=+1, L=+2)
#const FAD_CARRY = 0x80EA  ; 1 byte

; DIV layout (same physical memory):
#const FDV_SIGN  = 0x80E0  ; 1 byte
#const FDV_EXP   = 0x80E1  ; 2 bytes (L=+0, H=+1)
#const FDV_M1    = 0x80E3  ; 3 bytes (H=+0, M=+1, L=+2)
#const FDV_M2    = 0x80E6  ; 3 bytes (H=+0, M=+1, L=+2)
#const FDV_Q     = 0x80E9  ; 3 bytes (H=+0, M=+1, L=+2)
#const FDV_R     = 0x80EC  ; 3 bytes (H=+0, M=+1, L=+2)
#const FDV_CARRY = 0x80EF  ; 1 byte

; --- 0x80F0-0x80FF: Float operands / conversion (float.asm, math.asm)
#const FLOAT2         = 0x80F0  ; 4 bytes (0x80F0-0x80F3) - 2nd float operand
;      0x80F4                   ; 1 byte  — unused
#const FLOAT_INT32    = 0x80F5  ; 4 bytes (0x80F5-0x80F8) - 32-bit int conversion
#const ITF_TMP        = 0x80F9  ; 2 bytes (0x80F9-0x80FA) - INT_TO_FLOAT temp
#const FLOAT1         = 0x80FB  ; 4 bytes (0x80FB-0x80FE) - main float operand/result

; --- 0x8120-0x812F: VT100 buffer (vt100.asm) -----------------
#const VT100_BUFFER = 0x8120  ; 16 bytes (0x8120-0x812F)

; --- 0x8200-0x8283: XMODEM receive buffer (xmodem.asm) -------
#const XMODEM_RECEIVE_BUFFER = 0x8200  ; 132 bytes (0x8200-0x8283)

; --- 0x8337-0x833F: XMODEM variables (xmodem.asm) ------------
#const XMODEM_CRC             = 0x8337  ; 2 bytes (lo=+0, hi=+1)
#const XMODEM_PTRP            = 0x8339  ; 1 byte  - data pointer (page)
#const XMODEM_PTRH            = 0x833A  ; 1 byte  - data pointer (high)
#const XMODEM_PTR             = 0x833B  ; 1 byte  - data pointer (low)
#const XMODEM_BLK_NO          = 0x833C  ; 1 byte
#const XMODEM_RETRY_COUNTER   = 0x833D  ; 1 byte
#const XMODEM_RETRY_COUNTER2  = 0x833E  ; 1 byte
#const XMODEM_BLOCK_FLAG      = 0x833F  ; 1 byte

; --- 0x8340-0x834D: Utility variables (utils.asm) ------------
#const BINDEC32_VALUE  = 0x8340  ; 4 bytes (0x8340-0x8343)
#const BINDEC32_RESULT = 0x8344  ; 10 bytes (0x8344-0x834D)

; --- 0x83F1-0x83F5: ACIA RX buffer (serial.asm) --------------
#const ACIA_1_RX_BUFFER_AVAILABLE  = 0x83F1  ; 1 byte
#const ACIA_1_RX_BUFFER_PULL_INDEX = 0x83F2  ; 1 byte
#const ACIA_1_RX_BUFFER_PUSH_INDEX = 0x83F3  ; 1 byte
#const ACIA_1_RX_BUFFER_POINTER    = 0x83F4  ; 2 bytes (0x83F4-0x83F5)

; --- 0x83F6-0x83FF: Interrupt / Timer (interrupt.asm) --------
#const INT_TIMER_COUNTER_MSB        = 0x83F6  ; 1 byte
#const INT_TIMER_COUNTER_LSB        = 0x83F7  ; 1 byte
#const INT_EXTINT1_HANDLER_POINTER  = 0x83F8  ; 2 bytes (0x83F8-0x83F9)
#const INT_EXTINT2_HANDLER_POINTER  = 0x83FA  ; 2 bytes (0x83FA-0x83FB)
#const INT_TIMER_HANDLER_POINTER    = 0x83FC  ; 2 bytes (0x83FC-0x83FD)
#const INT_KEYBOARD_HANDLER_POINTER = 0x83FE  ; 2 bytes (0x83FE-0x83FF)
