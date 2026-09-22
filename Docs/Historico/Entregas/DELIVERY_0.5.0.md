# Entrega — ZEUVE 0.5.0

Fecha: 3 de julio de 2026.

## Resumen

ZEUVE 0.5.0 incorpora el módulo oficial Analizador de chats. Permite importar ZIP originales de WhatsApp y exportaciones completas de Instagram, seleccionar una conversación de Meta y analizar ambos orígenes de forma local y combinada.

## Funciones principales

- Importación segura de ZIP mediante `libarchive` del sistema.
- TXT de WhatsApp con variantes de fecha, multilínea, sistema y adjuntos.
- Catálogo de Instagram separado del análisis de mensajes.
- Selector buscable por categoría y compatible con nombres duplicados.
- Varias páginas `message_N.html`, fechas españolas e inglesas y conversión horaria.
- Modelo normalizado y deduplicación conservadora.
- Resumen, gráficos, filtros, perfiles, palabras, frases y emojis.
- Búsqueda con contexto y paginación.
- Conversaciones temporales y tiempos de respuesta por turnos.
- Comparación y fusiones temporales de identidades.
- Progreso y cancelación mediante el coordinador global.
- SQLite temporal, limpieza controlada e historial agregado sin contenido privado.
- Ajustes centralizados y ayuda contextual.

## Seguridad y privacidad

- Sin Internet, APIs, telemetría, WebKit o apertura de enlaces.
- Solo lectura de archivos seleccionados.
- Los adjuntos no se decodifican.
- Protección frente a rutas peligrosas, enlaces simbólicos, cifrado, ZIP bombs y límites extremos.
- Los temporales solo se eliminan cuando su propiedad puede verificarse.
- Los mensajes, participantes, consultas y nombres de conversaciones no se guardan en historial.

## Versión

- Versión anterior: 0.4.0, build 12.
- Versión nueva: 0.5.0, build 13.
- Módulo Analizador de chats: 0.1.0.
- Motivo: incorporación de un nuevo módulo oficial y un conjunto importante de funciones compatibles.

## Pruebas

- 93 pruebas Swift superadas, incluidas 22 específicas del nuevo módulo.
- 11 pruebas Python superadas.
- Compilación SwiftPM Release completada.
- `Scripts/verify_project.sh` completado sin fallos.
- Análisis sintáctico de la interfaz y regeneración del proyecto Xcode completados.
- Proyecto Xcode regenerado con los nuevos archivos y productos.

## Compatibilidad

- El Organizador y el Descargador no cambian su comportamiento aprobado.
- No se añaden paquetes Swift externos ni instalaciones manuales.
- `libarchive` y SQLite se enlazan desde el SDK/sistema mediante módulos C mínimos.
- App Sandbox continúa desactivado por decisión anterior; Hardened Runtime permanece configurado.

## Limitaciones

No se ha compilado ni abierto `ZEUVE.app` mediante Xcode en este entorno. La apariencia, accesibilidad, firma y flujo manual final quedan pendientes de un Mac Apple Silicon. La importación y el motor se han probado con datos sintéticos; no se incluyeron ni copiaron chats personales reales.
