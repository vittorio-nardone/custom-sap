; CH376S constants (serial UART mode, 115200 8N1 on ACIA #2).
; Shared by ch376_test_v*.asm; intended for future kernel/storage module.

#const CH376_SYNC1 = 0x57
#const CH376_SYNC2 = 0xAB

#const CH376_CMD_GET_IC_VER = 0x01
#const CH376_CMD_CHECK_EXIST = 0x06
#const CH376_CMD_GET_STATUS = 0x22
#const CH376_CMD_RD_USB_DATA0 = 0x27
#const CH376_CMD_SET_USB_MODE = 0x15
#const CH376_CMD_DISK_CONNECT = 0x30
#const CH376_CMD_DISK_MOUNT = 0x31
#const CH376_CMD_DISK_QUERY = 0x3F
#const CH376_CMD_SET_FILE_NAME = 0x2F
#const CH376_CMD_FILE_OPEN = 0x32
#const CH376_CMD_DIR_INFO_READ = 0x37
#const CH376_CMD_FILE_ENUM_GO = 0x33
#const CH376_CMD_FILE_CLOSE = 0x36
#const CH376_CMD_BYTE_READ = 0x3A
#const CH376_CMD_BYTE_RD_GO = 0x3B

#const CH376_USB_MODE_HOST = 0x06
#const CH376_USB_MODE_HOST_RESET = 0x07

#const CH376_INT_SUCCESS = 0x14
#const CH376_INT_CONNECT = 0x15
#const CH376_INT_DISK_ERR = 0x1F
#const CH376_INT_DISK_READ = 0x1D
#const CH376_INT_DISK_WRITE = 0x1E
#const CH376_CMD_RET_SUCCESS = 0x51
#const CH376_ERR_MISS_FILE = 0x42
#const CH376_ERR_OPEN_DIR = 0x41

#const CH376_DIR_ATTR_DIRECTORY = 0x10
#const CH376_DIR_INFO_SIZE = 32
#const CH376_DISK_QUERY_SIZE = 9
#const CH376_LOAD_MAX_LO = 0x00
#const CH376_LOAD_MAX_HI = 0x6C
#const CH376_READ_CHUNK = 0x40

#const CH376_RDB_MODE_BUF = 0x00
#const CH376_RDB_MODE_DST = 0x01

#const CH376_MAX_FILES = 0x28
#const CH376_NAME_ENTRY = 0x0F

#const ACIA2_CONTROL_STATUS_ADDR = 0x6022
#const ACIA2_RW_DATA_ADDR = 0x6023

; Hot-path RX vars in free kernel RAM (0x8284-0x8332). Must be 16-bit
; addresses: apps at 0x020000 would otherwise use 24-bit abs ops in the
; SEI burst and overrun ACIA2's 1-byte FIFO (~87us/byte @ 115200).
#const CH376_BUF = 0x8284
#const CH376_CAP = 0x82A4
#const CH376_OVERRUN = 0x82A5
#const CH376_TMO_BYTE = 0x82A6
#const CH376_RDB_MODE = 0x82A7
#const CH376_RD_LEFT = 0x82A8
#const CH376_WIRE_LEN = 0x82A9
#const CH376_RD_LEN = 0x82AA
#const CH376_PULL_MODE = 0x82AB
#const CH376_DST_PAGE = 0x82AC
#const CH376_DST_MSB = 0x82AD
#const CH376_DST_LSB = 0x82AE

; SEI burst code runs here (16-bit PC targets → fast branches).
; Image is embedded at file offset CH376_BURST_OUTP and copied at startup.
#const CH376_BURST_ENTRY = 0x82B0
#const CH376_BURST_OUTP = 0x1800
; Ends before ACIA RX idx @ 0x83F1. Overlaps idle XMODEM/BINDEC; OK during USB.
#const CH376_BURST_MAX = 0x120
