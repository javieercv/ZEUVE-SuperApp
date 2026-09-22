# Resultados de pruebas ZEUVE 0.10.1

Fecha: 5 de agosto de 2026.  
Entorno: Linux x86_64, Swift 6.2.1 y Python 3.

## Resultados superados

- `swift test --jobs 1`: 160 pruebas XCTest, 0 fallos.
- Swift Testing del Conversor universal: 45 pruebas, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests`: 36 pruebas, 0 fallos.
- `swift build -c release --jobs 1`: compilación Swift de producción completada.
- `Scripts/verify_project.sh`: completado correctamente.
- Sintaxis Bash de `build_macos.sh` y `prepare_social_engines_macos.sh`: correcta.
- Sintaxis Python de helpers y scripts de manifiesto: correcta.

## Regresiones específicas

- perfil de Instagram seleccionado como «Página web»;
- story de Instagram seleccionada como «Página web»;
- prioridad de `gallery-dl` para contenido directo de Instagram;
- mensaje accionable cuando Instagram exige iniciar sesión;
- sesión pegada y `cookies.txt` sin exposición en logs;
- preparación automática desde `build_macos.sh`;
- bloqueo preventivo de Xcode si faltan motores;
- actualización aislada de hashes, tamaños y licencias del manifiesto social;
- conservación del resto de entradas de `engines.json`.

## Originales y privacidad

El ZIP original 0.10.0 no se modificó. Las pruebas de sesión utilizaron datos sintéticos y temporales con permisos restringidos. No se incorporaron cookies, sesiones, URLs privadas ni el JSONL real al proyecto o al ZIP final.

## Pendiente en macOS Apple Silicon

- generar `gallery-dl` e `instaloader-zeuve` ARM64 mediante el flujo aprobado;
- ejecutar `verify_engines_macos.sh` sobre esos binarios;
- compilar Debug y Release con Xcode;
- verificar firma, apertura y Gatekeeper;
- analizar y descargar una publicación, un reel, una story y un perfil autorizados;
- comprobar sesión pegada, `cookies.txt` e importación expresa desde navegador;
- verificar interfaz, progreso, cancelación y limpieza en la aplicación nativa.

Estas comprobaciones no pueden darse por superadas desde Linux.
