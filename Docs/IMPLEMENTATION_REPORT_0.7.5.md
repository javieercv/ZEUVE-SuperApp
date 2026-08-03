# Informe de implementación — ZEUVE 0.7.5

Fecha: 30 de julio de 2026.

## Objetivo

Corregir dos comportamientos del Conversor universal: asegurar que convertir un vídeo a MP4 en modo simple realice una recodificación y acelerar vídeo → fotogramas, mostrando los archivos mientras se generan y conservando los resultados válidos al cancelar o fallar.

## Conversión real de vídeo

- La planificación de vídeo solo permite copia exacta o `-c:v copy` cuando el modo avanzado y la opción explícita de remux están activos.
- En modo simple, MP4 con códec automático utiliza H.264 mediante libx264. Resolución y FPS se mantienen salvo selección distinta.
- La pista de audio puede conservarse sin recodificar cuando es compatible; esto no evita la recodificación real de la pista de vídeo.
- La interfaz denomina la opción avanzada **Copia rápida sin recodificar el vídeo** y explica que no reduce tamaño ni altera calidad.
- El valor predeterminado de remux pasa a desactivado. Los ajustes migran al esquema 4 y el preajuste oficial MP4 se actualiza; los preajustes personalizados se respetan.
- Tras recodificar, FFprobe confirma que la salida contiene el códec solicitado antes de publicarla.

## Vídeo a fotogramas

- La extracción crea una carpeta visible `Procesando` dentro del destino y FFmpeg escribe directamente en ella.
- Al finalizar, la carpeta se renombra al nombre definitivo dentro del mismo volumen, eliminando la antigua copia completa desde el temporal interno.
- Al cancelar o fallar, se valida el último fotograma, se conserva el prefijo válido y la carpeta pasa a `Incompleto`; `tiempos.csv` pasa a `tiempos_parcial.csv`.
- Un registro privado en el workspace permite recuperar como incompleta una extracción abandonada por cierre inesperado.
- PNG mantiene codificación sin pérdida y cambia a compresión nivel 3 con predictor Up.
- `FrameTimingCSVCollector` genera el CSV durante la misma ejecución de FFmpeg usando `showinfo=checksum=0`, sin una segunda pasada completa con FFprobe.
- El progreso utiliza el número real comunicado por FFmpeg y distingue extracción, finalización del CSV, validación y publicación.
- La validación de carpetas recorre los archivos progresivamente, cuenta sin almacenar todas las rutas y comprueba una muestra inicial y final acotada.

## Protección de archivos

Los vídeos originales se abren en lectura y siguen protegidos mediante huellas y comparación de rutas. La carpeta visible solo se crea dentro del destino elegido, lleva marcadores propios de ZEUVE y no autoriza a borrar o renombrar carpetas ajenas. No se añaden dependencias, motores, conexiones, APIs ni telemetría.

## Versiones

- ZEUVE: 0.7.4 → 0.7.5, build 25 → 26.
- Conversor universal: 0.2.1 → 0.2.2.
- Organizador, Descargador y Analizador mantienen sus versiones.
