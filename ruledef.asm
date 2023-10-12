#once

#ruledef
{
    hlt => 0xFF                       ; Freeze CPU

    lda {value: u8} => 0xA9 @ value   ; Load Accumulator with Memory (immediate)
    lda {value: u16} => 0xAD @ value  ; Load Accumulator with Memory (absolute)

    sta {value: u16} => 0x8D @ value  ; Store Accumulator in Memory (absolute)

    adc {value: u8} => 0x69 @ value   ; Add Memory to Accumulator with Carry (immediate)

    jmp {value: u16} => 0x4C @ value  ; Jump to New Location (absolute)

    nop => 0x00                       ; No Operation
}