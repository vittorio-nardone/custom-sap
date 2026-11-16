#!/usr/bin/env python3
"""Functional + cycle microbench for LDA/STA (YDE)+."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "scripts" / "python"))

from microcode import INSTRUCTIONS_SET, verifyInstructionSet  # noqa: E402


def assemble(src: Path, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(
        ["customasm", str(src), "-f", "binary", "-o", str(out)],
        cwd=ROOT,
    )


def run_app(bin_path: Path) -> tuple[str, dict]:
    dump = Path("/tmp/yde_postinc_regs.json")
    if dump.exists():
        dump.unlink()
    proc = subprocess.run(
        [
            sys.executable,
            str(ROOT / "simulate.py"),
            "--autorun",
            "--program",
            str(bin_path),
            "--max-cycles",
            "2000000",
            "--quiet",
            "--dump-regs",
            str(dump),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    regs = json.loads(dump.read_text()) if dump.exists() else {}
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr, file=sys.stderr)
        raise SystemExit(f"simulator failed: {proc.returncode}")
    return proc.stdout, regs


def _add_op(cycles: int, name: str, taken: bool | None = None) -> int:
    inst = INSTRUCTIONS_SET[name]
    if taken is True and inst.get("cycles_true") is not None:
        return cycles + inst["cycles_true"]
    if taken is False and inst.get("cycles_true") is not None:
        return cycles + inst["cycles"]
    return cycles + inst["cycles"]


def store_walk_cycles(kind: str, nbytes: int = 64) -> int:
    """Opcode-cost model matching storage_store_entry old vs new."""
    verifyInstructionSet()
    c = 0
    e = 0
    if kind == "old":
        # per byte: LDA zp,x + PHX + LDXi + STAydeax + PLX + INE + BNEp [+ IND] + INX + JMPp
        for i in range(nbytes):
            c = _add_op(c, "LDApx")
            c = _add_op(c, "PHX")
            c = _add_op(c, "LDXi")
            c = _add_op(c, "STAydeax", taken=False)  # X=0, no page-cross via index
            c = _add_op(c, "PLX")
            c = _add_op(c, "INE")
            e = (e + 1) & 0xFF
            if e == 0:
                c = _add_op(c, "BNEp", taken=False)
                c = _add_op(c, "IND")
            else:
                c = _add_op(c, "BNEp", taken=True)
            c = _add_op(c, "INX")
            c = _add_op(c, "JMPp")
    else:
        for _ in range(nbytes):
            c = _add_op(c, "LDApx")
            wrapped = e == 0xFF
            c = _add_op(c, "STAydeinc", taken=wrapped)
            e = (e + 1) & 0xFF
            c = _add_op(c, "INX")
            c = _add_op(c, "JMPp")
    return c


def string24_walk_cycles(use_new: bool, nchars: int) -> int:
    """Walk cost only (no UART wait/TX), including NUL terminator handling."""
    verifyInstructionSet()
    c = 0
    e = 0
    if use_new:
        for i in range(nchars + 1):  # chars + NUL
            wrapped = e == 0xFF
            c = _add_op(c, "LDAydeinc", taken=wrapped)
            e = (e + 1) & 0xFF
            if i == nchars:
                # DEE; CPE #FF; BNE; maybe DED
                c = _add_op(c, "DEE")
                e = (e - 1) & 0xFF
                c = _add_op(c, "CPEi")
                if e == 0xFF:
                    c = _add_op(c, "BNEp", taken=False)
                    c = _add_op(c, "DED")
                else:
                    c = _add_op(c, "BNEp", taken=True)
                break
            c = _add_op(c, "JMPp")
    else:
        # ldx #0 once
        c = _add_op(c, "LDXi")
        for i in range(nchars + 1):
            c = _add_op(c, "LDAydeax", taken=False)
            if i == nchars:
                break
            c = _add_op(c, "INE")
            e = (e + 1) & 0xFF
            if e == 0:
                c = _add_op(c, "BNEa", taken=False)
                c = _add_op(c, "IND")
                c = _add_op(c, "JMPa")
            else:
                c = _add_op(c, "BNEa", taken=True)
    return c


def burst_dst_byte_cycles(kind: str) -> int:
    """Per-byte store advance in CH376 DST path (excluding UART wait)."""
    verifyInstructionSet()
    if kind == "old":
        # LDXi + STAydeax + INE + BNEp(taken)  [common case, no wrap]
        c = 0
        c = _add_op(c, "LDXi")
        c = _add_op(c, "STAydeax", taken=False)
        c = _add_op(c, "INE")
        c = _add_op(c, "BNEp", taken=True)
        return c
    c = 0
    c = _add_op(c, "STAydeinc", taken=False)
    return c


def check_postinc_flags() -> None:
    """C stays as it was. O=1 only when E was 0xFF (hardware pulses LO, not LC)."""
    from simulate import OttoCPU

    verifyInstructionSet()
    cpu = OttoCPU()
    base = 0x8400

    def step(opcode: int, *, y: int, d: int, e: int, c: bool, a: int = 0) -> None:
        cpu.PC = base
        cpu.memory[base] = opcode
        cpu.Y, cpu.D, cpu.E, cpu.A = y, d, e, a
        cpu.C, cpu.O = c, False
        cpu.step()

    cpu.memory[0x9000] = 0x11
    step(0xF4, y=0, d=0x90, e=0x00, c=True)
    assert (cpu.A, cpu.D, cpu.E, cpu.Y, cpu.C, cpu.O) == (0x11, 0x90, 0x01, 0, True, False)

    cpu.memory[0x90FF] = 0xAA
    step(0xF4, y=0, d=0x90, e=0xFF, c=False)
    assert (cpu.A, cpu.D, cpu.E, cpu.C, cpu.O) == (0xAA, 0x91, 0x00, False, True)

    cpu.A = 0xCC
    step(0xF5, y=0, d=0x92, e=0xFF, c=True, a=0xCC)
    assert cpu.memory[0x92FF] == 0xCC
    assert (cpu.D, cpu.E, cpu.C, cpu.O) == (0x93, 0x00, True, True)

    cpu.memory[0x0109FF] = 0xDD
    step(0xF6, y=1, d=0x09, e=0xFF, c=True)
    assert (cpu.A, cpu.D, cpu.E, cpu.Y, cpu.C, cpu.O) == (0xDD, 0x0A, 0x00, 1, True, True)

    step(0xF8, y=1, d=0x0A, e=0x00, c=False, a=0xEE)
    assert cpu.memory[0x010A00] == 0xEE
    assert (cpu.D, cpu.E, cpu.Y, cpu.C, cpu.O) == (0x0A, 0x01, 1, False, False)
    print("post-inc flags: C preserved, O tracks E wrap")


def check_jmp_indexed_carry() -> None:
    """JMP (zp,X) adds X to the 16-bit address. C stays unchanged."""
    from simulate import OttoCPU

    cpu = OttoCPU()
    cpu.memory[0x8400] = 0xF3
    cpu.memory[0x8401] = 0x90
    cpu.memory[0x8402] = 0xFE
    cpu.memory[0x9100] = 0x33
    cpu.memory[0x9101] = 0x44
    cpu.PC = 0x8400
    cpu.X = 2
    cpu.C = True
    cpu.A = 0xA5
    cpu.step()
    assert cpu.PC == 0x3344
    assert cpu.C is True and cpu.O is True and cpu.A == 0xA5
    print("JMP (zp,X): carry into table high byte, C preserved")


def main() -> None:
    check_postinc_flags()
    check_jmp_indexed_carry()
    verifyInstructionSet()
    lda = INSTRUCTIONS_SET["LDAydeinc"]
    sta = INSTRUCTIONS_SET["STAydeinc"]
    print(f"opcodes: LDA (YDE)+ = 0x{lda['c']:02X} ({lda['cycles']}/{lda['cycles_true']} cyc)")
    print(f"         STA (YDE)+ = 0x{sta['c']:02X} ({sta['cycles']}/{sta['cycles_true']} cyc)")

    app_src = ROOT / "apps" / "yde_postinc_test.asm"
    app_bin = ROOT / "roms" / "apps" / "current" / "asm" / "yde_postinc_test.bin"
    assemble(app_src, app_bin)
    out, regs = run_app(app_bin)
    print("--- simulator output ---")
    print(out)
    if "FAIL" in out or "OK" not in out or "bench_ok" not in out:
        raise SystemExit("functional test failed")
    if regs.get("OUT") != 0xAA:
        print("regs:", regs)
        raise SystemExit(f"unexpected OUT={regs.get('OUT')!r}")

    old_st = store_walk_cycles("old", 64)
    new_st = store_walk_cycles("new", 64)
    print(
        f"menu store_entry-style 64B: old={old_st} new={new_st} "
        f"saved={old_st - new_st} ({100 * (old_st - new_st) / old_st:.1f}%)"
    )

    msg_len = len(b"Hello, Otto expansion!")
    old_s = string24_walk_cycles(False, msg_len)
    new_s = string24_walk_cycles(True, msg_len)
    print(
        f"STRING24 walk ({msg_len} chars, no UART): old={old_s} new={new_s} "
        f"saved={old_s - new_s} ({100 * (old_s - new_s) / old_s:.1f}%)"
    )

    old_b = burst_dst_byte_cycles("old")
    new_b = burst_dst_byte_cycles("new")
    print(
        f"burst DST per-byte (no UART): old={old_b} new={new_b} "
        f"saved={old_b - new_b} ({100 * (old_b - new_b) / old_b:.1f}%)"
    )

    before = Path("/tmp/kernel-rom.before.bin")
    after = ROOT / "roms" / "system" / "kernel-rom.bin"
    if before.exists():
        print(f"kernel-rom.bin bytes: before={before.stat().st_size} after={after.stat().st_size} "
              f"saved={before.stat().st_size - after.stat().st_size}")


if __name__ == "__main__":
    main()
