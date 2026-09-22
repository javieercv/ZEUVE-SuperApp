# Resultados de pruebas — ZEUVE 0.12.1

## Cobertura específica

- «Mejor calidad compatible» incluido usa Original.
- Los presets 1080p, 720p y vídeo con subtítulos usan Vídeo.
- «Colección completa» conserva Original.
- Una copia incluida antigua en Vídeo migra a Original y se persiste con esquema 3.
- Identificador, favorito y preset personal permanecen intactos.
- Una configuración diferenciada con resolución concreta no se sobrescribe.

## Resultados

- Regresiones específicas: 4 de 4.
- XCTest: 195 de 195.
- Swift Testing: 45 de 45.
- Python: 52 de 52.
- Compilación Swift de producción: correcta.
- Validación de documentación y ejemplos JSON: correcta.
- Verificación de motores incluidos y empaquetados: correcta.
- Compilación Xcode Debug ARM64: correcta.
- Arranque de la aplicación generada: correcto; la interfaz muestra ZEUVE 0.12.1 (43).
- Migración sobre el almacenamiento real de la aplicación: «Mejor calidad compatible» queda en esquema 3 y modo `original`; los presets de vídeo y los presets personales permanecen diferenciados.

La etiqueta mostrada por la interfaz para ese modo es «Original sin convertir». El lector de accesibilidad externo dejó de responder al abrir la sección Presets, por lo que esa última etiqueta se contrastó con el estado persistido y con el mapeo de presentación de la interfaz, sin atribuir el fallo externo a ZEUVE.
