# Pruebas y validación — ZEUVE 0.20.5.0

## Evidencia de la entrega actual

La evidencia histórica específica está en:

- `Docs/Historico/Pruebas/TEST_RESULTS_0.20.5.0.md`
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.5.0.md`
- `Docs/Historico/Entregas/DELIVERY_0.20.5.0.md`

Esos archivos reflejan la ejecución realizada para esa entrega y no deben interpretarse como una prueba recién repetida después de cambios posteriores.

Para 0.20.5.0 constan 34 pruebas dirigidas del Limpiador y 5 regresiones específicas del preflight estructural. La evidencia de entrega registra por separado SwiftPM, tests, parseo, builds reales Debug/Release y verificación de la app. La rama portable de Spotlight queda cubierta por el mismo test contractual, aunque su ejecución no puede observarse en macOS.

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
