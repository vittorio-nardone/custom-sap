; XMODEM/CRC porting for Project Otto
;
; by Vittorio Nardone - Oct 2024
;
; Original ->
;
; XMODEM/CRC Receiver for the 65C02
;
; By Daryl Rictor & Ross Archer  Aug 2002
;
; 21st century code for 20th century CPUs (tm?)
; 
; A simple file transfer program to allow upload from a console device
; to the SBC utilizing the x-modem/CRC transfer protocol.  Requires just
; under 1k of either RAM or ROM, 132 bytes of RAM for the receive buffer,
; and 8 bytes of zero page RAM for variable storage.
;
; **************************************************************************
; This implementation of XMODEM/CRC does NOT conform strictly to the 
; XMODEM protocol standard in that it (1) does not accurately time character
; reception or (2) fall back to the Checksum mode.

; (1) For timing, it uses a crude timing loop to provide approximate
; delays.  These have been calibrated against a 1MHz CPU clock.  I have
; found that CPU clock speed of up to 5MHz also work but may not in
; every case.  Windows HyperTerminal worked quite well at both speeds!
;
; (2) Most modern terminal programs support XMODEM/CRC which can detect a
; wider range of transmission errors so the fallback to the simple checksum
; calculation was not implemented to save space.
; **************************************************************************
;
; Files uploaded via XMODEM-CRC must be
; in .o64 format -- the first two bytes are the load address in
; little-endian format:  
;  FIRST BLOCK
;     offset(0) = lo(load start address),
;     offset(1) = hi(load start address)
;     offset(2) = data byte (0)
;     offset(n) = data byte (n-2)
;
; Subsequent blocks
;     offset(n) = data byte (n)
;
; The TASS assembler and most Commodore 64-based tools generate this
; data format automatically and you can transfer their .obj/.o64 output
; file directly.  
;   
; The only time you need to do anything special is if you have 
; a raw memory image file (say you want to load a data
; table into memory). For XMODEM you'll have to 
; "insert" the start address bytes to the front of the file.
; Otherwise, XMODEM would have no idea where to start putting
; the data.

#bank kernel
#once
#include "serial.asm"

;-------------------------- The Code ----------------------------
;
; zero page variables (adjust these to suit your needs)
;
;
#const XMODEM_CRC			=	0x8337		; CRC lo byte  (two byte variable)
#const XMODEM_CRCH			=	0x8338		; CRC hi byte  

#const XMODEM_PTRP			=	0x8339		; data pointer (three byte variable)
#const XMODEM_PTRH			=	0x833a		; data pointer 
#const XMODEM_PTR			=	0x833b		; data pointer 


#const XMODEM_BLK_NO		=	0x833c			; block number 
#const XMODEM_RETRY_COUNTER	=	0x833d		; retry counter 
#const XMODEM_RETRY_COUNTER2 =	0x833e	; 2nd counter
#const XMODEM_BLOCK_FLAG	=	0x833f		; block flag 

#const XMODEM_RETRY_3SECONDS = 0x3f
#const XMODEM_RETRY_1SECOND = 0x15

;
;
; non-zero page variables and buffers
;
;
#const XMODEM_RECEIVE_BUFFER	=	0x8200      	; temp 132 byte receive buffer 
;(place anywhere, page aligned)
;
;
;  tables and constants
;
;
; The crclo & crchi labels are used to point to a lookup table to calculate
; the CRC for the 128 byte data blocks.  There are two implementations of these
; tables.  One is to use the tables included (defined towards the end of this
; file) and the other is to build them at run-time.  If building at run-time,
; then these two labels will need to be un-commented and declared in RAM.
;
;crclo		=	0x7D00      	; Two 256-byte tables for quick lookup
;crchi		= 	0x7E00      	; (should be page-aligned for speed)
;
;
;
; XMODEM Control Character Constants
#const XMODEM_SOH		=	0x01		; start block
#const XMODEM_EOT		=	0x04		; end of text marker
#const XMODEM_ACK		=	0x06		; good block acknowledged
#const XMODEM_NAK	 	=	0x15		; bad block acknowledged
;#const XMODEM_CAN		=	0x18		; cancel (not standard, not supported)
;#const XMODEM_CR		=	0x0d		; carriage return
;#const XMODEM_LF		=	0x0a		; line feed
#const XMODEM_ESC		=	0x1b		; ESC to exit

;
;^^^^^^^^^^^^^^^^^^^^^^ Start of Program ^^^^^^^^^^^^^^^^^^^^^^
;
; Xmodem/CRC upload routine
; By Daryl Rictor, July 31, 2002
;
; v0.3  tested good minus CRC
; v0.4  CRC fixed!!! init to 0x0000 rather than 0xFFFF as stated   
; v0.5  added CRC tables vs. generation at run time
; v 1.0 recode for use with SBC2
; v 1.1 added block 1 masking (block 257 would be corrupted)

; Start of program (adjust to your needs)
;
XMODEM_RCV:
	sty XMODEM_PTRP
	std XMODEM_PTRH
	ste XMODEM_PTR
	lda	0x01
	sta	XMODEM_BLK_NO				; set block # to 1
	sta	XMODEM_BLOCK_FLAG			; set flag to get address from block 1
.StartCrc:
	lda	"C"							; "C" start with CRC mode
	jsr	ACIA_SEND_CHAR				; send it
	lda	XMODEM_RETRY_3SECONDS	
	sta	XMODEM_RETRY_COUNTER2		; set loop counter for ~3 sec delay
	lda	0x00
	sta	XMODEM_CRC
	sta	XMODEM_CRCH 				; init CRC value	
	jsr	.GetByte					; wait for input
	bcs	.GotByte					; byte received, process it
	bcc	.StartCrc					; resend "C"

.StartBlk:
	lda	XMODEM_RETRY_3SECONDS		; 
	sta	XMODEM_RETRY_COUNTER2		; set loop counter for ~3 sec delay
	lda	0x00						;
	sta	XMODEM_CRC					;
	sta	XMODEM_CRCH					; init CRC value	
	jsr	.GetByte					; get first byte of block
	bcc	.StartBlk					; timed out, keep waiting...
.GotByte:
	cmp	XMODEM_ESC					; quitting?
	bne	.GotByte1					; no
;		lda	#0xFE						; Error code in "A" of desired
	rts								; YES - do BRK or change to RTS if desired
.GotByte1:
	cmp	XMODEM_SOH					; start of block?
	beq	.BegBlk						; yes
	cmp	XMODEM_EOT					;
	bne	.BadCrc						; Not XMODEM_SOH or XMODEM_EOT, so flush buffer & send NAK	
	jmp	.Done						; XMODEM_EOT - all done!
.BegBlk:
	ldx	0x00
.GetBlk:
	lde 0x00
.GetBlk1:								; fast loop to avoid serial overrun
	dee				
	beq .BadCrc						; exit from loop if no data is received after 256 retries

	lda ACIA_CONTROL_STATUS_ADDR  	; read serial 1 status
	bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
	beq .GetBlk1
	lda ACIA_RW_DATA_ADDR

.GetBlk2:
	sta	XMODEM_RECEIVE_BUFFER,x		; good char, save it in the rcv buffer
	inx								; inc buffer pointer	
	cpx	0x84						; <01> <FE> <128 bytes> <CRCH> <CRCL>
	bne	.GetBlk						; get 132 characters
	ldx	0x00						;
	lda	XMODEM_RECEIVE_BUFFER,x		; get block # from buffer
	cmp	XMODEM_BLK_NO				; compare to expected block #	
	beq	.GoodBlk1					; matched!
;		jsr	Print_Err					; Unexpected block number - abort	
	jsr	.Flush						; mismatched - flush buffer and then do BRK
	lda	0x01						; put error code in "A" if desired
	clc
	rts								; unexpected block # - fatal error - BRK or RTS
.GoodBlk1:
	eor	0xff						; 1's comp of block #
	inx								;
	
	tad
	lda XMODEM_RECEIVE_BUFFER,x
	tae
	tda

	cpd e							; compare with expected 1's comp of block #
	beq	.GoodBlk2 					; matched!
;		jsr	Print_Err					; Unexpected block number - abort	
	jsr .Flush						; mismatched - flush buffer and then do BRK
	lda	0x01						; put error code in "A" if desired
	clc
	rts								; bad 1's comp of block#	
.GoodBlk2:
	ldy	0x02						; 
.CalcCrc:
	lda	XMODEM_RECEIVE_BUFFER,y		; calculate the CRC for the 128 bytes of data	
	jsr	.UpdCrc						; could inline sub here for speed
	iny								;
	cpy	0x82						; 128 bytes
	bne	.CalcCrc					;
	lda	XMODEM_RECEIVE_BUFFER,y		; get hi CRC from buffer
	cmp	XMODEM_CRCH					; compare to calculated hi CRC
	bne	.BadCrc						; bad crc, send NAK
	iny								;
	lda	XMODEM_RECEIVE_BUFFER,y		; get lo CRC from buffer
	cmp	XMODEM_CRC					; compare to calculated lo CRC
	beq	.CopyBlk					; good CRC
.BadCrc:
	jsr	.Flush						; flush the input port
	lda	XMODEM_NAK					;
	jsr	ACIA_SEND_CHAR				; send NAK to resend block
	jmp	.StartBlk					; start over, get the block again			
;.GoodCrc:
	; ldx	0x02		;
	; lda	XMODEM_BLK_NO		; get the block number
	; cmp	0x01		; 1st block?
	; jmp CopyBlk
	; bne	CopyBlk		; no, copy all 128 bytes
	; lda	XMODEM_BLOCK_FLAG		; is it really block 1, not block 257, 513 etc.
	; beq	CopyBlk		; no, copy all 128 bytes
	; lda	XMODEM_RECEIVE_BUFFER,x		; get target address from 1st 2 bytes of blk 1
	; sta	ptr			; save lo address
	; inx				;
	; lda	XMODEM_RECEIVE_BUFFER,x		; get hi address
	; sta	ptr+1		; save it
	; inx				; point to first byte of data
	; dec	XMODEM_BLOCK_FLAG		; set the flag so we won't get another address		
.CopyBlk:
	ldx	0x00						; set offset to zero
	ldy 0x02
.CopyBlk3:
	lda	XMODEM_RECEIVE_BUFFER,y		; get data byte from buffer
	phy
	ldy XMODEM_PTRP
	ldd XMODEM_PTRH
	lde XMODEM_PTR
	sta	(yde),x						; save to target
	ply
	inc	XMODEM_PTR					; point to next address
	bne	.CopyBlk4					; did it step over page boundary?
	inc	XMODEM_PTRH					; adjust high address for page crossing
	bne	.CopyBlk4					; did it step over page boundary?
	inc	XMODEM_PTRP					; adjust high address for page crossing	
.CopyBlk4:
	iny								; point to next data byte
	cpy	0x82						; is it the last byte
	bne	.CopyBlk3					; no, get the next one
.IncBlk:
	inc	XMODEM_BLK_NO				; done.  Inc the block #
	lda	XMODEM_ACK					; send XMODEM_ACK
	jsr	ACIA_SEND_CHAR				;
	jmp	.StartBlk					; get next block
.Done:
	lda	XMODEM_ACK					; last block, send XMODEM_ACK and exit.
	jsr	ACIA_SEND_CHAR				;
	jsr	.Flush						; get leftover characters, if any
	;jsr	Print_Good	;
	lda 0x02						; put ok code in "A" if desired
	sec
	rts								;
;
;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
;
; subroutines
;
;										;
.GetByte:
	lda	0x00						; wait for chr input and cycle timing loop
	sta	XMODEM_RETRY_COUNTER		; set low value of timing loop
.StartCrcLp:
	;jsr	Get_Chr					; get chr from serial port, don't wait 

	clc
	lda ACIA_CONTROL_STATUS_ADDR  	; read serial 1 status
	bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; check if Receive Data Register is full
	beq .GetByte1

	bit ACIA_STATUS_REG_RECEIVER_OVERRUN
	beq .GetByte2
	ldo 0xEE
.GetByte2:		
	lda ACIA_RW_DATA_ADDR  			; read serial 1 data		
	sec
	rts

.GetByte1:
	dec	XMODEM_RETRY_COUNTER		; no character received, so dec counter
	bne	.StartCrcLp	;
	dec	XMODEM_RETRY_COUNTER2		; dec hi byte of counter
	bne	.StartCrcLp					; look for character again
	clc								; if loop times out, CLC, else SEC and return
	rts								; with character in "A"
;
.Flush:
	lda	XMODEM_RETRY_1SECOND		; flush receive buffer
	sta	XMODEM_RETRY_COUNTER2		; flush until empty for ~1 sec.
.Flush1:
	jsr	.GetByte					; read the port
	bcs	.Flush						; if chr recvd, wait for another
	rts								; else done

;
;
;======================================================================
;  I/O Device Specific Routines
;
;  Two routines are used to communicate with the I/O device.
;
; "Get_Chr" routine will scan the input port for a character.  It will
; return without waiting with the Carry flag CLEAR if no character is
; present or return with the Carry flag SET and the character in the "A"
; register if one was present.
;
; "ACIA_SEND_CHAR" routine will write one byte to the output port.  Its alright
; if this routine waits for the port to be ready.  its assumed that the 
; character was send upon return from this routine.
;
; Here is an example of the routines used for a standard 6551 ACIA.
; You would call the ACIA_Init prior to running the xmodem transfer
; routine.
;
; input chr from ACIA (no waiting)
;
.Get_Chr:
	clc
	lda ACIA_CONTROL_STATUS_ADDR  ; read serial 1 status
	bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; check if Receive Data Register is full
	beq .Get_Chr2
	lda ACIA_RW_DATA_ADDR  	; read serial 1 data		
	sec
.Get_Chr2:
	rts						; done

;=========================================================================
;
;
;  CRC subroutines 
;
;
.UpdCrc:
	eor 	XMODEM_CRCH			; Quick CRC computation with lookup tables
	tax		 					; updates the two bytes at crc & crc+1
	
	lda 	XMODEM_CRC_HI_TABLE,x
	tad
	lda 	XMODEM_CRC			; with the byte send in the "A" register
	eor 	d
	sta 	XMODEM_CRCH
	lda 	XMODEM_CRC_LO_TABLE,x
	sta 	XMODEM_CRC
	rts
;
; Alternate solution is to build the two lookup tables at run-time.  This might
; be desirable if the program is running from ram to reduce binary upload time.
; The following code generates the data for the lookup tables.  You would need to
; un-comment the variable declarations for crclo & crchi in the Tables and Constants
; section above and call this routine to build the tables before calling the
; "xmodem" routine.
;
;MAKECRCTABLE
;		ldx 	#0x00
;		LDA	#0x00
;zeroloop	sta 	crclo,x
;		sta 	crchi,x
;		inx
;		bne	zeroloop
;		ldx	#0x00
;fetch		txa
;		eor	crchi,x
;		sta	crchi,x
;		ldy	#0x08
;fetch1		asl	crclo,x
;		rol	crchi,x
;		bcc	fetch2
;		lda	crchi,x
;		eor	#0x10
;		sta	crchi,x
;		lda	crclo,x
;		eor	#0x21
;		sta	crclo,x
;fetch2		dey
;		bne	fetch1
;		inx
;		bne	fetch
;		rts
;
; The following tables are used to calculate the CRC for the 128 bytes
; in the xmodem data blocks.  You can use these tables if you plan to 
; store this program in ROM.  If you choose to build them at run-time, 
; then just delete them and define the two labels: crclo & crchi.
;
; low byte CRC lookup table (should be page aligned)
; *= 0x7D00
XMODEM_CRC_LO_TABLE:
 #d 0x00,0x21,0x42,0x63,0x84,0xA5,0xC6,0xE7,0x08,0x29,0x4A,0x6B,0x8C,0xAD,0xCE,0xEF
 #d 0x31,0x10,0x73,0x52,0xB5,0x94,0xF7,0xD6,0x39,0x18,0x7B,0x5A,0xBD,0x9C,0xFF,0xDE
 #d 0x62,0x43,0x20,0x01,0xE6,0xC7,0xA4,0x85,0x6A,0x4B,0x28,0x09,0xEE,0xCF,0xAC,0x8D
 #d 0x53,0x72,0x11,0x30,0xD7,0xF6,0x95,0xB4,0x5B,0x7A,0x19,0x38,0xDF,0xFE,0x9D,0xBC
 #d 0xC4,0xE5,0x86,0xA7,0x40,0x61,0x02,0x23,0xCC,0xED,0x8E,0xAF,0x48,0x69,0x0A,0x2B
 #d 0xF5,0xD4,0xB7,0x96,0x71,0x50,0x33,0x12,0xFD,0xDC,0xBF,0x9E,0x79,0x58,0x3B,0x1A
 #d 0xA6,0x87,0xE4,0xC5,0x22,0x03,0x60,0x41,0xAE,0x8F,0xEC,0xCD,0x2A,0x0B,0x68,0x49
 #d 0x97,0xB6,0xD5,0xF4,0x13,0x32,0x51,0x70,0x9F,0xBE,0xDD,0xFC,0x1B,0x3A,0x59,0x78
 #d 0x88,0xA9,0xCA,0xEB,0x0C,0x2D,0x4E,0x6F,0x80,0xA1,0xC2,0xE3,0x04,0x25,0x46,0x67
 #d 0xB9,0x98,0xFB,0xDA,0x3D,0x1C,0x7F,0x5E,0xB1,0x90,0xF3,0xD2,0x35,0x14,0x77,0x56
 #d 0xEA,0xCB,0xA8,0x89,0x6E,0x4F,0x2C,0x0D,0xE2,0xC3,0xA0,0x81,0x66,0x47,0x24,0x05
 #d 0xDB,0xFA,0x99,0xB8,0x5F,0x7E,0x1D,0x3C,0xD3,0xF2,0x91,0xB0,0x57,0x76,0x15,0x34
 #d 0x4C,0x6D,0x0E,0x2F,0xC8,0xE9,0x8A,0xAB,0x44,0x65,0x06,0x27,0xC0,0xE1,0x82,0xA3
 #d 0x7D,0x5C,0x3F,0x1E,0xF9,0xD8,0xBB,0x9A,0x75,0x54,0x37,0x16,0xF1,0xD0,0xB3,0x92
 #d 0x2E,0x0F,0x6C,0x4D,0xAA,0x8B,0xE8,0xC9,0x26,0x07,0x64,0x45,0xA2,0x83,0xE0,0xC1
 #d 0x1F,0x3E,0x5D,0x7C,0x9B,0xBA,0xD9,0xF8,0x17,0x36,0x55,0x74,0x93,0xB2,0xD1,0xF0 

; hi byte CRC lookup table (should be page aligned)
; *= 0x7E00
XMODEM_CRC_HI_TABLE:
 #d 0x00,0x10,0x20,0x30,0x40,0x50,0x60,0x70,0x81,0x91,0xA1,0xB1,0xC1,0xD1,0xE1,0xF1
 #d 0x12,0x02,0x32,0x22,0x52,0x42,0x72,0x62,0x93,0x83,0xB3,0xA3,0xD3,0xC3,0xF3,0xE3
 #d 0x24,0x34,0x04,0x14,0x64,0x74,0x44,0x54,0xA5,0xB5,0x85,0x95,0xE5,0xF5,0xC5,0xD5
 #d 0x36,0x26,0x16,0x06,0x76,0x66,0x56,0x46,0xB7,0xA7,0x97,0x87,0xF7,0xE7,0xD7,0xC7
 #d 0x48,0x58,0x68,0x78,0x08,0x18,0x28,0x38,0xC9,0xD9,0xE9,0xF9,0x89,0x99,0xA9,0xB9
 #d 0x5A,0x4A,0x7A,0x6A,0x1A,0x0A,0x3A,0x2A,0xDB,0xCB,0xFB,0xEB,0x9B,0x8B,0xBB,0xAB
 #d 0x6C,0x7C,0x4C,0x5C,0x2C,0x3C,0x0C,0x1C,0xED,0xFD,0xCD,0xDD,0xAD,0xBD,0x8D,0x9D
 #d 0x7E,0x6E,0x5E,0x4E,0x3E,0x2E,0x1E,0x0E,0xFF,0xEF,0xDF,0xCF,0xBF,0xAF,0x9F,0x8F
 #d 0x91,0x81,0xB1,0xA1,0xD1,0xC1,0xF1,0xE1,0x10,0x00,0x30,0x20,0x50,0x40,0x70,0x60
 #d 0x83,0x93,0xA3,0xB3,0xC3,0xD3,0xE3,0xF3,0x02,0x12,0x22,0x32,0x42,0x52,0x62,0x72
 #d 0xB5,0xA5,0x95,0x85,0xF5,0xE5,0xD5,0xC5,0x34,0x24,0x14,0x04,0x74,0x64,0x54,0x44
 #d 0xA7,0xB7,0x87,0x97,0xE7,0xF7,0xC7,0xD7,0x26,0x36,0x06,0x16,0x66,0x76,0x46,0x56
 #d 0xD9,0xC9,0xF9,0xE9,0x99,0x89,0xB9,0xA9,0x58,0x48,0x78,0x68,0x18,0x08,0x38,0x28
 #d 0xCB,0xDB,0xEB,0xFB,0x8B,0x9B,0xAB,0xBB,0x4A,0x5A,0x6A,0x7A,0x0A,0x1A,0x2A,0x3A
 #d 0xFD,0xED,0xDD,0xCD,0xBD,0xAD,0x9D,0x8D,0x7C,0x6C,0x5C,0x4C,0x3C,0x2C,0x1C,0x0C
 #d 0xEF,0xFF,0xCF,0xDF,0xAF,0xBF,0x8F,0x9F,0x6E,0x7E,0x4E,0x5E,0x2E,0x3E,0x0E,0x1E 
;
;
; End of File
;