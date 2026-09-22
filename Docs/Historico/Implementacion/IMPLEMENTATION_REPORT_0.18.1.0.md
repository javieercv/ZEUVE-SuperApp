# Informe de implementación — ZEUVE 0.18.1.0

Fecha: 21 de septiembre de 2026.

## Objetivo

Corregir la cobertura incompleta de ayuda contextual del Inspector multimedia después de 0.18.0.0 y aplicar de forma completa las reglas UX permanentes de ZEUVE: toda opción, métrica o estructura técnica que pueda resultar ambigua debe ofrecer explicación contextual mediante la infraestructura visual común, sin convertir controles evidentes en una interfaz saturada.

## Ajustes del Inspector

`MultimediaInspectorSettingsView` reutiliza `HelpLabel`, `HelpPickerRow`, `HelpToggleRow`, `HelpStepperRow` y `ContextualHelpButton` para explicar las preferencias técnicas de:

- pestaña y detalle inicial;
- preservación de metadatos;
- automatización mono-pista de espectrograma, señal y sonoridad;
- volumen, salto rápido y continuidad al cambiar de pista;
- zoom y desplazamiento temporal;
- estilo/representación de waveform y overlays;
- umbrales de silencio y posible clipping;
- FFT, ventana, escala, canal, rango dinámico, columnas y exportación PNG;
- mapa temporal de sonoridad;
- formato y secciones de informes;
- sufijo/contenedor de salida;
- preset predeterminado y editor completo de presets de lote.

Los controles evidentes como cancelar, cerrar, eliminar o iniciar una acción no reciben iconos de información innecesarios.

## Superficies del Inspector

Resumen, Pistas, Espectrograma, Metadatos y Lote incorporan ayuda general accesible. Además se completa la ayuda específica de conceptos que requieren interpretación, entre ellos:

- Integrated LUFS, LRA, True Peak, Sample Peak y estadísticas Short-term;
- sincronización/offsets declarados;
- silencios y **Posible clipping**;
- comparación A/B y flags Default/Forced;
- FFT, ventana, rango dinámico, Nyquist, escala y canal/downmix;
- capítulos;
- attachments, `attached_pic`, filename y MIME;
- metadatos editables frente a tags preservados de solo lectura;
- informes, estados y comportamiento del modo lote;
- inspección parcial.

La ayuda contextual se mantiene dentro de `ZEUVEApp`. El módulo de dominio `MultimediaInspectorModule` no adquiere estado de presentación ni dependencias de SwiftUI para resolverla.

## Seguridad y rendimiento

Abrir o cerrar un popover de ayuda no:

- ejecuta FFmpeg o FFprobe;
- inicia señal, sonoridad, espectrograma o waveform;
- invalida cachés;
- cambia la pista seleccionada o el estado Play/Pausa;
- modifica preferencias;
- escribe archivos;
- crea historial;
- accede a red.

No se añaden dependencias, motores, APIs, telemetría ni permisos. Las garantías existentes de `OperationCoordinator`, fingerprints, publicación segura, validación final y protección del original permanecen intactas.

## Regresiones automáticas

Se añade `Tests/ScriptTests/test_multimedia_inspector_help.py`, que protege cinco invariantes:

1. las cinco superficies principales mantienen ayuda general;
2. Ajustes usa los componentes de ayuda compartidos;
3. los temas cubren configuración y análisis;
4. métricas y estructuras ambiguas conservan ayuda específica;
5. el Inspector no crea iconos `info.circle`/`info.circle.fill` ni una UI de información paralela.

También se amplía `Scripts/verify/multimedia_inspector.py` para que la cobertura de ayuda forme parte del verificador estructural del módulo.

## Consolidación documental

`Docs/MULTIMEDIA_INSPECTOR.md` queda consolidado para reflejar el estado real del módulo 0.6.1. Se corrigen descripciones históricas que todavía presentaban capítulos, attachments o metadatos como funciones exclusivamente de lectura cuando desde 0.17 forman parte de la edición estructural aprobada.

Se actualizan asimismo README, changelog, arquitectura, alcance, seguridad, building, testing y decisiones del proyecto para documentar la corrección 0.18.1.0.

## Versionado

- ZEUVE: `0.18.1.0`.
- Build: `64`.
- Inspector multimedia: `0.6.1`.

No hay cambios funcionales en motores multimedia, red, privacidad, edición/remux ni archivos originales.
