# Entrega — ZEUVE 0.11.1

Fecha: 21 de agosto de 2026.

## Contenido

La entrega conserva el proyecto fuente completo de ZEUVE y añade la corrección de YouTube público en el Descargador universal, sus pruebas Swift, las reglas de verificación actualizadas, la documentación técnica, las decisiones y el historial de cambios.

## Versión

- Aplicación: 0.11.0 → 0.11.1.
- Build interno: 36 → 37.
- Descargador universal: 0.6.4 → 0.6.5.

## Comportamiento entregado

- Los vídeos públicos de YouTube se analizan y descargan sin cookies ni sesión del navegador.
- La cadena anónima se selecciona internamente y no añade configuración obligatoria a la interfaz.
- Las URLs firmadas del análisis no se reutilizan en la descarga anónima.
- Las sesiones siguen siendo opcionales y expresas para contenido realmente protegido.
- La solución usa exclusivamente los motores ya incluidos y no añade servicios externos ni nuevos permisos.
- Deno conserva su firma oficial y las autorizaciones JIT necesarias; la compilación comprueba ejecución JavaScript y firma profunda del paquete.

## Compatibilidad

No se cambia el tratamiento de Instagram ni del resto de plataformas. Los formatos, presets, historial, seguridad de temporales, publicación atómica y política de privacidad existentes se conservan.
