#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

EXCLUDED = {"__pycache__", ".git", ".DS_Store"}


def build_zip(project: Path, output: Path, include_tests: bool = False) -> Path:
    project = project.resolve()
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(project.rglob("*")):
            if not path.is_file() or any(part in EXCLUDED for part in path.parts):
                continue
            relative = path.relative_to(project)
            if not include_tests and "tests" in relative.parts:
                continue
            if path.resolve() == output:
                continue
            archive.write(path, Path(project.name) / relative)
    return output


def read_version(project: Path) -> str:
    match = re.search(r'APP_VERSION\s*=\s*"([^"]+)"', (project / "js" / "config.js").read_text(encoding="utf-8"))
    if not match:
        raise SystemExit("No se encontró APP_VERSION en js/config.js")
    return match.group(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", nargs="?")
    parser.add_argument("--include-tests", action="store_true")
    parser.add_argument("--no-stamp", action="store_true", help="no sellar la versión antes de empacar")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    version = read_version(project)

    # Sellar SIEMPRE antes de empacar. Sin esto se puede publicar un app.js nuevo cuyos
    # imports el navegador resuelve contra su caché, mezclando módulos de dos versiones.
    if not args.no_stamp:
        subprocess.run([sys.executable, str(project / "tools" / "sellar_version.py")], check=True)

    output = Path(args.output) if args.output else project.parent / f"ColoreaEnRA_v{version}.zip"
    print(build_zip(project, output, args.include_tests))


if __name__ == "__main__":
    main()
