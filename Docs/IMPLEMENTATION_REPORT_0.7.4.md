# Informe de implementación — ZEUVE 0.7.4

Fecha: 30 de julio de 2026.

## Objetivo

Reducir trabajo repetido, presión sobre el hilo principal y costes de búsqueda, progreso, diagnóstico, almacenamiento e historial sin cambiar el funcionamiento visible aprobado ni introducir dependencias, Internet o APIs.

## Cambios realizados

- Añadida una caché temporal compacta para búsquedas del Analizador, creada bajo demanda y separada por reglas de mayúsculas y diacríticos.
- Añadido almacenamiento adaptativo: memoria para índices razonables y `Data` mapeado desde un temporal privado para índices excepcionalmente grandes.
- Conservado el recorrido directo como alternativa si el índice temporal no puede construirse.
- Sustituida la preparación SQLite por mensaje por una sentencia preparada reutilizada dentro de una transacción.
- Eliminado un resumen analítico completo cuyo resultado se descartaba durante la importación.
- Compartidos `EngineRegistry` y `EngineDiagnosticService` entre Descargador y Conversor, manteniendo invalidación por cambios y actualización forzada.
- Añadido `LatestValueCoalescer` con control de generación para agrupar progreso frecuente y evitar que un valor obsoleto se publique después del estado final.
- Reducidos los recorridos completos para construir instantáneas de progreso del Conversor.
- Precalculadas una vez por operación las rutas canónicas de todos los originales protegidos.
- Reutilizado `ConverterInputScanner` mientras sus límites no cambien.
- Precalculados los diez primeros rankings de conversaciones dentro de la instantánea analítica.
- Movidas la limpieza de temporales abandonados y la carga del historial fuera del hilo principal.
- Añadido un índice SQLite global sobre `operation_history(created_at DESC)`.

## Compatibilidad y privacidad

No se añaden dependencias, motores, formatos, conexiones, telemetría ni persistencia nueva de chats. Los índices de búsqueda se eliminan con la sesión; los archivos originales continúan abriéndose en lectura y las protecciones de publicación del Conversor no se reducen.

## Versiones

- ZEUVE: 0.7.3 → 0.7.4, build 24 → 25.
- Descargador de YouTube: 0.4.0 → 0.4.1.
- Analizador de chats: 0.1.5 → 0.1.6.
- Conversor universal: 0.2.0 → 0.2.1.
