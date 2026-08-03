#!/usr/bin/env python3
"""Crea un ZIP limpio y completo de ZEUVE sin modificar el proyecto fuente."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_NAMES = {
    ".build",
    "build",
    "dist",
    ".swiftpm",
    ".engine-build",
    ".DS_Store",
    "__MACOSX",
    "xcuserdata",
    "__pycache__",
}
EXCLUDED_SUFFIXES = {".xcuserstate", ".log", ".pyc"}


def ignored(_directory: str, names: list[str]) -> set[str]:
    result: set[str] = set()
    for name in names:
        if name in EXCLUDED_NAMES or Path(name).suffix in EXCLUDED_SUFFIXES:
            result.add(name)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-verify", action="store_true", help="No ejecutar verify_project.sh antes de empaquetar.")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")
    args = parser.parse_args()

    if not args.skip_verify:
        subprocess.run(["bash", "Scripts/verify_project.sh"], cwd=ROOT, check=True)

    version = (ROOT / "VERSION").read_text().strip()
    folder_name = f"ZEUVE_Swift_{version}"
    args.output_dir.mkdir(parents=True, exist_ok=True)
    archive = args.output_dir / f"{folder_name}.zip"
    archive.unlink(missing_ok=True)

    with tempfile.TemporaryDirectory(prefix="zeuve-release-") as temporary:
        staging = Path(temporary) / folder_name
        shutil.copytree(ROOT, staging, ignore=ignored)
        for path in staging.rglob("*"):
            if path.name in EXCLUDED_NAMES or path.suffix in EXCLUDED_SUFFIXES:
                raise RuntimeError(f"Elemento excluido presente en el staging: {path}")
        base = archive.with_suffix("")
        shutil.make_archive(str(base), "zip", root_dir=staging.parent, base_dir=staging.name)

    print(archive)


if __name__ == "__main__":
    main()
