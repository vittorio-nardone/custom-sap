#!/usr/bin/env python3
"""Verify simulator indexed addressing matches Otto microcode page-cross limits.

zp,X / abs,X / DE,X / YDE,X: lo+index does NOT carry into the high byte.
(zp),X / (zp),Y: index DOES carry into the pointer high byte.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from simulate import OttoCPU  # noqa: E402


def _poke_op(cpu: OttoCPU, pc: int, *bytes_: int) -> None:
    for i, b in enumerate(bytes_):
        cpu.memory[pc + i] = b & 0xFF
    cpu.PC = pc


def test_zp_x_no_hi_carry() -> None:
    cpu = OttoCPU()
    # LDA $12FE,X  encoding: opcode + hi + lo (MSB-first u16)
    _poke_op(cpu, 0x8400, 0xBD, 0x12, 0xFE)
    cpu.memory[0x12FE] = 0xAA
    cpu.memory[0x12FF] = 0xBB
    cpu.memory[0x1300] = 0xCC  # would be correct if hi carried
    cpu.memory[0x1200] = 0xDD  # wrap target when X=2: hi stays 0x12, lo=0x00

    # X=0 → $12FE
    cpu.X = 0
    cpu.PC = 0x8400
    assert cpu.get_address_from_operands(2, index=cpu.X) == 0x12FE
    assert cpu.O is False

    # X=1 → $12FF (still same page)
    cpu.PC = 0x8400
    cpu.X = 1
    assert cpu.get_address_from_operands(2, index=cpu.X) == 0x12FF
    assert cpu.O is False

    # X=2 → wrap to $1200, NOT $1300
    cpu.PC = 0x8400
    cpu.X = 2
    assert cpu.get_address_from_operands(2, index=cpu.X) == 0x1200
    assert cpu.O is True


def test_abs_x_no_hi_carry() -> None:
    cpu = OttoCPU()
    # LDA $0012FE,X — page, hi, lo
    _poke_op(cpu, 0x8400, 0xBE, 0x00, 0x12, 0xFE)
    cpu.X = 2
    assert cpu.get_address_from_operands(3, index=cpu.X) == 0x001200
    assert cpu.O is True


def test_de_x_no_d_carry() -> None:
    cpu = OttoCPU()
    cpu.D = 0x12
    cpu.E = 0xFE
    cpu.X = 2
    assert cpu.get_address_from_registries("de", index=cpu.X) == 0x1200
    assert cpu.O is True
    cpu.Y = 0x01
    assert cpu.get_address_from_registries("yde", index=cpu.X) == 0x011200


def test_indirect_x_does_carry() -> None:
    cpu = OttoCPU()
    # Pointer at $8000 = $12FE (MSB-first in Otto indirect? load uses lo then hi+1)
    # load_from_memory reads MARl first then MAR+1 as hi — LE pointer in memory.
    cpu.memory[0x8000] = 0xFE
    cpu.memory[0x8001] = 0x12
    cpu.memory[0x1300] = 0xEE
    _poke_op(cpu, 0x8400, 0xBC, 0x80, 0x00)  # LDA ($8000),X
    cpu.X = 2
    val = cpu.load_from_memory(mem_operands_size=2, index=cpu.X, indirect=True)
    assert cpu.MAR == 0x1300
    assert val == 0xEE
    assert cpu.O is True


def main() -> None:
    test_zp_x_no_hi_carry()
    test_abs_x_no_hi_carry()
    test_de_x_no_d_carry()
    test_indirect_x_does_carry()
    print("test_indexed_pagecross: OK")


if __name__ == "__main__":
    main()
