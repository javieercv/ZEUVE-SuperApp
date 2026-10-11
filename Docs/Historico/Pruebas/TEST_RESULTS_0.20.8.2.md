# Resultados de pruebas — ZEUVE 0.20.8.2

11/10/2026 · Base remota `4c95ab1911ef32bd60a01dfe61a083e33aeacdcc`; marketing 0.20.8/revisión 2/build 76, Descargador 0.7.6, instaloader-zeuve 4.15.3-zeuve.5.

`run_tests.sh` y `verify_project.sh` completados: suite Swift completa, **125 tests del Descargador y 125 tests Python**, build SwiftPM Release, verificadores estructurales/documentales y build Xcode Debug real. `build_macos.sh Release` completa build, motores empaquetados y firma; bundle contrastado con VERSION (revisión 2/build 76). La primera pasada detectó la revisión anterior todavía fijada en el generador; se actualizó y reconstruyó antes de abrir la app.

Regresiones añadidas: resolución autenticada exacta y rechazo de metadata de otra cuenta; encabezado anónimo con canonical correcto y exclusión de sesiones; conservación de destacadas GraphQL con ausencia auxiliar de la misma colección, rechazo de propietario distinto/429 y restauración del contexto al cerrar el iterador. Threads conserva orden foto/vídeo, excluye avatar/poster/respuestas, rechaza permalink de otro post y respuestas con multimedia sin recurso propio. La cancelación previa detiene el descubrimiento antes de iniciar red.

Las expectativas de versión existentes se actualizan para el nuevo manifest/helper sin eliminar comprobaciones de preparación, permisos ni hashes. No se actualizan dependencias upstream.

La [QA nativa](DOWNLOADER_QA_0.20.8.2_20261011.md) cierra ocho IDs, verifica cuatro archivos/12.767.658 bytes y amplía la auditoría de privacidad a descargas autenticadas. Checklist: 634 OK, cero fallidas, tres parciales y dos pendientes; 637 ejecutadas de 639. Publicaciones/Reels públicos y Stories activas mantienen los límites documentados; Reddit online aplazado. No se certifica distribución notarizada.

La revisión final añade una regresión de ventana anónima llena: conserva los avisos de Stories/Destacadas aunque ya exista cursor y no consulta esas secciones sin sesión. Esta corrección no cambia los recorridos nativos descritos; el helper se reconstruye y se vuelve a verificar su empaquetado.
