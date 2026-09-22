# Entrega ZEUVE 0.12.3

Fecha: 2026-09-03  
Build: 45

La carpeta activa contiene ZEUVE 0.12.3 con el Plan A completo integrado. Se mantiene la estructura actual `ZEUVE_Swift` y no se crea otra carpeta versionada ni un ZIP adicional.

## Estado funcional

- Descargador universal 0.7.3 con perfiles de fábrica en Original para todas las plataformas.
- Migración selectiva del antiguo YouTube MP3 320 de fábrica sin sobrescribir perfiles personalizados.
- Navegador opcional retirado temporalmente de interfaz y routing; la preferencia histórica se conserva solo para lectura compatible y queda desactivada.
- Arranque idempotente, diagnóstico inicial acumulativo e historial global fuera del actor principal.
- Errores de persistencia prioritarios visibles y errores de manifiesto coherentes.
- Versión y token HTTP propios centralizados.
- `Scripts/clean_project.py` documentado y cubierto por tests.

## Privacidad y seguridad

No se incorporan dependencias, servicios, endpoints, telemetría, actualizaciones automáticas ni lectura silenciosa de cookies. No cambia la protección de originales ni la política de temporales y publicación. Los motores existentes permanecen en `Resources/Engines` y el script de limpieza no entra en esa raíz.

## Validación

`./Scripts/run_tests.sh` finaliza sin fallos: 203 XCTest (1 omitido por requerir macOS Apple Silicon), 45 pruebas Swift Testing y 60 pruebas Python. Las verificaciones estáticas/documentales y la regeneración del proyecto Xcode también se han comprobado correctamente.

La compilación `swift build -c release` se intentó en Linux y continuó compilando sin errores visibles hasta agotar el límite de ejecución del entorno, por lo que no se marca como completada. La compilación final con `./Scripts/build_macos.sh Release`, Xcode, firma, Hardened Runtime y las pruebas reales de motores empaquetados requieren macOS Apple Silicon y quedan pendientes de esa plataforma.

## Actualización — 2026-09-07

La entrega incorpora el restablecimiento global de ajustes en Ajustes > General con confirmación previa y bloqueo durante operaciones. La acción restaura los valores de fábrica de la aplicación y de los módulos configurables sin borrar historial, presets/preajustes, favoritas, perfiles personalizados, carpetas recientes, motores ni archivos del usuario. La sesión de Instagram recordada y los bookmarks de salida persistidos sí se eliminan de forma expresa.

La versión visible se mantiene en ZEUVE 0.12.3, build 45: esta actualización se integra en la entrega vigente sin modificar motores, dependencias, arquitectura de módulos, red, permisos ni formatos.

Las suites portables actualizadas finalizan con 204 XCTest (1 omitida), 46 Swift Testing y 64 pruebas Python, todas sin fallos. La compilación Release completa no finaliza dentro del límite de ejecución del entorno Linux; la validación final en macOS Apple Silicon continúa siendo obligatoria.
## Saneamiento interno adicional — 2026-09-07

Se incorpora la Fase 1 de mantenibilidad aprobada sin cambio funcional: cargador común de manifiestos, claves del Organizador y apariencia centralizadas sin alterar sus valores, ayuda contextual repartida por dominio y categorías de log universales en el Descargador. `ZEUVE.xcodeproj` se regenera para incluir los nuevos archivos Swift.

La versión permanece en 0.12.3/build 45 porque no cambia el producto visible ni el esquema de compatibilidad. Las suites portables disponibles pasan con 204 XCTest (1 omitida), 46 Swift Testing y 64 Python. La compilación Release completa vuelve a superar la ventana de ejecución del contenedor Linux sin mostrar un error de compilación; la validación final macOS Apple Silicon permanece pendiente.
## Fase 2 de mantenibilidad — 2026-09-07

La entrega vigente incorpora infraestructura común de bookmarks/security-scope en `ZEUVECore` y una política uniforme para fallos secundarios de historial. Descargador y Conversor conservan sus stores y claves; no se modifican bookmarks existentes ni carpetas del usuario.

Si una operación termina correctamente y solo falla el historial, la interfaz mantiene el resultado como correcto y muestra «Aviso». Esta política se aplica a Organizador, Descargador, Conversor, Analizador de chats e Instagram Followers. Los logs asociados se limitan al tipo técnico del error. El Organizador no ofrece «Deshacer» cuando el registro necesario no pudo persistirse.

Se mantiene la versión 0.12.3/build 45 y no cambian motores, red, privacidad, dependencias, esquema SQLite ni comportamiento de archivos originales.
## Fase 3 de mantenibilidad — 2026-09-07

La carpeta activa incorpora el catálogo central de módulos built-in y los routers de vista/Ajustes. AppModel, navegación, Dashboard, comandos e historial dejan de mantener enumeraciones paralelas de los cinco módulos; los ViewModels concretos y la compilación por targets permanecen explícitos y fuertemente tipados.

Un módulo cuyo manifiesto no se registre correctamente conserva el aviso de arranque y deja de mostrarse como herramienta disponible en Inicio, barra lateral, Ajustes y comandos. La compatibilidad del historial antiguo de YouTube se mantiene mediante un alias del Descargador universal.

No se ha añadido personalización de orden, visibilidad o atajos. Se conservan los órdenes actuales y ⌘1–⌘6, así como motores, red, privacidad, persistencia, archivos y dependencias. La versión continúa siendo ZEUVE 0.12.3, build 45.


## Actualización — Fase 4 de mantenibilidad (2026-09-07)

La carpeta activa incorpora el saneamiento interno por responsabilidades: resultados y analytics del Analizador, modelos y soporte FFmpeg del Conversor y tarjeta de ajustes del Descargador se organizan en fuentes más pequeñas con fronteras explícitas. No se modifica la interfaz visible, opciones, persistencia, historial, motores, red, privacidad ni archivos del usuario.

Los coordinadores grandes se revisaron y no se fragmentaron cuando la separación habría exigido ampliar estado privado o dispersar tareas/cancelación. La versión sigue siendo ZEUVE 0.12.3, build 45. La entrega conserva la misma raíz `ZEUVE_Swift`; el ZIP solo se generará cuando el usuario lo solicite.
## Actualización — Fase 5 de mantenibilidad (2026-09-07)

La carpeta activa incorpora el saneamiento de QA y verificadores. `verify_project.sh` conserva su interfaz y pasa a coordinar verificadores por dominio, añade coherencia automática SwiftPM/Xcode y una validación explícita de aplicación para macOS Apple Silicon. No se ha modificado código Swift de producción, `Package.swift`, manifiestos, motores, persistencia, red, privacidad, interfaz ni comportamiento.

Las suites portables quedan en 207 XCTest (1 omitida), 46 Swift Testing y 79 Python, sin fallos. El build Release del contenedor Linux no completa dentro del límite temporal aunque no muestra errores antes del corte; la comprobación definitiva en macOS Apple Silicon sigue siendo obligatoria. La versión permanece en ZEUVE 0.12.3, build 45.

