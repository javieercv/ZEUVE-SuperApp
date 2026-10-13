# Entrega — ZEUVE 0.21.0.0

## A. Resumen

**Desarrollo integrado y verificado; QA física y eficacia de protección pendientes.** 12/10/2026. Versión visible única de desarrollo y marketing 0.21.0.0; metadata Apple 0.21.0/revisión 0, build 79. Base remota sincronizada `744b1bf01e650ef34bf568c708e70cc8eeaeab03`, sin commits remotos nuevos al cerrar la integración. Implementación publicada y verificada en el remoto: `526cac3fdf226a228b33d50211f4419ed7bce7d2`. Sin ZIP ni carpeta versionada paralela.

## B. Funcionalidades

Sí indica código efectivo dentro del alcance y límites publicados; QA parcial no equivale a aceptación física completa.

| Funcionalidad | Implementada | Integrada | Compilada | Automática | macOS real | Permisos y límites |
| --- | --- | --- | --- | --- | --- | --- |
| Infraestructura residente | Sí | Sí | Sí | Sí | Parcial | Cierre/parada/reinicio; inicio de sesión real pendiente |
| Mezclador | Sí | Sí | Sí | Sí | Parcial | Captura audio; ruta QuickTime propia, sin medición acústica/AirPods/latencia |
| Protección de llamadas | Diagnóstico; protección pendiente | Sí | Sí | Sí | Pendiente FaceTime | Captura audio; no se declara protección eficaz |
| Dirección rueda | Sí | Sí | Sí | Sí | Permiso denegado efectivo | Accesibilidad; ruedas discretas globales, G305/trackpad pendientes |
| Botones adicionales | Sí | Sí | Sí | Sí | Pendiente | Accesibilidad; índices globales 3–31, sin identidad física |
| Selector ventanas | Sí | Sí | Sí | Sí | Pendiente AX | Accesibilidad; lista textual, límites de Spaces/AX |
| Distribuciones | Sí | Sí | Sí | Sí | Pendiente AX/pantallas | Accesibilidad; slots y reasociación explícita, sin títulos persistidos |
| Crear archivos | Sí | Sí | Sí | Sí | Panel OK; Finder parcial | Destino elegido, no sobrescribe; Servicio abre panel, publicación final no confirmada |
| Bandeja temporal | Sí | Sí | Sí | Sí | Picker/referencia/retirada OK | URLs RAM, máximo 500; drag externo pendiente |
| Acciones texto | Sí | Sí | Sí | Sí | TextEdit OK | Selección explícita texto plano; otros hosts pendientes |

## C. Arquitectura

Un proceso de app, icono residente y presencia normal en Dock. `ResidentRuntime` posee almacenamiento, coordinador, proveedores y ventanas; construye `AppModel` al abrir la principal. El catálogo de nueve servicios es independiente de los siete módulos. Solicitud y ejecución se distinguen; SettingsRepository/SQLite centraliza preferencias. Core Audio, entrada y AX comparten recursos por sus coordinadores, con tareas bajo propiedad, parada/cancelación y estados de fallo. Operaciones grandes de plantillas respetan OperationCoordinator. Atajos usan Carbon, sin monitor global de teclado.

## D. Archivos

- `Sources/ZEUVEQuickUtilities/`: contratos/catálogo/coordinador, permisos/atajos y bloques Audio, Input, Windows y Productivity.
- `Sources/ZEUVEApp/QuickUtilities/`: runtime, Ajustes/ayuda, paneles y UI de los bloques; integración localizada en ZEUVEApp, AppModel y SettingsView.
- `Package.swift`, generador y proyecto Xcode: target/producto/tests, versión/build y Hardened Runtime efectivo. Info.plist declara Servicios y descripción de captura; nuevo ZEUVE.entitlements.
- Scripts oficiales/verificadores y tests estructurales: nueva integración dinámica conservando guardas; DerivedData de verificación aislado e ignorado por Git.
- `Tests/ZEUVEQuickUtilitiesTests/`: 78 pruebas. Documentación viva, CHANGELOG, reglas/contexto de agentes e informes históricos de esta entrega.

## E. Dependencias y permisos

Sin nuevas dependencias externas, drivers, helpers root, procesos residentes adicionales ni red de estas utilidades. Frameworks públicos del sistema: SwiftUI/AppKit, Combine, CoreGraphics/ApplicationServices, Carbon/HIToolbox, ServiceManagement y Core Audio; no hay extensión Finder Sync. Audio Input en Hardened Runtime permite la ruta de reproducción; no se captura micrófono ni se pide su autorización. Accesibilidad/captura se solicitan cuando corresponden. Inicio automático opcional, desactivado por defecto.

Firma ad hoc validada; no hay identidad Developer ID válida ni notarización. TCC muestra consentimiento de Accesibilidad, pero la app todavía no obtiene confianza efectiva; no se eludió ese control. El usuario autorizó ambos permisos y aplazó la llamada de FaceTime a su prueba posterior.

## F. Rendimiento

Muestra Release de 15,18 s con AppModel ya abierto y nueve utilidades desactivadas: 0,07 % de un núcleo y RSS 166,67 MiB. No extrapolar a residente sin módulos, audio simultáneo, latencias de rueda/selector ni otros equipos.

## G. Regresiones y verificación

Las cuatro comprobaciones oficiales pasan: run_tests, verify_project, build_macos Debug y Release. Pase final: 565 Swift + 134 Python (699), incluidos 78 de utilidades. ARM64, versión/build, firma estricta, Hardened Runtime, entitlements y motores verificados. Versiones/contratos de siete módulos y seis motores requeridos conservados. Sin QA online nueva del Descargador.

Corrección posterior del arranque desde Xcode, sobre base remota `7952ccf`: desactivada la biblioteca auxiliar Debug en el target de app para evitar el rechazo de firma ad hoc, conservando Hardened Runtime. Compilación oficial Debug, 134 tests Python y Run real con Inicio visible verificados. La compilación Debug inicial no había incluido esa prueba de Run; la [evidencia de corrección](../Pruebas/TEST_RESULTS_0.21.0.0.md) registra el fallo reproducido y su resolución.

## H. Problemas y pendientes

Se corrigieron actualización del botón de creación y alerta, tamaño de Ajustes, propiedad/cancelación de tareas/callbacks, barreras de reset/parada/cierre y publicación segura por descriptor. En archivos sin clonación, creación exclusiva puede ser visible durante escritura; errores limpian sólo inode propio. Diagnóstico de llamada y mezclador tienen leases independientes y rechazan ganancias incompatibles.

Un test preexistente del Inspector falló por un fotograma en un pase bajo carga; el pase posterior completo pasó sin modificar código/criterios. Advertencias preexistentes Vision permanecen. La [evidencia detallada](../Pruebas/TEST_RESULTS_0.21.0.0.md) conserva TCC efectivo, Finder parcial, G305, pantallas, FaceTime/AirPods, suspensión/crash y matriz de sistemas como pendientes. Brillo externo, capturas flotantes, reposo avanzado y Descargador aplazado siguen fuera.

## I. Publicación

Se publica en el repositorio original, sin force-push ni sobrescrituras. Commit de implementación `526cac3fdf226a228b33d50211f4419ed7bce7d2` presente en `refs/heads/main`, comprobado con `git ls-remote` después del push. Este cierre documental se publica como commit posterior; el SHA final se indica en el informe al usuario y es consultable en Git. [Contrato funcional](../../Utilidades/QUICK_UTILITIES.md) y [implementación](../Implementacion/IMPLEMENTATION_REPORT_0.21.0.0.md).

## J. Continuación — 13/10/2026

Base remota `d37afc8`. Correcciones localizadas de ciclo de vida/cancelación y propiedad de recursos en Audio, Input y Windows, motivo nativo de inicio y visibilidad de la bandeja. Las cuatro comprobaciones oficiales pasan; 29 regresiones nuevas: 728 tests totales, 107 de utilidades, sin fallos; builds oficiales Debug y Release con firma/motores efectivos comprobados. Versión/build, siete módulos, red, permisos, dependencias externas y políticas de archivos conservados.

Publicación completa desde Finder comprobada, cerrando el parcial de la tabla B. TextEdit amplía QA a espacios y saltos Unicode. Release arranca sin ventanas con eventos login/Servicios; muestra residente de 15,01 s y 73,08 MiB RSS, sin incremento de CPU a la resolución de `ps`, sin certificar un inicio de sesión físico. macOS bloqueado interrumpe la repetición de Run/arrastre final; se solicita desbloqueo directo sin evasión. Accesibilidad efectiva, G305/trackpad, monitores/Spaces y FaceTime/AirPods mantienen pendientes según la [evidencia actualizada](../Pruebas/TEST_RESULTS_0.21.0.0.md); la llamada se aplaza por indicación del usuario.
