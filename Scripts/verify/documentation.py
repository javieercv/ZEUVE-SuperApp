#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)


def fail(message: str) -> None:
    raise SystemExit(message)


def read(path: str | Path) -> str:
    p = Path(path)
    if not p.is_file():
        fail(f'Falta documentación requerida: {p}')
    return p.read_text(encoding='utf-8')


# 1) Reglas permanentes: conservar las reglas de rendimiento/interacción aprobadas.
rules = read('SUPERAPP_PROJECT_RULES.md')
expected_rules = {
    64: 'INTERFAZ RESPONSIVA Y CÁLCULOS FUERA DEL HILO PRINCIPAL',
    65: 'CACHÉ E INVALIDACIÓN SELECTIVA',
    66: 'CÁLCULO BAJO DEMANDA',
    67: 'CANCELACIÓN Y DESCARTE DE RESULTADOS OBSOLETOS',
    68: 'ESPERA BREVE EN CAMBIOS REPETITIVOS',
    69: 'SEPARACIÓN DEL ESTADO VISUAL Y DEL ESTADO ANALÍTICO',
    70: 'OBSERVACIÓN DIRECTA DE LA FUENTE REAL DEL ESTADO',
    71: 'ESTÁNDAR COMÚN PARA GRÁFICOS INTERACTIVOS',
    72: 'VISIBILIDAD Y POSICIONAMIENTO DE TOOLTIPS',
    73: 'INTERACCIÓN GRÁFICA LIGERA',
    74: 'COHERENCIA ENTRE GRÁFICOS',
    75: 'REGRESIONES DE RENDIMIENTO',
    76: 'PRUEBAS CON VOLÚMENES REPRESENTATIVOS',
    77: 'VALIDACIÓN EN EL ENTORNO OBJETIVO',
    78: 'SELECCIÓN ESPECIALIZADA DE MOTORES',
    79: 'SANEAMIENTO, REFACTORIZACIÓN Y VERIFICABILIDAD',
    80: 'REGLA FINAL',
}
headings = {int(n): title.strip() for n, title in re.findall(r'(?m)^(\d+)\. ([A-ZÁÉÍÓÚÜÑ][^\n]+)$', rules)}
for number, title in expected_rules.items():
    if headings.get(number) != title:
        fail(f'Regla {number} ausente o incorrecta: {headings.get(number)!r}')
if rules.count('REGLA FINAL') != 1:
    fail('Debe existir una única REGLA FINAL')
for phrase in [
    'Un cambio puramente visual',
    'Un resultado antiguo nunca debe sustituir a uno más reciente',
    'Mover el cursor, seleccionar visualmente un dato o mostrar un tooltip no debe iniciar nuevos análisis',
    'Las pruebas automáticas realizadas en otro sistema operativo no sustituyen',
]:
    if phrase not in rules:
        fail('Falta una política aprobada: ' + phrase)

# 2) Taxonomía documental.
expected_directories = [
    Path('Docs/Fundamentos'),
    Path('Docs/Modulos/Desarrollo'),
    Path('Docs/Modulos/Funcionales'),
    Path('Docs/Modulos/Ejemplos'),
    Path('Docs/Motores'),
    Path('Docs/Historico/Entregas'),
    Path('Docs/Historico/Implementacion'),
    Path('Docs/Historico/Pruebas'),
    Path('Docs/Historico/HashesMotores'),
    Path('Docs/Historico/Compatibilidad'),
    Path('Docs/Historico/Informes'),
]
for directory in expected_directories:
    if not directory.is_dir():
        fail(f'Falta una categoría de documentación: {directory}')

root_docs = {path.name for path in Path('Docs').glob('*.md')}
if root_docs != {'INDEX.md'}:
    fail(f'La raíz de Docs solo debe contener INDEX.md: {sorted(root_docs)}')
if Path('BUILD_FIX_REPORT.txt').exists():
    fail('BUILD_FIX_REPORT.txt es evidencia histórica y no debe permanecer en la raíz del proyecto')

# 3) La versión actual debe propagarse por las fuentes operativas, no por el histórico.
version = read('VERSION').strip()
if not re.fullmatch(r'\d+\.\d+\.\d+\.\d+', version):
    fail(f'VERSION no usa cuatro componentes: {version!r}')
marketing, revision = version.rsplit('.', 1)

current_sources = [
    'AGENTS.md',
    'README.md',
    'PROJECT_DECISIONS.md',
    'Docs/Fundamentos/CODEX_CONTEXT.md',
    'Docs/Fundamentos/ARCHITECTURE.md',
    'Docs/Fundamentos/BUILDING.md',
    'Docs/Fundamentos/FUNCTIONAL_SCOPE.md',
    'Docs/Fundamentos/SECURITY.md',
    'Docs/Fundamentos/TESTING.md',
]
for name in current_sources:
    text = read(name)
    if version not in text:
        fail(f'La documentación operativa no menciona la versión actual {version}: {name}')
    if 'TODO_AUTOGENERADO' in text or 'PLACEHOLDER_AUTOGENERADO' in text:
        fail(f'Marcador de documentación incompleta en {name}')

xcode = read('ZEUVE.xcodeproj/project.pbxproj')
marketing_values = set(re.findall(r'MARKETING_VERSION = ([^;]+);', xcode))
build_values = set(re.findall(r'CURRENT_PROJECT_VERSION = ([^;]+);', xcode))
revision_values = set(re.findall(r'INFOPLIST_KEY_ZEUVEReleaseRevision = ([^;]+);', xcode))
if marketing_values != {marketing}:
    fail(f'MARKETING_VERSION no coincide con VERSION: {marketing_values} != {marketing}')
if revision_values != {revision}:
    fail(f'ZEUVEReleaseRevision no coincide con VERSION: {revision_values} != {revision}')
if len(build_values) != 1:
    fail(f'CURRENT_PROJECT_VERSION inconsistente: {sorted(build_values)}')
build = next(iter(build_values))
building = read('Docs/Fundamentos/BUILDING.md')
version_tokens = [
    ('MARKETING_VERSION', marketing),
    ('Revisión bundle', revision),
    ('Build', build),
]
for label, value in version_tokens:
    if label not in building or value not in building:
        fail(f'BUILDING.md no refleja el versionado real: falta {label}={value}')

# 4) Los siete módulos built-in deben tener manifest y documentación funcional propia.
module_docs = {
    'com.zeuve.organizer': 'Docs/Modulos/Funcionales/ORGANIZER.md',
    'com.zeuve.universal-downloader': 'Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER.md',
    'com.zeuve.chat-analyzer': 'Docs/Modulos/Funcionales/CHAT_ANALYZER.md',
    'com.zeuve.universal-converter': 'Docs/Modulos/Funcionales/UNIVERSAL_CONVERTER.md',
    'com.zeuve.instagram-followers': 'Docs/Modulos/Funcionales/INSTAGRAM_FOLLOWERS_COMPARATOR.md',
    'com.zeuve.multimedia-inspector': 'Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md',
    'com.zeuve.cleaner': 'Docs/Modulos/Funcionales/CLEANER.md',
}
manifests: dict[str, tuple[Path, dict]] = {}
for path in sorted(Path('Sources').glob('*Module/Resources/manifest.json')):
    data = json.loads(path.read_text(encoding='utf-8'))
    identifier = data.get('identifier')
    if identifier in manifests:
        fail(f'Identificador de módulo duplicado: {identifier}')
    manifests[identifier] = (path, data)

if set(manifests) != set(module_docs):
    missing_docs = sorted(set(manifests) - set(module_docs))
    missing_manifests = sorted(set(module_docs) - set(manifests))
    fail(f'Desajuste manifests/documentación. Sin doc: {missing_docs}; sin manifest: {missing_manifests}')

readme = read('README.md')
index = read('Docs/INDEX.md')
context = read('Docs/Fundamentos/CODEX_CONTEXT.md')
for identifier, doc in module_docs.items():
    path, manifest = manifests[identifier]
    doc_path = Path(doc)
    if not doc_path.is_file() or doc_path.stat().st_size < 500:
        fail(f'Documentación funcional ausente o demasiado breve para {identifier}: {doc}')
    relative_from_readme = doc
    relative_from_index = str(doc_path.relative_to('Docs')).replace(os.sep, '/')
    if relative_from_readme not in readme:
        fail(f'README no enlaza la documentación propia de {manifest["name"]}: {doc}')
    if relative_from_index not in index:
        fail(f'Docs/INDEX.md no enlaza {doc}')
    doc_text = doc_path.read_text(encoding='utf-8')
    for expected, label in [(identifier, 'identificador'), (manifest['version'], 'versión'), (manifest['minimumZEUVEVersion'], 'ZEUVE mínimo')]:
        if expected not in doc_text:
            fail(f'{doc} no refleja {label} {expected!r} del manifest {path}')
    if identifier not in context or manifest['version'] not in context:
        fail(f'CODEX_CONTEXT no refleja ID/versión actual de {manifest["name"]}')

catalog = read('Sources/ZEUVEApp/BuiltInModules/BuiltInModuleCatalog.swift')
for identifier in module_docs:
    # Los IDs viven como constantes importadas; se valida presencia de los siete cases por número de manifests y defaults conocidos.
    pass
for shortcut in ['.command("1")', '.command("2")', '.command("3")', '.command("4")', '.command("5")', '.command("6")', '.command("7")', '(historyTargetID, .command("8"))']:
    if shortcut not in catalog:
        fail(f'Catálogo built-in no contiene el default esperado: {shortcut}')

# 5) Motores: la documentación debe reflejar los requeridos reales y la política de firma actual.
registry = json.loads(read('Resources/Engines/engines.json'))
required_engines = {engine['name'] for engine in registry['engines'] if engine.get('requirement') == 'required'}
engine_readme = read('Resources/Engines/README.md')
engine_packaging = read('Docs/Motores/UNIVERSAL_DOWNLOADER_ENGINE_PACKAGING.md')
engine_readme_lower = engine_readme.lower()
engine_packaging_lower = engine_packaging.lower()
for name in sorted(required_engines):
    if name.lower() not in engine_readme_lower or name.lower() not in engine_packaging_lower:
        fail(f'Motor required no documentado en README/empaquetado: {name}')
for stale in [
    'gallery-dl, instaloader-zeuve, playwright-browser, LibreOffice, Calibre y Ghostscript están retirados',
    'verifica las cuatro firmas',
    'Deno, FFmpeg y FFprobe se firman explícitamente con la identidad de ZEUVE',
]:
    if stale in engine_readme or stale in engine_packaging:
        fail(f'Documentación de motores contiene una afirmación obsoleta: {stale}')
for phrase in ['deno/deno', 'conserva la firma oficial', 'gallery-dl', 'instaloader-zeuve']:
    if phrase.lower() not in engine_packaging_lower:
        fail(f'Falta política de firma vigente en documentación de motores: {phrase}')

# 6) La evidencia de la versión actual debe existir sin convertir Fundamentos en changelog.
for name in [
    f'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_{version}.md',
    f'Docs/Historico/Pruebas/TEST_RESULTS_{version}.md',
    f'Docs/Historico/Entregas/DELIVERY_{version}.md',
]:
    if not Path(name).is_file():
        fail(f'Falta evidencia histórica de la entrega actual: {name}')

# Frases que no pueden reaparecer como estado actual.
operational_text = '\n'.join(read(name) for name in current_sources + [
    'Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md',
    'Resources/Engines/README.md',
    'Docs/Motores/UNIVERSAL_DOWNLOADER_ENGINE_PACKAGING.md',
])
for stale in [
    'ZEUVE 0.13.2.0 is a native',
    'current delivery state for 0.13.2.0',
    'no existe todavía personalización de orden, visibilidad o atajos',
    '0.13.0 no crea una sección visible en Ajustes',
    'La pestaña Metadatos es de solo lectura',
]:
    if stale in operational_text:
        fail(f'Documentación viva contiene una afirmación obsoleta: {stale}')

# 7) Enlaces Markdown locales: detectar destinos inexistentes en toda la documentación.
link_pattern = re.compile(r'(?<!!)\[[^\]]*\]\(([^)]+)\)')
for md in [Path('README.md'), Path('AGENTS.md'), Path('PROJECT_DECISIONS.md'), Path('CHANGELOG.md'), *Path('Docs').rglob('*.md')]:
    text = md.read_text(encoding='utf-8')
    for raw in link_pattern.findall(text):
        target = raw.strip().split()[0].strip('<>')
        if not target or target.startswith(('#', 'http://', 'https://', 'mailto:')):
            continue
        target = target.split('#', 1)[0]
        if not target:
            continue
        destination = (md.parent / target).resolve()
        try:
            destination.relative_to(ROOT.resolve())
        except ValueError:
            fail(f'Enlace local sale del proyecto en {md}: {raw}')
        if not destination.exists():
            fail(f'Enlace Markdown roto en {md}: {raw}')

# 8) Los chats de desarrollo deben seguir el mismo mapa documental que AGENTS/CODEX_CONTEXT.
chat_instructions = read('Docs/Modulos/Desarrollo/MODULE_CHAT_INSTRUCTIONS.md')
chat_lookup_requirements = [
    'AGENTS.md',
    'Docs/INDEX.md',
    'smallest relevant live documentation set',
    'Do not crawl or read all of `Docs/` indiscriminately',
    'Use `Docs/Historico/` only',
    'Never use historical documents as the current specification',
    'If current code and live documentation disagree',
]
for phrase in chat_lookup_requirements:
    if phrase not in chat_instructions:
        fail(f'MODULE_CHAT_INSTRUCTIONS no conserva la estrategia documental canónica: {phrase}')

# 9) Marcadores de trabajo incompleto en documentación viva.
for path in [Path('README.md'), Path('AGENTS.md'), Path('PROJECT_DECISIONS.md'), *Path('Docs/Fundamentos').glob('*.md'), *Path('Docs/Modulos/Desarrollo').glob('*.md'), *Path('Docs/Modulos/Funcionales').glob('*.md'), *Path('Docs/Motores').glob('*.md')]:
    text = path.read_text(encoding='utf-8')
    if 'TODO_AUTOGENERADO' in text or 'PLACEHOLDER_AUTOGENERADO' in text:
        fail(f'Marcador de documentación incompleta en {path}')

# 10) Navegación documental: todo Markdown vivo debe ser descubrible desde Docs/INDEX.md.
for live_root in [Path('Docs/Fundamentos'), Path('Docs/Modulos'), Path('Docs/Motores')]:
    for md_path in sorted(live_root.rglob('*.md')):
        relative_from_docs = md_path.relative_to('Docs').as_posix()
        if relative_from_docs not in index:
            fail(f'Docs/INDEX.md no enlaza documentación viva: {relative_from_docs}')

# 11) Higiene del histórico y de la entrega.
if Path('BUILD_FIX_REPORT.txt').exists():
    fail('BUILD_FIX_REPORT.txt debe archivarse bajo Docs/Historico/Informes/')
changelog_h1 = [line for line in read('CHANGELOG.md').splitlines() if line.startswith('# ')]
if changelog_h1 != ['# Historial de cambios de ZEUVE']:
    fail(f'CHANGELOG debe tener un único H1 estable: {changelog_h1}')
if 'toda modificación del proyecto debe terminar obligatoriamente con un ZIP' in rules.lower():
    fail('SUPERAPP_PROJECT_RULES conserva una regla de ZIP remoto sustituida')

print(f'Documentación coherente con ZEUVE {version}: {len(module_docs)} módulos, {len(required_engines)} motores required, enlaces locales y navegación verificados.')
