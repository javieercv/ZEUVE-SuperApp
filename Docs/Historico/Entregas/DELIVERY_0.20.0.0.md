# Entrega — ZEUVE 0.20.0.0

## Contenido

- personalización compartida del orden de módulos y atajos, incluida la personalización de Historial;
- valores de fábrica Organizador `⌘1`, Descargador `⌘2`, Analizador `⌘3`, Conversor `⌘4`, Comparador `⌘5`, Inspector `⌘6`, Limpiador `⌘7` e Historial `⌘8`;
- Limpiador 0.1.0 integrado como séptimo módulo built-in;
- análisis de apps, residuos, limpieza y espacio mediante un pipeline compartido;
- inventario histórico y migración SQLite schema 3;
- Papelera predeterminada, borrado permanente opt-in, revalidación y Undo verificable;
- settings centralizados, tests y verificador específico;
- documentación de privacidad/archivos y actualización de reglas vigentes;
- proyecto Xcode regenerado con marketing 0.20.0 y build 66.

## Garantías de alcance y seguridad

No se introducen red, telemetría, dependencias externas, motores, helper root, `sudo` ni shell en el Limpiador. Poder analizar una ubicación no autoriza a eliminarla: toda retirada pasa por candidato/plan visible, selección explícita, revalidación y resultado por elemento. Los datos persistentes, App Groups compartidos, elementos inciertos, rutas que requieren administrador y componentes protegidos no se autoseleccionan.

## Validación disponible

`BuildProject` desde Xcode compila correctamente esta copia tras corregir errores de concurrencia Swift 6 del Limpiador y dos fallos de integración/sintaxis de la app. En esta sesión, `swift test --disable-sandbox --jobs 1` pasa con un skip ambiental de `ScopedBookmarksAgent`, y los tests Python estructurales pasan 108/108. `run_tests.sh` y `verify_project.sh` pasan completos en el entorno portable histórico (RC=0). Tanto `CleanerModule` como el paquete SwiftPM completo compilan en Release (`swift build -c release --jobs 1`, RC=0). Las comprobaciones estructurales, documentales, manifests, integración, coherencia SwiftPM/Xcode y parseo de la UI pasan. `verify_app_macos.sh` omite correctamente la QA funcional real fuera de macOS Apple Silicon/Xcode. Véase `Docs/TEST_RESULTS_0.20.0.0.md`.

## Distribución web

La entrega incluye un ZIP limpio del proyecto completo actualizado. El ZIP excluye `.build`, `build`, DerivedData, caches, temporales, logs, `.DS_Store`, `__MACOSX` y datos locales de Xcode. La carpeta mantenida sigue siendo la misma base activa de trabajo; el ZIP es únicamente el artefacto de entrega.
