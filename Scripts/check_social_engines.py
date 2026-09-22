#!/usr/bin/env python3
"""Comprueba que los motores necesarios para Instagram están incluidos y vigentes."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

EXPECTED_VERSIONS = {
    "gallery-dl": "1.32.9",
    "instaloader-zeuve": "4.15.3-zeuve.2",
}


def missing_engines(root: Path) -> list[str]:
    manifest_path = root / "engines.json"
    if not manifest_path.is_file():
        return list(EXPECTED_VERSIONS)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = {entry["name"]: entry for entry in manifest.get("engines", [])}
    missing: list[str] = []
    for name, expected_version in EXPECTED_VERSIONS.items():
        item = entries.get(name)
        if item is None:
            missing.append(name)
            continue
        executable = root / item.get("relativePath", "")
        if (
            item.get("version") != expected_version
            or not executable.is_file()
            or item.get("size", 0) <= 0
            or item.get("sha256") == "0" * 64
            or not (root / item.get("licenseFile", "")).is_file()
        ):
            missing.append(name)
    return missing


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("engine_root", nargs="?", type=Path, default=Path("Resources/Engines"))
    parser.add_argument("--print-missing", action="store_true")
    args = parser.parse_args()
    missing = missing_engines(args.engine_root.resolve())
    if args.print_missing:
        print(",".join(missing))
    if missing:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
