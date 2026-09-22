#!/usr/bin/env python3
from __future__ import annotations

import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def swiftpm_library_products(root: Path = ROOT) -> list[str]:
    package = (root / "Package.swift").read_text()
    products = re.findall(r'\.library\(name:\s*"([^"]+)"', package)
    if not products:
        raise ValueError("No se han podido leer los productos de biblioteca de Package.swift.")
    return products


def generator_products(root: Path = ROOT) -> list[str]:
    generator = (root / "Scripts/generate_xcode_project.py").read_text()
    match = re.search(r'^products\s*=\s*(\[[^\n]+\])\s*$', generator, flags=re.MULTILINE)
    if match is None:
        raise ValueError("generate_xcode_project.py no expone una lista products verificable.")
    try:
        value = ast.literal_eval(match.group(1))
    except (SyntaxError, ValueError) as error:
        raise ValueError(f"No se puede interpretar products del generador Xcode: {error}") from error
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError("products del generador Xcode debe ser una lista literal de nombres.")
    return value


def verify_pbx_products(products: list[str], root: Path = ROOT) -> None:
    pbx_path = root / "ZEUVE.xcodeproj/project.pbxproj"
    if not pbx_path.is_file():
        raise ValueError("Falta ZEUVE.xcodeproj/project.pbxproj; regenera el proyecto Xcode.")
    pbx = pbx_path.read_text()
    missing = [name for name in products if f"productName = {name};" not in pbx]
    if missing:
        raise ValueError("El proyecto Xcode no enlaza productos declarados por SwiftPM: " + ", ".join(missing))


def verify(root: Path = ROOT) -> list[str]:
    swiftpm = swiftpm_library_products(root)
    generator = generator_products(root)
    if swiftpm != generator:
        only_swiftpm = [name for name in swiftpm if name not in generator]
        only_generator = [name for name in generator if name not in swiftpm]
        order_mismatch = not only_swiftpm and not only_generator and swiftpm != generator
        details: list[str] = []
        if only_swiftpm:
            details.append("faltan en Xcode: " + ", ".join(only_swiftpm))
        if only_generator:
            details.append("sobran en Xcode: " + ", ".join(only_generator))
        if order_mismatch:
            details.append("el orden no coincide con Package.swift")
        raise ValueError("SwiftPM y generate_xcode_project.py no están sincronizados: " + "; ".join(details))
    verify_pbx_products(swiftpm, root)
    return swiftpm


def main() -> None:
    try:
        products = verify()
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print(f"Integración SwiftPM/Xcode coherente: {len(products)} productos enlazados.")


if __name__ == "__main__":
    main()
