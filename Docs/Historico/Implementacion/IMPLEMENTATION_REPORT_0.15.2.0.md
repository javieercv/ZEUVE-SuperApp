# Informe de implementación — ZEUVE 0.15.2.0

Fecha: 9 de septiembre de 2026.

## Problema

La serialización de UI de 0.15.1.0 no hacía atómica la sustitución dentro de `MultimediaAudioPreviewService`. Al suspenderse un `start` durante la limpieza, el actor podía aceptar otro `start`; la limpieza antigua seguía consultando propiedades compartidas y podía detener la sesión más reciente. El caso real A→B→C terminaba en una fuente antigua o fallida.

## Corrección

`PreviewSourceReplacementGate` concede un ticket por generación. Cada petición invalida las anteriores antes de esperar y solo el ticket vigente puede crear o publicar una sesión.

El servicio retira de su estado compartido la tarea de decode, scheduler, player y engine como `DetachedPreviewPlaybackResources`. Cancela de inmediato la cola y la tarea, pide al runner terminar el grupo FFmpeg con plazo acotado, espera `waitpid` y después detiene/desecha AVAudioPlayerNode y AVAudioEngine. Esa limpieza solo conserva referencias de la sesión retirada y no puede tocar recursos posteriores.

`replaceSource` es la ruta común de start, seek, resume y cambio de pista. `pause` y `stop` invalidan la generación y usan el mismo cierre. Los callbacks de decode validan el ticket antes de publicar un fallo.

`MultimediaInspectorViewModel` conserva la posición aunque exista una fuente solicitada aún no confirmada. `requestedPreviewSourceID` representa el estado transitorio: la nueva fila muestra **Cargando…**, la anterior vuelve a **Escuchar** desde el clic y solo la fuente confirmada muestra **Pausar**. Waveform, espectrograma y monitor siguen validando sus generaciones antes de publicar.

## Alcance

No se han modificado arquitectura modular, dependencias, red, privacidad, permisos, motores, versiones de FFmpeg/FFprobe, DSP, formatos, archivos de usuario ni otros módulos. `SpectrogramView.swift` continúa leyendo `model.defaultPreferences.allowedFFTSizes`.

## Versionado

- ZEUVE: `0.15.2.0`.
- Build: `53`.
- Inspector multimedia: `0.3.2`.
- `MARKETING_VERSION`: `0.15.2`.
- `ZEUVEReleaseRevision`: `0`.
