; USB mass storage constants (CH376S in serial UART mode on ACIA #2).
;
; RAM variables for this module are declared in kernel/memmap.asm.

#once

; --- ACIA #2: the CH376 module runs 115200 8N1 on this port ---------
#const ACIA2_CONTROL_STATUS_ADDR = 0x6022
#const ACIA2_RW_DATA_ADDR        = 0x6023

; --- UART framing ---------------------------------------------------
#const CH376_SYNC1 = 0x57
#const CH376_SYNC2 = 0xAB

; --- Commands -------------------------------------------------------
#const CH376_CMD_GET_IC_VER    = 0x01
#const CH376_CMD_CHECK_EXIST   = 0x06
#const CH376_CMD_GET_STATUS    = 0x22
#const CH376_CMD_RD_USB_DATA0  = 0x27
#const CH376_CMD_SET_USB_MODE  = 0x15
#const CH376_CMD_DISK_CONNECT  = 0x30
#const CH376_CMD_DISK_MOUNT    = 0x31
#const CH376_CMD_DISK_QUERY    = 0x3F
#const CH376_CMD_SET_FILE_NAME = 0x2F
#const CH376_CMD_FILE_OPEN     = 0x32
#const CH376_CMD_DIR_INFO_READ = 0x37
#const CH376_CMD_FILE_ENUM_GO  = 0x33
#const CH376_CMD_FILE_CLOSE    = 0x36
#const CH376_CMD_FILE_CREATE   = 0x34
#const CH376_CMD_BYTE_READ     = 0x3A
#const CH376_CMD_BYTE_RD_GO    = 0x3B
#const CH376_CMD_BYTE_WRITE    = 0x3C
#const CH376_CMD_BYTE_WR_GO    = 0x3D
#const CH376_CMD_WR_REQ_DATA   = 0x2D
#const CH376_CMD_READ_VAR8     = 0x0A
#const CH376_CMD_WRITE_VAR8    = 0x0B
#const CH376_VAR_FILE_DIR_IDX  = 0x3B  ; index of current FAT_DIR_INFO in its sector
#const CH376_VAR_END_DIR_INFO  = 0x0D  ; write 0 after consuming DIR_INFO_READ data

#const CH376_USB_MODE_HOST       = 0x06
#const CH376_USB_MODE_HOST_RESET = 0x07

; --- Interrupt / return status --------------------------------------
#const CH376_INT_SUCCESS     = 0x14
#const CH376_INT_CONNECT     = 0x15
#const CH376_INT_DISK_ERR    = 0x1F
#const CH376_INT_DISK_READ   = 0x1D
#const CH376_INT_DISK_WRITE  = 0x1E
#const CH376_CMD_RET_SUCCESS = 0x51
#const CH376_ERR_MISS_FILE   = 0x42
#const CH376_ERR_OPEN_DIR    = 0x41

; --- FAT directory entries ------------------------------------------
#const CH376_DIR_ATTR_HIDDEN    = 0x02
#const CH376_DIR_ATTR_SYSTEM    = 0x04
#const CH376_DIR_ATTR_DIRECTORY = 0x10
#const CH376_DIR_INFO_SIZE      = 32
#const CH376_DISK_QUERY_SIZE    = 9

; --- Transfer sizing -------------------------------------------------
#const CH376_READ_CHUNK  = 0x40
#const CH376_WRITE_CHUNK = 0x40

#const CH376_RDB_MODE_BUF = 0x00
#const CH376_RDB_MODE_DST = 0x01

; --- Browser entry table (STORAGE_NAMES in memmap.asm) ---------------
#const CH376_MAX_FILES       = 0x28  ; 40 entries
#const CH376_NAME_ENTRY      = 0x10  ; 11 name + 4 size + 1 flags
#const CH376_ENTRY_FLAG_DIR  = 0x01
#const CH376_LFN_ENTRY       = 0x20  ; display name bytes per STORAGE_LFN slot
#const CH376_LFN_ATTR        = 0x0F  ; VFAT long-name directory attribute
#const CH376_LFN_LAST        = 0x40  ; sequence bit: first physical / last logical slot
#const CH376_LFN_DISP_MAX    = 0x1F  ; max ASCII chars stored (room for NUL in 32-byte slot)

; --- OT application header (see scripts/python/add_header.py) --------
#const STORAGE_OT_MAGIC0 = 0x4F  ; 'O'
#const STORAGE_OT_MAGIC1 = 0x54  ; 'T'
#const STORAGE_OT_VER    = 0x01
#const STORAGE_OT_SIZE   = 0x06

; --- Address ranges that must never be a transfer endpoint -----------
#const STORAGE_IO_START    = 0x6000
#const STORAGE_IO_END      = 0x67FF
#const STORAGE_VIDEO_START = 0x6800
#const STORAGE_VIDEO_END   = 0x7FFF

; --- STORAGE_STATUS flags --------------------------------------------
#const STORAGE_ST_PRESENT = 0x01
#const STORAGE_ST_MOUNTED = 0x02
