#!/usr/bin/env python3
"""Smoke: shell mount + dir lists entries from the CH376 virtual stick."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    proc = subprocess.run(
        [
            sys.executable,
            str(ROOT / "simulate.py"),
            "--ch376",
            "--headless",
            "--input",
            "mount\rdir\r",
            "--max-cycles",
            "20000000",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    out = proc.stdout + proc.stderr
    if "Mounting USB... OK" not in out:
        print(out)
        raise SystemExit("FAIL: mount did not report OK")
    if "?unknown" in out:
        print(out)
        raise SystemExit(
            "FAIL: shell returned ?unknown (builtin table page-cross?)"
        )
    if "HELLO.TXT" not in out and "hello.txt" not in out.upper():
        # listing prints 8.3 and optional LFN
        if "HELLO" not in out:
            print(out)
            raise SystemExit("FAIL: dir listing missing HELLO.TXT")
    if "total" not in out:
        print(out)
        raise SystemExit("FAIL: dir listing missing total line")
    print("test_shell_mount_dir: OK")


if __name__ == "__main__":
    main()
