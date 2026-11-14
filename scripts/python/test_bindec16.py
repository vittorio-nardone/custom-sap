#!/usr/bin/env python3
"""Regression + cycle harness for ACIA_SEND_DECIMAL16S / BINDEC16.

Builds apps/bindec16_test.asm, runs it in the simulator, checks stdout against
the golden signed-decimal lines, and attributes cycles to decimal-print
symbols (ACIA_SEND_DECIMAL16S and callees under BINDEC*).

Usage (repo root):
  python3 scripts/python/test_bindec16.py
  python3 scripts/python/test_bindec16.py --json /tmp/bindec16_stats.json
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

APP_SRC = ROOT / "apps" / "bindec16_test.asm"
APP_BIN = ROOT / "roms" / "apps" / "current" / "asm" / "bindec16_test.bin"

# Must match apps/bindec16_test.asm .values (signed 16-bit).
TEST_VALUES = [
    0,
    1,
    9,
    10,
    99,
    100,
    999,
    1000,
    9999,
    10000,
    32767,
    -32768,
    -1,
    -42,
    42,
    6000,
]

EXPECTED_LINES = [str(v) for v in TEST_VALUES]


def expected_output() -> str:
    return (
        "bindec16_test\r\n"
        + "".join(f"{line}\r\n" for line in EXPECTED_LINES)
        + "OK\r\n"
    )


def build_app() -> None:
    APP_BIN.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "customasm",
        str(APP_SRC),
        "-f",
        "binary",
        "-o",
        str(APP_BIN),
    ]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr or r.stdout or "customasm failed\n")
        raise SystemExit(2)


def load_code_symbols() -> list[tuple[int, str]]:
    sym_re = re.compile(r"^#const\s+([A-Z][A-Z0-9_]*)\s+=\s+0x([0-9a-fA-F]+)\s*$")
    out: list[tuple[int, str]] = []
    for line in (ROOT / "kernel" / "symbols.asm").read_text().splitlines():
        m = sym_re.match(line.strip())
        if not m:
            continue
        name, addr = m.group(1), int(m.group(2), 16)
        if 0x00FF <= addr <= 0x5FFF:
            out.append((addr, name))
    out.sort()
    uniq: list[tuple[int, str]] = []
    seen: set[int] = set()
    for a, n in out:
        if a in seen:
            continue
        seen.add(a)
        uniq.append((a, n))
    return uniq


def lookup_sym(code_syms: list[tuple[int, str]], pc: int) -> str:
    if pc >= 0x8400:
        return "app"
    lo, hi = 0, len(code_syms)
    while lo < hi:
        mid = (lo + hi) // 2
        if code_syms[mid][0] <= pc:
            lo = mid + 1
        else:
            hi = mid
    if lo == 0:
        return "boot"
    return code_syms[lo - 1][1]


def run_profiled() -> dict:
    from simulate import OttoCPU, autorun_command_bytes, push_input, run_cpu_loop

    code_syms = load_code_symbols()
    cpu = OttoCPU()
    cpu.load_binary(
        "roms/system/kernel-rom.bin",
        cpu.memory_regions["rom"]["start"],
        auto_detect_header=False,
    )
    effective = cpu.load_binary(str(APP_BIN), 0x8400)

    serial_bytes: list[int] = []
    orig_wb = cpu.write_byte

    def capture_wb(address, value):
        if address == 0x6021:
            # Always capture app+kernel serial during the run; filter later by phase
            if getattr(cpu, "_app_running", False) or getattr(cpu, "_app_started", False):
                serial_bytes.append(value & 0xFF)
            return
        orig_wb(address, value)

    cpu.write_byte = capture_wb

    cpu._app_running = False
    cpu._app_started = False
    cpu._app_sp = 0
    cpu._app_address = effective
    cpu._app_track_enabled = False

    bucket_cyc = Counter()
    app_cyc = 0
    boot_cyc = 0
    orig_step = cpu.step

    def tracked():
        nonlocal app_cyc, boot_cyc
        if not cpu._app_track_enabled:
            if cpu.serial_io is not None or len(cpu.KEY) == 0:
                cpu._app_track_enabled = True
        if (
            cpu._app_track_enabled
            and not cpu._app_running
            and not cpu._app_started
            and cpu.PC >= cpu._app_address
        ):
            cpu._app_running = True
            cpu._app_started = True
            cpu._app_sp = cpu.SP
        elif cpu._app_running and cpu.PC < cpu._app_address and cpu.SP > cpu._app_sp:
            cpu._app_running = False

        pc = cpu.PC
        before = cpu.cycles
        in_app = cpu._app_running
        orig_step()
        added = cpu.cycles - before
        if not in_app:
            boot_cyc += added
            return
        app_cyc += added
        sym = lookup_sym(code_syms, pc)
        if sym.startswith("BINDEC") or sym.startswith("ACIA_SEND_DECIMAL"):
            bucket_cyc["decimal_print"] += added
            bucket_cyc[sym] += added
        elif sym.startswith("ACIA_"):
            bucket_cyc["serial"] += added
        elif sym.startswith("MATH16_NEGATE"):
            bucket_cyc["negate"] += added
            bucket_cyc[sym] += added
        elif sym == "app":
            bucket_cyc["app"] += added
        else:
            bucket_cyc["other"] += added

    cpu.step = tracked
    push_input(cpu, autorun_command_bytes(effective))
    args = SimpleNamespace(autorun=True, max_cycles=5_000_000)
    exit_code, stop_reason = run_cpu_loop(cpu, args)

    # Decode captured serial; strip CR from CRLF pairs for comparison helpers
    text = "".join(chr(b) for b in serial_bytes)
    # Simulator may emit LF or CR; normalize to \n for golden compare after
    # converting CR to nothing when followed by structure we expect with \r\n
    return {
        "exit_code": exit_code,
        "stop_reason": stop_reason,
        "total_cycles": cpu.cycles,
        "boot_cycles": boot_cyc,
        "app_cycles": app_cyc,
        "serial_text": text,
        "buckets": dict(bucket_cyc),
        "decimal_print_cycles": bucket_cyc.get("decimal_print", 0),
        "has_bindec16": any(a for a, n in code_syms if n == "BINDEC16"),
        "bindec16_cycles": bucket_cyc.get("BINDEC16", 0),
        "bindec32_cycles": bucket_cyc.get("BINDEC32", 0),
        "send_decimal16s_cycles": bucket_cyc.get("ACIA_SEND_DECIMAL16S", 0),
        "send_decimal32_cycles": bucket_cyc.get("ACIA_SEND_DECIMAL32", 0),
    }


def normalize_serial(text: str) -> str:
    """Normalize CR/LF to \\n for stable compares."""
    t = text.replace("\r\n", "\n").replace("\n\r", "\n").replace("\r", "\n")
    while "\n\n" in t:
        t = t.replace("\n\n", "\n")
    return t


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", type=Path, default=None)
    ap.add_argument("--skip-build", action="store_true")
    args = ap.parse_args()

    if not args.skip_build:
        print("building", APP_SRC.name, flush=True)
        build_app()

    print("running simulator…", flush=True)
    result = run_profiled()
    got = normalize_serial(result["serial_text"])
    exp = normalize_serial(expected_output())

    ok = got == exp
    print("--- serial ---")
    print(got, end="" if got.endswith("\n") else "\n")
    print("--- check ---")
    if ok:
        print("OUTPUT MATCHES GOLDEN")
    else:
        print("OUTPUT MISMATCH")
        print("expected:")
        print(repr(exp))
        print("got:")
        print(repr(got))

    print("--- cycles ---")
    print(f"app_cycles:              {result['app_cycles']}")
    print(f"decimal_print_cycles:    {result['decimal_print_cycles']}")
    print(f"ACIA_SEND_DECIMAL16S:    {result['send_decimal16s_cycles']}")
    print(f"ACIA_SEND_DECIMAL32:     {result['send_decimal32_cycles']}")
    print(f"BINDEC16:                {result['bindec16_cycles']}")
    print(f"BINDEC32:                {result['bindec32_cycles']}")
    print(f"BINDEC16 symbol present: {result['has_bindec16']}")
    print(f"stop: {result['stop_reason']} exit={result['exit_code']}")

    payload = {
        "ok": ok,
        "expected_lines": EXPECTED_LINES,
        **{k: v for k, v in result.items() if k != "serial_text"},
        "serial_normalized": got,
    }
    if args.json:
        args.json.write_text(json.dumps(payload, indent=2))
        print(f"wrote {args.json}")

    return 0 if ok and result["exit_code"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
