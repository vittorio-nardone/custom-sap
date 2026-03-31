; @load-address 0x8400
#bankdef ram
{
    #addr 0x8400
    #size 0x2C00 ; forth memory starts from 0xB000
    #outp 0
}

test_forth:

.test_math_forth:
    #d ": test-math",  0x0D
    #d "  CR .", 0x22, " Running math tests", 0x22, " CR",  0x0D
    #d "   5 3 + 8 = IF .", 0x22, "   5 3 + ... OK", 0x22, " CR ELSE .", 0x22, "   5 3 + ... FAILED", 0x22, " CR THEN",  0x0D
    #d "   10 4 - 6 = IF .", 0x22, "   10 4 - ... OK", 0x22, " CR ELSE .", 0x22, "   10 4 - ... FAILED", 0x22, " CR THEN",  0x0D
    #d "   7 2 * 14 = IF .", 0x22, "   7 2 * ... OK", 0x22, " CR ELSE .", 0x22, "   7 2 * ... FAILED", 0x22, " CR THEN",  0x0D
    #d "   20 5 / 4 = IF .", 0x22, "   20 5 / ... OK", 0x22, " CR ELSE .", 0x22, "   20 5 / ... FAILED", 0x22, " CR THEN",  0x0D
    #d "   10 3 MOD 1 = IF .", 0x22, "   10 3 MOD ... OK", 0x22, " CR ELSE .", 0x22, "   10 3 MOD ... FAILED", 0x22, " CR THEN",  0x0D
    #d ";",  0x0D
    #d 0x00

.test_stack_forth:
    #d ": test-stack", 0x0D
    #d "  CR .", 0x22, " Running stack tests", 0x22, " CR", 0x0D
    #d "  5 DUP 5 = IF .", 0x22, "   DUP ... OK", 0x22, " CR ELSE .", 0x22, "   DUP ... FAILED", 0x22, " CR THEN", 0x0D
    #d "  DROP", 0x0D
    #d "  1 2 DROP 1 = IF .", 0x22, "   DROP ... OK", 0x22, " CR ELSE .", 0x22, "   DROP ... FAILED", 0x22, " CR THEN", 0x0D
    #d "  8 9 SWAP 8 = IF .", 0x22, "   SWAP ... OK", 0x22, " CR ELSE .", 0x22, "   SWAP ... FAILED", 0x22, " CR THEN", 0x0D
    #d "  10 20 OVER 10 = IF .", 0x22, "   OVER ... OK", 0x22, " CR ELSE .", 0x22, "   OVER ... FAILED", 0x22, " CR THEN", 0x0D
    #d "  DROP DROP", 0x0D
    #d "  1 2 3 ROT 1 = IF .", 0x22, "   ROT ... OK", 0x22, " CR ELSE .", 0x22, "   ROT ... FAILED", 0x22, " CR THEN", 0x0D
    #d "  DROP DROP", 0x0D
    #d ";", 0x0D

.test_f_forth:
    #d "( Large letter F )", 0x0D
    #d ": STAR 42 EMIT ;", 0x0D
    #d ": STARS 0 DO STAR LOOP ;", 0x0D
    #d ": MARGIN  CR 30 SPACES ;", 0x0D
    #d ": BLIP MARGIN STAR ;", 0x0D
    #d ": BAR  MARGIN 5 STARS ;", 0x0D
    #d ": F    BAR BLIP BAR BLIP BLIP CR ;", 0x0D
    #d 0x0D
    #d 0x00

.test_run:
    #d ": test test-stack test-math ;",  0x0D
    #d 0x0D