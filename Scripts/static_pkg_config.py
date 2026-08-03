#!/usr/bin/env python3
"""Implementación mínima y reproducible de pkg-config para el build de FFmpeg.

Solo lee archivos .pc desde PKG_CONFIG_PATH. No consulta rutas del sistema ni
instalaciones de Homebrew. Admite las operaciones que usa configure de FFmpeg
para libmp3lame y opus.
"""

from __future__ import annotations

import os
import re
import shlex
import sys
from dataclasses import dataclass
from pathlib import Path

TOOL_VERSION = "0.29.2"
COMPARISON_OPERATORS = {">=", "<=", "=", ">", "<"}
MODE_OPTIONS = {
    "--exists",
    "--cflags",
    "--cflags-only-I",
    "--cflags-only-other",
    "--libs",
    "--libs-only-L",
    "--libs-only-l",
    "--libs-only-other",
    "--modversion",
}
IGNORED_OPTIONS = {
    "--static",
    "--print-errors",
    "--silence-errors",
    "--short-errors",
    "--errors-to-stdout",
    *MODE_OPTIONS,
}


@dataclass(frozen=True)
class Requirement:
    package: str
    operator: str | None = None
    version: str | None = None


@dataclass
class Package:
    name: str
    version: str
    cflags: str
    libs: str
    libs_private: str
    variables: dict[str, str]


def expand(value: str, variables: dict[str, str]) -> str:
    pattern = re.compile(r"\$\{([^}]+)\}")
    previous = None
    while value != previous:
        previous = value
        value = pattern.sub(lambda match: variables.get(match.group(1), ""), value)
    return value.strip()


def load_package(name: str) -> Package:
    search_paths = [
        Path(value)
        for value in os.environ.get("PKG_CONFIG_PATH", "").split(os.pathsep)
        if value
    ]
    for directory in search_paths:
        path = directory / f"{name}.pc"
        if not path.is_file():
            continue
        variables: dict[str, str] = {"pcfiledir": str(path.parent)}
        fields: dict[str, str] = {}
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line and (":" not in line or line.index("=") < line.index(":")):
                key, value = line.split("=", 1)
                variables[key.strip()] = value.strip()
            elif ":" in line:
                key, value = line.split(":", 1)
                fields[key.strip()] = value.strip()
        variables = {key: expand(value, variables) for key, value in variables.items()}
        return Package(
            name=name,
            version=expand(fields.get("Version", "0"), variables),
            cflags=expand(fields.get("Cflags", ""), variables),
            libs=expand(fields.get("Libs", ""), variables),
            libs_private=expand(fields.get("Libs.private", ""), variables),
            variables=variables,
        )
    raise FileNotFoundError(name)


def version_key(value: str) -> tuple[tuple[int, int | str], ...]:
    """Convierte una versión en una clave comparable sin dependencias externas."""
    parts: list[tuple[int, int | str]] = []
    for token in re.findall(r"\d+|[A-Za-z]+", value):
        if token.isdigit():
            parts.append((1, int(token)))
        else:
            parts.append((0, token.lower()))
    return tuple(parts)


def compare_versions(current: str, operator: str, required: str) -> bool:
    left = version_key(current)
    right = version_key(required)
    return {
        ">=": left >= right,
        "<=": left <= right,
        "=": left == right,
        ">": left > right,
        "<": left < right,
    }[operator]


def normalize_requirement_arguments(argv: list[str]) -> list[str]:
    pattern = re.compile(
        r"^([A-Za-z0-9_.+][A-Za-z0-9_.+-]*)\s*(>=|<=|=|>|<)\s*([A-Za-z0-9_.+-]+)$"
    )
    normalized: list[str] = []
    for argument in argv:
        stripped = argument.strip()
        if stripped.startswith("-"):
            normalized.append(argument)
            continue
        match = pattern.fullmatch(stripped)
        if match:
            normalized.extend(match.groups())
        else:
            normalized.append(argument)
    return normalized


def parse_requirements(tokens: list[str]) -> list[Requirement]:
    requirements: list[Requirement] = []
    index = 0
    while index < len(tokens):
        package = tokens[index]
        if package.startswith("-") or package in COMPARISON_OPERATORS:
            index += 1
            continue
        operator: str | None = None
        version: str | None = None
        if index + 2 < len(tokens) and tokens[index + 1] in COMPARISON_OPERATORS:
            operator = tokens[index + 1]
            version = tokens[index + 2]
            index += 3
        else:
            index += 1
        requirements.append(Requirement(package, operator, version))
    unique: dict[str, Requirement] = {}
    for requirement in requirements:
        unique[requirement.package] = requirement
    return list(unique.values())


def output_flags(packages: list[Package], mode: str, static: bool) -> str:
    values: list[str] = []
    for package in packages:
        if mode.startswith("--cflags"):
            flags = shlex.split(package.cflags)
            if mode == "--cflags-only-I":
                flags = [flag for flag in flags if flag.startswith("-I")]
            elif mode == "--cflags-only-other":
                flags = [flag for flag in flags if not flag.startswith("-I")]
        else:
            payload = package.libs
            if static and package.libs_private:
                payload = f"{payload} {package.libs_private}"
            flags = shlex.split(payload)
            if mode == "--libs-only-L":
                flags = [flag for flag in flags if flag.startswith("-L")]
            elif mode == "--libs-only-l":
                flags = [flag for flag in flags if flag.startswith("-l")]
            elif mode == "--libs-only-other":
                flags = [
                    flag
                    for flag in flags
                    if not flag.startswith("-L") and not flag.startswith("-l")
                ]
        values.extend(flags)
    return " ".join(dict.fromkeys(values))


def main(argv: list[str]) -> int:
    if "--version" in argv:
        print(TOOL_VERSION)
        return 0

    for argument in argv:
        if argument.startswith("--atleast-pkgconfig-version="):
            required = argument.split("=", 1)[1]
            return 0 if compare_versions(TOOL_VERSION, ">=", required) else 1

    argv = normalize_requirement_arguments(argv)
    static = "--static" in argv
    print_errors = "--print-errors" in argv
    errors_to_stdout = "--errors-to-stdout" in argv
    error_stream = sys.stdout if errors_to_stdout else sys.stderr
    variable_name = next(
        (argument.split("=", 1)[1] for argument in argv if argument.startswith("--variable=")),
        None,
    )
    mode = next((argument for argument in argv if argument in MODE_OPTIONS), "--exists")

    version_constraint: tuple[str, str] | None = None
    for option, operator in (
        ("--atleast-version=", ">="),
        ("--exact-version=", "="),
        ("--max-version=", "<="),
    ):
        match = next((argument for argument in argv if argument.startswith(option)), None)
        if match:
            version_constraint = (operator, match.split("=", 1)[1])
            break

    tokens = [
        argument
        for argument in argv
        if argument not in IGNORED_OPTIONS
        and not argument.startswith("--variable=")
        and not argument.startswith("--define-variable=")
        and not argument.startswith("--atleast-version=")
        and not argument.startswith("--exact-version=")
        and not argument.startswith("--max-version=")
    ]
    requirements = parse_requirements(tokens)
    if not requirements:
        if print_errors:
            print("No se ha indicado ningún paquete.", file=error_stream)
        return 1

    try:
        packages = [load_package(requirement.package) for requirement in requirements]
    except FileNotFoundError as error:
        if print_errors:
            print(f"No se encuentra {error.args[0]}.pc en PKG_CONFIG_PATH", file=error_stream)
        return 1

    packages_by_name = {package.name: package for package in packages}
    for requirement in requirements:
        package = packages_by_name[requirement.package]
        operator = requirement.operator
        required_version = requirement.version
        if version_constraint is not None:
            operator, required_version = version_constraint
        if operator and required_version and not compare_versions(
            package.version, operator, required_version
        ):
            if print_errors:
                print(
                    f"{package.name} {package.version} no cumple {operator} {required_version}",
                    file=error_stream,
                )
            return 1

    if variable_name is not None:
        print(packages[0].variables.get(variable_name, ""))
        return 0
    if mode == "--exists":
        return 0
    if mode == "--modversion":
        print("\n".join(package.version for package in packages))
        return 0

    print(output_flags(packages, mode, static))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
