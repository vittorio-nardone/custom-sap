#!/usr/bin/env python3
"""
Esegue la suite TinyPascal tramite il simulatore: carica tinypascal_ide.bin a 0x020000,
autorun r020000, poi comandi editor n / lo / incolla sorgente / r.

Uso (dalla root del repo, venv attivo):
  python pascal/tools/run_tinypascal_suite.py
  python pascal/tools/run_tinypascal_suite.py --cross   # anche compile+run Python a 0x8400

Exit 0 se compare "OK (" dopo Compiling e non compare "Err L".
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SUITE = ROOT / "pascal" / "examples" / "tinypascal_suite.pas"
IDE_BIN = ROOT / "roms" / "apps" / "asm" / "tinypascal_ide.bin"


def build_ide_lo_input(suite_path: Path) -> str:
    text = suite_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    parts = ["n\r", "lo\r"]
    for line in lines:
        parts.append(line + "\r")
    parts.append("\r\r")  # due linee vuote consecutive terminano il paste (lo)
    parts.append("r\r")
    parts.append("q\r")  # esci dall'editor
    return "".join(parts)


def run_simulate(extra_input: str, max_cycles: int) -> tuple[int, str]:
    cmd = [
        sys.executable,
        str(ROOT / "simulate.py"),
        "--autorun",
        "--program",
        str(IDE_BIN),
        "--address",
        "0x020000",
        "--max-cycles",
        str(max_cycles),
        "--input",
        extra_input,
    ]
    r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    return r.returncode, out


def check_onboard_output(out: str) -> list[str]:
    errs: list[str] = []
    if "Err L" in out:
        errs.append('Trovato "Err L" (errore compilatore on-board)')
    if "OK (" not in out:
        errs.append('Manca "OK (" dopo la compilazione on-board')
    low = out.lower()
    if "invalid p-code" in low:
        errs.append("P-Machine: invalid P-code")
    return errs


def run_python_cross(suite_path: Path, max_cycles: int) -> int:
    out_bin = ROOT / "roms" / "apps" / "pascal" / "_suite_cross.bin"
    out_bin.parent.mkdir(parents=True, exist_ok=True)
    r1 = subprocess.run(
        [
            sys.executable,
            str(ROOT / "pascal_compiler.py"),
            str(suite_path),
            "-o",
            str(out_bin),
        ],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    print(r1.stdout, end="")
    if r1.returncode != 0:
        print(r1.stderr, file=sys.stderr)
        return r1.returncode
    r2 = subprocess.run(
        [
            sys.executable,
            str(ROOT / "simulate.py"),
            "--autorun",
            "--program",
            str(out_bin),
            "--max-cycles",
            str(max_cycles),
            "--quiet",
        ],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    print(r2.stdout, end="")
    if r2.stderr:
        print(r2.stderr, file=sys.stderr)
    return r2.returncode


def main() -> int:
    ap = argparse.ArgumentParser(description="Test TinyPascal on-board via IDE nel simulatore")
    ap.add_argument(
        "--suite",
        type=Path,
        default=DEFAULT_SUITE,
        help="File .pas della suite (default: pascal/examples/tinypascal_suite.pas)",
    )
    ap.add_argument("--max-cycles", type=int, default=12_000_000)
    ap.add_argument(
        "--cross",
        action="store_true",
        help="Esegue anche pascal_compiler.py + simulate su binario a 0x8400",
    )
    ap.add_argument("-q", "--quiet", action="store_true", help="Non stampare tutto lo stdout")
    args = ap.parse_args()

    if not IDE_BIN.is_file():
        print(f"Manca {IDE_BIN}; eseguire ./generate-all.sh", file=sys.stderr)
        return 2

    if args.cross:
        print("--- Cross-compiler (Python) + P-Machine @ 0x8400 ---")
        cr = run_python_cross(args.suite, min(args.max_cycles, 4_000_000))
        if cr != 0:
            return cr

    inp = build_ide_lo_input(args.suite)
    code, out = run_simulate(inp, args.max_cycles)
    if not args.quiet:
        print(out)
    problems = check_onboard_output(out)
    if problems:
        for p in problems:
            print(p, file=sys.stderr)
        return 1
    if code != 0:
        print(f"simulate.py exit {code}", file=sys.stderr)
        return code
    print("OK: compilazione on-board riuscita (messaggio OK + nessun Err L)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
