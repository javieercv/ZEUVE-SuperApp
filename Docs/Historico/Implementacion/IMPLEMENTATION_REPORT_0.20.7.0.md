# Implementación — ZEUVE 0.20.7.0

Fecha: 05/10/2026. Marketing 0.20.7, build 73. Base remota comprobada: `17003a32f05e42134f244e5381fe5f0d872a248c`, rama `main`, sin cambios locales iniciales ni divergencia.

## Alcance autorizado

Corrección de parciales locales O-18, C-11, C-48, I-93, I-96, I-134, I-135, I-161 e I-162. El usuario mantiene el Descargador excluido, incluidos D-15/D-60 y la cobertura remota de P-12. I-29/I-35 conservan su requisito de comprobación acústica. No se amplían motores, dependencias, red, permisos, esquema SQLite ni formatos persistidos.

## Cambios

- Organizador 0.1.5: editor de reglas en Ajustes con alta/edición/eliminación. Normalización de extensión y validación de componentes de carpeta antes de persistir y planificar. Preflight y movimiento rechazan destinos con enlaces simbólicos para proteger el alcance elegido.
- Conversor 0.3.2: la cabecera ADTS no pasa por el detector de tramas MPEG reservadas. El estado aplicado de una receta se compara con las opciones reales; callbacks programáticos conservan favorito/preset, una edición real o destino incompatible invalidan la selección.
- Inspector 0.7.5: extracción bitmap con time base explícito de un microsegundo, duración acotada, borrados transparentes como límites y fusión de frames retenidos. Los bitmaps no reconocidos siguen revisables; SRT excluye eventos vacíos/inválidos.
- `MediaEditReview` representa las pistas efectivas y valores antes/después. La vista individual no anuncia como conservada una pista retirada. Cada elemento de lote abre un detalle de plan, avisos o motivo de no aplicabilidad; una preparación nueva invalida la anterior.
- MOV: FFmpeg produce el temporal QuickTime sin remapear la portada como vídeo. `QuickTimeArtworkWriter` escribe `covr` JPEG/PNG en el `moov` final del workspace propio antes de validar y publicar. Verifica propiedad, marca QuickTime, tamaños y átomos; conserva offsets de muestras y rechaza estructuras inseguras. No altera originales ni cambia el contenedor a MP4. MP4/MOV no ofrecen un título de portada que el contenedor no conserve.

## Verificación y aceptación

Consulta [resultados técnicos](../Pruebas/TEST_RESULTS_0.20.7.0.md) y [aceptación manual](../Pruebas/MANUAL_QA_0.20.7.0_20261005.md). Las pruebas nativas de servicio comprueban los motores reales, Vision, portada y hashes de paquetes. Los nueve IDs locales también pasan desde UI; la checklist conserva títulos, IDs y evidencias previas y queda en 599 OK, 1 fallo, 5 parciales y 34 pendientes.

La QA Release descubrió que la primera validación de componentes rechazaba nombres válidos. Se reprodujo en un test optimizado y se sustituyó por comprobación explícita de componentes y búsqueda de caracteres prohibidos con `rangeOfCharacter`; la suite Release y el recorrido de crear, editar, mover, deshacer y reiniciar pasan con el código final.

No se crea ZIP ni otra carpeta versionada. La copia interna de QA utiliza datos y archivos propios aislados. La distribución notarizada y cualquier contenido remoto permanecen fuera de esta verificación.
