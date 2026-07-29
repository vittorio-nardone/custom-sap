#!/usr/bin/env python3
"""Generate roms/apps/catalog.json for OttoTerminal F10 app repository."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
ABI_ROOT = REPO_ROOT / "kernel" / "abi"
APPS_ROOT = REPO_ROOT / "roms" / "apps"
CATALOG_PATH = APPS_ROOT / "catalog.json"
KERNEL_ASM = REPO_ROOT / "kernel" / "kernel.asm"


def read_kernel_version() -> str:
    text = KERNEL_ASM.read_text(encoding="utf-8")
    match = re.search(r'#const\s+KERNEL_VERSION\s*=\s*"([^"]+)"', text)
    if not match:
        raise SystemExit("KERNEL_VERSION not found in kernel/kernel.asm")
    return match.group(1)


def has_apps(path: Path) -> bool:
    if not path.is_dir():
        return False
    return any(path.glob("*.bin"))


def target_entry(target_id: str, kernel_version: str, label: str, base_rel: str) -> dict:
    return {
        "id": target_id,
        "kernel_version": kernel_version,
        "label": label,
        "base_path": base_rel,
        "catalog_path": f"{base_rel}/asm",
        "pascal_path": f"{base_rel}/pascal",
    }


def collect_targets() -> list[dict]:
    targets: list[dict] = []

    current_asm = APPS_ROOT / "current" / "asm"
    if has_apps(current_asm):
        targets.append(target_entry(
            "current",
            read_kernel_version(),
            "Latest",
            "roms/apps/current",
        ))

    if ABI_ROOT.is_dir():
        for abi_dir in sorted(ABI_ROOT.glob("v*"), key=lambda p: p.name):
            version = abi_dir.name  # v1.2.101
            base_rel = f"roms/apps/{version}"
            catalog_dir = REPO_ROOT / base_rel / "asm"
            if not has_apps(catalog_dir):
                continue

            manifest_path = abi_dir / "manifest.json"
            label = version
            kernel_version = version
            if manifest_path.is_file():
                try:
                    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                    kernel_version = manifest.get("kernel_version", version)
                    label = kernel_version
                except json.JSONDecodeError:
                    pass

            targets.append(target_entry(version, kernel_version, label, base_rel))

    if not targets:
        raise SystemExit("No app catalogs found (build apps first)")

    return targets


def main() -> None:
    targets = collect_targets()
    catalog = {
        "version": 2,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "default_target": "current" if any(t["id"] == "current" for t in targets) else targets[0]["id"],
        "targets": targets,
    }

    APPS_ROOT.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {CATALOG_PATH} ({len(targets)} target(s))")
    for target in targets:
        print(f"  - {target['id']}: {target['catalog_path']} ({target['kernel_version']})")


if __name__ == "__main__":
    main()
