# Informe de implementación — ZEUVE 0.19.0.0

Fecha: 21 de septiembre de 2026.

## Versiones

- ZEUVE: `0.19.0.0`.
- Marketing: `0.19.0`.
- Build: `65`.
- Inspector multimedia: `0.7.0`.

## Alcance implementado

La entrega completa el macro-bloque aprobado del Inspector sin cambiar motores, red ni frontera con el Conversor. Se ha añadido preview de vídeo FFmpeg incremental con transporte A/V compartido, límites de recursos y fallback hardware/software; subtítulos textuales sincronizados; edición estructural de vídeo; carátulas diferenciadas de streams de vídeo; carpetas y reglas semánticas para lote; preflight y ejecución segura; indicios explicables de fuente previamente lossy y anomalías temporales; OCR bitmap local/revisable; favoritas de configuraciones; informes schema 3; settings y ayuda contextual.

## Seguridad e invariantes

No se implementa transcode audiovisual. Los originales son solo lectura; la edición usa workspace temporal, fingerprints, FFmpeg con argumentos separados, FFprobe posterior y publicación segura. No se sigue symlinks en carpetas de lote. Preview y análisis mantienen buffers acotados/cancelación y los resultados obsoletos se descartan. No se añade permiso de red, telemetría, API, plugin loader ni dependencia externa.

## Compatibilidad deliberada

- HDR: preview de inspección, no monitor HDR de referencia.
- ASS/SSA: contenido/timing; estilos avanzados no garantizados sin libass.
- Bitmap: OCR local revisable; la pista original permanece. PGS es el objetivo principal y VobSub queda condicionado a la ruta real del FFmpeg empaquetado.
- Batch: reglas sobre streams existentes; no hay emparejamiento automático de ficheros externos.

## Persistencia y migraciones

Las preferencias nuevas se decodifican con defaults seguros cuando falta un campo antiguo. Rule sets y favoritas usan stores separados sin rutas. El manifest declara `favorites` solo después de existir implementación completa. El informe JSON pasa de schema 2 a schema 3 mediante campos aditivos.

## Archivos principales

Se amplían los modelos/planificadores/validadores/command builders del Inspector, ViewModel, vistas, settings, report exporter, batch y stores. Se añaden servicios específicos bajo `Preview/`, `Analysis/`, `OCR/` y `Batch/`. El proyecto Xcode se regenera para incorporar todas las fuentes.

## Motores/dependencias

Se reutilizan FFmpeg/FFprobe 8.1.2 y frameworks del sistema (AVFoundation/AppKit/CoreVideo/Accelerate/Vision donde procede). No cambia packaging, firma, instalación o versiones de engines.

## Mantenimiento de compilación

Tras la integración 0.19.0.0 se corrigieron bloqueos de build sin cambiar comportamiento aprobado: el OCR bitmap ya no sombrea el identificador de operación del actor con el UUID del workspace temporal, la vista de Espectrograma usa el contrato actual `MediaTrackSource.streamIndex` y evalúa el análisis avanzado solo cuando existe una pista seleccionada, y `MultimediaBatchDiscoveredFile` expone un inicializador público para que la capa App pueda preparar el preflight estructural con archivos ya fingerprintados.

También se endureció la apertura de archivos en el Inspector: la inspección publica primero las selecciones iniciales de vídeo/audio y solo después expone el resultado a la UI; si el archivo no contiene audio y la pestaña guardada era Espectrograma, vuelve a Resumen. La vista de Espectrograma muestra un estado estable de “Sin pistas de audio” y desactiva acciones que requieren una fuente de audio resuelta.

La apertura queda además protegida frente a metadatos incompletos de FFprobe en pistas de audio: si `sample_rate` o `channels` no son positivos, ZEUVE no inicia espectrograma, señal, sonoridad, preview ni análisis avanzado para esa pista. Los servicios de análisis validan esos invariantes antes de crear acumuladores o decodificar PCM, evitando divisiones por cero y crashes nativos al abrir archivos con streams de audio mal declarados.

## Corrección de recursión al abrir/cerrar el Inspector

`open(_:)` y `closeAnalysis()` restauran las preferencias mediante `applyPreferencesToNewSession()`. El observador de `@Published previewPlaybackRate` se reasignaba incondicionalmente, incluso para el valor válido `1`. Con Combine, la reasignación vuelve a ejecutar `didSet` hasta agotar la pila, antes de lanzar la inspección FFprobe.

La corrección en `MultimediaInspectorViewModel.swift` solo reasigna cuando el valor necesita normalizarse y termina esa invocación para que audio y vídeo se actualicen una sola vez. Conserva el rango 0,5×–2×, convierte valores no finitos a 1× y captura el valor validado para la actualización asíncrona del audio.

`Tests/ScriptTests/test_multimedia_inspector_playback_rate.py` compila y ejecuta el observador extraído del código real con Combine de macOS y colaboradores de prueba. La versión anterior termina con SIGSEGV; la corregida supera 22 asignaciones con/sin vídeo, incluidas restauraciones repetidas, límites, NaN e infinitos, y verifica cantidad de actualizaciones y conservación de posición. La suite SwiftPM no compila la capa App, por lo que esta regresión nativa complementa sus pruebas.

No cambia motores, dependencias, permisos, preferencias persistentes, red, formatos admitidos ni acceso a originales.
