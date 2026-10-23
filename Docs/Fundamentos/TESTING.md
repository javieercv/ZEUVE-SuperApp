# Pruebas y validación — ZEUVE 0.21.0.0

La familia residente fue **RETIRADA el 23/10/2026** por decisión del usuario. Su QA pendiente deja de ser alcance vigente. El siguiente párrafo conserva el estado del intento anterior a su retirada.

La nueva familia residente estaba **EN VALIDACIÓN**. Sus [resultados actuales](../Historico/Pruebas/TEST_RESULTS_0.21.0.0.md) distinguen compilación, pruebas automáticas, integración y QA real. Un tap creado, un atajo enviado o una ventana enumerada no acredita eficacia del audio, identidad física del ratón ni comportamiento completo de aplicaciones externas. La protección durante llamadas permanece sin completar mientras falte un diagnóstico reproducible y una ruta eficaz comprobada.

La verificación de la retirada cubre la ausencia de referencias en código/configuración, coherencia SwiftPM/Xcode, tests restantes, builds y recorrido nativo de arranque, navegación, Ajustes y cierre. Resultados en el [registro de retirada](../Historico/Implementacion/QUICK_UTILITIES_RETIREMENT_20261023.md).

## Evidencia conservada del Descargador — 0.20.8.4

La ronda de pruebas queda cerrada por decisión del usuario el 12/10/2026. El desarrollo y la QA del Descargador se aplazan hasta que el usuario los retome. Se conservan los resultados, exclusiones y límites descritos a continuación; este cierre documental no añade comprobaciones ni certifica el catálogo completo de Instagram.

La entrega anterior 0.20.8.4 dispone de [regresiones y verificación](../Historico/Pruebas/TEST_RESULTS_0.20.8.4.md) y [QA nativa de perfiles públicos/Reels](../Historico/Pruebas/DOWNLOADER_QA_0.20.8.4_20261012.md). Estado acumulado: 637 OK, cero fallidas, dos parciales excluidas y cero pendientes de 639; D-39/D-41 pasan en sus criterios documentados. La aceptación se basa en el catálogo y descargas reales, sin sustituir el perfil por enlaces independientes ni las miniaturas por vídeos. La muestra finita sigue declarada parcial frente al feed global cuando este no permite la consulta anónima. Stories activas y cuentas privadas se excluyen por instrucción del usuario; Reddit online continúa aplazado. Los IDs no repetidos conservan su evidencia previa.

La evidencia técnica de los parciales corregidos está en [TEST_RESULTS_0.20.7.0.md](../Historico/Pruebas/TEST_RESULTS_0.20.7.0.md). Los nueve IDs locales pasan su [aceptación desde UI](../Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005.md); las pruebas de servicio complementan ese recorrido. La [revalidación manual de 04/10/2026](../Historico/Pruebas/MANUAL_QA_0.20.6.0_20261004.md) conserva los 22 IDs comprobados en la entrega anterior. El [cierre de I-29/I-35](../Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005_AUDIO_VIDEO.md) mide la salida de audio capturada y los frames presentados, incluidos mute/ganancia, salto/reanudación y cambio de pista. La checklist acumulada al 10/10/2026 (`Cheklist Manual de aceptacion de ZEUVE.md`, en la raíz) registra 613 OK, 9 fallidas, 8 parciales y 9 pendientes: 630 pruebas ejecutadas, incluidas las parciales. Todo estado sin OK restante pertenece al Descargador o a su autenticación remota, incluido P-12; P-11 pasa en el alcance de análisis documentado.

## Evidencia de aceptaciones anteriores

El [perfil público adicional del 10/10/2026](../Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010_PUBLIC_PROFILE.md) confirma un fixture con publicaciones/Reels/foto, pero el análisis de perfil sigue con request_blocked y catálogo vacío pese a todos los filtros activos. Enlaces concretos del mismo origen sí resuelven 17 elementos y un Reel, que se descarga y decodifica entero. Se amplía evidencia sin cambiar estados: las pruebas de catálogo no se sustituyen por enlaces independientes.

La [Story privada autorizada](../Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010_PRIVATE_STORY.md) se reproduce en Brave, pero su análisis anónimo en ZEUVE queda vacío y no muestra panel de sesión. Tras desbloquear macOS se repite con archivo de sesión normalizado aceptado: también vacío, sin panel ni validación efectiva. El perfil con sesión se cancela a ≈184 s sin catálogo. Auditoría final: 234 logs frente a 8 valores reales, 0 coincidencias; no certifica descarga autenticada ni invalida P-12. Cookies temporales eliminadas, app cerrada y sesión original de Brave conservada. Estados acumulados sin cambios; los 9 pendientes dependen de catálogo/panel operativos. Reddit aplazado expresamente por el usuario.

La [QA exploratoria remota del Descargador del 09/10/2026](../Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261009.md) utiliza enlaces aportados por el usuario y datos aislados en Debug. Registra fallos de tipo, duplicación y presentación, además de cancelación y continuidad. Por instrucción posterior del usuario, sus resultados se incorporan a la checklist: la casilla indica ejecución y el símbolo distingue correcta, fallida o parcial. La [continuación del 10/10/2026](../Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010.md) cierra tres requisitos, prueba las combinaciones de carpetas con descargas reales y ejecuta de nuevo `run_tests.sh` sin fallos. El [remate posterior](../Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010_CONTINUATION.md) completa descarga/decodificación de la repetición y prueba EroMe con duplicados y fotos omitidas. P-12 queda fallido: canarios de token/password/sessionid se conservan en metadata.error de una rama remota fallida, sin utilizar secretos reales. La [QA de sesión autorizada](../Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010_SESSION.md) prueba exportación Instagram de Brave, selector de archivo y análisis con cookies, sin obtener catálogo ni certificar validación efectiva. D-47 falla por incompatibilidad de expiración vacía; D-44/D-46/D-48 quedan parciales y P-11 pasa en los dos análisis documentados. Se eliminan solo las copias de cookies QA, sin alterar Brave; no se guarda ningún item de Llavero. D-45/D-49–D-51 siguen sin ejecución por panel inaccesible. No modifica producto ni convierte estas pruebas Debug en aceptación completa de Release; las evidencias históricas del cierre anterior se conservan.

La aceptación manual anterior conserva sus resultados en:

- `Docs/Historico/Pruebas/TEST_RESULTS_0.20.7.0.md`
- `Docs/Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005.md`
- `Docs/Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005_AUDIO_VIDEO.md`
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.7.0.md`
- `Docs/Historico/Entregas/DELIVERY_0.20.7.0.md`

Esos archivos distinguen regresiones automáticas, integración con motores reales, builds, firma local y aceptación manual. Los informes anteriores conservan su evidencia, sin interpretarse como pruebas recién repetidas después de cambios posteriores.

## Comandos base

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
```

`run_tests.sh` ejecuta:

```bash
swift test
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

## Capas de validación

### SwiftPM

Cubre Core, Storage, Operations, Engines y targets de módulos. Debe validar modelos, planificadores, políticas, persistencia, seguridad y regresiones que puedan probarse sin la app completa.

### Tests Python

Protegen scripts, arquitectura, integración, build, documentación, políticas de motores y regresiones que necesitan inspeccionar código/recursos o ejecutar harnesses auxiliares.

### Verificadores

`Scripts/verify/` comprueba, entre otros, manifests, estructura, documentación, políticas de motores, módulos y coherencia con el proyecto Xcode. La documentación vigente debe fallar verificación si deja un módulo built-in sin documento funcional o conserva referencias estructurales inválidas.

### Xcode/macOS

La validación final de SwiftUI/AppKit, firma, Hardened Runtime, ARM64 y `.app` empaquetada requiere macOS Apple Silicon. SwiftPM en Linux es útil como validación portable, pero no sustituye esta capa.

## QA manual

Cuando un cambio toca UI o flujo funcional, además de tests automáticos se revisan los escenarios afectados: abrir/cerrar, errores, cancelación, estados vacíos, reintentos, navegación, persistencia, conflictos y accesibilidad/ayuda contextual según corresponda.

No debe afirmarse que una prueba manual se realizó si solo se revisó código o se ejecutó un test estructural.

## Seguridad en pruebas

- Preferir fixtures sintéticos/anonimizados.
- Originales reales del usuario solo se usan temporalmente con autorización y no se incorporan a tests, docs, logs ni entregas.
- Tests destructivos deben usar temporales controlados o mecanismos inyectables.
- Bookmarks, Papelera, Spotlight, AppKit y otros servicios del sistema pueden tener limitaciones ambientales; distinguir `skip`/entorno de un fallo de lógica.

## Release

Antes de considerar una entrega validada, ejecutar el máximo posible del flujo oficial. Si Xcode, firma, motores ARM64 o lanzamiento real no pueden comprobarse en el entorno actual, declararlo expresamente y mantener esa comprobación como pendiente de plataforma, no eliminarla del proceso.

## Aceptación de utilidades rápidas — registro retirado

> Retirado del código el 23/10/2026 por decisión del usuario. Este apartado conserva el diseño y los límites del intento, no describe funciones actuales ni QA pendiente. Véase el [registro de retirada](../Historico/Implementacion/QUICK_UTILITIES_RETIREMENT_20261023.md).

Los tests de `ZEUVEQuickUtilitiesTests` cubren estados idempotentes, almacenamiento inválido, permisos denegados/revocados, atajos, transformaciones de rueda, pares de botones, rutas/ganancia de audio, geometría/identidades de ventanas y publicación/texto/referencias. Los backends inyectados pertenecen a tests; la app utiliza servicios nativos reales.

QA física necesaria: cerrar/reabrir/salir, arranque de sesión autorizado, permisos reales, repetición de activaciones y reset, G305/receptor USB y trackpad, filtros de terceros, ventanas en Spaces/fullscreen y pantallas externas, Servicios en Finder/apps de texto y niveles reales de audio antes/durante/después de llamada. No dar por validada la protección hasta reproducir la atenuación y medir una ruta eficaz. No acceder a datos personales adicionales para forzar una prueba.

Matriz obligatoria: macOS 14.0–14.1, 14.2+, 15, 26 y 27 cuando exista entorno. Registrar por separado disponibilidad API estimada, compilación y ensayo real; el mezclador no se activa en 14.0–14.1. Presupuestos y mediciones CPU/RSS/latencia deben proceder de la app real, con todas desactivadas y combinaciones activas. Conservar pendientes cuando falten hardware, autorización o reproducción.
