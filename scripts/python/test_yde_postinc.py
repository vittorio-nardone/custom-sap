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


def main() -> None:
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
