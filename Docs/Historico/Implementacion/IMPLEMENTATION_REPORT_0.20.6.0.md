# Implementación — ZEUVE 0.20.6.0

Plan de corrección aprobado el 04/10/2026. Base remota sincronizada: `10b8ac3e22140d5985a00d04db17461c611196bc`. Marketing 0.20.6, build 72; Conversor 0.3.1, Inspector 0.7.4 y Limpiador 0.1.4.

## Correcciones por causa raíz

| Área / IDs | Cambio |
|---|---|
| S-16 | El reset global del ViewModel del Inspector restaura preferencias sin llamar a la restauración de presets. Se preservan reglas/favoritos y el reset específico sigue separado. |
| C-14/C-15 | `ConverterMediaPolicy` comparte límites por canales efectivos entre plan y builder. FFprobe local coordinado informa el bitrate automático; 320 explícito mono se rechaza y estéreo permanece admitido. |
| C-20 | UI y plan limitan WebM a copia avanzada de vídeo compatible VP8/VP9/AV1; audio seleccionado se comprueba por stream. No se incorpora encoder. |
| C-35/C-36/C-37 | Pandoc fija plain/markdown/html; detector desambigua TXT/MD textual y el validador recorre todo el UTF-8, rechazando firmas binarias, contenido vacío y controles incompatibles. |
| C-46/P-16 | La tarea de ejecución devuelve estado terminal después del servicio y limpieza, vacía secretos efímeros y permite otra operación. |
| I-33/I-38/I-39 | El vídeo usa el gate de sustitución existente, espera el task anterior completo y descarta generaciones viejas. El monitor sigue durante el seek pausado pendiente. |
| I-66 | Transporte reservado; altura visual según espacio y desplazamiento para espectrograma, avisos/revisión y contenido del reproductor. |
| I-120 | Metadata y pista de vídeo comparten el valor efectivo. El ordinal de salida se resuelve tras reordenar en comando y validador. |
| I-127/I-136 | Ausencia de codec_name y fallback attachment se normalizan; se mantienen códec conocido, filename/MIME y extradata_size conocido. |
| I-130/I-131 | Las carátulas MP4 nuevas usan título vacío; la UI explica la limitación y el validador bloquea títulos no representables solicitados. |
| I-133 | La carátula MKV existente se copia sin recodificar a temporal propio y se adjunta con filename/MIME; no se cuenta como vídeo normal. |
| I-132 | Compatibilidad sobre carátulas efectivas. Idioma ausente/und se equiparan sin ignorar idiomas reales. |
| I-164 | Cancelar preflight cancela la tarea real; se espera al cerrar y se descartan resultados obsoletos. Controles y guardas evitan solapamiento de análisis/edición. |
| L-74 | La disponibilidad de Deshacer se reconstruye desde SQLite, con reserva global y verificación de Papelera, fingerprint, escritura y conflictos; se revalida al restaurar. |

## Invariantes

No cambian esquema SQLite, formatos persistidos, defaults, permisos, servicios, motores ni dependencias. Se conservan originales, publicación segura y política de fotogramas incompletos recuperables. No se trabaja sobre Descargador ni sesiones remotas; no se corrigen parciales adicionales. MOV/carátulas continúa fuera del encargo.

Se añaden regresiones de métodos reales de ZEUVEApp compilados en harness, persistencia reabierta, límites mono/estéreo, texto íntegro, metadata, normalización con contrastes negativos y ciclo de decodificación. Las integraciones con motores reales son opt-in mediante variables ZEUVE_QA_FIXTURES/ENGINES/OUTPUTS y solo usan fixtures sintéticos preparados.

La implementación queda distinguida de aceptación: el controlador nativo perdió su conexión durante el intento de revalidación; ningún ID manual se convierte en OK por estas pruebas automáticas. Véanse resultados y checklist mantenida.
