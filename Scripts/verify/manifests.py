#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Validación JSON de todos los manifiestos actuales.
import json
from pathlib import Path
for path in Path('Sources').glob('*/Resources/manifest.json'):
    data = json.loads(path.read_text())
    required = {
        'schemaVersion', 'identifier', 'name', 'summary', 'version',
        'minimumZEUVEVersion', 'moduleAPI', 'technology', 'executionMode',
        'permissions', 'capabilities', 'presentation'
    }
    missing = sorted(required - data.keys())
    if missing:
        raise SystemExit(f'{path}: faltan campos: {", ".join(missing)}')
