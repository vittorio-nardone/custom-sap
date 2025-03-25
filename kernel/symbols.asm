#const MICROCODE_test = 0x200
#const SQTAB_LSB = 0x776
#const SQTAB_MSB = 0x876
#const POW2_LSB = 0x976
#const POW2_MSB = 0x986
#const DIVIDE_INT = 0x996
#const MULTIPLY_INT = 0x9bf
#const MATH_test = 0xa0e
#const MEMORY_START_PTR = 0x8100
#const MEMORY_MAP_START_PTR = 0x8102
#const MEMORY_TMP_PTR = 0x8104
#const MEMORY_SIZE = 0x4000
#const MEMORY_BLOCK_SIZE = 0x40
#const MEMORY_MAX_BLOCKS = 0x100
#const MEMORY_INIT_DEFAULT = 0xa3b
#const MEMORY_INIT = 0xa56
#const MEMORY_ALLOCATE = 0xa71
#const MEMORY_DEALLOCATE = 0xace
#const BINDEC32_VALUE = 0x8340
#const BINDEC32_RESULT = 0x8344
#const BINHEX = 0xb17
#const HEXBIN = 0xb36
#const BINDEC = 0xb5a
#const BINDEC32 = 0xb9a
#const ACIA_CONTROL_STATUS_ADDR = 0x6020
#const ACIA_RW_DATA_ADDR = 0x6021
#const ACIA_INIT_MASTER_RESET = 0x3
#const ACIA_INIT_115200_8N1 = 0x15
#const ACIA_INIT_28800_8N1 = 0x16
#const ACIA_INIT_ENABLE_RX_INT = 0x80
#const ACIA_INIT_ENABLE_TX_INT = 0x20
#const ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL = 0x1
#const ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY = 0x2
#const ACIA_STATUS_REG_RECEIVER_OVERRUN = 0x20
#const ACIA_1_RX_BUFFER_AVAILABLE = 0x83f1
#const ACIA_1_RX_BUFFER_PULL_INDEX = 0x83f2
#const ACIA_1_RX_BUFFER_PUSH_INDEX = 0x83f3
#const ACIA_1_RX_BUFFER_POINTER = 0x83f4
#const ACIA_INIT = 0xbc8
#const ACIA_SEND_STRING = 0xbe0
#const ACIA_SEND_STRING_NO_WAIT = 0xbf6
#const ACIA_WAIT_SEND_CLEAR = 0xc0d
#const ACIA_SEND_CHAR = 0xc18
#const ACIA_SEND_HEX = 0xc20
#const ACIA_SEND_DECIMAL = 0xc34
#const ACIA_SEND_NEWLINE = 0xc4e
#const ACIA_READ_CHAR = 0xc61
#const ACIA_READ_TO_BUFFER = 0xc6d
#const ACIA_PULL_FROM_BUFFER = 0xc92
#const ACIA_SEND_DECIMAL32 = 0xcae
#const INT_EXTINT1 = 0x1
#const INT_EXTINT2 = 0x2
#const INT_TIMER = 0x4
#const INT_KEYBOARD = 0x8
#const INT_TIMER_COUNTER_MSB = 0x83f6
#const INT_TIMER_COUNTER_LSB = 0x83f7
#const INT_EXTINT1_HANDLER_POINTER = 0x83f8
#const INT_EXTINT2_HANDLER_POINTER = 0x83fa
#const INT_TIMER_HANDLER_POINTER = 0x83fc
#const INT_KEYBOARD_HANDLER_POINTER = 0x83fe
#const INTERRUPT_HANDLER = 0xff
#const INTERRUPT_INIT = 0x127
#const INTERRUPT_DUMMY_HANDLER = 0x156
#const INTERRUPT_TIMER_HANDLER = 0x157
#const INTERRUPT_SERIAL_HANDLER = 0x161
#const XMODEM_CRC = 0x8337
#const XMODEM_CRCH = 0x8338
#const XMODEM_PTRP = 0x8339
#const XMODEM_PTRH = 0x833a
#const XMODEM_PTR = 0x833b
#const XMODEM_BLK_NO = 0x833c
#const XMODEM_RETRY_COUNTER = 0x833d
#const XMODEM_RETRY_COUNTER2 = 0x833e
#const XMODEM_BLOCK_FLAG = 0x833f
#const XMODEM_RETRY_3SECONDS = 0x3f
#const XMODEM_RETRY_1SECOND = 0x15
#const XMODEM_RECEIVE_BUFFER = 0x8200
#const XMODEM_SOH = 0x1
#const XMODEM_EOT = 0x4
#const XMODEM_ACK = 0x6
#const XMODEM_NAK = 0x15
#const XMODEM_ESC = 0x1b
#const XMODEM_RCV = 0xccd
#const XMODEM_CRC_LO_TABLE = 0xe30
#const XMODEM_CRC_HI_TABLE = 0xf30
#const VT100_BUFFER = 0x8120
#const VT100 = 0x1030
#const VT100_ERASE_SCREEN = 0x1057
#const VT100_CURSOR_HOME = 0x1065
#const VT100_CURSOR_POSITION = 0x1072
#const VT100_CURSOR_UP = 0x109e
#const VT100_CURSOR_DOWN = 0x10ab
#const VT100_CURSOR_RIGHT = 0x10b8
#const VT100_CURSOR_LEFT = 0x10c5
#const VT100_CLEAR_LINE_END = 0x10d2
#const VT100_CLEAR_LINE_START = 0x10df
#const VT100_CLEAR_ENTIRE_LINE = 0x10ed
#const VT100_TEXT_RESET = 0x10fb
#const VT100_TEXT_BOLD = 0x1109
#const VT100_TEXT_UNDERLINE = 0x1117
#const VT100_TEXT_BLINK = 0x1125
#const VT100_TEXT_REVERSE = 0x1133
#const VT100_FG_BLACK = 0x1141
#const VT100_FG_RED = 0x1150
#const VT100_FG_GREEN = 0x115f
#const VT100_FG_YELLOW = 0x116e
#const VT100_FG_BLUE = 0x117d
#const VT100_FG_MAGENTA = 0x118c
#const VT100_FG_CYAN = 0x119b
#const VT100_FG_WHITE = 0x11aa
#const VT100_BG_BLACK = 0x11b9
#const VT100_BG_RED = 0x11c8
#const VT100_BG_GREEN = 0x11d7
#const VT100_BG_YELLOW = 0x11e6
#const VT100_BG_BLUE = 0x11f5
#const VT100_BG_MAGENTA = 0x1204
#const VT100_BG_CYAN = 0x1213
#const VT100_BG_WHITE = 0x1222
#const VT100_SCROLL_SCREEN_FULL = 0x1231
#const VT100_SCROLL_SCREEN_REGION = 0x123e
#const VT100_SCROLL_DOWN = 0x126a
#const VT100_SCROLL_UP = 0x1276
#const VT100_ENABLE_WRAP = 0x1282
#const VT100_DISABLE_WRAP = 0x1290
#const VT100_FONT_DEFAULT = 0x129e
#const VT100_FONT_ALTERNATE = 0x12aa
#const VT100_DEVICE_RESET = 0x12b6
#const VT100_QUERY_CURSOR_POSITION = 0x12c2
#const ISTRUCTIONS = 0x12d0
#const boot = 0x0
#const MAIN_MENU_STATUS = 0x8000
#const MAIN_MENU_INPUT_BUFFER_COUNT = 0x8001
#const MAIN_MENU_ADDR_PAGE = 0x8002
#const MAIN_MENU_ADDR_MSB = 0x8003
#const MAIN_MENU_ADDR_LSB = 0x8004
#const MAIN_MENU_DUMP_COUNT = 0x8005
#const MAIN_MENU_OPCODE_MSB = 0x8006
#const MAIN_MENU_OPCODE_LSB = 0x8007
#const MAIN_MENU_OPCODE_LENGTH = 0x8008
#const MAIN_MENU_OPCODE_LENGTH_2 = 0x8009
#const MAIN_MENU_OPCODE_PTR = 0x800a
#const MAIN_MENU_INPUT_BUFFER = 0x800b
#const main = 0x1af8
