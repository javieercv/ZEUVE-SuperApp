# Pruebas — ZEUVE 0.20.8.4

12/10/2026. Base remota sincronizada `3f499d8eab1ac7382066266454dac545cd9bcf3a`. Marketing 0.20.8/revisión 4/build 78; Descargador 0.7.8, helper 4.15.3-zeuve.7.

`Scripts/run_tests.sh`: **284 XCTest + 203 Swift Testing = 487 Swift**, correctas. **134 Python**, correctas en la repetición final de scripts. Descargador: 129 XCTest; helper: 26 pruebas Python.

La regresión Swift valida clasificación Reel/vídeo de carrusel, identidad, posición, resolución MP4, carpeta y ausencia de autenticación. Cuatro nuevas pruebas Python cubren la consulta existente e identidad exacta, selección de versión, propiedad/código/privacidad, sesión excluida, correspondencia de hijos, parada tras 429/budget y paginación sin omitir fotos al faltar un vídeo. Las ventanas posteriores no consultan vídeos de ventanas previas; los campos internos de paginación no se emiten.

`Scripts/verify_project.sh` pasa: tests, SwiftPM Release, verificadores del proyecto, scripts/documentos/manifiestos, 80 fuentes de app, 11 productos enlazados y build real Debug. Tras el ajuste final del helper se repiten los 134 tests de scripts y verificadores afectados, reconstrucción del motor y Release completo.

`Scripts/build_macos.sh Release` pasa: ARM64, bundle 0.20.8.4/build 78, seis motores y firma ad hoc/validación profunda correctos. El payload del helper empaquetado coincide con el source ejecutable actualizado y contiene las posiciones estables; SHA-256 del payload `4ad1e1fe8121b418ce7e8587dc11340b8def2b804d8b6dfacd9b68e744f4c9e0`. No hay upstream, dependencia, permiso, esquema o endpoint nuevo. Sin ZIP/DMG/notarización.

[QA nativa](DOWNLOADER_QA_0.20.8.4_20261012.md): URL y @usuario, 24→42 recursos, cuatro Reels, tres descargas válidas (Reel, vídeo de carrusel y foto). Se decodifican íntegramente. D-39/D-41 pasan en el criterio documentado; el catálogo global sigue sin certificarse por 401. Stories activas/cuentas privadas y Reddit excluidos; no se convierten en OK. Checklist 637 OK, cero fallidas, dos parciales y cero pendientes.
