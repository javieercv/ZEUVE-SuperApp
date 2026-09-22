# Informe de implementación — ZEUVE 0.13.2.0

Fecha: 8 de septiembre de 2026.

## Objetivo y causa medida

La Fase 2 reduce el tiempo de generación del espectrograma sin cambiar su alcance visible. La versión 0.13.1.0 ejecutaba una FFT en cada hop del 50 % y solo después promediaba el resultado dentro de un máximo de 1.800 columnas. En el MKV real esto suponía unas 64.700 FFT por pista estéreo para producir 1.800 columnas.

El perfil reveló además dos costes independientes: conversión f32le byte a byte con allocations por bloque, y retención de objetos `Data` autoreleased en la tarea que drenaba stdout. Esta última elevaba el pico del proceso de benchmark a unos 535 MiB en el MKV. La UI dibujaba un rectángulo por píxel en Canvas. La cancelación devolvía estado cancelado, pero FFmpeg heredaba `SIGTERM` y `SIGINT` bloqueadas y podía terminar de decodificar la pista completa.

## Algoritmo adaptativo

`SpectrogramAnalysisPlanner` calcula el número de hops densos y el presupuesto permitido por columnas y memoria. Si todos los hops caben en `maximumColumns × 8`, se conservan. Para archivos largos cada columna se divide en ocho estratos y se selecciona una ventana dentro de cada estrato. El trabajo queda limitado a ocho FFT por columna y canal, salvo el modo denso justificado para contenido corto.

El acumulador recorre el PCM una sola vez, descarta frames que no pertenecen a ventanas planificadas y reutiliza buffers de canal de tamaño FFT. Para mezcla analiza cada canal y agrega potencia por bin antes de convertir a dB. No promedia PCM y por tanto conserva señales antífase.

## PCM, Accelerate y memoria

- f32le se copia por bloques a almacenamiento Float alineado y solo se conservan de cero a tres bytes residuales.
- La tarea de lectura incluye un `autoreleasepool` por bloque para liberar `Data` de forma predecible.
- Ventana, setup DFT, entrada imaginaria, salidas real/imaginaria, buffer con ventana y potencia se reutilizan durante toda la petición.
- La potencia se acumula antes de convertir una vez a dB por columna.
- El modelo mantiene como máximo 1.800 columnas y dispone además de un presupuesto de 64 MiB que reduce columnas para FFT grandes.

En estéreo, pedir a FFmpeg un canal mediante `pan` no mostró mejora material: 0,129 s frente a 0,128 s en el MP3 y 0,698 s frente a 0,689 s en el MKV. Para pistas con más de dos canales se usa `pan` al elegir un canal individual, reduciendo el ancho PCM y el trabajo Swift; una señal 7.1 sintética mejoró la decodificación de 0,104 a 0,092 s.

## Caché, parámetros y render

La clave analítica incluye fingerprint, stream, canal, FFT, ventana, intervalo y límite de columnas. La caché LRU vive solo en memoria, mantiene como máximo cuatro entradas y 64 MiB y se invalida si cambia el archivo. No persiste datos ni genera logs.

Pista, canal, FFT y ventana requieren un modelo analítico distinto. Rango dinámico, escala lineal/logarítmica y zoom reinterpretan el modelo existente. El raster se genera en una tarea separada y Canvas dibuja una imagen en vez de construir un `Path` por píxel.

## Progreso y cancelación

El progreso conocido avanza de 0 a 0,95 con los frames PCM, reserva la fase final para preparar/publicar el modelo y solo emite 1 al terminar. Las actualizaciones son monótonas.

`posix_spawn` establece una máscara de señales vacía para el proceso hijo. Cancelar marca el acumulador, solicita la terminación del grupo FFmpeg, espera su recolección y descarta resultados parciales. El benchmark explícito detuvo la operación unos 30 ms después de solicitar la cancelación y no dejó procesos ni una operación global activa.

## Seguridad y compatibilidad

Los archivos se abren en lectura y se validan por fingerprint antes de publicar el resultado. No se añaden red, APIs, telemetría, dependencias, motores, permisos, temporales en disco ni persistencia de información privada. El aislamiento principal de SwiftUI permanece en el ViewModel; los buffers mutables están confinados en acumuladores por petición y protegidos por un único lock.

La versión canónica pasa de 0.13.1.0 a 0.13.2.0, `MARKETING_VERSION` a 0.13.2, build interno a 49 e Inspector multimedia a 0.1.2.
