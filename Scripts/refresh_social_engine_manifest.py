#!/usr/bin/env python3
"""Actualiza únicamente las entradas de los motores sociales ya preparados.

No descarga ni ejecuta código. Calcula los hashes y tamaños de los binarios
producidos en macOS y sustituye los marcadores ``NOT_PROVIDED`` del manifiesto.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

SOCIAL_ENGINES = {
    "gallery-dl": {
        "executable": "gallery-dl",
        "relativePath": "gallery-dl/gallery-dl",
        "licenseFile": "licenses/gallery-dl/LICENSE",
        "version": "1.32.9",
        "source": "https://pypi.org/project/gallery-dl/1.32.9/",
        "purpose": "Analizar y descargar fotografías, vídeos, carruseles, álbumes y galerías compatibles.",
    },
    "instaloader-zeuve": {
        "executable": "instaloader-zeuve",
        "relativePath": "instaloader/instaloader-zeuve",
        "licenseFile": "licenses/instaloader/LICENSE",
        "version": "4.15.3-zeuve.2",
        "source": "https://pypi.org/project/instaloader/4.15.3/",
        "purpose": "Resolver publicaciones públicas y catalogar contenido de Instagram, con sesión solo cuando sea necesaria.",
    },
}


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("engine_root", type=Path)
    args = parser.parse_args()

    root = args.engine_root.resolve()
    manifest_path = root / "engines.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = {entry["name"]: entry for entry in data.get("engines", [])}

    for name, fixed in SOCIAL_ENGINES.items():
        entry = entries.get(name)
        if entry is None:
            entry = {"name": name}
            data.setdefault("engines", []).append(entry)
        executable = (root / fixed["relativePath"]).resolve()
        license_file = (root / fixed["licenseFile"]).resolve()
        if root not in executable.parents or root not in license_file.parents:
            raise SystemExit(f"Ruta no segura para {name}")
        if not executable.is_file():
            raise SystemExit(f"Falta el ejecutable preparado: {executable}")
        if not license_file.is_file():
            raise SystemExit(f"Falta la licencia preparada: {license_file}")
        entry.update(
            relativePath=fixed["relativePath"],
            executable=fixed["executable"],
            licenseFile=fixed["licenseFile"],
            version=fixed["version"],
            source=fixed["source"],
            purpose=fixed["purpose"],
            diagnosticArguments=["--version"],
            sha256=digest(executable),
            size=executable.stat().st_size,
            architecture="arm64",
            requirement="required",
        )

    manifest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
