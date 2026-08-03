#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import sys
import tempfile
import unittest
from dataclasses import dataclass
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "Scripts" / "static_pkg_config.py"
SPEC = importlib.util.spec_from_file_location("zeuve_static_pkg_config", TOOL)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"No se puede cargar {TOOL}")
PKG_CONFIG = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PKG_CONFIG
SPEC.loader.exec_module(PKG_CONFIG)


@dataclass
class ToolResult:
    returncode: int
    stdout: str
    stderr: str


class StaticPkgConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="zeuve-pkg-config-")
        self.pkgconfig = Path(self.temporary.name)
        prefix = self.pkgconfig.parent / "prefix"
        (self.pkgconfig / "opus.pc").write_text(
            "\n".join(
                [
                    f"prefix={prefix}",
                    "exec_prefix=${prefix}",
                    "libdir=${exec_prefix}/lib",
                    "includedir=${prefix}/include",
                    "",
                    "Name: opus",
                    "Description: Opus codec",
                    "Version: 1.5.2",
                    "Libs: -L${libdir} -lopus",
                    "Libs.private: -lm",
                    "Cflags: -I${includedir}/opus",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        (self.pkgconfig / "libmp3lame.pc").write_text(
            "\n".join(
                [
                    f"prefix={prefix}",
                    "exec_prefix=${prefix}",
                    "libdir=${exec_prefix}/lib",
                    "includedir=${prefix}/include",
                    "",
                    "Name: libmp3lame",
                    "Description: LAME encoder",
                    "Version: 3.100",
                    "Libs: -L${libdir} -lmp3lame",
                    "Libs.private: -lm",
                    "Cflags: -I${includedir}",
                    "",
                ]
            ),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_tool(self, *arguments: str) -> ToolResult:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch.dict(os.environ, {"PKG_CONFIG_PATH": str(self.pkgconfig)}, clear=False):
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                returncode = PKG_CONFIG.main(list(arguments))
        return ToolResult(returncode, stdout.getvalue(), stderr.getvalue())

    def test_reports_pkg_config_version_without_package(self) -> None:
        result = self.run_tool("--version")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout.strip(), r"^\d+\.\d+\.\d+$")

    def test_accepts_pkg_config_minimum_version_probe(self) -> None:
        self.assertEqual(self.run_tool("--atleast-pkgconfig-version=0.28").returncode, 0)
        self.assertNotEqual(self.run_tool("--atleast-pkgconfig-version=99.0").returncode, 0)

    def test_grouped_requirement_is_normalized(self) -> None:
        result = self.run_tool("--exists", "--print-errors", "opus >= 1.3.1")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_grouped_requirement_rejects_too_new_version(self) -> None:
        result = self.run_tool("--exists", "--print-errors", "opus >= 9.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no cumple", result.stderr)

    def test_variable_query_is_not_treated_as_package(self) -> None:
        result = self.run_tool("--variable=includedir", "opus")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.strip().endswith("/prefix/include"))

    def test_static_libs_include_private_dependencies(self) -> None:
        result = self.run_tool("--static", "--libs", "libmp3lame")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-lmp3lame", result.stdout)
        self.assertIn("-lm", result.stdout)

    def test_cflags_and_modversion(self) -> None:
        cflags = self.run_tool("--cflags", "opus")
        version = self.run_tool("--modversion", "opus")
        self.assertEqual(cflags.returncode, 0, cflags.stderr)
        self.assertIn("/include/opus", cflags.stdout)
        self.assertEqual(version.stdout.strip(), "1.5.2")

    def test_missing_package_reports_error(self) -> None:
        result = self.run_tool("--exists", "--print-errors", "missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing.pc", result.stderr)


if __name__ == "__main__":
    unittest.main()
