from intelhex import IntelHex


##### Segments mapping
SEG_G = 0x01
SEG_F = 0x02
SEG_E = 0x04
SEG_D = 0x08
SEG_C = 0x10
SEG_B = 0x20
SEG_A = 0x40
SEG_H = 0x80

##### Value to segments mapping
SEG_MAP = [
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F,
    SEG_B | SEG_C,
    SEG_A | SEG_B | SEG_D | SEG_E | SEG_G,
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_G,
    SEG_B | SEG_C | SEG_F | SEG_G,
    SEG_A | SEG_C | SEG_D | SEG_F | SEG_G,
    SEG_A | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G,
    SEG_A | SEG_B | SEG_C,
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G,
    SEG_A | SEG_B | SEG_C | SEG_F | SEG_G,
    
    SEG_A | SEG_B | SEG_C | SEG_E | SEG_F | SEG_G,
    SEG_C | SEG_D | SEG_E | SEG_F | SEG_G,
    SEG_A | SEG_D | SEG_E | SEG_F,
    SEG_B | SEG_C | SEG_D | SEG_E | SEG_G,
    SEG_A | SEG_D | SEG_E | SEG_F | SEG_G,
    SEG_A | SEG_E | SEG_F | SEG_G
]

SEG_DOT = SEG_C | SEG_D | SEG_E | SEG_G

##### Generating rom file
ih = IntelHex()

print("Generating 7 segments data")

for v in range(256):        # Value 0->255
    for d in range(4):      # Digit 0->3    (0 = LSB)
        for m in range(2):  # Mode  0->1    (0 = dec, 1 = hex)
            addr = v + (d * 256) + (m * 1024)
            seg = 0

            match m:
                case 0:
                    match d:
                        case 0:
                            digit = v % 10 
                            seg = SEG_MAP[digit]
                        case 1:
                            digit = (v // 10) % 10
                            seg = SEG_MAP[digit]
                        case 2:
                            digit = (v // 100)
                            seg = SEG_MAP[digit]
                        case 3:
                            digit = 0
                            seg = 0
                case 1:
                    match d:
                        case 0:
                            digit = v % 16 
                            seg = SEG_MAP[digit]
                        case 1:
                            digit = (v // 16) % 16
                            seg = SEG_MAP[digit]
                        case 2:
                            digit = 0
                            seg = SEG_DOT
                        case 3:
                            digit = 0
                            seg = SEG_MAP[0]
            
            #print(f"{v:02}/{v:02x} - {d:02} {m:02} - {addr:04x} {digit:02}/{digit:02x} - {seg:02x}")
            ih[addr] = seg

##### Saving rom file
ih.write_hex_file("roms/7seg-rom.hex")
ih.tobinfile("roms/7seg-rom.bin")

print("All done")