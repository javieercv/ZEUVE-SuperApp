#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Versión, arquitectura modular y políticas del descargador.
from pathlib import Path
import json
version = Path('VERSION').read_text().strip()
parts = version.split('.')
assert len(parts) == 4 and all(part.isdigit() for part in parts), 'VERSION debe usar MAJOR.MINOR.PATCH.REVISION'
assert version == '0.20.4.0'
marketing_version = '.'.join(parts[:3])
release_revision = parts[3]
pbx = Path('ZEUVE.xcodeproj/project.pbxproj').read_text()
for required in [f'MARKETING_VERSION = {marketing_version};', 'CURRENT_PROJECT_VERSION = 70;', f'INFOPLIST_KEY_ZEUVEReleaseRevision = {release_revision};', 'ENABLE_HARDENED_RUNTIME = YES;', 'ZEUVEEngines', 'UniversalDownloaderModule', 'ChatAnalyzerModule', 'UniversalConverterModule', 'InstagramFollowersModule', 'MultimediaInspectorModule', 'CleanerModule', 'Engines in Resources']:
    if required not in pbx:
        raise SystemExit('El proyecto Xcode no contiene: ' + required)
package = Path('Package.swift').read_text()
for required in ['ZEUVEEngines', 'UniversalDownloaderModule', 'ChatAnalyzerModule', 'UniversalConverterModule', 'InstagramFollowersModule', 'MultimediaInspectorModule', 'CLibArchive', 'CZEUVEProcess']:
    if required not in package:
        raise SystemExit('Package.swift no contiene: ' + required)
manifest = json.loads(Path('Sources/UniversalDownloaderModule/Resources/manifest.json').read_text())
assert manifest['identifier'] == 'com.zeuve.universal-downloader'
assert manifest['version'] == '0.7.3'
assert manifest['minimumZEUVEVersion'] == '0.10.4'
assert manifest['technology'] == 'mixed' and manifest['executionMode'] == 'builtIn'
assert 'browserCookies' in manifest['permissions']
organizer = json.loads(Path('Sources/OrganizerModule/Resources/manifest.json').read_text())
assert 'openExternalApplications' in organizer['permissions']
chat = json.loads(Path('Sources/ChatAnalyzerModule/Resources/manifest.json').read_text())
assert chat['identifier'] == 'com.zeuve.chat-analyzer'
assert chat['version'] == '0.1.6'
assert chat['minimumZEUVEVersion'] == '0.5.0'
assert chat['technology'] == 'swift' and chat['executionMode'] == 'builtIn'
assert chat['permissions'] == ['readUserSelectedFiles']
assert 'networkAccess' not in chat['permissions']
converter = json.loads(Path('Sources/UniversalConverterModule/Resources/manifest.json').read_text())
assert converter['identifier'] == 'com.zeuve.universal-converter'
assert converter['version'] == '0.3.0'
assert converter['minimumZEUVEVersion'] == '0.7.0'
assert converter['technology'] == 'mixed' and converter['executionMode'] == 'builtIn'
assert 'networkAccess' not in converter['permissions']
instagram_followers = json.loads(Path('Sources/InstagramFollowersModule/Resources/manifest.json').read_text())
assert instagram_followers['identifier'] == 'com.zeuve.instagram-followers'
assert instagram_followers['version'] == '0.1.0'
assert instagram_followers['minimumZEUVEVersion'] == '0.8.0'
assert instagram_followers['technology'] == 'swift' and instagram_followers['executionMode'] == 'builtIn'
assert 'networkAccess' not in instagram_followers['permissions']
assert 'readUserSelectedFiles' in instagram_followers['permissions']
assert 'writeUserSelectedFolder' in instagram_followers['permissions']
assert 'openExternalApplications' in instagram_followers['permissions']

multimedia = json.loads(Path('Sources/MultimediaInspectorModule/Resources/manifest.json').read_text())
assert multimedia['identifier'] == 'com.zeuve.multimedia-inspector'
assert multimedia['version'] == '0.7.2'
assert multimedia['minimumZEUVEVersion'] == '0.13.0'
assert multimedia['technology'] == 'mixed' and multimedia['executionMode'] == 'builtIn'
assert 'networkAccess' not in multimedia['permissions']
assert 'favorites' in multimedia['capabilities']
assert 'readUserSelectedFiles' in multimedia['permissions']
assert 'writeUserSelectedFolder' in multimedia['permissions']
assert 'executeBundledTools' in multimedia['permissions']
assert 'openExternalApplications' in multimedia['permissions']
assert 'presets' in multimedia['capabilities']

engines = json.loads(Path('Resources/Engines/engines.json').read_text())
engine_names = {item['name'] for item in engines['engines']}
required_engine_names = {'yt-dlp','deno','ffmpeg','ffprobe','gallery-dl','instaloader-zeuve'}
assert required_engine_names <= engine_names
yt_dlp = next(item for item in engines['engines'] if item['name'] == 'yt-dlp')
for item in engines['engines']:
    assert item['source'].startswith(('local-bundle:', 'local-cache:', 'https://dl.deno.land/', 'https://ffmpeg.org/', 'https://pypi.org/', 'https://playwright.dev/'))
    if item['name'] in required_engine_names:
        assert item['requirement'] == 'required'
for required in ['bundleSHA256', 'bundleSize', 'bundleFileCount']:
    assert required in yt_dlp, 'Falta integridad del paquete descomprimido: ' + required

# Regresión: LocalLogger.write devuelve una URL; ignorarla debe ser explícito.
from pathlib import Path
for path in Path('Sources').rglob('*.swift'):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if 'try? await logger?.write' in line and '_ = try?' not in line:
            raise SystemExit(f'{path}:{number}: resultado de LocalLogger.write ignorado sin "_ ="')

# SQLite y libarchive usan el SDK/sistema mediante module.modulemap, sin Homebrew o pkg-config.
from pathlib import Path
text = Path('Package.swift').read_text()
for forbidden in ['pkgConfig: "sqlite3"', 'providers: [.brew(["sqlite3"])', 'pkgConfig: "libarchive"', 'providers: [.brew(["libarchive"])']:
    if forbidden in text:
        raise SystemExit('Package.swift contiene una dependencia del entorno de desarrollo: ' + forbidden)
for module, link in [('CSQLite', 'sqlite3'), ('CLibArchive', 'archive')]:
    modulemap = Path(f'Sources/{module}/module.modulemap').read_text()
    for required in ['header "shim.h"', f'link "{link}"']:
        if required not in modulemap:
            raise SystemExit(f'{module}/module.modulemap está incompleto: falta ' + required)
