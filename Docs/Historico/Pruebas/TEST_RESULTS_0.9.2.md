# Resultados de pruebas — ZEUVE 0.9.2

Fecha: 4 de agosto de 2026.

## Entorno

- Linux x86_64.
- Swift 6.2.1.
- Compilación y pruebas mediante Swift Package Manager.
- El entorno no permite abrir ni validar visualmente una aplicación macOS.

## Suite Swift completa

Comando:

```bash
swift test --jobs 4
```

Resultado:

- 144 pruebas XCTest superadas.
- 45 pruebas Swift Testing superadas.
- 189 pruebas Swift en total.
- 0 fallos.
- Tiempo medido del comando: 13,13 segundos con caché de compilación disponible.

## Descargador universal

La batería específica contiene 45 pruebas XCTest y todas superaron la ejecución. La cobertura nueva comprueba:

- extracción de URL directa, manifiesto, protocolo, cabeceras y caducidad;
- preferencia por un manifiesto DASH común cuando vídeo y audio llegan separados;
- ausencia de URL firmada, token y cabeceras en el JSON codificado;
- uso del recurso resuelto en el comando sin volver a pasar la página como URL de descarga;
- aplicación y redacción de cabeceras;
- detección de referencias caducadas;
- escalado 16 → 8 → 4 → 1;
- reducción únicamente ante señales compatibles con limitación o fallo de fragmentos;
- decodificación de ajustes antiguos con aceleración segura;
- publicación mediante movimiento dentro del mismo volumen;
- conservación del tamaño y desaparición del temporal tras publicar;
- protecciones anteriores de temporales, conflictos, symlinks, historial y privacidad.

## Pruebas Python y contratos estáticos

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado:

- 32 pruebas superadas.
- 0 fallos.

Incluyen comprobaciones de interfaz, ayuda contextual, ajustes centralizados, referencia efímera no persistente, descarga adaptativa y publicación optimizada.

## Compilación Release

Comandos:

```bash
swift build -c release --target YouTubeDownloaderModule --jobs 4
swift build -c release --jobs 4
```

Resultados:

- Target `YouTubeDownloaderModule`: compilación Release completada, 22,95 segundos.
- Paquete Swift completo: compilación Release completada, 31,22 segundos con artefactos parciales ya compilados.

## Verificación integral del proyecto

Comando:

```bash
ZEUVE_SWIFT_JOBS=4 bash Scripts/verify_project.sh
```

Resultado: completado sin errores. El script repitió la suite Swift, la compilación Release, las 32 pruebas Python, la validación de documentación, manifiestos y políticas estáticas, y regeneró el proyecto Xcode. Las comprobaciones exclusivas de macOS Apple Silicon fueron omitidas explícitamente por el entorno.

## Sintaxis de interfaz

Los siguientes archivos superaron `swiftc -frontend -parse`:

- `ContextualHelp.swift`
- `SettingsView.swift`
- `YouTubeDownloaderView.swift`
- `YouTubeDownloaderViewModel.swift`

El proyecto Xcode se regeneró con versión 0.9.2 y build 30.

## Verificaciones pendientes del entorno objetivo

No se ha comprobado en este entorno:

- apertura real de ZEUVE en macOS;
- comportamiento visual de SwiftUI/AppKit y VoiceOver;
- descarga desde la página privada concreta que produjo la incidencia;
- velocidad real de su servidor, CDN o conexión;
- atributos extendidos «De dónde» en macOS;
- firma, Hardened Runtime, Gatekeeper y empaquetado final de la app;
- ejecución de los binarios ARM64 incluidos.

La implementación elimina de forma comprobable la segunda resolución cuando existe una referencia válida y la segunda copia completa cuando el destino está en el mismo volumen. La mejora exacta en una web concreta debe medirse en un Mac con esa misma página.
