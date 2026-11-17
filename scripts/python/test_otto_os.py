#!/usr/bin/env python3
"""Simulator tests for Otto OS: PATH, /BIN apps, and STORAGE_* API."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PY = sys.executable
SIM = ROOT / "simulate.py"
STICK = ROOT / "roms/sim/ch376"
ASM = ROOT / "roms/apps/current/asm"


def run_shell(script: str, max_cycles: int = 40_000_000) -> str:
    proc = subprocess.run(
        [
            PY,
            str(SIM),
            "--ch376",
            "--headless",
            "--input",
            script,
            "--max-cycles",
            str(max_cycles),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    out = proc.stdout + proc.stderr
    return out


def run_autorun(program: Path, max_cycles: int = 12_000_000) -> tuple[int, str]:
    proc = subprocess.run(
        [
            PY,
            str(SIM),
            "--ch376",
            "--autorun",
            "--program",
            str(program),
            "--max-cycles",
            str(max_cycles),
            "--quiet",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout + proc.stderr


def require(cond: bool, msg: str, out: str) -> None:
    if not cond:
        print(out)
        raise SystemExit(f"FAIL: {msg}")


def test_path_and_more() -> None:
    out = run_shell("mount\rpath\rcd DOCS\rmore GUIDE.TXT\r")
    require("Mounting USB... OK" in out, "mount OK", out)
    require("PATH=/BIN" in out, "default PATH", out)
    require("Otto docs" in out, "more printed GUIDE.TXT via PATH", out)
    require("Apps:" in out or "Shell:" in out, "more content", out)
    # more is an external app — must not be ?unknown before it runs
    before_q = out.split("more GUIDE.TXT", 1)[-1]
    require("?unknown" not in before_q.split("INFO: Execution ended.")[0],
            "more resolved via PATH", out)
    require("Invalid memory" not in out, "no simulator fault", out)
    print("test_path_and_more: OK")


def test_mkdir_rmdir_del_fcopy_ren_find() -> None:
    # Clean leftovers from prior runs
    for name in ("BAK.TXT", "BAK2.TXT", "OSDIR2"):
        p = STICK / name
        if p.exists():
            if p.is_dir():
                p.rmdir()
            else:
                p.unlink()
    out = run_shell(
        "mount\r"
        "fcopy HELLO.TXT BAK.TXT\r"
        "find otto HELLO.TXT\r"
        "ren BAK.TXT BAK2.TXT\r"
        "mkdir OSDIR2\r"
        "rmdir OSDIR2\r"
        "del BAK2.TXT\r"
        "dir\r"
    )
    require("Mounting USB... OK" in out, "mount", out)
    require(out.count("OK") >= 4, "apps reported OK", out)
    require("FOUND" in out, "find found otto in HELLO.TXT", out)
    require("Invalid memory" not in out, "no simulator fault", out)
    require(out.upper().count("?UNKNOWN") == 0, "PATH resolved apps", out)
    # BAK2 should be gone after del
    require(not (STICK / "BAK2.TXT").exists(), "del removed BAK2.TXT", out)
    print("test_mkdir_rmdir_del_fcopy_ren_find: OK")


def test_edit_via_path() -> None:
    out = run_shell("mount\rcd DOCS\redit\rq\r", max_cycles=25_000_000)
    require("Mounting USB... OK" in out, "mount", out)
    require("EDIT" in out.upper(), "edit banner", out)
    require("?unknown" not in out, "edit via PATH", out)
    print("test_edit_via_path: OK")


def test_storage_api() -> None:
    prog = ASM / "storage_api_test.bin"
    require(prog.is_file(), f"missing {prog}", "")
    code, out = run_autorun(prog)
    require(code == 0, f"exit {code}", out)
    require("PASS" in out, "PASS", out)
    print("test_storage_api: OK")


def test_storage_smoke() -> None:
    prog = ASM / "storage_smoke.bin"
    require(prog.is_file(), f"missing {prog}", "")
    code, out = run_autorun(prog, max_cycles=10_000_000)
    require(code == 0, f"exit {code}", out)
    require("PASS" in out.upper() or "pass" in out.lower() or "OK" in out,
            "smoke pass", out)
    print("test_storage_smoke: OK")


def main() -> None:
    # Ensure BIN apps present
    for name in ("MORE.BIN", "FCOPY.BIN", "REN.BIN", "FIND.BIN",
                 "DEL.BIN", "MKDIR.BIN", "RMDIR.BIN", "EDIT.BIN"):
        p = STICK / "BIN" / name
        require(p.is_file(), f"missing stick app {p}", "")

    test_path_and_more()
    test_mkdir_rmdir_del_fcopy_ren_find()
    test_edit_via_path()
    test_storage_api()
    test_storage_smoke()
    print("test_otto_os: ALL OK")


if __name__ == "__main__":
    main()
