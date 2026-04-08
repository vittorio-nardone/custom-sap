#!/usr/bin/env python3
"""
Confronta l'output P-Machine tra cross-compiler (Python) e compilatore on-board (IDE a 0x020000).

Per ogni pascal/examples/*.pas: compila con pascal_compiler.py, esegue in simulate --quiet;
poi esegue tinypascal_ide.bin con n/lo/.../r (due linee vuote terminano lo) e estrae il blocco
tra "P-Machine (...): started" e "execution complete".

Uso (venv attivo, dalla root):
  python pascal/tools/compare_pascal_ide_cross.py
  python pascal/tools/compare_pascal_ide_cross.py --only hello.pas
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXAMPLES = ROOT / "pascal" / "examples"
IDE_BIN = ROOT / "roms" / "apps" / "asm" / "tinypascal_ide.bin"

PM_BLOCK = re.compile(
    r"P-Machine \([^)]+\): started\r?\n(.*)\r?\nP-Machine \([^)]+\): execution complete",
    re.DOTALL,
)

# readln: stesso input dopo 'r' nell'IDE e in --input per il cross-run
READLN_EXTRA: dict[str, str] = {
    "string_readln_delay.pas": "Otto\r",
}

# output non deterministico / confronto non applicabile
SKIP_COMPARE: dict[str, str] = {
    "random.pas": "random non deterministico",
    "peekpoke.pas": "poke(2,0,…) corrompe il binario IDE a 0x020000 nello stesso run",
    "mandelbrot.pas": "serve >100M cicli per 40x20 in compare automatico",
}

# cicli extra per esempi pesanti
MAX_CYCLES: dict[str, int] = {
    "tinypascal_suite.pas": 18_000_000,
    "vt100_demo.pas": 12_000_000,
    "string_readln_delay.pas": 12_000_000,
    "float_func.pas": 8_000_000,
}


def normalize(s: str) -> str:
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    return s.rstrip("\n")


def extract_pm_body(full: str) -> str | None:
    m = PM_BLOCK.search(full)
    if not m:
        return None
    return normalize(m.group(1))


def build_ide_input(pas_path: Path, after_run: str) -> str:
    lines = pas_path.read_text(encoding="utf-8").splitlines()
    parts = ["n\r", "lo\r"]
    for line in lines:
        parts.append(line + "\r")
    parts.append("\r\r")
    parts.append("r\r")
    parts.append(after_run)
    parts.append("q\r")
    return "".join(parts)


def run_cross(bin_path: Path, max_cycles: int, extra_input: str) -> tuple[int, str]:
    # No --quiet: con --input in coda a KEY, _app_started in simulate può restare false
    # e --quiet sopprimerebbe l'output del programma.
    cmd = [
        sys.executable,
        str(ROOT / "simulate.py"),
        "--autorun",
        "--program",
        str(bin_path),
        "--max-cycles",
        str(max_cycles),
    ]
    if extra_input:
        cmd.extend(["--input", extra_input])
    r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    return r.returncode, out


def run_ide(inp: str, max_cycles: int) -> tuple[int, str]:
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
        inp,
    ]
    r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    return r.returncode, out


def compile_pas(pas_path: Path, out_bin: Path) -> int:
    r = subprocess.run(
        [
            sys.executable,
            str(ROOT / "pascal_compiler.py"),
            str(pas_path),
            "-o",
            str(out_bin),
        ],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    if r.returncode != 0 and r.stderr:
        print(r.stderr, file=sys.stderr)
    return r.returncode


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", type=str, default=None, help="Solo questo file (es. hello.pas)")
    args = ap.parse_args()

    if not IDE_BIN.is_file():
        print(f"Manca {IDE_BIN}; eseguire ./generate-all.sh", file=sys.stderr)
        return 2

    files = sorted(EXAMPLES.glob("*.pas"))
    if args.only:
        files = [EXAMPLES / args.only]
        if not files[0].is_file():
            print(f"File non trovato: {files[0]}", file=sys.stderr)
            return 2

    failures: list[str] = []
    skipped: list[str] = []

    with tempfile.TemporaryDirectory() as td:
        tdir = Path(td)
        for pas in files:
            rel = pas.name
            max_c = MAX_CYCLES.get(rel, 12_000_000)
            extra = READLN_EXTRA.get(rel, "")

            if rel in SKIP_COMPARE:
                skipped.append(f"{rel}: {SKIP_COMPARE[rel]}")
                continue

            bin_path = tdir / (pas.stem + ".bin")
            if compile_pas(pas, bin_path) != 0:
                failures.append(f"{rel}: compile cross fallita")
                continue

            cr, cross_out = run_cross(bin_path, max_c, extra)
            if cr != 0:
                failures.append(f"{rel}: simulate cross exit {cr}")
                continue
            cross_body = extract_pm_body(cross_out)
            if cross_body is None:
                failures.append(f"{rel}: cross: blocco P-Machine non trovato")
                continue

            ide_in = build_ide_input(pas, extra)
            ir, ide_out = run_ide(ide_in, max_c)
            if ir != 0:
                failures.append(f"{rel}: simulate IDE exit {ir}")
                continue
            if "Err L" in ide_out:
                failures.append(f'{rel}: IDE: "Err L"')
                continue
            ide_body = extract_pm_body(ide_out)
            if ide_body is None:
                failures.append(f"{rel}: IDE: blocco P-Machine non trovato")
                continue

            if cross_body != ide_body:
                failures.append(f"{rel}: output diverso\n--- cross ---\n{cross_body!r}\n--- ide ---\n{ide_body!r}")

    for s in skipped:
        print(f"SKIP {s}")
    if failures:
        for f in failures:
            print(f"FAIL {f}")
        return 1
    print(f"OK: {len(files) - len(skipped)} esempi confrontati, identici.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
