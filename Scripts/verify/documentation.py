#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Las reglas permanentes de rendimiento e interacción deben estar completas y numeradas.
from pathlib import Path
import re
text = Path('SUPERAPP_PROJECT_RULES.md').read_text()
expected = {
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
headings = {int(n): title.strip() for n, title in re.findall(r'(?m)^(\d+)\. ([A-ZÁÉÍÓÚÜÑ][^\n]+)$', text)}
for number, title in expected.items():
    if headings.get(number) != title:
        raise SystemExit(f'Regla {number} ausente o incorrecta: {headings.get(number)!r}')
if text.count('REGLA FINAL') != 1:
    raise SystemExit('Debe existir una única REGLA FINAL')
for phrase in [
    'Un cambio puramente visual',
    'Un resultado antiguo nunca debe sustituir a uno más reciente',
    'Mover el cursor, seleccionar visualmente un dato o mostrar un tooltip no debe iniciar nuevos análisis',
    'Las pruebas automáticas realizadas en otro sistema operativo no sustituyen',
]:
    if phrase not in text:
        raise SystemExit('Falta una política aprobada: ' + phrase)

# La documentación modular mínima debe existir y no contener marcadores de trabajo incompleto.
from pathlib import Path
required = [
    'Docs/Modulos/Desarrollo/MODULE_DEVELOPMENT_GUIDE.md',
    'Docs/Modulos/Desarrollo/MODULE_CHAT_INSTRUCTIONS.md',
    'Docs/Modulos/Desarrollo/MODULE_IMPLEMENTATION_CHECKLIST.md',
    'Docs/Modulos/Desarrollo/MODULE_BRIEF_TEMPLATE.md',
    'Docs/Modulos/Desarrollo/MODULE_EXAMPLES.md',
    'Docs/Modulos/Desarrollo/MODULE_API.md',
    'Docs/Modulos/Funcionales/YOUTUBE_DOWNLOADER.md',
    'Docs/Motores/UNIVERSAL_DOWNLOADER_ENGINES.md',
    'Docs/Motores/YOUTUBE_ENGINES.md',
    'Docs/Modulos/Funcionales/YOUTUBE_PRIVACY_AND_NETWORK.md',
    'Docs/Motores/UNIVERSAL_DOWNLOADER_ENGINE_PACKAGING.md',
    'Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER.md',
    'Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER_PRIVACY_AND_NETWORK.md',
    'Docs/Historico/HashesMotores/ENGINE_HASHES_0.2.0.md',
    'Docs/Historico/HashesMotores/ENGINE_HASHES_0.2.4.md',
    'Docs/Historico/HashesMotores/ENGINE_HASHES_0.11.4.md',
    'Docs/Historico/HashesMotores/ENGINE_HASHES_0.11.5.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.2.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.2.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.2.1.md',
    'Docs/Historico/Entregas/DELIVERY_0.2.1.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.2.2.md',
    'Docs/Historico/Entregas/DELIVERY_0.2.2.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.2.3.md',
    'Docs/Historico/Entregas/DELIVERY_0.2.3.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.2.4.md',
    'Docs/Historico/Entregas/DELIVERY_0.2.4.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.3.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.3.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.4.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.4.0.md',
    'Docs/Modulos/Funcionales/CHAT_ANALYZER.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.5.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.5.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.5.1.md',
    'Docs/Historico/Entregas/DELIVERY_0.5.1.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.5.2.md',
    'Docs/Historico/Entregas/DELIVERY_0.5.2.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.5.5.md',
    'Docs/Historico/Entregas/DELIVERY_0.5.5.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.5.6.md',
    'Docs/Historico/Entregas/DELIVERY_0.5.6.md',
    'Docs/Modulos/Funcionales/UNIVERSAL_CONVERTER.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.6.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.6.0.md',
    'Docs/Historico/Compatibilidad/COMPATIBILITY_MATRIX_0.7.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.7.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.7.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.7.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.7.2.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.7.2.md',
    'Docs/Historico/Entregas/DELIVERY_0.7.2.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.7.3.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.7.3.md',
    'Docs/Historico/Entregas/DELIVERY_0.7.3.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.7.4.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.7.4.md',
    'Docs/Historico/Entregas/DELIVERY_0.7.4.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.7.5.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.7.5.md',
    'Docs/Historico/Entregas/DELIVERY_0.7.5.md',
    'Docs/Modulos/Funcionales/INSTAGRAM_FOLLOWERS_COMPARATOR.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.8.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.8.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.8.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.9.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.9.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.9.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.9.1.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.9.1.md',
    'Docs/Historico/Entregas/DELIVERY_0.9.1.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.9.2.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.9.2.md',
    'Docs/Historico/Entregas/DELIVERY_0.9.2.md',
    'Docs/Motores/ENGINE_MANAGEMENT.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.10.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.10.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.10.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.10.1.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.10.1.md',
    'Docs/Historico/Entregas/DELIVERY_0.10.1.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.10.2.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.10.2.md',
    'Docs/Historico/Entregas/DELIVERY_0.10.2.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.10.3.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.10.3.md',
    'Docs/Historico/Entregas/DELIVERY_0.10.3.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.10.4.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.10.4.md',
    'Docs/Historico/Entregas/DELIVERY_0.10.4.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.11.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.11.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.11.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.11.2.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.11.2.md',
    'Docs/Historico/Entregas/DELIVERY_0.11.2.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.11.3.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.11.3.md',
    'Docs/Historico/Entregas/DELIVERY_0.11.3.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.11.4.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.11.4.md',
    'Docs/Historico/Entregas/DELIVERY_0.11.4.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.11.5.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.11.5.md',
    'Docs/Historico/Entregas/DELIVERY_0.11.5.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.12.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.12.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.12.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.12.1.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.12.1.md',
    'Docs/Historico/Entregas/DELIVERY_0.12.1.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.12.2.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.12.2.md',
    'Docs/Historico/Entregas/DELIVERY_0.12.2.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.12.3.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.12.3.md',
    'Docs/Historico/Entregas/DELIVERY_0.12.3.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.12.4.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.12.4.md',
    'Docs/Historico/Entregas/DELIVERY_0.12.4.md',
    'Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.19.0.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.19.0.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.19.0.0.md',
    'Docs/Modulos/Funcionales/CLEANER.md',
    'Docs/Modulos/Funcionales/CLEANER_PRIVACY_AND_FILES.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.0.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.20.0.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.20.0.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.13.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.13.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.13.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.13.1.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.13.1.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.13.1.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.13.2.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.13.2.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.13.2.0.md',
    'Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.14.0.0.md',
    'Docs/Historico/Pruebas/TEST_RESULTS_0.14.0.0.md',
    'Docs/Historico/Entregas/DELIVERY_0.14.0.0.md',
]
for name in required:
    path = Path(name)
    if not path.is_file() or path.stat().st_size < 200:
        raise SystemExit(f'Documentación modular ausente o incompleta: {name}')

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
        raise SystemExit(f'Falta una categoría de documentación: {directory}')

root_docs = {path.name for path in Path('Docs').glob('*.md')}
if root_docs != {'INDEX.md'}:
    raise SystemExit(f'La raíz de Docs solo debe contener INDEX.md: {sorted(root_docs)}')
for path in map(Path, required):
    text = path.read_text()
    if 'TODO_AUTOGENERADO' in text or 'PLACEHOLDER_AUTOGENERADO' in text:
        raise SystemExit(f'Marcador de documentación incompleta en {path}')
