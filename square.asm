#once

; **********************************************************
; SQUARE LOOKUP TABLE
;
; DESCRIPTION:
;;   This table store the results of X*X operation
;;

SQTAB_LSB:
    #d8  0x00 ; lsb of 0x00
    #d8  0x01 ; lsb of 0x01
    #d8  0x04 ; lsb of 0x04
    #d8  0x09 ; lsb of 0x09
    #d8  0x10 ; lsb of 0x10
    #d8  0x19 ; lsb of 0x19
    #d8  0x24 ; lsb of 0x24
    #d8  0x31 ; lsb of 0x31
    #d8  0x40 ; lsb of 0x40
    #d8  0x51 ; lsb of 0x51
    #d8  0x64 ; lsb of 0x64
    #d8  0x79 ; lsb of 0x79
    #d8  0x90 ; lsb of 0x90
    #d8  0xA9 ; lsb of 0xA9
    #d8  0xC4 ; lsb of 0xC4
    #d8  0xE1 ; lsb of 0xE1
    #d8  0x00 ; lsb of 0x100
    #d8  0x21 ; lsb of 0x121
    #d8  0x44 ; lsb of 0x144
    #d8  0x69 ; lsb of 0x169
    #d8  0x90 ; lsb of 0x190
    #d8  0xB9 ; lsb of 0x1B9
    #d8  0xE4 ; lsb of 0x1E4
    #d8  0x11 ; lsb of 0x211
    #d8  0x40 ; lsb of 0x240
    #d8  0x71 ; lsb of 0x271
    #d8  0xA4 ; lsb of 0x2A4
    #d8  0xD9 ; lsb of 0x2D9
    #d8  0x10 ; lsb of 0x310
    #d8  0x49 ; lsb of 0x349
    #d8  0x84 ; lsb of 0x384
    #d8  0xC1 ; lsb of 0x3C1
    #d8  0x00 ; lsb of 0x400
    #d8  0x41 ; lsb of 0x441
    #d8  0x84 ; lsb of 0x484
    #d8  0xC9 ; lsb of 0x4C9
    #d8  0x10 ; lsb of 0x510
    #d8  0x59 ; lsb of 0x559
    #d8  0xA4 ; lsb of 0x5A4
    #d8  0xF1 ; lsb of 0x5F1
    #d8  0x40 ; lsb of 0x640
    #d8  0x91 ; lsb of 0x691
    #d8  0xE4 ; lsb of 0x6E4
    #d8  0x39 ; lsb of 0x739
    #d8  0x90 ; lsb of 0x790
    #d8  0xE9 ; lsb of 0x7E9
    #d8  0x44 ; lsb of 0x844
    #d8  0xA1 ; lsb of 0x8A1
    #d8  0x00 ; lsb of 0x900
    #d8  0x61 ; lsb of 0x961
    #d8  0xC4 ; lsb of 0x9C4
    #d8  0x29 ; lsb of 0xA29
    #d8  0x90 ; lsb of 0xA90
    #d8  0xF9 ; lsb of 0xAF9
    #d8  0x64 ; lsb of 0xB64
    #d8  0xD1 ; lsb of 0xBD1
    #d8  0x40 ; lsb of 0xC40
    #d8  0xB1 ; lsb of 0xCB1
    #d8  0x24 ; lsb of 0xD24
    #d8  0x99 ; lsb of 0xD99
    #d8  0x10 ; lsb of 0xE10
    #d8  0x89 ; lsb of 0xE89
    #d8  0x04 ; lsb of 0xF04
    #d8  0x81 ; lsb of 0xF81
    #d8  0x00 ; lsb of 0x1000
    #d8  0x81 ; lsb of 0x1081
    #d8  0x04 ; lsb of 0x1104
    #d8  0x89 ; lsb of 0x1189
    #d8  0x10 ; lsb of 0x1210
    #d8  0x99 ; lsb of 0x1299
    #d8  0x24 ; lsb of 0x1324
    #d8  0xB1 ; lsb of 0x13B1
    #d8  0x40 ; lsb of 0x1440
    #d8  0xD1 ; lsb of 0x14D1
    #d8  0x64 ; lsb of 0x1564
    #d8  0xF9 ; lsb of 0x15F9
    #d8  0x90 ; lsb of 0x1690
    #d8  0x29 ; lsb of 0x1729
    #d8  0xC4 ; lsb of 0x17C4
    #d8  0x61 ; lsb of 0x1861
    #d8  0x00 ; lsb of 0x1900
    #d8  0xA1 ; lsb of 0x19A1
    #d8  0x44 ; lsb of 0x1A44
    #d8  0xE9 ; lsb of 0x1AE9
    #d8  0x90 ; lsb of 0x1B90
    #d8  0x39 ; lsb of 0x1C39
    #d8  0xE4 ; lsb of 0x1CE4
    #d8  0x91 ; lsb of 0x1D91
    #d8  0x40 ; lsb of 0x1E40
    #d8  0xF1 ; lsb of 0x1EF1
    #d8  0xA4 ; lsb of 0x1FA4
    #d8  0x59 ; lsb of 0x2059
    #d8  0x10 ; lsb of 0x2110
    #d8  0xC9 ; lsb of 0x21C9
    #d8  0x84 ; lsb of 0x2284
    #d8  0x41 ; lsb of 0x2341
    #d8  0x00 ; lsb of 0x2400
    #d8  0xC1 ; lsb of 0x24C1
    #d8  0x84 ; lsb of 0x2584
    #d8  0x49 ; lsb of 0x2649
    #d8  0x10 ; lsb of 0x2710
    #d8  0xD9 ; lsb of 0x27D9
    #d8  0xA4 ; lsb of 0x28A4
    #d8  0x71 ; lsb of 0x2971
    #d8  0x40 ; lsb of 0x2A40
    #d8  0x11 ; lsb of 0x2B11
    #d8  0xE4 ; lsb of 0x2BE4
    #d8  0xB9 ; lsb of 0x2CB9
    #d8  0x90 ; lsb of 0x2D90
    #d8  0x69 ; lsb of 0x2E69
    #d8  0x44 ; lsb of 0x2F44
    #d8  0x21 ; lsb of 0x3021
    #d8  0x00 ; lsb of 0x3100
    #d8  0xE1 ; lsb of 0x31E1
    #d8  0xC4 ; lsb of 0x32C4
    #d8  0xA9 ; lsb of 0x33A9
    #d8  0x90 ; lsb of 0x3490
    #d8  0x79 ; lsb of 0x3579
    #d8  0x64 ; lsb of 0x3664
    #d8  0x51 ; lsb of 0x3751
    #d8  0x40 ; lsb of 0x3840
    #d8  0x31 ; lsb of 0x3931
    #d8  0x24 ; lsb of 0x3A24
    #d8  0x19 ; lsb of 0x3B19
    #d8  0x10 ; lsb of 0x3C10
    #d8  0x09 ; lsb of 0x3D09
    #d8  0x04 ; lsb of 0x3E04
    #d8  0x01 ; lsb of 0x3F01
    #d8  0x00 ; lsb of 0x4000
    #d8  0x01 ; lsb of 0x4101
    #d8  0x04 ; lsb of 0x4204
    #d8  0x09 ; lsb of 0x4309
    #d8  0x10 ; lsb of 0x4410
    #d8  0x19 ; lsb of 0x4519
    #d8  0x24 ; lsb of 0x4624
    #d8  0x31 ; lsb of 0x4731
    #d8  0x40 ; lsb of 0x4840
    #d8  0x51 ; lsb of 0x4951
    #d8  0x64 ; lsb of 0x4A64
    #d8  0x79 ; lsb of 0x4B79
    #d8  0x90 ; lsb of 0x4C90
    #d8  0xA9 ; lsb of 0x4DA9
    #d8  0xC4 ; lsb of 0x4EC4
    #d8  0xE1 ; lsb of 0x4FE1
    #d8  0x00 ; lsb of 0x5100
    #d8  0x21 ; lsb of 0x5221
    #d8  0x44 ; lsb of 0x5344
    #d8  0x69 ; lsb of 0x5469
    #d8  0x90 ; lsb of 0x5590
    #d8  0xB9 ; lsb of 0x56B9
    #d8  0xE4 ; lsb of 0x57E4
    #d8  0x11 ; lsb of 0x5911
    #d8  0x40 ; lsb of 0x5A40
    #d8  0x71 ; lsb of 0x5B71
    #d8  0xA4 ; lsb of 0x5CA4
    #d8  0xD9 ; lsb of 0x5DD9
    #d8  0x10 ; lsb of 0x5F10
    #d8  0x49 ; lsb of 0x6049
    #d8  0x84 ; lsb of 0x6184
    #d8  0xC1 ; lsb of 0x62C1
    #d8  0x00 ; lsb of 0x6400
    #d8  0x41 ; lsb of 0x6541
    #d8  0x84 ; lsb of 0x6684
    #d8  0xC9 ; lsb of 0x67C9
    #d8  0x10 ; lsb of 0x6910
    #d8  0x59 ; lsb of 0x6A59
    #d8  0xA4 ; lsb of 0x6BA4
    #d8  0xF1 ; lsb of 0x6CF1
    #d8  0x40 ; lsb of 0x6E40
    #d8  0x91 ; lsb of 0x6F91
    #d8  0xE4 ; lsb of 0x70E4
    #d8  0x39 ; lsb of 0x7239
    #d8  0x90 ; lsb of 0x7390
    #d8  0xE9 ; lsb of 0x74E9
    #d8  0x44 ; lsb of 0x7644
    #d8  0xA1 ; lsb of 0x77A1
    #d8  0x00 ; lsb of 0x7900
    #d8  0x61 ; lsb of 0x7A61
    #d8  0xC4 ; lsb of 0x7BC4
    #d8  0x29 ; lsb of 0x7D29
    #d8  0x90 ; lsb of 0x7E90
    #d8  0xF9 ; lsb of 0x7FF9
    #d8  0x64 ; lsb of 0x8164
    #d8  0xD1 ; lsb of 0x82D1
    #d8  0x40 ; lsb of 0x8440
    #d8  0xB1 ; lsb of 0x85B1
    #d8  0x24 ; lsb of 0x8724
    #d8  0x99 ; lsb of 0x8899
    #d8  0x10 ; lsb of 0x8A10
    #d8  0x89 ; lsb of 0x8B89
    #d8  0x04 ; lsb of 0x8D04
    #d8  0x81 ; lsb of 0x8E81
    #d8  0x00 ; lsb of 0x9000
    #d8  0x81 ; lsb of 0x9181
    #d8  0x04 ; lsb of 0x9304
    #d8  0x89 ; lsb of 0x9489
    #d8  0x10 ; lsb of 0x9610
    #d8  0x99 ; lsb of 0x9799
    #d8  0x24 ; lsb of 0x9924
    #d8  0xB1 ; lsb of 0x9AB1
    #d8  0x40 ; lsb of 0x9C40
    #d8  0xD1 ; lsb of 0x9DD1
    #d8  0x64 ; lsb of 0x9F64
    #d8  0xF9 ; lsb of 0xA0F9
    #d8  0x90 ; lsb of 0xA290
    #d8  0x29 ; lsb of 0xA429
    #d8  0xC4 ; lsb of 0xA5C4
    #d8  0x61 ; lsb of 0xA761
    #d8  0x00 ; lsb of 0xA900
    #d8  0xA1 ; lsb of 0xAAA1
    #d8  0x44 ; lsb of 0xAC44
    #d8  0xE9 ; lsb of 0xADE9
    #d8  0x90 ; lsb of 0xAF90
    #d8  0x39 ; lsb of 0xB139
    #d8  0xE4 ; lsb of 0xB2E4
    #d8  0x91 ; lsb of 0xB491
    #d8  0x40 ; lsb of 0xB640
    #d8  0xF1 ; lsb of 0xB7F1
    #d8  0xA4 ; lsb of 0xB9A4
    #d8  0x59 ; lsb of 0xBB59
    #d8  0x10 ; lsb of 0xBD10
    #d8  0xC9 ; lsb of 0xBEC9
    #d8  0x84 ; lsb of 0xC084
    #d8  0x41 ; lsb of 0xC241
    #d8  0x00 ; lsb of 0xC400
    #d8  0xC1 ; lsb of 0xC5C1
    #d8  0x84 ; lsb of 0xC784
    #d8  0x49 ; lsb of 0xC949
    #d8  0x10 ; lsb of 0xCB10
    #d8  0xD9 ; lsb of 0xCCD9
    #d8  0xA4 ; lsb of 0xCEA4
    #d8  0x71 ; lsb of 0xD071
    #d8  0x40 ; lsb of 0xD240
    #d8  0x11 ; lsb of 0xD411
    #d8  0xE4 ; lsb of 0xD5E4
    #d8  0xB9 ; lsb of 0xD7B9
    #d8  0x90 ; lsb of 0xD990
    #d8  0x69 ; lsb of 0xDB69
    #d8  0x44 ; lsb of 0xDD44
    #d8  0x21 ; lsb of 0xDF21
    #d8  0x00 ; lsb of 0xE100
    #d8  0xE1 ; lsb of 0xE2E1
    #d8  0xC4 ; lsb of 0xE4C4
    #d8  0xA9 ; lsb of 0xE6A9
    #d8  0x90 ; lsb of 0xE890
    #d8  0x79 ; lsb of 0xEA79
    #d8  0x64 ; lsb of 0xEC64
    #d8  0x51 ; lsb of 0xEE51
    #d8  0x40 ; lsb of 0xF040
    #d8  0x31 ; lsb of 0xF231
    #d8  0x24 ; lsb of 0xF424
    #d8  0x19 ; lsb of 0xF619
    #d8  0x10 ; lsb of 0xF810
    #d8  0x09 ; lsb of 0xFA09
    #d8  0x04 ; lsb of 0xFC04
    #d8  0x01 ; lsb of 0xFE01

SQTAB_MSB:
    #d8 0x00 ; msb of 0x00
    #d8 0x00 ; msb of 0x01
    #d8 0x00 ; msb of 0x04
    #d8 0x00 ; msb of 0x09
    #d8 0x00 ; msb of 0x10
    #d8 0x00 ; msb of 0x19
    #d8 0x00 ; msb of 0x24
    #d8 0x00 ; msb of 0x31
    #d8 0x00 ; msb of 0x40
    #d8 0x00 ; msb of 0x51
    #d8 0x00 ; msb of 0x64
    #d8 0x00 ; msb of 0x79
    #d8 0x00 ; msb of 0x90
    #d8 0x00 ; msb of 0xA9
    #d8 0x00 ; msb of 0xC4
    #d8 0x00 ; msb of 0xE1
    #d8 0x01 ; msb of 0x100
    #d8 0x01 ; msb of 0x121
    #d8 0x01 ; msb of 0x144
    #d8 0x01 ; msb of 0x169
    #d8 0x01 ; msb of 0x190
    #d8 0x01 ; msb of 0x1B9
    #d8 0x01 ; msb of 0x1E4
    #d8 0x02 ; msb of 0x211
    #d8 0x02 ; msb of 0x240
    #d8 0x02 ; msb of 0x271
    #d8 0x02 ; msb of 0x2A4
    #d8 0x02 ; msb of 0x2D9
    #d8 0x03 ; msb of 0x310
    #d8 0x03 ; msb of 0x349
    #d8 0x03 ; msb of 0x384
    #d8 0x03 ; msb of 0x3C1
    #d8 0x04 ; msb of 0x400
    #d8 0x04 ; msb of 0x441
    #d8 0x04 ; msb of 0x484
    #d8 0x04 ; msb of 0x4C9
    #d8 0x05 ; msb of 0x510
    #d8 0x05 ; msb of 0x559
    #d8 0x05 ; msb of 0x5A4
    #d8 0x05 ; msb of 0x5F1
    #d8 0x06 ; msb of 0x640
    #d8 0x06 ; msb of 0x691
    #d8 0x06 ; msb of 0x6E4
    #d8 0x07 ; msb of 0x739
    #d8 0x07 ; msb of 0x790
    #d8 0x07 ; msb of 0x7E9
    #d8 0x08 ; msb of 0x844
    #d8 0x08 ; msb of 0x8A1
    #d8 0x09 ; msb of 0x900
    #d8 0x09 ; msb of 0x961
    #d8 0x09 ; msb of 0x9C4
    #d8 0x0A ; msb of 0xA29
    #d8 0x0A ; msb of 0xA90
    #d8 0x0A ; msb of 0xAF9
    #d8 0x0B ; msb of 0xB64
    #d8 0x0B ; msb of 0xBD1
    #d8 0x0C ; msb of 0xC40
    #d8 0x0C ; msb of 0xCB1
    #d8 0x0D ; msb of 0xD24
    #d8 0x0D ; msb of 0xD99
    #d8 0x0E ; msb of 0xE10
    #d8 0x0E ; msb of 0xE89
    #d8 0x0F ; msb of 0xF04
    #d8 0x0F ; msb of 0xF81
    #d8 0x10 ; msb of 0x1000
    #d8 0x10 ; msb of 0x1081
    #d8 0x11 ; msb of 0x1104
    #d8 0x11 ; msb of 0x1189
    #d8 0x12 ; msb of 0x1210
    #d8 0x12 ; msb of 0x1299
    #d8 0x13 ; msb of 0x1324
    #d8 0x13 ; msb of 0x13B1
    #d8 0x14 ; msb of 0x1440
    #d8 0x14 ; msb of 0x14D1
    #d8 0x15 ; msb of 0x1564
    #d8 0x15 ; msb of 0x15F9
    #d8 0x16 ; msb of 0x1690
    #d8 0x17 ; msb of 0x1729
    #d8 0x17 ; msb of 0x17C4
    #d8 0x18 ; msb of 0x1861
    #d8 0x19 ; msb of 0x1900
    #d8 0x19 ; msb of 0x19A1
    #d8 0x1A ; msb of 0x1A44
    #d8 0x1A ; msb of 0x1AE9
    #d8 0x1B ; msb of 0x1B90
    #d8 0x1C ; msb of 0x1C39
    #d8 0x1C ; msb of 0x1CE4
    #d8 0x1D ; msb of 0x1D91
    #d8 0x1E ; msb of 0x1E40
    #d8 0x1E ; msb of 0x1EF1
    #d8 0x1F ; msb of 0x1FA4
    #d8 0x20 ; msb of 0x2059
    #d8 0x21 ; msb of 0x2110
    #d8 0x21 ; msb of 0x21C9
    #d8 0x22 ; msb of 0x2284
    #d8 0x23 ; msb of 0x2341
    #d8 0x24 ; msb of 0x2400
    #d8 0x24 ; msb of 0x24C1
    #d8 0x25 ; msb of 0x2584
    #d8 0x26 ; msb of 0x2649
    #d8 0x27 ; msb of 0x2710
    #d8 0x27 ; msb of 0x27D9
    #d8 0x28 ; msb of 0x28A4
    #d8 0x29 ; msb of 0x2971
    #d8 0x2A ; msb of 0x2A40
    #d8 0x2B ; msb of 0x2B11
    #d8 0x2B ; msb of 0x2BE4
    #d8 0x2C ; msb of 0x2CB9
    #d8 0x2D ; msb of 0x2D90
    #d8 0x2E ; msb of 0x2E69
    #d8 0x2F ; msb of 0x2F44
    #d8 0x30 ; msb of 0x3021
    #d8 0x31 ; msb of 0x3100
    #d8 0x31 ; msb of 0x31E1
    #d8 0x32 ; msb of 0x32C4
    #d8 0x33 ; msb of 0x33A9
    #d8 0x34 ; msb of 0x3490
    #d8 0x35 ; msb of 0x3579
    #d8 0x36 ; msb of 0x3664
    #d8 0x37 ; msb of 0x3751
    #d8 0x38 ; msb of 0x3840
    #d8 0x39 ; msb of 0x3931
    #d8 0x3A ; msb of 0x3A24
    #d8 0x3B ; msb of 0x3B19
    #d8 0x3C ; msb of 0x3C10
    #d8 0x3D ; msb of 0x3D09
    #d8 0x3E ; msb of 0x3E04
    #d8 0x3F ; msb of 0x3F01
    #d8 0x40 ; msb of 0x4000
    #d8 0x41 ; msb of 0x4101
    #d8 0x42 ; msb of 0x4204
    #d8 0x43 ; msb of 0x4309
    #d8 0x44 ; msb of 0x4410
    #d8 0x45 ; msb of 0x4519
    #d8 0x46 ; msb of 0x4624
    #d8 0x47 ; msb of 0x4731
    #d8 0x48 ; msb of 0x4840
    #d8 0x49 ; msb of 0x4951
    #d8 0x4A ; msb of 0x4A64
    #d8 0x4B ; msb of 0x4B79
    #d8 0x4C ; msb of 0x4C90
    #d8 0x4D ; msb of 0x4DA9
    #d8 0x4E ; msb of 0x4EC4
    #d8 0x4F ; msb of 0x4FE1
    #d8 0x51 ; msb of 0x5100
    #d8 0x52 ; msb of 0x5221
    #d8 0x53 ; msb of 0x5344
    #d8 0x54 ; msb of 0x5469
    #d8 0x55 ; msb of 0x5590
    #d8 0x56 ; msb of 0x56B9
    #d8 0x57 ; msb of 0x57E4
    #d8 0x59 ; msb of 0x5911
    #d8 0x5A ; msb of 0x5A40
    #d8 0x5B ; msb of 0x5B71
    #d8 0x5C ; msb of 0x5CA4
    #d8 0x5D ; msb of 0x5DD9
    #d8 0x5F ; msb of 0x5F10
    #d8 0x60 ; msb of 0x6049
    #d8 0x61 ; msb of 0x6184
    #d8 0x62 ; msb of 0x62C1
    #d8 0x64 ; msb of 0x6400
    #d8 0x65 ; msb of 0x6541
    #d8 0x66 ; msb of 0x6684
    #d8 0x67 ; msb of 0x67C9
    #d8 0x69 ; msb of 0x6910
    #d8 0x6A ; msb of 0x6A59
    #d8 0x6B ; msb of 0x6BA4
    #d8 0x6C ; msb of 0x6CF1
    #d8 0x6E ; msb of 0x6E40
    #d8 0x6F ; msb of 0x6F91
    #d8 0x70 ; msb of 0x70E4
    #d8 0x72 ; msb of 0x7239
    #d8 0x73 ; msb of 0x7390
    #d8 0x74 ; msb of 0x74E9
    #d8 0x76 ; msb of 0x7644
    #d8 0x77 ; msb of 0x77A1
    #d8 0x79 ; msb of 0x7900
    #d8 0x7A ; msb of 0x7A61
    #d8 0x7B ; msb of 0x7BC4
    #d8 0x7D ; msb of 0x7D29
    #d8 0x7E ; msb of 0x7E90
    #d8 0x7F ; msb of 0x7FF9
    #d8 0x81 ; msb of 0x8164
    #d8 0x82 ; msb of 0x82D1
    #d8 0x84 ; msb of 0x8440
    #d8 0x85 ; msb of 0x85B1
    #d8 0x87 ; msb of 0x8724
    #d8 0x88 ; msb of 0x8899
    #d8 0x8A ; msb of 0x8A10
    #d8 0x8B ; msb of 0x8B89
    #d8 0x8D ; msb of 0x8D04
    #d8 0x8E ; msb of 0x8E81
    #d8 0x90 ; msb of 0x9000
    #d8 0x91 ; msb of 0x9181
    #d8 0x93 ; msb of 0x9304
    #d8 0x94 ; msb of 0x9489
    #d8 0x96 ; msb of 0x9610
    #d8 0x97 ; msb of 0x9799
    #d8 0x99 ; msb of 0x9924
    #d8 0x9A ; msb of 0x9AB1
    #d8 0x9C ; msb of 0x9C40
    #d8 0x9D ; msb of 0x9DD1
    #d8 0x9F ; msb of 0x9F64
    #d8 0xA0 ; msb of 0xA0F9
    #d8 0xA2 ; msb of 0xA290
    #d8 0xA4 ; msb of 0xA429
    #d8 0xA5 ; msb of 0xA5C4
    #d8 0xA7 ; msb of 0xA761
    #d8 0xA9 ; msb of 0xA900
    #d8 0xAA ; msb of 0xAAA1
    #d8 0xAC ; msb of 0xAC44
    #d8 0xAD ; msb of 0xADE9
    #d8 0xAF ; msb of 0xAF90
    #d8 0xB1 ; msb of 0xB139
    #d8 0xB2 ; msb of 0xB2E4
    #d8 0xB4 ; msb of 0xB491
    #d8 0xB6 ; msb of 0xB640
    #d8 0xB7 ; msb of 0xB7F1
    #d8 0xB9 ; msb of 0xB9A4
    #d8 0xBB ; msb of 0xBB59
    #d8 0xBD ; msb of 0xBD10
    #d8 0xBE ; msb of 0xBEC9
    #d8 0xC0 ; msb of 0xC084
    #d8 0xC2 ; msb of 0xC241
    #d8 0xC4 ; msb of 0xC400
    #d8 0xC5 ; msb of 0xC5C1
    #d8 0xC7 ; msb of 0xC784
    #d8 0xC9 ; msb of 0xC949
    #d8 0xCB ; msb of 0xCB10
    #d8 0xCC ; msb of 0xCCD9
    #d8 0xCE ; msb of 0xCEA4
    #d8 0xD0 ; msb of 0xD071
    #d8 0xD2 ; msb of 0xD240
    #d8 0xD4 ; msb of 0xD411
    #d8 0xD5 ; msb of 0xD5E4
    #d8 0xD7 ; msb of 0xD7B9
    #d8 0xD9 ; msb of 0xD990
    #d8 0xDB ; msb of 0xDB69
    #d8 0xDD ; msb of 0xDD44
    #d8 0xDF ; msb of 0xDF21
    #d8 0xE1 ; msb of 0xE100
    #d8 0xE2 ; msb of 0xE2E1
    #d8 0xE4 ; msb of 0xE4C4
    #d8 0xE6 ; msb of 0xE6A9
    #d8 0xE8 ; msb of 0xE890
    #d8 0xEA ; msb of 0xEA79
    #d8 0xEC ; msb of 0xEC64
    #d8 0xEE ; msb of 0xEE51
    #d8 0xF0 ; msb of 0xF040
    #d8 0xF2 ; msb of 0xF231
    #d8 0xF4 ; msb of 0xF424
    #d8 0xF6 ; msb of 0xF619
    #d8 0xF8 ; msb of 0xF810
    #d8 0xFA ; msb of 0xFA09
    #d8 0xFC ; msb of 0xFC04
    #d8 0xFE ; msb of 0xFE01
