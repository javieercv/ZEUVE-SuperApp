# Resultados de pruebas — ZEUVE 0.4.0

Fecha: 2 de julio de 2026.

## Objetivo

Validar la centralización de los ajustes persistentes, la separación entre valores predeterminados y opciones de la operación actual, la gestión de presets y diagnóstico dentro de Ajustes, y la ausencia de accesos independientes de configuración en los módulos.

## Pruebas Swift

Comando:

```bash
swift test --jobs 2
```

Resultado final:

- 71 pruebas ejecutadas;
- 71 superadas;
- 0 fallos;
- compilación Debug de todos los paquetes completada.

La primera ejecución detectó correctamente una expectativa antigua del manifiesto que todavía comprobaba la versión 0.3.0. La prueba se actualizó a 0.4.0 y la suite completa se volvió a ejecutar sin fallos.

Se añadieron dos pruebas específicas:

- persistencia independiente de `organizer.defaultOptions` frente a la antigua clave de opciones de operación;
- persistencia conjunta de `youtube.defaultSettings` y `youtube.defaultAdvancedMode`.

## Pruebas Python

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado:

- 11 pruebas ejecutadas;
- 11 superadas;
- 0 fallos.

## Validaciones de interfaz y arquitectura

Se comprobó estáticamente que:

- Ajustes contiene las secciones General, Organizador de archivos y Descargador de YouTube;
- el Descargador contiene las subsecciones Predeterminados, Presets y Diagnóstico;
- `YouTubeDownloaderView` no contiene botones Presets, Diagnóstico, estados de presentación asociados ni rueda de ajustes;
- `OrganizerView` no contiene una rueda de ajustes;
- el Descargador conserva un selector rápido para aplicar presets;
- las opciones de una operación del Organizador ya no se guardan sobre sus valores predeterminados;
- al seleccionar una carpeta para una nueva operación, el Organizador recupera los valores predeterminados centralizados;
- los valores persistentes usan las claves `organizer.defaultOptions`, `youtube.defaultSettings` y `youtube.defaultAdvancedMode`;
- todas las vistas SwiftUI/AppKit se pueden analizar sintácticamente;
- el proyecto Xcode incluye los archivos actuales y declara versión 0.4.0, build 12.

## Compilación Release

La compilación SwiftPM Release se ejecuta mediante:

```bash
swift build -c release --jobs 2
```

Resultado final:

- compilación completada correctamente;
- sin errores de enlace ni de compilación en los paquetes Swift;
- la repetición incremental terminó en 0,43 segundos tras la compilación completa previa.

Esta compilación verifica los paquetes Swift, pero no equivale a compilar ni abrir la aplicación macOS mediante Xcode.

## Validación global

El script `Scripts/verify_project.sh` volvió a superar las 71 pruebas Swift y alcanzó la compilación Release. La ejecución conjunta fue interrumpida por el límite temporal del entorno durante esa recompilación. Para no confundir ese límite con un fallo, la compilación Release y todas las fases posteriores se ejecutaron por separado:

- 11 pruebas Python superadas;
- documentación modular y ejemplos JSON validados;
- manifiestos JSON validados;
- scripts shell y Python comprobados sintácticamente;
- todas las vistas SwiftUI/AppKit analizadas sintácticamente;
- proyecto Xcode regenerado con 13 archivos Swift de aplicación;
- comprobaciones estáticas de centralización y ausencia de accesos duplicados superadas.

## Pruebas no disponibles en este entorno

El entorno no es macOS Apple Silicon y no permite comprobar:

- compilación real de `ZEUVE.app` mediante Xcode;
- apertura visual de la ventana de Ajustes;
- comportamiento real de los paneles y listas SwiftUI;
- navegación mediante teclado y VoiceOver;
- apariencia en modo claro y oscuro;
- firma, Gatekeeper y motores dentro de la aplicación empaquetada.

Estas comprobaciones continúan pendientes de un Mac Apple Silicon con Xcode.
