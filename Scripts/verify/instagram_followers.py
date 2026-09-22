#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Integración, privacidad y comportamiento del Comparador de seguidores de Instagram.
from pathlib import Path
import json
required_files = [
    'Sources/InstagramFollowersModule/InstagramFollowersService.swift',
    'Sources/InstagramFollowersModule/Archive/InstagramFollowersArchive.swift',
    'Sources/InstagramFollowersModule/Parsing/InstagramFollowersJSONParser.swift',
    'Sources/InstagramFollowersModule/Analysis/InstagramFollowersComparator.swift',
    'Sources/InstagramFollowersModule/Export/InstagramFollowersExporter.swift',
    'Sources/InstagramFollowersModule/History/InstagramFollowersHistory.swift',
    'Sources/ZEUVEApp/InstagramFollowers/InstagramFollowersView.swift',
    'Sources/ZEUVEApp/InstagramFollowers/InstagramFollowersViewModel.swift',
    'Tests/InstagramFollowersModuleTests/InstagramFollowersModuleTests.swift',
]
for name in required_files:
    if not Path(name).is_file():
        raise SystemExit('Falta un componente del Comparador de Instagram: ' + name)
module = '\n'.join(path.read_text(errors='ignore') for path in Path('Sources/InstagramFollowersModule').rglob('*') if path.is_file())
app = '\n'.join(path.read_text(errors='ignore') for path in Path('Sources/ZEUVEApp').rglob('*.swift'))
for forbidden in ['URLSession', 'WKWebView', 'http://localhost', 'browserCookies', 'networkAccess']:
    if forbidden in module:
        raise SystemExit('El Comparador contiene una vía de red o permiso prohibido: ' + forbidden)
for required in [
    'relationships_following', 'string_list_data', 'media_list_data',
    'followers_([0-9]+)', 'archive_entry_is_encrypted', 'archive_entry_symlink',
    'Task.checkCancellation()', 'readRelevantFiles', 'normalizedKey',
    'destinationExists', 'InstagramFollowersHistoryPayload',
]:
    if required not in module:
        raise SystemExit('Falta una protección o función del Comparador: ' + required)
for required in [
    'instagramFollowersModuleIdentifier', 'InstagramFollowersView',
    'InstagramFollowersHistoryPresenter', 'Analizar exportación',
    'Abrir en Instagram', 'Estos resultados corresponden al momento',
    'Task.sleep(for: .milliseconds(180))',
]:
    if required not in app:
        raise SystemExit('Falta integración visible del Comparador: ' + required)
view_model = Path('Sources/ZEUVEApp/InstagramFollowers/InstagramFollowersViewModel.swift').read_text()
if 'Data(contentsOf:' in view_model or 'InstagramFollowersArchiveReader' in view_model:
    raise SystemExit('La búsqueda o interfaz del Comparador relee directamente los archivos de origen.')
history = Path('Sources/InstagramFollowersModule/History/InstagramFollowersHistory.swift').read_text()
for forbidden in ['username', 'profileURL', 'searchText', 'baseFolder: result']:
    if forbidden in history:
        raise SystemExit('El historial del Comparador puede almacenar datos privados: ' + forbidden)
manifest = json.loads(Path('Sources/InstagramFollowersModule/Resources/manifest.json').read_text())
assert manifest['permissions'] == ['readUserSelectedFiles', 'writeUserSelectedFolder', 'openExternalApplications']
