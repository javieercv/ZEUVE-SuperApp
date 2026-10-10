# Pruebas y validación — ZEUVE 0.20.7.0

La evidencia técnica de los parciales corregidos está en [TEST_RESULTS_0.20.7.0.md](../Historico/Pruebas/TEST_RESULTS_0.20.7.0.md). Los nueve IDs locales pasan su [aceptación desde UI](../Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005.md); las pruebas de servicio complementan ese recorrido. La [revalidación manual de 04/10/2026](../Historico/Pruebas/MANUAL_QA_0.20.6.0_20261004.md) conserva los 22 IDs comprobados en la entrega anterior. El [cierre de I-29/I-35](../Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005_AUDIO_VIDEO.md) mide la salida de audio capturada y los frames presentados, incluidos mute/ganancia, salto/reanudación y cambio de pista. La checklist acumulada al 10/10/2026 (`Cheklist Manual de aceptacion de ZEUVE.md`, en la raíz) registra 611 OK, 6 fallidas, 7 parciales y 15 pendientes: 624 pruebas ejecutadas, incluidas las parciales. Todo estado sin OK restante pertenece al Descargador o a su autenticación remota, incluidos P-11/P-12.

## Evidencia de la entrega actual

La [QA exploratoria remota del Descargador del 09/10/2026](../Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261009.md) utiliza enlaces aportados por el usuario y datos aislados en Debug. Registra fallos de tipo, duplicación y presentación, además de cancelación y continuidad. Por instrucción posterior del usuario, sus resultados se incorporan a la checklist: la casilla indica ejecución y el símbolo distingue correcta, fallida o parcial. La [continuación del 10/10/2026](../Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010.md) cierra tres requisitos, prueba las combinaciones de carpetas con descargas reales y ejecuta de nuevo `run_tests.sh` sin fallos. La descarga completa de la repetición queda parcial tras cancelación controlada y bloqueo de sesión macOS. No modifica producto ni convierte estas pruebas Debug en aceptación completa de Release; las evidencias históricas del cierre anterior se conservan.

La entrega actual conserva sus resultados en:

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
