# Retirada de microutilidades — 23/10/2026

## Decisión y base

El usuario descarta la familia completa y aprueba el plan técnico de retirada. Se conserva la documentación y el histórico del intento, sin reescribir las evidencias previas. Base sincronizada: `5b9f1f9b07cc4ca2e9245ef61144429fa1c2e09f`, rama `main`, sin cambios locales previos.

La versión visible sigue siendo ZEUVE 0.21.0.0, metadata Apple 0.21.0/revisión 0 y build 79. Este trabajo retira un intento no aceptado y mantiene el repositorio; no prepara una nueva entrega versionada o ZIP.

## Cambios

- Eliminadas `Sources/ZEUVEQuickUtilities`, `Sources/ZEUVEApp/QuickUtilities` y `Tests/ZEUVEQuickUtilitiesTests`: audio, entrada, ventanas, productividad, estados/coordinación, atajos globales y runtime residente.
- `ZEUVEApp.swift`, `AppModel.swift` y `SettingsView.swift` recuperan la composición de ventanas, almacenamiento, operaciones y Ajustes anterior a la integración. Se mantienen las guardas de cancelación y retirada del observador, y se evita duplicar la tarea de terminación.
- Eliminados el target/producto y las referencias de SwiftPM, generador/proyecto Xcode, pruebas estructurales y verificadores. Once bibliotecas enlazadas: cuatro capas compartidas y siete módulos.
- Retirados `NSServices`, `NSAudioCaptureUsageDescription` y `Resources/ZEUVE.entitlements` con su referencia de firma. El verificador de firma admite ausencia de entitlements; conserva Hardened Runtime, rechazo de App Sandbox y validación del arranque Debug sin dylib auxiliar.
- La documentación funcional del intento permanece en `Docs/Utilidades/QUICK_UTILITIES.md`, marcada como retirada. README, índice, decisiones, contexto y fundamentos distinguen estado actual y registro anterior. Los documentos históricos existentes no se modifican.

No se reabre el Descargador ni se modifica el código de los siete módulos. No hay dependencias, endpoints o servicios externos nuevos. No se borran preferencias ni archivos personales. Las claves antiguas carecen de consumidores; no se añaden migraciones ni se manipulan registros de inicio con macOS/TCC del usuario.

## Verificación

- `./Scripts/run_tests.sh`: 487 pruebas Swift (284 XCTest y 203 Swift Testing) y 134 pruebas Python, todas correctas: 621 en total. Se retiran las 107 pruebas exclusivas de la familia eliminada; no se debilitan las pruebas de los módulos.
- `git diff --check`: correcto. Búsqueda en fuentes, tests, scripts, SwiftPM y proyecto/plist sin referencias de las microutilidades.
- Coherencia SwiftPM/Xcode: once bibliotecas y 80 archivos Swift de app.
- Ningún documento histórico existente modificado; nuevo informe de retirada independiente.

- `./Scripts/verify_project.sh`: correcto, incluidos tests, build SwiftPM Release, verificadores de dominio/documentación/manifests, sintaxis, generación Xcode y build nativo Debug.
- `./Scripts/build_macos.sh Debug`: correcto, con motores empaquetados, firmas verificadas y Hardened Runtime efectivo. Debug sigue sin biblioteca auxiliar `ZEUVE.debug.dylib`.
- Entorno: macOS 26.6.2 Apple Silicon, Xcode 27.0 (27A266a).

## QA nativa

Sobre la app Debug construida por el verificador, con `ZEUVE_DATA_DIR` temporal aislado:

- Arranque real en Inicio, siete módulos presentes y sin alerta de inicio.
- Ajustes desde la barra lateral: General y seis secciones de módulo; no aparece Utilidades rápidas.
- Cambio de tema a Oscuro y apertura de Ajustes con ⌘,: el valor se comparte entre ambas vistas.
- Apertura de Ajustes del Organizador y visualización de sus opciones conservadas.
- ⌘8 abre Historial vacío; ⌘1 abre Organizador. Menú ZEUVE conserva siete accesos de módulos e Historial, sin controles de utilidades.
- Cierre de la última ventana: cero ventanas; reapertura nativa: Organizador vuelve a mostrarse. Salir con ⌘Q termina el proceso; log de app vacío.
- El controlador de UI nativo perdió su conexión durante el recorrido. Se completan las comprobaciones mediante AppleScript/System Events con la autorización permanente del proyecto. No se amplía el alcance a aplicaciones o datos personales.

## Release y cierre

- `./Scripts/build_macos.sh Release`: correcto, con validación de motores empaquetados y firmas. Hardened Runtime efectivo, sin App Sandbox.
- Inspección del bundle Release: sin `NSServices`, `NSAudioCaptureUsageDescription` o autorización Audio Input. Símbolos exclusivos de utilidades/runtime ausentes del ejecutable.
- Lanzamiento real de Release con el mismo almacenamiento QA aislado: Inicio y Ajustes correctos, tema Oscuro conservado tras reiniciar y sin sección de utilidades. Salir termina el proceso; log vacío. El control nativo volvió a estar disponible para esta comprobación final.
- Búsqueda sobre archivos versionados no documentales: cero referencias a la familia retirada. 38 archivos exclusivos eliminados. Diff limitado a esa retirada, su integración y documentación.
- Datos de QA aislados retirados después de comprobar el cierre; no se accedió a originales, preferencias o historial personales.

No se han repetido pruebas funcionales exhaustivas de los siete módulos ni QA remota del Descargador; no se modificó su código. Las builds muestran advertencias de concurrencia de Vision en OCR del Inspector, en código preexistente ajeno a esta retirada, sin errores de compilación. No se modifica ese alcance.

La carpeta activa es la única copia mantenida. No se crea ZIP. La publicación y verificación del commit remoto se realizan al cerrar la tarea conforme a `REPOSITORY_WORKFLOW.md`.
