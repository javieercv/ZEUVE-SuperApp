# Informe de implementación — ZEUVE 0.20.2.0

## Alcance

Inspector multimedia 0.7.2 reduce la latencia percibida de Play/Pausa, reanudación, seek y transporte sin cambiar la semántica estabilizada en 0.7.1. Se conservan identidad solicitada/confirmada, generaciones, `MultimediaPreviewControlResolver`, seek optimista, pausa de vídeo con fuente/frame retenidos y protección frente a procesos obsoletos.

## Implementación

`ExternalProcessRunner.run` admite una gracia de cancelación opt-in, manteniendo 2 s como valor global. Solo los FFmpeg efímeros de preview de audio/vídeo solicitan 50 ms. La cancelación sigue enviando SIGTERM al grupo, escala cuando corresponde y espera el cierre/recolección antes de liberar el registro.

En audio, la salida audible se detiene y el engine se pausa antes de esperar la limpieza del decoder, evitando que una pausa o sustitución parezca responder tarde. En vídeo, Pausa y Stop publican primero el estado seguro que ya corresponde a la operación y después completan la cancelación del decoder. El ViewModel actualiza el transporte de forma optimista, deja de mantener el monitor de 100 ms durante Pausa y evita republicar snapshots/frames sin cambios.

No se eliminan gates, `operationID`, generaciones ni validaciones de identidad. No se añaden dependencias, motores, red, permisos ni cambios destructivos sobre originales.
