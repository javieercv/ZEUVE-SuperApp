#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Regresiones de conversión real y vídeo a fotogramas de ZEUVE 0.7.5.
from pathlib import Path
builder = Path('Sources/UniversalConverterModule/Execution/FFmpegCommandBuilder.swift').read_text()
planner = Path('Sources/UniversalConverterModule/Planning/ConversionPlanner.swift').read_text()
execution = Path('Sources/UniversalConverterModule/Execution/UniversalConverterExecutionService.swift').read_text()
workspace = Path('Sources/UniversalConverterModule/Execution/ConverterWorkspace.swift').read_text()
visible = Path('Sources/UniversalConverterModule/Execution/VisibleFrameOutputSession.swift').read_text()
view_model = Path('Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift').read_text()
help_text = Path('Sources/ZEUVEApp/UniversalConverter/UniversalConverterHelp.swift').read_text()
for required in ['showinfo=checksum=0', '"-compression_level", "3"', '"-pred", "up"']:
    if required not in builder:
        raise SystemExit('Se ha perdido una optimización de fotogramas: ' + required)
for required in ['options.advancedMode', 'options.preferRemuxWhenPossible', '"-c:v", "copy"']:
    if required not in builder + planner:
        raise SystemExit('La copia rápida de vídeo no conserva su control avanzado: ' + required)
for required in ['VisibleFrameOutputCoordinator', 'preserveIncompleteFrames', 'result.wasCancelled', 'FrameTimingCSVCollector']:
    if required not in execution + visible:
        raise SystemExit('Falta una protección del flujo visible de fotogramas: ' + required)
for required in ['recoverAbandonedVisibleFrameOutputs', 'visibleFrameRecordURL']:
    if required not in workspace:
        raise SystemExit('Falta recuperación de fotogramas incompletos: ' + required)
for required in ['universalConverter.defaults.v4', 'legacySettingsV3Key', 'universalConverter.presets.v4', 'legacyPresetsV3Key']:
    if required not in view_model:
        raise SystemExit('Falta migración segura de los ajustes de recodificación: ' + required)
for required in ['Copia rápida sin recodificar', 'no reduce el tamaño']:
    if required not in help_text + Path('Sources/ZEUVEApp/UniversalConverter/UniversalConverterView.swift').read_text():
        raise SystemExit('La interfaz no explica correctamente el remux: ' + required)

# El Conversor universal debe conservar su arquitectura, seguridad y rendimiento aprobados.
from pathlib import Path
required = [
    'Sources/UniversalConverterModule/UniversalConverterModuleDefinition.swift',
    'Sources/UniversalConverterModule/Execution/UniversalConverterExecutionService.swift',
    'Sources/UniversalConverterModule/Execution/NativeImageService.swift',
    'Sources/UniversalConverterModule/Execution/NativePDFService.swift',
    'Sources/UniversalConverterModule/Archive/ConverterArchive.swift',
    'Sources/ZEUVEApp/UniversalConverter/UniversalConverterView.swift',
    'Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift',
    'Tests/UniversalConverterModuleTests/UniversalConverterCoreTests.swift',
]
for name in required:
    if not Path(name).is_file(): raise SystemExit('Falta un archivo del Conversor: ' + name)
module = '\n'.join(path.read_text(errors='ignore') for path in Path('Sources/UniversalConverterModule').rglob('*.swift'))
for value in ['h264_videotoolbox', 'fps_mode', 'passthrough', 'tiempos.csv', 'ImageIO', 'PDFKit', 'ConverterSafePath', 'revision']:
    if value not in module: raise SystemExit('Falta una garantía del Conversor: ' + value)
for required in ['libx264', 'libwebp', 'PandocCommandBuilder']:
    if required not in module: raise SystemExit('Falta una capacidad aprobada del Conversor: ' + required)
for forbidden in ['CalibreCommandBuilder', 'GhostscriptCommandBuilder', 'case .calibre', 'case .ghostscript']:
    if forbidden in module: raise SystemExit('El Conversor conserva un motor retirado: ' + forbidden)
for forbidden in ['/bin/sh', 'libx265', 'URLSession', 'ProcessInfo.processInfo.environment["PATH"]']:
    if forbidden in module: raise SystemExit('Contenido no aprobado en el Conversor: ' + forbidden)
for forbidden in ['LibreOffice', 'soffice', 'case doc, docx', 'case libreOffice']:
    if forbidden in module: raise SystemExit('El Conversor conserva soporte ofimático retirado: ' + forbidden)
models = '\n'.join(path.read_text() for path in sorted(Path('Sources/UniversalConverterModule/Models').glob('*.swift')))
for required in ['case txt, markdown, html, csv, json, xml', 'case .csv, .json, .xml: return .data']:
    if required not in models: raise SystemExit('CSV no se conserva como formato de datos genérico: ' + required)
for extension in ['doc','docx','xls','xlsx','ppt','pptx','odt','ods','odp','rtf']:
    if f'case "{extension}":' in models: raise SystemExit('Extensión ofimática todavía registrada: ' + extension)
view_model = Path('Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift').read_text()
for value in ['planRevision', 'planTask?.cancel()', 'Task.sleep', 'guard revision == self.planRevision']:
    if value not in view_model: raise SystemExit('Falta control de resultados obsoletos: ' + value)
