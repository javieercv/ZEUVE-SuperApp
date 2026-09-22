# Resultados de pruebas — ZEUVE 0.12.4

Fecha: 2026-09-07  
Build: 46  
Entorno portable: Linux x86_64

## Cobertura nueva

Se añadieron o actualizaron regresiones para:

- cancelación de la `Task` propietaria de `ExternalProcessRunner`, comprobando desaparición del proceso padre y de su descendiente y limpieza del registro activo;
- retención de logs limitada a archivos propiedad de ZEUVE, tope global y permisos restrictivos;
- conservación de bookmarks irresolubles y refresco de bookmarks stale;
- rechazo de entradas ZIP que normalizan a la misma ruta;
- cancelación durante streaming prolongado de libarchive;
- deduplicación, orden estable, estadísticas y paginación de `TemporaryChatStore` sin materializar toda la sesión;
- equivalencia entre las analíticas respaldadas por SQLite y las analíticas heredadas sobre un dataset representativo para resumen, actividad, participantes, palabras, conversaciones, respuestas agregadas y búsqueda;
- verificadores estructurales del nuevo ciclo del Descargador, Wayback efímero, privacidad del Organizador y arquitectura SQLite del Analizador.

La diferencia deliberada en tiempos de respuesta es que la ruta store-backed no conserva el array completo de muestras individuales cuando no es necesario para la UI; mantiene conteo, agregados, distribución y estadísticas por participante.

## Resultados portables

- XCTest: 214 ejecutadas, 0 fallos, 1 omitida por requerir macOS Apple Silicon.
- Swift Testing: 47 pruebas, 0 fallos.
- Python `Tests/ScriptTests`: 79 pruebas, 0 fallos.

Las suites se ejecutaron también por separado para evitar que el límite temporal del contenedor cortara el script combinado durante fases anteriores de la intervención.

Los verificadores portables de integración, estructura, motores, documentación, rendimiento, Conversor, Descargador, Analizador, Comparador de Instagram, manifiestos, parseo de `ZEUVEApp` y coherencia SwiftPM/Xcode pasan sin errores. `ZEUVEApp` contiene 54 fuentes Swift y la coherencia SwiftPM/Xcode confirma 9 productos enlazados.

`swift build -c release --jobs 1` no llega a completar dentro de la ventana máxima de ejecución de este contenedor Linux; progresa por los targets sin mostrar errores de compilación antes del corte. Por ello el build Release no se registra como validado en Linux y la comprobación definitiva sigue siendo macOS Apple Silicon.

## Validación pendiente de plataforma

Este entorno no sustituye la validación de macOS. Deben ejecutarse en un Mac Apple Silicon `./Scripts/verify_project.sh` / `Scripts/verify_app_macos.sh` y las comprobaciones reales de Xcode ARM64, firma, Hardened Runtime, apertura de la aplicación, Keychain, AppKit/SwiftUI y motores empaquetados. El resultado de cualquier comprobación portable adicional de cierre se refleja en `Docs/DELIVERY_0.12.4.md`.
