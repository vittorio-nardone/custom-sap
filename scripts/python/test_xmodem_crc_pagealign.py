#!/usr/bin/env python3
"""Reproduce / verify XMODEM CRC table page-alignment vs zp,X hardware limits.

XMODEM_RCV.UpdCrc does `LDA table,x` (zp,X). If the 256-byte CRC tables are not
page-aligned, indices that cross the page read the wrong ROM byte and Otto NAKs
blocks that VGA32 padded with 0x1A — the 1.4.x upload regression.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from simulate import OttoCPU  # noqa: E402


def _sym(path: Path) -> dict[str, int]:
    text = path.read_text()
    out: dict[str, int] = {}
    for m in re.finditer(r"#const (\w+) = (0x[0-9a-fA-F]+)", text):
        out[m.group(1)] = int(m.group(2), 16)
    return out


def _hw_table_read(cpu: OttoCPU, table_base: int, idx: int) -> int:
    """Read ROM[table_base + idx] the way LDA table,x does on hardware."""
    # Encode a fake LDA abs-zp,X at PC and use get_address_from_operands.
    hi = (table_base >> 8) & 0xFF
    lo = table_base & 0xFF
    cpu.memory[0xF000] = 0xBD
    cpu.memory[0xF001] = hi
    cpu.memory[0xF002] = lo
    cpu.PC = 0xF000
    addr = cpu.get_address_from_operands(2, index=idx)
    return cpu.memory[addr & 0xFFFF]


def _crc_hw(cpu: OttoCPU, block: bytes, lo_base: int, hi_base: int) -> tuple[int, int]:
    crc_lo = 0
    crc_hi = 0
    for byte in block:
        idx = byte ^ crc_hi
        th = _hw_table_read(cpu, hi_base, idx)
        tl = _hw_table_read(cpu, lo_base, idx)
        crc_hi = (crc_lo ^ th) & 0xFF
        crc_lo = tl & 0xFF
    return crc_hi, crc_lo


def _crc_ideal(rom: bytes, block: bytes, lo_base: int, hi_base: int) -> tuple[int, int]:
    crc_lo = 0
    crc_hi = 0
    for byte in block:
        idx = byte ^ crc_hi
        th = rom[hi_base + idx]
        tl = rom[lo_base + idx]
        crc_hi = (crc_lo ^ th) & 0xFF
        crc_lo = tl & 0xFF
    return crc_hi, crc_lo


def check_rom(rom_path: Path, sym_path: Path, expect_aligned: bool, expect_1a_match: bool) -> None:
    rom = rom_path.read_bytes()
    sym = _sym(sym_path)
    lo = sym["XMODEM_CRC_LO_TABLE"]
    hi = sym["XMODEM_CRC_HI_TABLE"]
    print(f"  ROM {rom_path} LO={lo:#06x} HI={hi:#06x}")

    aligned = (lo & 0xFF) == 0 and (hi & 0xFF) == 0
    if aligned != expect_aligned:
        raise SystemExit(
            f"alignment: got page_off lo={lo & 0xFF:#x} hi={hi & 0xFF:#x}, "
            f"expect_aligned={expect_aligned}"
        )
    if hi != lo + 0x100:
        raise SystemExit(f"HI table should follow LO at +0x100 (got {hi - lo:#x})")

    cpu = OttoCPU()
    cpu.memory[: len(rom)] = rom

    # Sanity: within-page index must match ideal
    assert _hw_table_read(cpu, lo, 0) == rom[lo]
    assert _hw_table_read(cpu, lo, 1) == rom[lo + 1]

    blk = bytes([0x1A] * 128)  # VGA32 XMODEM pad
    ideal = _crc_ideal(rom, blk, lo, hi)
    hw = _crc_hw(cpu, blk, lo, hi)
    match = ideal == hw
    print(f"  128x0x1A CRC ideal={ideal} hw_zp_x={hw} match={match}")
    if match != expect_1a_match:
        raise SystemExit(
            f"CRC match={match} but expect_1a_match={expect_1a_match} "
            f"(misaligned tables + hw zp,X → NAK on upload)"
        )

    # Also exercise OT-header-ish first block (common F10 payload prefix)
    ot = b"OT\x01\x00\x84\x00" + bytes([0x1A] * 122)
    ot_match = _crc_ideal(rom, ot, lo, hi) == _crc_hw(cpu, ot, lo, hi)
    print(f"  OT+0x1A pad CRC match={ot_match}")
    if expect_aligned and not ot_match:
        raise SystemExit("aligned tables must CRC-match OT padded block")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    rom = ROOT / "roms/system/kernel-rom.bin"
    sym = ROOT / "kernel/symbols.asm"

    if mode == "reproduce":
        print("Expect MISALIGNED tables + CRC mismatch (bug):")
        check_rom(rom, sym, expect_aligned=False, expect_1a_match=False)
        print("test_xmodem_crc_pagealign reproduce: OK (bug present)")
    elif mode == "verify":
        print("Expect page-aligned tables + CRC match (fix):")
        check_rom(rom, sym, expect_aligned=True, expect_1a_match=True)
        print("test_xmodem_crc_pagealign verify: OK (fix confirmed)")
    else:
        raise SystemExit("usage: test_xmodem_crc_pagealign.py [reproduce|verify]")


if __name__ == "__main__":
    main()
