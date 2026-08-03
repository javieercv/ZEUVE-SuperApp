# Entrega — ZEUVE 0.5.1

Fecha: 3 de julio de 2026.

## Resumen

ZEUVE 0.5.1 corrige la importación de chats grandes de WhatsApp, distingue correctamente los adjuntos al subir un TXT, adapta el cuadro de carga a la plataforma elegida y permite analizar ZIP de Instagram que contienen directamente una sola conversación.

## Correcciones realizadas

- La muestra inicial de 256 KB de WhatsApp ya no actúa como límite del TXT completo.
- El TXT de WhatsApp se procesa progresivamente desde archivo o ZIP.
- Por defecto no existe límite para cada archivo de conversación.
- Se añade un límite opcional y persistente en `Ajustes > Analizador de chats`.
- Los adjuntos de un TXT directo se muestran como no comprobados en vez de faltantes.
- Los stickers WEBP exportados por WhatsApp se distinguen de las imágenes WEBP normales.
- El cuadro de subida, sus textos, el diálogo de macOS y los tipos aceptados cambian según WhatsApp, Instagram o Ambas plataformas.
- Se admiten exportaciones completas de Meta y ZIP que contienen directamente una conversación de Instagram.
- Las rutas de fotos, vídeos y audios de los ZIP individuales se adaptan a la estructura incluida.
- Si Instagram contiene una sola conversación, queda seleccionada automáticamente; el análisis continúa requiriendo la acción expresa del usuario.

## Seguridad y privacidad

- No se añaden dependencias, Internet, APIs, telemetría ni procesos externos.
- Los originales se abren solo para lectura y no se extraen junto a los archivos del usuario.
- Las protecciones frente a traversal, rutas absolutas, cifrado, enlaces, entradas duplicadas y relaciones de compresión continúan activas.
- El límite opcional del chat es independiente de las protecciones estructurales del ZIP.
- Los chats reales aportados no forman parte del código, las pruebas permanentes, la documentación ni el ZIP final.

## Versión

- Versión anterior: 0.5.0, build 13.
- Versión nueva: 0.5.1, build 14.
- Módulo Analizador de chats: 0.1.0 → 0.1.1.
- Motivo: correcciones compatibles y ajustes menores del módulo existente.

## Pruebas

- 97 pruebas Swift superadas.
- 11 pruebas Python superadas.
- Compilación SwiftPM Release completada.
- `Scripts/verify_project.sh` completado sin fallos.
- Proyecto Xcode regenerado.
- Integración comprobada temporalmente con los ZIP reales de WhatsApp e Instagram aportados.
- Huellas de los archivos originales verificadas antes y después.

## Archivos principales modificados

- `Sources/ChatAnalyzerModule/Archive/ChatArchive.swift`: lectura parcial real y transmisión de entradas ZIP.
- `Sources/ChatAnalyzerModule/Import/WhatsAppImporter.swift`: importación progresiva, límite opcional y adjuntos no comprobados.
- `Sources/ChatAnalyzerModule/Import/InstagramImporter.swift`: ZIP de conversación directa y reubicación de adjuntos.
- `Sources/ChatAnalyzerModule/Import/ChatParsingUtilities.swift`: identificación de stickers.
- `Sources/ChatAnalyzerModule/ChatAnalyzerModels.swift`: ajuste y resumen nuevos.
- `Sources/ChatAnalyzerModule/ChatAnalyzerService.swift`: agregación de adjuntos no comprobados.
- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerView.swift`: cuadro y selector dependientes de la plataforma.
- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift`: detección y selección automática.
- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift`: indicador de adjuntos no comprobados.
- `Sources/ZEUVEApp/SettingsView.swift` y `Components/ContextualHelp.swift`: límite opcional centralizado y ayuda.
- `Tests/ChatAnalyzerModuleTests/ChatAnalyzerTests.swift`: regresiones nuevas.
- Archivos de versión, proyecto Xcode, scripts, changelog y documentación.

## Elementos no modificados funcionalmente

- Organizador de archivos.
- Descargador de YouTube y motores incluidos.
- Historial global fuera de la agregación necesaria del nuevo campo.
- Arquitectura general, permisos y política de red.

## Limitaciones

No se ha compilado ni abierto `ZEUVE.app` con Xcode porque el entorno no es macOS Apple Silicon. El flujo visual final, el selector nativo, arrastrar y soltar, VoiceOver, firma y notarización deben comprobarse en un Mac compatible. La suite valida la lógica y la sintaxis, pero no sustituye esa prueba manual.
