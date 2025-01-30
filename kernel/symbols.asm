#const MICROCODE_test = 0x200
#const SQTAB_LSB = 0x70d
#const SQTAB_MSB = 0x80d
#const POW2_LSB = 0x90d
#const POW2_MSB = 0x91d
#const DIVIDE_INT = 0x92d
#const MULTIPLY_INT = 0x956
#const MATH_test = 0x9a5
#const BINDEC32_VALUE = 0x8340
#const BINDEC32_RESULT = 0x8344
#const BINHEX = 0x9d2
#const HEXBIN = 0x9f1
#const BINDEC = 0xa15
#const BINDEC32 = 0xa55
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
#const ACIA_INIT = 0xa83
#const ACIA_SEND_STRING = 0xa9b
#const ACIA_SEND_STRING_NO_WAIT = 0xab1
#const ACIA_WAIT_SEND_CLEAR = 0xac8
#const ACIA_SEND_CHAR = 0xad3
#const ACIA_SEND_HEX = 0xadb
#const ACIA_SEND_DECIMAL = 0xaef
#const ACIA_SEND_NEWLINE = 0xb09
#const ACIA_READ_CHAR = 0xb1c
#const ACIA_READ_TO_BUFFER = 0xb28
#const ACIA_PULL_FROM_BUFFER = 0xb4d
#const ACIA_SEND_DECIMAL32 = 0xb69
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
#const XMODEM_RCV = 0xb88
#const XMODEM_CRC_LO_TABLE = 0xceb
#const XMODEM_CRC_HI_TABLE = 0xdeb
#const VT100_BUFFER = 0x8120
#const VT100 = 0xeeb
#const VT100_ERASE_SCREEN = 0xf12
#const VT100_CURSOR_HOME = 0xf20
#const VT100_CURSOR_POSITION = 0xf2d
#const VT100_CURSOR_UP = 0xf59
#const VT100_CURSOR_DOWN = 0xf66
#const VT100_CURSOR_RIGHT = 0xf73
#const VT100_CURSOR_LEFT = 0xf80
#const VT100_CLEAR_LINE_END = 0xf8d
#const VT100_CLEAR_LINE_START = 0xf9a
#const VT100_CLEAR_ENTIRE_LINE = 0xfa8
#const VT100_TEXT_RESET = 0xfb6
#const VT100_TEXT_BOLD = 0xfc4
#const VT100_TEXT_UNDERLINE = 0xfd2
#const VT100_TEXT_BLINK = 0xfe0
#const VT100_TEXT_REVERSE = 0xfee
#const VT100_FG_BLACK = 0xffc
#const VT100_FG_RED = 0x100b
#const VT100_FG_GREEN = 0x101a
#const VT100_FG_YELLOW = 0x1029
#const VT100_FG_BLUE = 0x1038
#const VT100_FG_MAGENTA = 0x1047
#const VT100_FG_CYAN = 0x1056
#const VT100_FG_WHITE = 0x1065
#const VT100_BG_BLACK = 0x1074
#const VT100_BG_RED = 0x1083
#const VT100_BG_GREEN = 0x1092
#const VT100_BG_YELLOW = 0x10a1
#const VT100_BG_BLUE = 0x10b0
#const VT100_BG_MAGENTA = 0x10bf
#const VT100_BG_CYAN = 0x10ce
#const VT100_BG_WHITE = 0x10dd
#const VT100_SCROLL_SCREEN_FULL = 0x10ec
#const VT100_SCROLL_SCREEN_REGION = 0x10f9
#const VT100_SCROLL_DOWN = 0x1125
#const VT100_SCROLL_UP = 0x1131
#const VT100_ENABLE_WRAP = 0x113d
#const VT100_DISABLE_WRAP = 0x114b
#const VT100_FONT_DEFAULT = 0x1159
#const VT100_FONT_ALTERNATE = 0x1165
#const VT100_DEVICE_RESET = 0x1171
#const VT100_QUERY_CURSOR_POSITION = 0x117d
#const ISTRUCTIONS = 0x118b
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
#const main = 0x1981
