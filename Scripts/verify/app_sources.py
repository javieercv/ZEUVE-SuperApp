#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_ROOT = ROOT / "Sources/ZEUVEApp"


def main() -> None:
    files = sorted(APP_ROOT.rglob("*.swift"))
    if not files:
        raise SystemExit("No se han encontrado fuentes Swift en Sources/ZEUVEApp.")
    for path in files:
        subprocess.run(
            ["swiftc", "-frontend", "-parse", str(path)],
            cwd=ROOT,
            check=True,
            stdout=subprocess.DEVNULL,
        )
    print(f"Parseo sintáctico ZEUVEApp correcto: {len(files)} archivos Swift.")


if __name__ == "__main__":
    main()
