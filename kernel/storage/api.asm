; Public USB mass storage API.
;
; Every entry point reports success with C=1 and failure with C=0.
; Initialisation is lazy: nothing touches ACIA #2 until the first call, so a
; machine without the CH376 module boots normally and simply gets C=0 here.
;
; See kernel/storage/README.md for the calling conventions.

#once
#bank kernel

; Print '.' on ACIA #1 during long DISK_MOUNT waits (mount is not instant).
storage_mount_progress:
    lda "."
    jmp ACIA_SEND_CHAR

; Set the CH376 working path from CH376_FNBUF.
storage_set_name_fnbuf:
    ldy 0x00
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jmp ch376_cmd_set_file_name

; **********************************************************
; SUBROUTINE: STORAGE_INIT
;   Reset ACIA #2 and probe for the CH376 module.
; **********************************************************

STORAGE_INIT:
    lda 0x00
    sta CH376_STATUS
    sta CH376_INT_FLAG
    sta CH376_INT_STATUS
    jsr ch376_acia2_init
    jsr ch376_set_timeout
    jsr ch376_drain_rx
    lda 0xAA
    jsr ch376_cmd_check_exist
    bcc .absent
    lda STORAGE_ST_PRESENT
    sta CH376_STATUS
    sec
    rts
.absent:
    clc
    rts

; **********************************************************
; SUBROUTINE: STORAGE_MOUNT
;   Bring up USB host mode and mount the first FAT partition.
; **********************************************************

STORAGE_MOUNT:
    ; Always probe and reset ACIA #2. Skipping INIT when STORAGE_ST_PRESENT
    ; was set left us talking to an uninitialised port (infinite TX wait).
    jsr STORAGE_INIT
    bcc .fail
    lda CH376_USB_MODE_HOST_RESET
    jsr ch376_cmd_set_usb_mode
    bcc .fail
    lda CH376_USB_MODE_HOST
    jsr ch376_cmd_set_usb_mode
    bcc .fail
    lda CH376_CMD_DISK_CONNECT
    jsr ch376_cmd_wait_status
    bcc .fail
    jsr ch376_drain_rx
    jsr ch376_delay_short
    jsr ch376_set_timeout_long
    lda 0x08
    sta CH376_RETRIES
.retry:
    lda CH376_CMD_DISK_MOUNT
    jsr ch376_cmd_wait_status
    bcs .check
    dec CH376_RETRIES
    beq .settled
    jsr ch376_delay_short
    jsr storage_mount_progress
    jmp .retry
.check:
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq .settled
    dec CH376_RETRIES
    beq .settled
    jsr ch376_delay_short
    jsr storage_mount_progress
    jmp .retry
.settled:
    jsr ch376_set_timeout
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    bne .fail
    lda CH376_STATUS
    ora STORAGE_ST_MOUNTED
    sta CH376_STATUS
    lda 0x00
    sta CH376_DEPTH
    sec
    rts
.fail:
    jsr ch376_set_timeout
    lda CH376_STATUS
    and 0xFD                  ; clear STORAGE_ST_MOUNTED
    sta CH376_STATUS
    clc
    rts

; **********************************************************
; SUBROUTINE: STORAGE_STATUS
;   A = STORAGE_ST_* flags.
; **********************************************************

STORAGE_STATUS:
    lda CH376_STATUS
    rts

; **********************************************************
; SUBROUTINE: STORAGE_ENSURE_MOUNTED
; **********************************************************

STORAGE_ENSURE_MOUNTED:
    lda CH376_STATUS
    and STORAGE_ST_MOUNTED
    beq STORAGE_MOUNT
    sec
    rts

; **********************************************************
; SUBROUTINE: STORAGE_SET_NAME
;   Y:DE = null-terminated path (upper-cased on the wire).
; **********************************************************

STORAGE_SET_NAME:
    jmp ch376_cmd_set_file_name

; **********************************************************
; SUBROUTINE: STORAGE_OPEN
;   Open the file selected by STORAGE_SET_NAME.
;   C=0 leaves the reason in CH376_LAST_STATUS (0x42 = not found).
; **********************************************************

STORAGE_OPEN:
    jsr ch376_set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .fail
    jsr ch376_set_timeout
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    bne .not_open
    sec
    rts
.fail:
    jsr ch376_set_timeout
.not_open:
    clc
    rts

; **********************************************************
; SUBROUTINE: STORAGE_CREATE
;   Create (or truncate) the file selected by STORAGE_SET_NAME.
; **********************************************************

STORAGE_CREATE:
    jsr ch376_set_timeout_long
    jsr ch376_cmd_file_create
    bcc .fail
    jsr ch376_set_timeout
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    bne .not_created
    sec
    rts
.fail:
    jsr ch376_set_timeout
.not_created:
    clc
    rts

; **********************************************************
; SUBROUTINE: STORAGE_CLOSE
;   A = 0 (keep size) or 1 (update size).
; **********************************************************

STORAGE_CLOSE:
    jmp ch376_cmd_file_close

; **********************************************************
; SUBROUTINE: STORAGE_READ
;   Read from the open file into Y:DE.
;   CH376_REMAIN_LO/HI = bytes wanted, CH376_LOADED_LO/HI = bytes stored.
; **********************************************************

STORAGE_READ:
    jmp ch376_file_read_to

; **********************************************************
; SUBROUTINE: STORAGE_WRITE
;   Write CH376_REMAIN_LO/HI raw bytes from Y:DE to the open file.
; **********************************************************

STORAGE_WRITE:
    jmp ch376_file_write_from

; **********************************************************
; SUBROUTINE: STORAGE_LOAD_FILE
;
; DESCRIPTION:
;   Mount if needed, open CH376_FNBUF, apply the OT header rules used by the
;   XMODEM loader and copy the payload into memory.
;
; INPUTS:
;   CH376_FNBUF               null-terminated path
;   CH376_TOTAL_LO/HI         file size in bytes
;   CH376_OT_AUTO             1 = take the address from the OT header
;   STORAGE_ADDR_PAGE/MSB/LSB destination when CH376_OT_AUTO = 0
;
; OUTPUTS:
;   C=1 loaded; STORAGE_LOAD_PTRP/H/PTR = effective address,
;   CH376_LOADED_LO/HI = bytes stored, CH376_OT_FOUND = 1 if a header was
;   present (and therefore stripped).
; **********************************************************

STORAGE_LOAD_FILE:
    lda 0x00
    sta CH376_OT_FOUND
    sta CH376_PRELOAD
    jsr STORAGE_ENSURE_MOUNTED
    bcc .fail_open
    jsr storage_set_name_fnbuf
    jsr STORAGE_OPEN
    bcc .fail_open

    lda CH376_OT_AUTO
    beq .explicit
    ; Auto mode defaults to the application load address.
    lda 0x00
    sta STORAGE_LOAD_PTRP
    lda 0x84
    sta STORAGE_LOAD_PTRH
    lda 0x00
    sta STORAGE_LOAD_PTR
    jmp .probe
.explicit:
    jsr .use_explicit_addr

.probe:
    ; A file shorter than the header cannot carry one.
    lda CH376_TOTAL_HI
    bne .probe_read
    lda CH376_TOTAL_LO
    cmp STORAGE_OT_SIZE
    bcc .placed
.probe_read:
    lda STORAGE_OT_SIZE
    sta CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd CH376_BUF[15:8]
    lde CH376_BUF[7:0]
    jsr ch376_file_read_to
    bcc .fail_close
    sec
    lda CH376_TOTAL_LO
    sbc STORAGE_OT_SIZE
    sta CH376_TOTAL_LO
    lda CH376_TOTAL_HI
    sbc 0x00
    sta CH376_TOTAL_HI
    ldy 0x00
    ldd CH376_BUF[15:8]
    lde CH376_BUF[7:0]
    jsr STORAGE_OT_CHECK
    bcs .header_found
    ; No header: those 6 bytes are payload and must be replayed.
    lda STORAGE_OT_SIZE
    sta CH376_PRELOAD
    jmp .placed
.header_found:
    lda 0x01
    sta CH376_OT_FOUND
    lda CH376_OT_AUTO
    bne .placed
    ; Explicit address wins; the header is only stripped.
    jsr .use_explicit_addr

.placed:
    lda STORAGE_LOAD_PTRP
    sta CH376_DEST_PAGE
    lda STORAGE_LOAD_PTRH
    sta CH376_DEST_MSB
    lda STORAGE_LOAD_PTR
    sta CH376_DEST_LSB

    clc
    lda CH376_TOTAL_LO
    adc CH376_PRELOAD
    sta CH376_REMAIN_LO
    lda CH376_TOTAL_HI
    adc 0x00
    sta CH376_REMAIN_HI
    lda CH376_REMAIN_LO
    ora CH376_REMAIN_HI
    beq .no_payload
    ldy CH376_DEST_PAGE
    ldd CH376_DEST_MSB
    lde CH376_DEST_LSB
    jsr STORAGE_CHECK_RANGE
    bcc .fail_close

    lda CH376_PRELOAD
    beq .rest
    ldy CH376_DEST_PAGE
    ldd CH376_DEST_MSB
    lde CH376_DEST_LSB
    ldx 0x00
.replay:
    lda CH376_BUF,x
    sta yde,x
    inx
    cpx CH376_PRELOAD
    bcc .replay
    clc
    lda CH376_DEST_LSB
    adc CH376_PRELOAD
    sta CH376_DEST_LSB
    lda CH376_DEST_MSB
    adc 0x00
    sta CH376_DEST_MSB
    lda CH376_DEST_PAGE
    adc 0x00
    sta CH376_DEST_PAGE

.rest:
    lda CH376_TOTAL_LO
    ora CH376_TOTAL_HI
    beq .no_rest
    lda CH376_TOTAL_LO
    sta CH376_REMAIN_LO
    lda CH376_TOTAL_HI
    sta CH376_REMAIN_HI
    ldy CH376_DEST_PAGE
    ldd CH376_DEST_MSB
    lde CH376_DEST_LSB
    jsr ch376_file_read_to
    bcc .fail_close
    jmp .total

.no_payload:
.no_rest:
    lda 0x00
    sta CH376_LOADED_LO
    sta CH376_LOADED_HI

.total:
    clc
    lda CH376_LOADED_LO
    adc CH376_PRELOAD
    sta CH376_LOADED_LO
    lda CH376_LOADED_HI
    adc 0x00
    sta CH376_LOADED_HI
    lda 0x00
    jsr ch376_cmd_file_close
    jsr ch376_set_timeout
    sec
    rts

.use_explicit_addr:
    lda STORAGE_ADDR_PAGE
    sta STORAGE_LOAD_PTRP
    lda STORAGE_ADDR_MSB
    sta STORAGE_LOAD_PTRH
    lda STORAGE_ADDR_LSB
    sta STORAGE_LOAD_PTR
    rts

.fail_close:
    lda 0x00
    jsr ch376_cmd_file_close
.fail_open:
    jsr ch376_set_timeout
    clc
    rts

; **********************************************************
; SUBROUTINE: STORAGE_SAVE_FILE
;
; DESCRIPTION:
;   Mount if needed, create (truncating) CH376_FNBUF and write a memory range.
;
; INPUTS:
;   CH376_FNBUF               null-terminated path
;   CH376_SAVE_PAGE/MSB/LSB   source address
;   CH376_TOTAL_LO/HI         byte count
;   CH376_OT_FLAG             1 = prepend an OT header
;
; OUTPUTS:
;   C=1 saved, CH376_LOADED_LO/HI = bytes written (header included)
; **********************************************************

STORAGE_SAVE_FILE:
    jsr STORAGE_ENSURE_MOUNTED
    bcc .fail_open
    lda CH376_TOTAL_LO
    sta CH376_REMAIN_LO
    lda CH376_TOTAL_HI
    sta CH376_REMAIN_HI
    ldy CH376_SAVE_PAGE
    ldd CH376_SAVE_MSB
    lde CH376_SAVE_LSB
    jsr STORAGE_CHECK_RANGE
    bcc .fail_open

    jsr storage_set_name_fnbuf
    jsr STORAGE_OPEN
    bcs .truncate
    lda CH376_LAST_STATUS
    cmp CH376_ERR_MISS_FILE
    bne .fail_open
    jmp .create
.truncate:
    lda 0x00
    jsr ch376_cmd_file_close
    jsr storage_set_name_fnbuf
.create:
    jsr STORAGE_CREATE
    bcc .fail_open

    lda CH376_OT_FLAG
    beq .body
    jsr STORAGE_OT_WRITE_HDR
    bcc .fail_close
.body:
    lda CH376_TOTAL_LO
    sta CH376_REMAIN_LO
    lda CH376_TOTAL_HI
    sta CH376_REMAIN_HI
    ldy CH376_SAVE_PAGE
    ldd CH376_SAVE_MSB
    lde CH376_SAVE_LSB
    jsr ch376_file_write_from
    bcc .fail_close
    lda CH376_OT_FLAG
    beq .close
    clc
    lda CH376_LOADED_LO
    adc STORAGE_OT_SIZE
    sta CH376_LOADED_LO
    lda CH376_LOADED_HI
    adc 0x00
    sta CH376_LOADED_HI
.close:
    lda 0x01
    jsr ch376_cmd_file_close
    jsr ch376_set_timeout
    sec
    rts

.fail_close:
    lda 0x01
    jsr ch376_cmd_file_close
.fail_open:
    jsr ch376_set_timeout
    clc
    rts
