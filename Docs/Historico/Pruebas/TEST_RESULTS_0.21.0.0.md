# Pruebas — ZEUVE 0.21.0.0

**Integración verificada; QA física y protección durante FaceTime pendientes.** 12/10/2026. Versión visible única 0.21.0.0, metadata Apple 0.21.0/revisión 0, build 79. Base remota `744b1bf01e650ef34bf568c708e70cc8eeaeab03`.

## Verificaciones oficiales ejecutadas

Entorno: macOS 26.6.2 ARM64, Xcode/SDK macOS 27. El SDK no acredita ejecución en macOS 27.

- `./Scripts/run_tests.sh`: exit 0 en el pase final; **565 tests Swift** (362 XCTest + 203 Swift Testing) y **134 Python**, sin fallos finales. Incluye los siete módulos, Core, Storage, Operations, Engines y **78 tests de utilidades rápidas**.
- `./Scripts/verify_project.sh`: exit 0; tests, Release SwiftPM, verificadores de arquitectura/motores/documentación/rendimiento/módulos, Python, manifests, parseo y coherencia SwiftPM/Xcode, más build Debug nativo en `build/VerificationDerivedData`.
- `./Scripts/build_macos.sh Debug` y `Release`: exit 0. La app final Release es ARM64, versión 0.21.0.0/build 79; motores y `codesign --verify --deep --strict` pasan. Se comprobó Hardened Runtime en la firma efectiva y Audio Input habilitado, sin App Sandbox.
- Firma ad hoc: el entorno tiene cero identidades de firma válidas. No se afirma Developer ID, notarización ni instalación definitiva.
- `git diff --check` pasa. No se ejecutó QA online nueva del Descargador ni se generó ZIP.

Los 78 tests nuevos cubren Audio 30 (17 mezclador + 13 diagnóstico/leases), Input 17, Windows 11, coordinación 8 y Productividad 12. Incluyen cancelación/cleanup, configuración incompatible, ownership compartido, reset/paradas/cierre concurrentes, conservación de plantillas/perfiles, ganancia/rampas/RMS, eventos inválidos y pares de botones, geometrías/topologías, identidades ambiguas, Unicode, referencias desaparecidas, publicación exclusiva, sustitución adversaria del temporal y cancelación sin residuos.

## QA nativa ejecutada

Almacenamiento y archivos sintéticos aislados mediante `ZEUVE_DATA_DIR`; no se persistieron títulos privados, texto del usuario, PCM ni pulsaciones. CUA confundió inicialmente copias de ZEUVE; los resultados siguientes se comprobaron sobre Release y, cuando fue necesario, System Events dirigido al PID exacto.

| Función | Evidencia real | Límite pendiente |
| --- | --- | --- |
| Residente/Ajustes | Apertura, catálogo nueve utilidades, estados y cierre/reinicio; parada global deja preferencias enabled=[]; ajustes recuperables | Inicio real de sesión sin ventana, memoria sin AppModel y barra de menús física no certificados |
| Mezclador | Descubre QuickTime reproduciendo tono estéreo propio; crea ruta real, silencio, nivel intermedio y desactivación sin error | Sin medición acústica, latencia, AirPods, desconexión/suspensión o crash real |
| Protección de llamadas | Diagnóstico integrado y estados reales revisados; 13 tests de ruta/leases/RMS | No ejecutado durante FaceTime; usuario indica que lo probará después. Protección no completada ni descartada |
| Rueda/botones | Denegación efectiva y parada verificadas; macOS muestra Accesibilidad concedida tras autenticación del usuario | La app sigue recibiendo falta de confianza efectiva, incluso tras reañadir la app/reiniciar. No se declara event tap activo ni QA G305/trackpad |
| Selector/distribuciones | Integración y tests AX mediante backends/modelos | QA AX real, Spaces, pantallas externas y asociaciones físicas pendientes por el permiso efectivo |
| Crear archivos | Panel nativo crea archivo vacío en carpeta explícita; original intacto | Finder registra el Servicio y abre panel con carpeta seleccionada correcta; publicación final desde esa invocación no confirmada, se conserva como prueba parcial |
| Bandeja | Panel real, picker añade original.txt como referencia, retirar referencia conserva archivo; parada cierra panel | Arrastre real hacia otro destino y reinicio con referencias pendientes de QA |
| Texto | Servicio real de TextEdit transforma selección sintética áéñ a ÁÉÑ y líneas a mayúsculas, resultado guardado y comprobado | Otros hosts, campos protegidos y selección enriquecida no certificados |

Accesibilidad: consentimiento visible no equivale a `AXIsProcessTrusted()` efectivo. La discrepancia de TCC se conserva como limitación de esta compilación; las copias previas/firma ad hoc son hipótesis, no causa demostrada. No se editaron bases TCC ni se eludieron controles del sistema.

## Rendimiento

Release, AppModel ya iniciado, ventanas abiertas y nueve utilidades desactivadas (preferencia vacía comprobada): **15,18 s**, CPU acumulada equivalente a **0,07 % de un núcleo**, RSS **166,67 MiB**. Es una muestra corta de un equipo; no prueba consumo del residente sin módulos ni latencias. El escenario de audio simultáneo, selector y ratón requiere medición adicional.

## Incidencias y correcciones

Se corrigieron en código nuevo: botones de creación que no reaccionaban a estado, ventana Ajustes que colapsaba de tamaño, actualización de alerta de errores, publicación por descriptor propio y limpieza por identidad, tareas/dialogos/callbacks al detener, leases de audio independientes, propiedad/cancelación del refresh, barreras de stop/reset/shutdown y errores separados de almacenamiento.

Se actualizaron verificadores estructurales para comprobar la integración dinámica a través de ResidentRuntime, conservando las guardas de navegación, coordinación, siete módulos y reset. En un pase concurrente con compilaciones, la prueba preexistente `pausedVideoSeekPublishesNewFrameAndRapidReplacementLeavesNoBusyRunner` observó 42,033333 s frente a 42 s. La repetición completa sin esa carga pasó; no se modificó el Inspector ni se relajó la prueba. Permanecen advertencias preexistentes de concurrencia Vision en OCR.

## Matriz de plataformas

14.0–14.1: APIs base estimadas, Process Taps no disponibles. 14.2+/15: compatibilidad API estimada dentro de los límites publicados, sin runtime probado aquí. 26: sólo evidencia de esta tabla. 27: SDK utilizado, runtime no probado.

## Corrección de arranque desde Xcode — 12/10/2026

Base remota sincronizada `7952ccfa9a0acaccdde42a1b6cd9acc12c9f56ef`. La comprobación Debug inicial cubrió compilación y firma, pero no Run desde Xcode. Tras el aviso del usuario se reprodujo un SIGABRT de dyld antes de ejecutar código de la app: `ZEUVE.debug.dylib` era rechazada por discrepancia de Team ID con firma ad hoc y Hardened Runtime.

El generador y el proyecto fijan `ENABLE_DEBUG_DYLIB = NO` sólo para el target de app Debug. La app conserva Hardened Runtime y validación de bibliotecas; no se modifican entitlements ni lógica Swift. El script oficial incorpora una comprobación de dependencias del ejecutable Debug.

- `./Scripts/build_macos.sh Debug`: exit 0, motores y firma estricta verificados; nueva comprobación de ausencia de la biblioteca auxiliar superada.
- Suite Python: 134 tests, sin fallos. Coherencia Xcode: 12 productos coherentes.
- Run real con el botón de Xcode: proceso en ejecución bajo LLDB y ventana Inicio visible con los siete módulos. El ejecutable de DerivedData de Xcode no depende de `ZEUVE.debug.dylib`; firma efectiva ad hoc con Hardened Runtime.

Esta corrección cierra el fallo de arranque comunicado; las limitaciones de QA física, TCC y FaceTime anteriores siguen pendientes.
