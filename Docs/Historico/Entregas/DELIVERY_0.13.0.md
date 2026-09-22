# Entrega — ZEUVE 0.13.0

Fecha: 7 de septiembre de 2026.

ZEUVE 0.13.0 incorpora `Inspector multimedia` 0.1.0 como sexto módulo built-in y centraliza FFprobe en `ZEUVEEngines/MediaInspection` para Inspector multimedia y Conversor universal.

## Estado funcional entregado

El módulo abre o recibe por arrastre archivos de audio/vídeo en modo de solo lectura, presenta Resumen, Pistas, Espectrograma y Metadatos, y exige `Editar` antes de crear un borrador modificable. Undo/Redo actúa exclusivamente sobre el borrador. El remux genera siempre un archivo nuevo y valida el resultado con FFprobe antes de publicarlo.

La edición 0.13.0 está limitada a audio y subtítulos: añadir, eliminar, reordenar, idioma, título, default y forced cuando corresponde. Vídeo y audio nunca se recodifican automáticamente. Los subtítulos solo pueden usar una conversión auxiliar autorizada cuando la política de compatibilidad lo permite. MKV, MP4, MOV y WebM son los contenedores editables iniciales.

La previsualización enumera vídeo/audio conservados por copia, adiciones, eliminaciones y conversiones auxiliares. Las entradas se verifican al preparar/ejecutar y se vuelven a comprobar después de FFmpeg, antes de publicar. El espacio se comprueba tanto en el volumen temporal como en el destino e incluye conservadoramente las entradas externas añadidas.

El espectrograma usa FFmpeg para PCM float32 incremental y una implementación DSP independiente en Swift. En macOS usa Accelerate/vDSP. No incluye ni enlaza Spek ni wxWidgets, y no incorpora código GPL de Spek.

## Privacidad y dependencias

Inspector multimedia es local, su manifiesto no solicita red y no se han añadido dependencias externas. El historial permanente almacena únicamente datos agregados de resultados publicados; no persiste rutas absolutas, metadata completa, títulos de pistas, PCM ni datos espectrales.

El original nunca se sobrescribe. Las salidas pasan por workspace temporal, validación FFprobe y publicación conflict-safe; symlinks y rutas equivalentes se tratan de forma conservadora.

## Validación final ejecutada

- `./Scripts/run_tests.sh`: **PASS**, 375 tests contabilizados, 0 fallos, 1 omitido por plataforma.
- `swift build -c release --jobs 2`: **PASS**.
- `ZEUVE_SWIFT_JOBS=2 ./Scripts/verify_project.sh`: **PASS**.
- `./Scripts/build_macos.sh Release`: no puede ejecutarse en Linux x86_64; termina con el guardarraíl previsto que exige macOS Apple Silicon con Xcode.
- `verify_app_macos.sh`: omitido por plataforma, tal como documenta el propio script.

No se presenta la validación portable como sustituto de una compilación Xcode real. Antes de distribuir, debe abrirse/compilarse en macOS Apple Silicon y realizar la validación manual indicada en la documentación del módulo.
