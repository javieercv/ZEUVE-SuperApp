# Resultados de pruebas — ZEUVE 0.9.0

Fecha: 4 de agosto de 2026.

## Entorno utilizado

- Sistema: Linux x86_64.
- Swift: 6.2.1.
- Pruebas sin datos privados y sin incorporar URLs reales del usuario.
- No se utilizó Internet para validar plataformas reales.

## Pruebas específicas del Descargador universal

Comando:

```bash
swift test --filter YouTubeDownloaderModuleTests --jobs 1
```

Resultado:

- 33 pruebas XCTest ejecutadas.
- 33 superadas.
- 0 fallos.

Cobertura relevante:

- URLs universales, YouTube heredado, duplicados y red local.
- Detección HTML de vídeo, source, iframe, metadatos, JSON-LD, HLS y DASH.
- Normalización y eliminación de tokens únicamente para comparar.
- Cookies Netscape.
- Ajustes compatibles con versiones anteriores.
- Parser incremental de miles de elementos.
- Directos, formatos, subtítulos, progreso y comandos.
- Presets, bookmarks, historial, privacidad, temporales y publicación.
- Manifiesto y ausencia de componentes remotos.

## Suite Swift completa

Comando:

```bash
swift test --jobs 1
```

Resultado:

- 132 pruebas XCTest superadas.
- 45 pruebas Swift Testing superadas.
- 177 pruebas Swift totales sin fallos.
- Duración informada de XCTest: 8,349 segundos.

La suite cubre también Organizador, Analizador de chats, Conversor universal, Comparador de seguidores, núcleo, almacenamiento, motores y procesos.

## Comprobaciones adicionales realizadas

- 26 pruebas Python de scripts y políticas superadas sin fallos.
- Documentación de módulos y ejemplos JSON validados.
- Todos los manifiestos JSON actuales validados.
- Regeneración de `ZEUVE.xcodeproj` para 0.9.0, build 28.
- Análisis sintáctico con `swiftc -frontend -parse` de las vistas y ViewModels macOS modificados.
- Compilación Release del target `YouTubeDownloaderModule` completada correctamente.
- Comprobación del manifiesto 0.5.0 y de sus permisos aprobados.
- Revisión estática de migración, deduplicación, ausencia de `AsyncImage`, logs y claves heredadas.
- Garantías estáticas del Conversor universal comprobadas para evitar regresiones no relacionadas.

## Pruebas que no pueden darse por realizadas en este entorno

- Compilación Release completa de todos los targets: se intentó, pero el entorno interrumpió la operación por tiempo mientras compilaba targets grandes. No apareció un error de compilación antes de la interrupción; por ello no se presenta como superada.
- Compilación de la aplicación SwiftUI/AppKit para macOS.
- Apertura real de `ZEUVE.app`.
- Firma, Hardened Runtime, Gatekeeper y empaquetado final ARM64.
- Navegación visual, VoiceOver, teclado, modos claro y oscuro.
- Descargas reales en páginas y plataformas externas.
- Cookies y proxy frente a servicios reales.
- HTTP y servidores de una red local real.
- Cancelación durante una descarga real y durante FFmpeg en macOS.
- Páginas dinámicas que necesiten JavaScript complejo.

Por estas limitaciones no se afirma que la interfaz nativa o la compatibilidad con una web concreta estén validadas. Deben comprobarse en un Mac Apple Silicon.
