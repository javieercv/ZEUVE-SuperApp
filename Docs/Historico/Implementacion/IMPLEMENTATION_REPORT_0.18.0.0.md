# Informe de implementación — ZEUVE 0.18.0.0

Fecha: 21 de septiembre de 2026.

## Objetivo

Cerrar el tercer macro-bloque del Inspector multimedia añadiendo trabajo por lotes, presets reutilizables y una auditoría amplia de personalización, sin introducir edición estructural masiva ni debilitar las garantías de seguridad existentes.

## Lotes

El Inspector acepta varios archivos seleccionados o arrastrados. Un único archivo conserva el flujo individual; dos o más abren el modo lote. `MultimediaBatchViewModel` mantiene la cola y su estado visual, mientras `MultimediaBatchProcessor` reutiliza los servicios existentes de FFprobe, señal, sonoridad, espectrograma e informes.

Cada elemento se procesa estrictamente en secuencia. La configuración puede solicitar:

- inspección FFprobe;
- análisis de señal;
- sonoridad EBU R128;
- espectrograma PNG;
- informe TXT, Markdown o JSON.

No se generan waveform, preview ni A/B en lotes porque son superficies interactivas. Con cero pistas de audio se omiten los análisis de audio; con exactamente una pueden ejecutarse; con dos o más se conservan la inspección y un aviso, pero ZEUVE no selecciona ninguna pista silenciosamente.

Un fallo de un elemento no detiene los siguientes. La cancelación termina la fase actual, marca como cancelados los pendientes y conserva las salidas que ya se publicaron correctamente. `Reintentar fallidos` reconstruye una cola únicamente con los elementos fallidos y mantiene la configuración actual.

## Salidas y protección de archivos

Los informes y espectrogramas usan nombres previsibles y la política de conflictos existente. Toda publicación recibe la lista completa de originales del lote como rutas protegidas, por lo que una salida no puede sustituir silenciosamente otro archivo seleccionado.

Cada entrada conserva `FileFingerprint` y se vuelve a comprobar antes del trabajo. Los symlinks se rechazan. La cola retiene únicamente resúmenes compactos y referencias a salidas publicadas; los modelos pesados de inspección, señal, LUFS y espectrograma se liberan al terminar cada elemento.

El historial crea una sola entrada agregada por lote con contadores y duración. No persiste nombres, rutas, lista de archivos, metadata privada ni resultados de análisis por archivo.

## Presets

Se añade `MultimediaInspectorBatchPresetStore`, persistido mediante `SettingsRepository` bajo `multimediaInspector.batchPresets.v1`.

Los cuatro presets incluidos, con UUID estables, son:

- Inspección rápida;
- Informe técnico;
- Análisis de audio completo;
- Espectrogramas.

Los presets guardan únicamente operaciones y parámetros de análisis/exportación. No almacenan archivos, rutas ni carpetas de salida. Crear, editar, duplicar, renombrar, eliminar y restaurar presets se realiza desde los Ajustes centralizados.

## Personalización

La auditoría de configurabilidad amplía `MultimediaInspectorPreferences` y `MultimediaInspectorSettingsView` para exponer comportamientos razonablemente personalizables:

- automatización mono-pista de espectrograma, señal y sonoridad;
- volumen inicial y saltos del reproductor;
- continuidad de posición y estado Play/Pausa al cambiar de pista;
- paso de zoom y desplazamiento temporal;
- estilo, representación, guía central y overlays de waveform/espectrograma;
- umbrales de silencio y posible clipping;
- ventana, FFT, rango dinámico, límite de columnas, escala, canal y dimensiones de exportación del espectrograma;
- formato y secciones de informes;
- preservación de metadata, sufijo y contenedor preferido de salida;
- preset de lote predeterminado.

La restauración del Inspector devuelve preferencias y presets a los valores incluidos, sin borrar archivos, resultados ni historial.

No se convierten en opciones las invariantes de seguridad: fingerprints, rechazo de symlinks, publicación segura, protección del original, validación final, stream copy de vídeo/audio, privacidad y `OperationCoordinator` permanecen obligatorios.

## QA corregido durante el cierre

Se actualizaron dos regresiones de pruebas que habían quedado desalineadas con la implementación aprobada:

- la prueba Python del flujo automático ahora espera `signalAnalysisTask`, nombre real de la tarea de señal;
- la prueba Swift de normalización del rango dinámico del preset espera el límite superior aprobado de `12 dB`, coherente con `MultimediaInspectorPreferences` y con la UI de Ajustes.

No se cambió el comportamiento de producción para satisfacer estas regresiones; se corrigieron las expectativas obsoletas.

## Corrección posterior de build Xcode

Se corrigió una inicialización de `MultimediaBatchViewModel` que Swift 6 rechazaba en Xcode porque consultaba la propiedad publicada `presets` antes de terminar de inicializar todas las propiedades almacenadas. La lógica se mantiene igual: los presets se cargan primero en una constante local, se resuelve el preset predeterminado y después se asignan `presets`, `selectedPresetID` y `configuration`.

## Versionado

- ZEUVE: `0.18.0.0`.
- Build: `63`.
- Inspector multimedia: `0.6.0`.

No se añaden dependencias, red, APIs, motores ni telemetría.
