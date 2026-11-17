#once

; ============================================================
; KERNEL RAM ALLOCATION MAP (0x8000 - 0x83FF)
;
; All kernel modules MUST define their RAM variables here.
; Addresses are listed in ascending order.
; Each entry indicates the owning module.
; ============================================================

; --- 0x8000-0x8008: Shell / menu state (kernel.asm, shell.asm) -
#const MAIN_MENU_STATUS              = 0x8000  ; 1 byte
#const MAIN_MENU_INPUT_BUFFER_COUNT  = 0x8001  ; 1 byte
#const MAIN_MENU_ADDR_PAGE           = 0x8002  ; 1 byte - working address page
#const MAIN_MENU_ADDR_MSB            = 0x8003  ; 1 byte
#const MAIN_MENU_ADDR_LSB            = 0x8004  ; 1 byte
#const MAIN_MENU_DUMP_COUNT          = 0x8005  ; 1 byte
#const ACIA_RDEC_SIGN                = 0x8006  ; 1 byte - sign flag (serial.asm)
#const ACIA_RDEC_COUNT               = 0x8007  ; 1 byte - digit count for backspace
#const MAIN_MENU_INPUT_CURSOR        = 0x8008  ; 1 byte - cursor in input buffer

; --- 0x8009-0x800A: Shell argc / scratch -----------------------
#const SHELL_ARGC                    = 0x8009  ; 1 byte - token count (0..4)
#const SHELL_FLAGS                   = 0x800A  ; 1 byte - SHELL_F_* 

; --- 0x800B-0x801A: free (legacy 16-byte input; moved) --------

; Input buffer relocated — see SHELL_INPUT_BUF at 0x834E
#const MAIN_MENU_INPUT_BUFFER        = 0x834E  ; alias: 40-byte shell input

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

; --- 0x8100-0x8101: Random generator state (random.asm) ------
#const RANDOM_STATE = 0x8100  ; 2 bytes (0x8100-0x8101) - LFSR 16-bit state (LSB, MSB)

; --- 0x8120-0x812F: VT100 buffer (vt100.asm) -----------------
#const VT100_BUFFER = 0x8120  ; 16 bytes (0x8120-0x812F)

; --- 0x8200-0x8283: XMODEM receive buffer (xmodem.asm) -------
#const XMODEM_RECEIVE_BUFFER = 0x8200  ; 132 bytes (0x8200-0x8283)

; --- 0x8333-0x833F: XMODEM variables (xmodem.asm) ------------
#const XMODEM_AUTO_ADDR       = 0x8333  ; 1 byte  - auto-detect address from OT header (0=no, 1=yes)
#const XMODEM_LOAD_PTRP       = 0x8334  ; 1 byte  - effective load address (page)
#const XMODEM_LOAD_PTRH       = 0x8335  ; 1 byte  - effective load address (high)
#const XMODEM_LOAD_PTR        = 0x8336  ; 1 byte  - effective load address (low)
#const XMODEM_CRC             = 0x8337  ; 2 bytes (lo=+0, hi=+1)
#const XMODEM_PTRP            = 0x8339  ; 1 byte  - data pointer (page)
#const XMODEM_PTRH            = 0x833A  ; 1 byte  - data pointer (high)
#const XMODEM_PTR             = 0x833B  ; 1 byte  - data pointer (low)
#const XMODEM_BLK_NO          = 0x833C  ; 1 byte
#const XMODEM_RETRY_COUNTER   = 0x833D  ; 1 byte
#const XMODEM_RETRY_COUNTER2  = 0x833E  ; 1 byte
#const XMODEM_BLOCK_FLAG      = 0x833F  ; 1 byte

; --- 0x8284-0x82AF: USB storage hot RX path (storage/burst.asm) ---
; These MUST stay below 0x10000 so the SEI burst uses 16-bit (zero page)
; operands: ACIA #2 has a 1-byte RX FIFO and 115200 baud leaves ~87us per
; byte, which 24-bit absolute addressing does not meet.
#const CH376_BUF        = 0x8284  ; 32 bytes (0x8284-0x82A3) - dir entry / scratch payload
#const CH376_CAP        = 0x82A4  ; 1 byte  - max bytes to keep in CH376_BUF
#const CH376_OVERRUN    = 0x82A5  ; 1 byte  - ACIA #2 status captured on burst failure
#const CH376_TMO_BYTE   = 0x82A6  ; 1 byte  - per-byte timeout counter (burst)
#const CH376_RDB_MODE   = 0x82A7  ; 1 byte  - 0 = into CH376_BUF, 1 = into CH376_DST_*
#const CH376_RD_LEFT    = 0x82A8  ; 1 byte  - bytes still expected in current burst
#const CH376_WIRE_LEN   = 0x82A9  ; 1 byte  - length byte announced by the chip
#const CH376_RD_LEN     = 0x82AA  ; 1 byte  - copy of WIRE_LEN for diagnostics
#const CH376_PULL_MODE  = 0x82AB  ; 1 byte  - last burst outcome marker
#const CH376_DST_PAGE   = 0x82AC  ; 1 byte  - burst destination (page)
#const CH376_DST_MSB    = 0x82AD  ; 1 byte  - burst destination (high)
#const CH376_DST_LSB    = 0x82AE  ; 1 byte  - burst destination (low)
#const CH376_WR_WANT    = 0x82AF  ; 1 byte  - bytes asked for in current BYTE_WRITE

; --- 0x82B0-0x82EF: USB storage state (kernel/storage/*.asm) ------
#const CH376_TMO         = 0x82B0  ; 2 bytes - UART timeout reload (lo, hi)
#const CH376_TMO_SAVE    = 0x82B2  ; 2 bytes - saved timeout during USB waits
#const CH376_SCRATCH     = 0x82B4  ; 1 byte
#const CH376_SCRATCH2    = 0x82B5  ; 1 byte
#const CH376_LAST_STATUS = 0x82B6  ; 1 byte  - last CH376 interrupt status
#const CH376_INT_FLAG    = 0x82B7  ; 1 byte  - always 0 (polling only, kept for driver parity)
#const CH376_INT_STATUS  = 0x82B8  ; 1 byte
#const CH376_REMAIN_LO   = 0x82B9  ; 1 byte  - bytes left to transfer (low)
#const CH376_REMAIN_HI   = 0x82BA  ; 1 byte  - bytes left to transfer (high)
#const CH376_LOADED_LO   = 0x82BB  ; 1 byte  - bytes transferred (low)
#const CH376_LOADED_HI   = 0x82BC  ; 1 byte  - bytes transferred (high)
#const CH376_TOTAL_LO    = 0x82BD  ; 1 byte  - requested transfer size (low)
#const CH376_TOTAL_HI    = 0x82BE  ; 1 byte  - requested transfer size (high)
#const CH376_STATUS      = 0x82BF  ; 1 byte  - STORAGE_ST_* flags
#const CH376_DEPTH       = 0x82C0  ; 1 byte  - directory nesting level (0 = root)
#const CH376_SELECT      = 0x82C1  ; 1 byte  - menu selection (1-based)
#const CH376_DOTDOT      = 0x82C2  ; 1 byte  - selected entry is ".."
#const CH376_ENTRY_FLAGS = 0x82C3  ; 1 byte  - CH376_ENTRY_FLAG_*
#const CH376_SIZE_0      = 0x82C4  ; 1 byte  - FAT size / hex input (LSB)
#const CH376_SIZE_1      = 0x82C5  ; 1 byte
#const CH376_SIZE_2      = 0x82C6  ; 1 byte
#const CH376_SIZE_3      = 0x82C7  ; 1 byte  - FAT size (MSB)
#const CH376_SAVE_PAGE   = 0x82C8  ; 1 byte  - save source address (page)
#const CH376_SAVE_MSB    = 0x82C9  ; 1 byte
#const CH376_SAVE_LSB    = 0x82CA  ; 1 byte
#const CH376_CMP_PAGE    = 0x82CB  ; 1 byte  - range check work area
#const CH376_CMP_MSB     = 0x82CC  ; 1 byte
#const CH376_CMP_LSB     = 0x82CD  ; 1 byte
#const CH376_CMP_TMP     = 0x82CE  ; 1 byte
#const CH376_RETRIES     = 0x82CF  ; 1 byte  - DISK_MOUNT retry counter
#const CH376_OT_AUTO     = 0x82D0  ; 1 byte  - 1 = take load address from OT header
#const CH376_OT_FLAG     = 0x82D1  ; 1 byte  - 1 = prepend OT header when saving
#const CH376_OT_FOUND    = 0x82D2  ; 1 byte  - 1 = OT header present in loaded file
#const CH376_PRELOAD     = 0x82D3  ; 1 byte  - bytes of file data sitting in CH376_BUF
#const CH376_FILE_COUNT  = 0x82D4  ; 1 byte  - entries listed in STORAGE_NAMES
#const CH376_ENUM_LEFT   = 0x82D5  ; 1 byte  - FILE_ENUM_GO budget
#const CH376_OPEN_ST     = 0x82D6  ; 1 byte  - status of the listing FILE_OPEN
#const STORAGE_ADDR_PAGE = 0x82D7  ; 1 byte  - caller supplied address (page)
#const STORAGE_ADDR_MSB  = 0x82D8  ; 1 byte
#const STORAGE_ADDR_LSB  = 0x82D9  ; 1 byte
#const STORAGE_LOAD_PTRP = 0x82DA  ; 1 byte  - effective load address (page)
#const STORAGE_LOAD_PTRH = 0x82DB  ; 1 byte  - effective load address (high)
#const STORAGE_LOAD_PTR  = 0x82DC  ; 1 byte  - effective load address (low)
#const CH376_DEST_PAGE   = 0x82DD  ; 1 byte  - running destination while loading
#const CH376_DEST_MSB    = 0x82DE  ; 1 byte
#const CH376_DEST_LSB    = 0x82DF  ; 1 byte
#const CH376_FNBUF       = 0x82E0  ; 16 bytes (0x82E0-0x82EF) - path passed to the chip

; --- 0x82F0-0x831B: LFN assemble state (storage/menu.asm listing) -
#const CH376_LFN_TMP     = 0x82F0  ; 40 bytes - UCS-2->ASCII assemble buffer
#const CH376_LFN_LEN     = 0x8318  ; 1 byte  - bytes used in CH376_LFN_TMP
#const CH376_LFN_CKSUM   = 0x8319  ; 1 byte  - expected short-name checksum
#const CH376_LFN_NEXT    = 0x831A  ; 1 byte  - next expected LFN ordinal (0 = idle)
#const CH376_LFN_READY   = 0x831B  ; 1 byte  - 1 = TMP holds a name for the next 8.3
#const CH376_LIST_IDX    = 0x831C  ; 1 byte  - 0-based index while finishing a listing
#const CH376_LIST_NUM    = 0x831D  ; 1 byte  - 1-based line number while printing
#const CH376_DIR_INDEX   = 0x831E  ; 1 byte  - FAT_DIR_INFO index within sector (LFN walk)
#const CH376_LIST_STYLE  = 0x831F  ; 1 byte  - 1=tabular (shell dir), 2=quiet (enum only)

; --- 0x8320-0x8332: free ------------------------------------------

; --- 0x834E-0x83BF: Shell (kernel/shell.asm) ----------------------
#const SHELL_INPUT_BUF               = 0x834E  ; 40 bytes (0x834E-0x8375)
#const SHELL_INPUT_MAX               = 0x28    ; 40
#const SHELL_CWD                     = 0x8376  ; 32 bytes NUL path ("/", "/BIN", ...)
#const SHELL_CWD_MAX                 = 0x20    ; 32
#const SHELL_CWD_LEN                 = 0x8396  ; 1 byte
#const SHELL_ARGV0                   = 0x8397  ; 1 byte - offset into SHELL_INPUT_BUF
#const SHELL_ARGV1                   = 0x8398  ; 1 byte
#const SHELL_ARGV2                   = 0x8399  ; 1 byte
#const SHELL_ARGV3                   = 0x839A  ; 1 byte
#const SHELL_WORK                    = 0x839B  ; 16 bytes scratch (fill/copy/path)
#const SHELL_WORK_END                = 0x83AA
; SHELL_F_* in SHELL_FLAGS:
;   bit0 = last USB op failed → prompt shows ?> until remount
#const SHELL_F_USB_ERR               = 0x01

; --- 0x83AB-0x83B7: Shell command history state -------------------
#const SHELL_HIST_LEN                = 0x83AB  ; 1 byte - entries stored (0..5)
#const SHELL_HIST_HEAD               = 0x83AC  ; 1 byte - next write slot (0..4)
#const SHELL_HIST_POS                = 0x83AD  ; 1 byte - 0xFF=live edit, else age 0..4
#const SHELL_HIST_DRAFT_LEN          = 0x83AE  ; 1 byte
#const SHELL_HIST_SLEN               = 0x83AF  ; 5 bytes (0x83AF-0x83B3) per-slot length
#const SHELL_HIST_MAX                = 0x05    ; ring depth
#const SHELL_HIST_PAINTED            = 0x83B4  ; 1 byte - chars echoed after prompt

; --- 0x83B5-0x83B8: tab-complete scratch ----------------------------
#const SHELL_TAB_TOK                 = 0x83B5  ; 1 byte - token start in input buf
#const SHELL_TAB_PLEN                = 0x83B6  ; 1 byte - typed prefix length
#const SHELL_TAB_N                   = 0x83B7  ; 1 byte - match count
#const SHELL_TAB_DIR                 = 0x83B8  ; 1 byte - 1 if sole match is a dir

; --- 0x83B9-0x83D9: arg passed into launched external apps ----------
; Bare "edit notes.txt" / "exec EDIT.BIN notes.txt" → path here.
#const SHELL_APP_ARGC                = 0x83B9  ; 1 byte - 0=none, 1=path present
#const SHELL_APP_ARG                 = 0x83BA  ; 32 bytes NUL path (0x83BA-0x83D9)

; --- 0x83DA-0x83F0: Shell PATH + CWD save (Otto OS) ---------------
#const SHELL_PATH_LEN                = 0x83DA  ; 1 byte - length of SHELL_PATH text
#const SHELL_CWD_SAVE_LEN            = 0x83DB  ; 1 byte - saved CWD length (PATH search)
; 0x83DC-0x83F0 still free (21 bytes)

; --- 0xDC00-0xE37F: USB dir tables (storage/menu.asm) -------------
; Lives in application RAM: only valid while the kernel USB menu is running.
#const STORAGE_NAMES     = 0xDC00  ; 40 entries x 16 bytes (0xDC00-0xDE7F)
#const STORAGE_LFN       = 0xDE80  ; 40 entries x 32 bytes (0xDE80-0xE37F), NUL-term ASCII

; --- 0xE400-0xE4EF: Shell history text (shell.asm) ----------------
; App RAM. Slots start with E<=0xA0 so DE,X copies never page-cross.
#const SHELL_HIST                    = 0xE400  ; 5 x 40 bytes (0xE400-0xE4C7)
#const SHELL_HIST_DRAFT              = 0xE4C8  ; 40 bytes live-line backup (0xE4C8-0xE4EF)

; --- 0xE4F0-0xE53F: Otto OS PATH + CWD backup (shell.asm) ---------
#const SHELL_PATH                    = 0xE4F0  ; 40 bytes NUL path list ("/BIN;/TOOLS")
#const SHELL_PATH_MAX                = 0x28    ; 40
#const SHELL_CWD_SAVE                = 0xE518  ; 32 bytes — CWD backup during PATH search
; 0xE538-0xE53F reserved (8 bytes)

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
