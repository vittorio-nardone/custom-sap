#once

#ruledef
{
    hlt => 0xFF                       ; Freeze CPU

    lda {value: u8} => 0xA9 @ value   ; Load Accumulator with Memory (immediate)
    lda {value: u16} => 0xAD @ value  ; Load Accumulator with Memory (absolute)

    ldo {value: u8} => 0xFE @ value   ; Load Output with Memory (immediate)

    cmp {value: u8} => 0xC9 @ value   ; Compre Memory with Accumulator (immediate)

    sta {value: u16} => 0x8D @ value  ; Store Accumulator in Memory (absolute)

    adc {value: u8} => 0x69 @ value   ; Add Memory to Accumulator with Carry (immediate)

    jmp {value: u16} => 0x4C @ value  ; Jump to New Location (absolute)

    beq {value: u16} => 0xF0 @ value  ; Branch on Result Zero (absolute)
    bne {value: u16} => 0xD0 @ value  ; Branch on Result Not Zero (absolute)

    bcs {value: u16} => 0xB0 @ value  ; Branch on Carry Set (absolute)
    bcc {value: u16} => 0x90 @ value  ; Branch on Carry Clear (absolute)

    nop => 0x00                       ; No Operation
}