# Resultados de pruebas — ZEUVE 0.5.0

Fecha: 3 de julio de 2026.

## Objetivo

Validar el nuevo módulo Analizador de chats, su integración con ZEUVE, la importación local de WhatsApp e Instagram, el motor estadístico, la privacidad, la seguridad ZIP, la cancelación y la ausencia de regresiones en los módulos existentes.

## Pruebas Swift

Comando:

```bash
swift test --jobs 1
```

Resultado final:

- 93 pruebas ejecutadas;
- 93 superadas;
- 0 fallos;
- 22 pruebas específicas del Analizador de chats;
- compilación Debug de todos los paquetes completada.

Las pruebas específicas cubren:

- manifiesto y ausencia de permiso de red;
- normalización de rutas ZIP y rechazo de traversal;
- componentes `./` legítimos;
- formatos de WhatsApp, multilínea, sistema y adjuntos;
- ZIP de WhatsApp, adjuntos faltantes y no referenciados;
- catálogo de Instagram, índices, varias páginas y orden final;
- nombres duplicados con identificadores distintos;
- enlaces externos sin apertura ni referencia de adjunto;
- estrategias horarias reales;
- fechas numéricas ambiguas en ambos órdenes;
- filtros nocturnos;
- palabras, bigramas y emojis compuestos;
- umbrales de conversación y turnos de respuesta;
- búsqueda y límite temporal del contexto;
- historial sin contenido privado, también en cancelación y fallo;
- persistencia y restauración de ajustes;
- eliminación de bases y temporales propios;
- rechazo a eliminar una carpeta sin marcador de propiedad;
- integridad del TXT original;
- cancelación cooperativa;
- deduplicación conservadora.

## Pruebas Python

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

- 11 pruebas ejecutadas;
- 11 superadas;
- 0 fallos.

## Compilación

Se comprueban:

```bash
swift build -c release --jobs 1
swiftc -frontend -parse <vistas de ZEUVEApp>
python3 Scripts/generate_xcode_project.py
```

Resultado: compilación SwiftPM Release completada correctamente. La compilación SwiftPM valida el núcleo y los módulos, incluido el enlace con `libarchive` del sistema en el entorno disponible. El análisis sintáctico valida los archivos de la aplicación, pero no sustituye una compilación SwiftUI/AppKit mediante Xcode.

## Seguridad y privacidad

Se verifica estáticamente que:

- el manifiesto solo declara lectura de archivos seleccionados;
- el módulo no contiene `URLSession`, WebKit ni apertura de enlaces externos;
- `CLibArchive` usa el SDK/sistema, sin Homebrew ni `pkg-config`;
- los temporales usan un marcador de propiedad;
- historial y logs no incluyen mensajes, participantes, consultas o rutas completas;
- el proyecto no contiene datos personales reales como fixtures.

## Originales

Las pruebas comparan contenido y huella del TXT antes y después de importarlo. Los ZIP y carpetas de prueba son sintéticos y se crean en directorios temporales.

## Pruebas no disponibles en este entorno

El entorno de implementación es Linux x86_64 con Swift 6.2.1. No permite comprobar:

- compilación del objetivo `ZEUVE.app` mediante Xcode;
- apertura real de la aplicación;
- selección de archivos, arrastrar y soltar y paneles nativos;
- aspecto claro y oscuro;
- comportamiento de Swift Charts;
- teclado y VoiceOver;
- firma, Hardened Runtime y Gatekeeper;
- rendimiento real con millones de mensajes en un Mac Apple Silicon.

## Validación global

`Scripts/verify_project.sh` se ejecutó completo y finalizó correctamente. Incluyó:

- 93 pruebas Swift;
- compilación SwiftPM Release;
- 11 pruebas Python;
- validación de manifiestos y documentación;
- comprobaciones estáticas de privacidad, ajustes e integración;
- análisis sintáctico de las 16 fuentes de `ZEUVEApp`;
- regeneración del proyecto Xcode;
- comprobación sintáctica de scripts shell y Python.

La validación de motores y la compilación Xcode se omitieron automáticamente porque el entorno no es macOS Apple Silicon.
