# Implementación — ZEUVE 0.21.0.0

**Integración y compilación verificadas — 12/10/2026.** La validación física y la eficacia durante FaceTime permanecen pendientes; véase la evidencia de pruebas.

## Base y alcance

Commit inicial sincronizado: `744b1bf01e650ef34bf568c708e70cc8eeaeab03`. Versión visible única 0.21.0.0; metadata Apple 0.21.0, revisión 0/build 79. Los siete módulos mantienen versiones y contratos. Descargador y motores sin reapertura del alcance aplazado; sin ZIP.

## Implementación integrada

Target `ZEUVEQuickUtilities`: catálogo, coordinador y permisos; servicios Audio/Input/Windows/Productivity. `ResidentRuntime` y barra de menús integran arranque independiente de ventana y apertura diferida de `AppModel`. Settings/SQLite centralizados, registro Carbon de atajos y recursos bajo propiedad de sus bloques.

Entrada usa tap real de sesión off-main con máscaras mínimas, rueda discreta global y botones globales por índice. Ventanas usan AX público, selector textual y distribuciones por slots/asociación explícita. Productividad usa Servicios, publicación exclusiva de archivos y bandeja RAM. Mezclador usa Process Taps/rutas propias sólo en fuentes y formatos/salidas compatibles.

**Protección de llamadas no completada:** pendiente de comparación real FaceTime/altavoces y eficacia medida. Su activación normal continúa no disponible; no declara protección por preferencia ni por éxito de una API. No se reutilizó ElfiSariña.

`CallAudioProtectionService` incorpora `prepareDiagnostic`, `beginDiagnostic(sourceIDs:)`, `stopDiagnostic` y lectura de RMS para intentar una ruta real de reproducción privada a ganancia 1. La UI exige fuentes elegidas y una llamada preparada por el usuario; no abre llamadas, cambia volumen maestro o captura micrófono/conversaciones. La prueba no se persiste ni se autoactiva. `diagnosticDidChange` permite al runtime observar el ciclo aunque la vista use `contentDidChange`.

`AudioRoutingCoordinator` mantiene propietarios independientes `mixer`/`callDiagnostic`; rechaza ganancias incompatibles, conserva las rutas ajenas al detener un propietario y ofrece parada global. Apertura/refresco se retienen y cancelan/esperan; eventos nativos pasan por un consumidor propio de `AsyncStream` acotado. El callback obtiene RMS agregado del último buffer sólo para el diagnóstico, con lectura atómica en RAM, sin PCM ni persistencia. Los niveles internos no certifican volumen físico ni eficacia.

Se añaden 13 pruebas de diagnóstico, propiedad compartida, conflictos, cancelación, limpieza y cálculo RMS. Su ejecución/aceptación se consigna únicamente cuando exista evidencia en el informe de pruebas; no se declara aquí que hayan pasado. La QA física de la hipótesis y su conversión en protección normal continúan pendientes.

## Recursos, seguridad y límites

Sin drivers, root, helpers privilegiados, nuevas dependencias externas o red. APIs/frameworks del sistema, descripción de captura y Servicios en Info.plist. Accesibilidad/captura se solicitan por función. Sin PCM, pulsaciones, textos o títulos privados persistidos. El comportamiento detallado vigente está en [QUICK_UTILITIES](../../Utilidades/QUICK_UTILITIES.md).

## Verificación conocida

Las cuatro comprobaciones oficiales pasan. El pase final reúne 565 tests Swift y 134 Python, incluidos 78 de utilidades. Release ARM64 tiene Hardened Runtime y Audio Input efectivos, firma ad hoc validada y motores verificados. Sin Developer ID/notarización en este entorno.

QA nativa confirma panel de creación, integración Servicios de TextEdit, bandeja por referencias, apertura de ruta de mezclador, parada y reinicio. Accesibilidad efectiva, hardware G305/monitores, publicación final del Servicio de Finder y protección durante FaceTime conservan los límites detallados en [pruebas](../Pruebas/TEST_RESULTS_0.21.0.0.md).
