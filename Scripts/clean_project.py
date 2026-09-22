#!/usr/bin/env python3
"""
Limpieza segura de artefactos regenerables del proyecto ZEUVE.

Uso:
    python3 Scripts/clean_project.py
    python3 Scripts/clean_project.py --apply

Sin --apply solo muestra lo que eliminaría.
No compila ni ejecuta tests después de limpiar para no regenerar cachés.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path
from typing import Iterable


PROJECT_MARKERS = (
    Path("Package.swift"),
    Path("Sources"),
    Path("Tests"),
    Path("Resources/Engines/engines.json"),
)

KNOWN_REGENERABLE_PATHS = (
    Path(".build"),
    Path("build"),
    Path(".swiftpm"),
    Path("ZEUVE.xcodeproj/xcuserdata"),
    Path("ZEUVE.xcodeproj/project.xcworkspace/xcuserdata"),
)

REQUIRED_ENGINES = (
    Path("Resources/Engines/deno/deno"),
    Path("Resources/Engines/ffmpeg/ffmpeg"),
    Path("Resources/Engines/ffmpeg/ffprobe"),
    Path("Resources/Engines/gallery-dl/gallery-dl"),
    Path("Resources/Engines/yt-dlp/yt-dlp_macos"),
    Path("Resources/Engines/instaloader/instaloader-zeuve"),
)

TEMP_FILE_NAMES = {".DS_Store"}
TEMP_FILE_PREFIXES = ("._",)
TEMP_FILE_SUFFIXES = (".tmp", ".temp", ".swp")
TEMP_FILE_TRAILING = ("~",)


def human_size(size: int) -> str:
    units = ("B", "KB", "MB", "GB", "TB")
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{size} B"


def path_size(path: Path) -> int:
    if not path.exists() and not path.is_symlink():
        return 0
    if path.is_symlink():
        return 0
    if path.is_file():
        try:
            return path.stat().st_size
        except OSError:
            return 0

    total = 0
    for current_root, dirs, files in os.walk(path, followlinks=False):
        current = Path(current_root)
        dirs[:] = [d for d in dirs if not (current / d).is_symlink()]
        for name in files:
            p = current / name
            if p.is_symlink():
                continue
            try:
                total += p.stat().st_size
            except OSError:
                pass
    return total


def find_project_root(start: Path) -> Path | None:
    current = start.resolve()
    if current.is_file():
        current = current.parent

    for candidate in (current, *current.parents):
        if all((candidate / marker).exists() for marker in PROJECT_MARKERS):
            return candidate
    return None


def ensure_inside_root(root: Path, path: Path) -> None:
    root_resolved = root.resolve()
    absolute = path.absolute()
    try:
        absolute.relative_to(root_resolved)
    except ValueError as exc:
        raise RuntimeError(f"Ruta fuera del proyecto rechazada: {path}") from exc


def is_temp_file(path: Path) -> bool:
    name = path.name
    return (
        name in TEMP_FILE_NAMES
        or name.startswith(TEMP_FILE_PREFIXES)
        or name.endswith(TEMP_FILE_SUFFIXES)
        or name.endswith(TEMP_FILE_TRAILING)
    )


def collect_candidates(root: Path, include_logs: bool) -> list[Path]:
    candidates: set[Path] = set()

    for rel in KNOWN_REGENERABLE_PATHS:
        p = root / rel
        if p.exists() or p.is_symlink():
            candidates.add(p)

    # Cachés Python en Scripts y Tests; nunca dentro de Resources/Engines.
    for base_rel in (Path("Scripts"), Path("Tests")):
        base = root / base_rel
        if not base.exists():
            continue

        for current_root, dirs, files in os.walk(base, topdown=True, followlinks=False):
            current = Path(current_root)
            dirs[:] = [d for d in dirs if not (current / d).is_symlink()]

            for dirname in list(dirs):
                if dirname == "__pycache__":
                    candidates.add(current / dirname)
                    dirs.remove(dirname)

            for filename in files:
                p = current / filename
                if is_temp_file(p) or (include_logs and p.suffix == ".log"):
                    candidates.add(p)

    # Temporales de macOS/editor por el proyecto, sin entrar en bundles de motores.
    engines_root = (root / "Resources/Engines").resolve()

    for current_root, dirs, files in os.walk(root, topdown=True, followlinks=False):
        current = Path(current_root)

        try:
            current.resolve().relative_to(engines_root)
            dirs[:] = []
            continue
        except ValueError:
            pass

        filtered_dirs = []
        for dirname in dirs:
            p = current / dirname

            if p.is_symlink():
                continue

            if p in candidates:
                continue

            if dirname == "xcuserdata":
                candidates.add(p)
                continue

            filtered_dirs.append(dirname)

        dirs[:] = filtered_dirs

        for filename in files:
            p = current / filename
            if is_temp_file(p) or (include_logs and p.suffix == ".log"):
                candidates.add(p)

    return sorted(candidates, key=lambda p: (len(p.parts), str(p)), reverse=True)


def delete_path(root: Path, path: Path) -> int:
    ensure_inside_root(root, path)
    size = path_size(path)

    if path.is_symlink() or path.is_file():
        path.unlink(missing_ok=True)
    elif path.is_dir():
        shutil.rmtree(path)

    return size


def verify_project(root: Path) -> list[str]:
    errors: list[str] = []

    for marker in PROJECT_MARKERS:
        if not (root / marker).exists():
            errors.append(f"Falta marcador del proyecto: {marker}")

    for rel in REQUIRED_ENGINES:
        p = root / rel

        if not p.exists():
            errors.append(f"Falta motor obligatorio: {rel}")
        elif not p.is_file():
            errors.append(f"Motor no es un archivo: {rel}")
        elif not os.access(p, os.X_OK):
            errors.append(f"Motor no es ejecutable: {rel}")

    return errors


def print_candidates(root: Path, candidates: Iterable[Path]) -> int:
    total = 0

    for path in candidates:
        size = path_size(path)
        total += size
        print(f"  - {path.relative_to(root)}  [{human_size(size)}]")

    return total


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Limpia artefactos regenerables de ZEUVE sin tocar código, documentación ni motores."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Ruta dentro de ZEUVE. Por defecto: directorio actual.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Ejecuta la limpieza. Sin esta opción solo se simula.",
    )
    parser.add_argument(
        "--include-logs",
        action="store_true",
        help="Incluye *.log. Desactivado por defecto para conservar diagnósticos.",
    )
    parser.add_argument(
        "--skip-size",
        action="store_true",
        help="Omite el cálculo del tamaño total del proyecto.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = find_project_root(args.root)

    if root is None:
        print(
            "ERROR: no se ha encontrado una raíz ZEUVE válida.\n"
            "Se requieren Package.swift, Sources/, Tests/ y Resources/Engines/engines.json.",
            file=sys.stderr,
        )
        return 2

    print(f"Proyecto: {root}")

    pre_errors = verify_project(root)
    if pre_errors:
        print("\nAVISO: la verificación previa detectó:")
        for error in pre_errors:
            print(f"  ! {error}")
        print("La limpieza no puede reparar esos elementos y no los modificará.")

    before = None if args.skip_size else path_size(root)
    if before is not None:
        print(f"Tamaño antes: {human_size(before)}")

    candidates = collect_candidates(root, include_logs=args.include_logs)

    if not candidates:
        print("\nNo hay artefactos regenerables conocidos que limpiar.")
        post_errors = verify_project(root)
        if post_errors:
            print("Verificación final: REVISAR")
            for error in post_errors:
                print(f"  ! {error}")
            return 3
        print("Verificación final: OK")
        return 0

    print("\nElementos detectados:")
    estimated = print_candidates(root, candidates)
    print(f"\nEspacio estimado recuperable: {human_size(estimated)}")

    if not args.apply:
        print("\nSIMULACIÓN: no se ha eliminado nada.")
        print("Para ejecutar la limpieza:")
        print("  python3 Scripts/clean_project.py --apply")
        return 0

    deleted = 0
    failures: list[str] = []

    print("\nLimpiando...")
    for path in candidates:
        try:
            deleted += delete_path(root, path)
            print(f"  OK  {path.relative_to(root)}")
        except Exception as exc:
            failures.append(f"{path}: {exc}")
            print(f"  ERROR  {path.relative_to(root)}: {exc}")

    after = None if args.skip_size else path_size(root)

    print("\nResultado:")
    print(f"  Espacio eliminado (estimado): {human_size(deleted)}")
    if before is not None and after is not None:
        print(f"  Tamaño antes: {human_size(before)}")
        print(f"  Tamaño después: {human_size(after)}")
        print(f"  Diferencia medida: {human_size(max(0, before - after))}")

    residual = collect_candidates(root, include_logs=args.include_logs)
    if residual:
        print("\nQuedan elementos regenerables detectados:")
        for path in residual:
            print(f"  ! {path.relative_to(root)}")
    else:
        print("\nCachés/temporales objetivo: OK")

    post_errors = verify_project(root)
    if post_errors:
        print("Verificación de proyecto/motores: REVISAR")
        for error in post_errors:
            print(f"  ! {error}")
    else:
        print("Verificación de proyecto/motores: OK")

    print("\nNo se ha recompilado ni ejecutado tests, para no recrear las cachés eliminadas.")

    if failures:
        return 4
    if post_errors:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
