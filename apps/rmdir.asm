; @load-address 0x8400
; RMDIR — remove an empty directory (Otto OS).
;   rmdir NAME
;
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    jsr os_take_arg
    bcc .bad
    jsr os_split_args
    bcc .bad
    jsr os_set_name1
    bcc .usb
    jsr STORAGE_RMDIR
    bcc .usb
    jsr os_ok
    rts
.bad:
    jsr os_err_arg
    rts
.usb:
    jsr os_err_usb
    rts

#include "os_lib.asm"
