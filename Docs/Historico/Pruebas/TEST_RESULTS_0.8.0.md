# Resultados de pruebas — ZEUVE 0.8.0

## Entorno disponible

- Linux x86_64.
- Swift 6.2.1.
- libarchive y SQLite del sistema.
- Sin Xcode, AppKit ejecutable ni Mac Apple Silicon disponibles en este entorno.

## Pruebas específicas del módulo

Se ejecutaron 21 pruebas XCTest específicas del módulo y todas finalizaron correctamente.

Cobertura:

- prioridad `value` sobre `href` y `title`;
- URLs directas y rutas `/_u/`;
- fallback `title` y `media_list_data`;
- valores inválidos y URL completas ignoradas;
- archivos vacíos válidos;
- distinción entre JSON malformado e incompatible;
- normalización sin distinguir mayúsculas;
- conservación de puntos y guiones bajos;
- deduplicación entre varios archivos;
- ZIP con carpeta raíz arbitraria;
- varios `followers_*.json`, orden numérico y huecos;
- rechazo de múltiples `following.json` y ausencia de seguidores;
- catálogo avanzado y secuencias duplicadas;
- análisis completo con varios archivos;
- exportación CSV y rechazo de sobrescritura silenciosa;
- historial sin nombres privados y actualización del indicador de exportación;
- manifiesto offline;
- volumen sintético de 40.000 seguidos y 35.000 seguidores únicos;
- cancelación sin devolver listas parciales.

El caso de volumen finalizó entre 2,21 y 2,83 segundos en distintas ejecuciones del entorno Linux utilizado. Este dato sirve como referencia lógica y no sustituye una medición en el Mac objetivo.

## Verificaciones del proyecto

Resultados completados en Linux x86_64:

- `swift test --jobs 1`: 128 pruebas XCTest y 45 pruebas Swift Testing, sin fallos.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: 26 pruebas, sin fallos.
- análisis sintáctico `swiftc -frontend -parse` de las vistas SwiftUI: correcto.
- regeneración de `ZEUVE.xcodeproj`: correcta para 0.8.0, build 27.
- `swift build -c release --jobs 1`: completado correctamente en 52,19 segundos en la ejecución final.
- `Scripts/verify_project.sh`: completado correctamente; la fase Xcode/macOS se omitió de forma explícita por no ejecutarse en Apple Silicon.

## Validación macOS pendiente

No se puede afirmar todavía que la interfaz nativa funciona visualmente porque este entorno no dispone de Xcode ni AppKit ejecutable. Debe comprobarse en un Mac Apple Silicon:

- compilación Debug y Release;
- apertura del módulo desde sidebar, dashboard y comando de teclado;
- paneles de selección y guardado;
- arrastrar y soltar ZIP y JSON;
- sustitución confirmada de un archivo exportado existente;
- apertura manual de un perfil;
- modos claro y oscuro;
- VoiceOver y tamaños de ventana;
- cancelación con exportaciones grandes;
- fluidez de búsqueda y lista con volúmenes representativos.

## Validación del ZIP de entrega

Después del empaquetado se comprobó una copia extraída en un directorio limpio:

- `unzip -t`: archivo íntegro, sin errores de compresión;
- raíz única `ZEUVE_Swift_0.8.0`;
- ausencia de `.build`, `.swiftpm`, `.git`, DerivedData, `xcuserdata`, `__MACOSX`, `.DS_Store`, `._*`, logs y cachés;
- presencia del módulo, vistas, pruebas, manifiesto, proyecto Xcode y documentación;
- `swift build --target InstagramFollowersModule --jobs 1`: correcto en 2,08 segundos;
- 21 pruebas específicas ejecutadas desde la copia extraída: todas correctas.
