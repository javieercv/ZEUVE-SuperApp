# Resultados de pruebas — ZEUVE 0.12.3

Fecha: 2026-09-03  
Build: 45

## Cobertura añadida

La entrega añade regresiones para perfiles originales por plataforma, migración selectiva del antiguo YouTube MP3 320, conservación de perfiles personalizados, desactivación persistente del flag legacy de navegador, ausencia de `.browser` en el routing y limpieza segura mediante `Scripts/clean_project.py`.

También se amplía `Scripts/verify_project.sh` para comprobar arranque idempotente, carga del historial fuera de `MainActor`, versión 0.12.3/45, Descargador 0.7.3, User-Agent sin literales antiguos, opción de navegador no visible y compilación de los scripts Python nuevos.

## Resultado en el entorno actual

`./Scripts/run_tests.sh` finaliza correctamente:

- 203 pruebas XCTest ejecutadas.
- 1 prueba omitida exclusivamente porque el diagnóstico ejecutable de yt-dlp requiere macOS Apple Silicon.
- 0 fallos XCTest.
- 45 pruebas Swift Testing completadas, 0 fallos.
- 60 pruebas Python de `Tests/ScriptTests`, 0 fallos.

La parte portable/estática de `Scripts/verify_project.sh` también se comprobó correctamente: validaciones de regresión, documentación, JSON, parseo de los Swift de `ZEUVEApp`, scripts Python y regeneración de `ZEUVE.xcodeproj` finalizaron sin errores. La propia verificación omitió correctamente las comprobaciones de motores/Xcode que exigen macOS Apple Silicon.

## Compilación Release

Se intentó `swift build -c release` en este entorno Linux en dos ocasiones. En ambas el proceso continuó compilando targets en configuración Release sin mostrar errores de compilación antes de alcanzar el límite de tiempo disponible, por lo que **no se considera una compilación Release finalizada ni validada**.

No se ha podido ejecutar `./Scripts/build_macos.sh Release`, ni validar Xcode, firma, Hardened Runtime o ejecución física de los motores empaquetados, porque el entorno actual no es macOS Apple Silicon y no dispone de Xcode ni de la configuración de distribución necesaria.

## Estado

Las suites portables y las comprobaciones estáticas disponibles quedan validadas sin fallos. La validación final de plataforma debe completarse en macOS Apple Silicon antes de una distribución firmada.

## Actualización — restablecimiento global de ajustes (2026-09-07)

Se añaden regresiones para:

- eliminación conjunta del bookmark actual y legacy del Descargador;
- eliminación del bookmark recordado del Conversor;
- presencia de confirmación y bloqueo durante operaciones para el restablecimiento global;
- coordinación de tema, Organizador, Descargador, Analizador y Conversor sin borrar historial;
- conservación explícita de presets/preajustes, favoritas y perfiles personalizados;
- eliminación de la sesión recordada de Instagram y de las carpetas de salida persistidas.

Resultado actualizado de `./Scripts/run_tests.sh`:

- 204 pruebas XCTest ejecutadas, 0 fallos y 1 omitida por requerir macOS Apple Silicon;
- 46 pruebas Swift Testing, 0 fallos;
- 64 pruebas Python, 0 fallos.

Los archivos Swift modificados de `ZEUVEApp` se validaron adicionalmente con `swiftc -frontend -parse`. Las comprobaciones posteriores al `swift build -c release` de `verify_project.sh` se ejecutaron por separado y finalizaron correctamente, incluida la regeneración de `ZEUVE.xcodeproj` con 34 archivos Swift de aplicación.

La compilación `swift build -c release` se intentó repetidamente en Linux, tanto con 1 como con 4 trabajos y con una ventana de ejecución ampliada. El proceso avanzó por los targets sin mostrar errores pero no terminó antes del límite del entorno, por lo que no se declara completada. Xcode, firma, Hardened Runtime, apertura real de la interfaz y validación de motores empaquetados siguen requiriendo macOS Apple Silicon.
## Actualización — saneamiento interno de mantenibilidad (2026-09-07)

Después de reorganizar manifiestos, claves, ayuda y categorías de log se obtuvieron los siguientes resultados portables:

- 204 pruebas XCTest: 0 fallos y 1 omitida porque el diagnóstico ejecutable de yt-dlp requiere macOS Apple Silicon.
- 46 pruebas Swift Testing: 0 fallos en la ejecución de verificación. Una ejecución previa mostró de forma aislada un fallo de la prueba de ZIP cifrado; al repetirla sola y dentro de `verify_project.sh` pasó correctamente, sin relación con los archivos modificados.
- 64 pruebas Python de `Tests/ScriptTests`: 0 fallos.
- Los 133 temas trasladados desde `ContextualHelp.swift` se compararon contra el ZIP de entrada y no presentan cambios de contenido; todos los Swift de `ZEUVEApp` pasan `swiftc -frontend -parse`.
- El proyecto Xcode se regeneró con 39 archivos Swift de aplicación.

`swift build -c release` y, por extensión, la ejecución completa de `verify_project.sh`, no terminan dentro del límite de ejecución de este contenedor Linux. La compilación avanzó por `ZEUVECore`, almacenamiento, operaciones, motores y módulos grandes sin mostrar errores antes del corte. Las comprobaciones estáticas posteriores se ejecutaron separadamente. La compilación Xcode, firma, apertura real y validación de motores empaquetados continúan requiriendo macOS Apple Silicon.


## Actualización — Fase 2 de mantenibilidad (2026-09-07)

Se añaden tres XCTest en `FolderBookmarkAndHistoryPolicyTests` para validar el round-trip del codec común de carpetas, el éxito silencioso del historial y la conversión de un fallo de persistencia en un aviso saneado que no propaga el error original.

Resultado de `./Scripts/run_tests.sh` tras la Fase 2:

- 207 pruebas XCTest: 0 fallos y 1 omitida porque el diagnóstico ejecutable de yt-dlp requiere macOS Apple Silicon.
- 46 pruebas Swift Testing: 0 fallos.
- 64 pruebas Python de `Tests/ScriptTests`: 0 fallos.
- Todos los Swift de `Sources/ZEUVEApp` pasan `swiftc -frontend -parse`.
- `ZEUVE.xcodeproj` se regenera correctamente con 39 archivos Swift de aplicación.

`verify_project.sh` alcanza y supera las suites funcionales, pero vuelve a agotar la ventana del contenedor durante `swift build -c release`. La compilación Release también se ejecutó de forma aislada con una ventana mayor: avanzó por Core, Storage, Operations, Organizer, Engines, Instagram Followers, Chat Analyzer y Universal Converter sin mostrar errores antes del corte, pero no terminó y por tanto no se declara validada. La compilación Xcode, firma, Hardened Runtime y apertura real siguen requiriendo macOS Apple Silicon.
## Actualización — Fase 3 de mantenibilidad (2026-09-07)

Se añaden cinco pruebas Python en `test_builtin_module_catalog.py` para proteger el catálogo único, el consumo desde registro/navegación/Dashboard/comandos, la inyección localizada de ViewModels, la integración de Ajustes e historial y la conservación de los órdenes/atajos actuales. La regresión existente del Comparador de Instagram se adapta para verificar el catálogo en vez de exigir su ID literal en las pantallas.

Resultados portables tras la Fase 3:

- 207 pruebas XCTest: 0 fallos y 1 omitida porque el diagnóstico ejecutable de yt-dlp requiere macOS Apple Silicon.
- 46 pruebas Swift Testing: 0 fallos.
- 69 pruebas Python de `Tests/ScriptTests`: 0 fallos.
- Los 42 Swift de `Sources/ZEUVEApp` pasan `swiftc -frontend -parse`.
- `Scripts/generate_xcode_project.py` regenera `ZEUVE.xcodeproj` incluyendo los tres Swift nuevos de `BuiltInModules`.

`verify_project.sh` supera las suites funcionales y comienza la compilación Release sin mostrar errores, pero el contenedor Linux vuelve a agotar su ventana durante la compilación de los módulos grandes. `swift build -c release --jobs 1` se repitió de forma aislada y avanzó por Core, Storage, Operations, Organizer, Instagram Followers, Chat Analyzer y Engines sin error antes del corte; no se declara completada. La compilación Xcode, firma, apertura real y validación visual de la nueva navegación siguen correspondiendo al Mac Apple Silicon.


## Actualización — Fase 4 de mantenibilidad (2026-09-07)

La reorganización se valida con regresiones existentes y cinco pruebas estructurales nuevas en `test_phase4_source_organization.py`. Estas comprueban que los resultados del Analizador se mantienen separados por sección, el monolito de modelos del Conversor no reaparece, `ChatAnalytics` conserva un namespace ligero con implementación por dominio, el soporte FFmpeg permanece fuera del coordinador y la tarjeta de ajustes del Descargador sigue conectada sin crear una superficie funcional nueva.

La equivalencia de los bloques trasladados se comprobó contra la carpeta de Fase 3: los modelos del Conversor, analytics del Analizador y helpers FFmpeg conservan el mismo código lógico salvo los cambios mínimos de visibilidad necesarios entre archivos; los bloques de resultados conservan la misma lógica y todas las cadenas Swift del `UniversalDownloaderView` original siguen presentes en la composición nueva.

Resultados portables tras la Fase 4: 207 XCTest con 0 fallos y 1 omitida por requerir macOS Apple Silicon; 46 pruebas Swift Testing con 0 fallos. 74 pruebas Python de `Tests/ScriptTests`: 0 fallos, incluidas las cinco regresiones estructurales nuevas de esta fase. Todos los Swift de `Sources/ZEUVEApp` pasan `swiftc -frontend -parse` y `Scripts/generate_xcode_project.py` regenera el proyecto incluyendo las nuevas fuentes.

`verify_project.sh` supera las suites funcionales y las comprobaciones previas a Release. La compilación `swift build -c release` del contenedor Linux avanza por los targets sin error visible pero vuelve a exceder su ventana de ejecución; no se declara completada. Xcode, firma, apertura y validación real de SwiftUI siguen correspondiendo a macOS Apple Silicon.
## Actualización — Fase 5 de mantenibilidad (2026-09-07)

La migración del verificador se comprobó contra la Fase 4: los 23 bloques Python que antes estaban embebidos en `verify_project.sh` aparecen íntegros en los nuevos verificadores por dominio. `Sources/`, `Package.swift` y el contenido de `ZEUVE.xcodeproj/project.pbxproj` permanecen idénticos a la Fase 4 después de regenerar el proyecto.

Resultados portables: 207 XCTest con 0 fallos y 1 omitida por requerir macOS Apple Silicon; 46 pruebas Swift Testing con 0 fallos; 79 pruebas Python de `Tests/ScriptTests` con 0 fallos. Las cinco nuevas regresiones verifican la arquitectura del propio sistema de QA y la detección de un producto SwiftPM ausente del generador Xcode. Los 54 Swift de `Sources/ZEUVEApp` pasan el parseo sintáctico automático y la coherencia SwiftPM/generador/`.pbxproj` confirma 9 productos enlazados.

`swift build -c release --jobs 1` se intentó con una ventana ampliada y avanzó por Core, Storage, Operations, Organizer, Engines e Instagram Followers sin mostrar errores, pero no terminó antes del límite del contenedor Linux; no se declara completado. `Scripts/verify_app_macos.sh` informa correctamente que la validación real de la aplicación se omite fuera de macOS Apple Silicon. La compilación Xcode ARM64, firma, apertura y ejecución real siguen pendientes de la validación del usuario en Mac.

