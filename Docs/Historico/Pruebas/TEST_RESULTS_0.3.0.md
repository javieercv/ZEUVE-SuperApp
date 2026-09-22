# Resultados de pruebas — ZEUVE 0.3.0

Fecha: 2 de julio de 2026.

## Alcance comprobado

La versión 0.3.0 modifica la interfaz del Descargador, añade bitrate MP3 configurable, cambia valores predeterminados, incorpora ayuda contextual compartida y migra el esquema de presets.

## Pruebas Swift

Se ejecutó:

```bash
swift test --disable-sandbox
```

Resultado: **69 pruebas superadas, 0 fallos**.

La cobertura nueva comprueba:

- MP4 como contenedor de vídeo predeterminado;
- MP3 como formato de audio predeterminado;
- 320 kbps como bitrate MP3 predeterminado;
- Título como nombre predeterminado;
- argumentos `128K`, `192K`, `256K` y `320K` para MP3;
- ausencia de `--audio-quality` en formatos distintos de MP3;
- decodificación de configuraciones antiguas sin el campo `mp3Bitrate`;
- migración de presets del esquema 1 al esquema 2 conservando sus valores;
- versión 0.3.0 del manifiesto del módulo.

## Pruebas de scripts

Se ejecutó:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py'
```

Resultado: **11 pruebas superadas, 0 fallos**.

Estas pruebas verifican las políticas de firma y empaquetado de motores, las dependencias estáticas aprobadas y los scripts relacionados con la construcción.

## Compilación

Se ejecutó:

```bash
swift build -c release --jobs 2
```

Resultado: **compilación SwiftPM Release completada correctamente**.

Esta compilación cubre los módulos incluidos en `Package.swift`. La aplicación SwiftUI se mantiene como objetivo Xcode y no forma parte del paquete SwiftPM.

## Interfaz

Todos los archivos Swift de `Sources/ZEUVEApp` se analizaron con:

```bash
swiftc -frontend -parse
```

Resultado: **sin errores sintácticos**.

La comprobación incluye el componente compartido de ayuda contextual y las vistas del Descargador, Organizador y Ajustes.

También se regeneró `ZEUVE.xcodeproj` y se verificó que contiene:

- versión 0.3.0 y build 11;
- el nuevo archivo `ContextualHelp.swift`;
- las vistas y recursos actuales del proyecto.

## Validaciones adicionales

Se comprobaron correctamente:

- ejemplos y manifiestos JSON;
- documentación requerida para la entrega;
- versión del módulo y del proyecto;
- estructura de motores y archivos obligatorios;
- coherencia de los scripts de compilación y empaquetado.

El script integral `Scripts/verify_project.sh` alcanzó y superó las pruebas Swift, la compilación Release, las comprobaciones estáticas, las pruebas Python y la documentación. El entorno interrumpió el proceso al final por su límite de ejecución. Las fases restantes —JSON, análisis sintáctico completo y regeneración del proyecto Xcode— se ejecutaron inmediatamente por separado y terminaron correctamente.

## Comprobaciones no realizadas

Este entorno es Linux x86_64. Por tanto, no se ha podido:

- compilar el objetivo macOS mediante Xcode;
- firmar y abrir una aplicación `.app`;
- verificar visualmente los paneles emergentes;
- probar VoiceOver y navegación por teclado dentro de la aplicación;
- ejecutar una prueba manual completa en un Mac Apple Silicon.

No se ha realizado una descarga real desde YouTube porque los cambios de esta versión afectan a configuración e interfaz. El generador de comandos y la compatibilidad de presets sí están cubiertos mediante pruebas automáticas.
