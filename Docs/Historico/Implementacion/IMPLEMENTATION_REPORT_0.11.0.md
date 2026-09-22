# Informe de implementación — ZEUVE 0.11.0

Fecha: 6 de agosto de 2026.

## Objetivo aprobado

Eliminar completamente Calibre y la conversión de libros electrónicos, conservar la detección de esos formatos y su clasificación en el Organizador, mantener Pandoc para TXT/Markdown/HTML, eliminar Ghostscript y la conversión de EPS, conservar las referencias históricas y elevar ZEUVE a 0.11.0.

## Cambios realizados

### Calibre y ebooks

- Se elimina `CalibreCommandBuilder.swift`.
- Se retiran las rutas, disponibilidad, diagnósticos, requisitos y ramas de ejecución de Calibre.
- Se elimina Calibre de `engines.json`, de la preparación, la firma y las verificaciones de motores.
- Se elimina su licencia incluida.
- EPUB, MOBI, AZW/AZW3 y FB2 dejan de producir rutas de conversión.
- El escáner continúa reconociendo esos formatos y los rechaza con un mensaje específico de libro electrónico no compatible.
- El Organizador no se modifica y conserva sus reglas de clasificación.

### Pandoc

- Pandoc 3.10 permanece registrado y preparado.
- Su matriz y constructor de comandos quedan limitados a TXT, Markdown y HTML.
- Se elimina EPUB como salida de Pandoc.

### Ghostscript y EPS

- Se elimina `GhostscriptCommandBuilder.swift`.
- Se elimina `Resources/Engines/ghostscript` y su licencia.
- Se retiran todas las rutas de preparación, firma, diagnóstico, verificación y ejecución.
- EPS permanece en el detector, pero el escáner lo rechaza de forma explícita y no crea planes de conversión.

### Regresiones, versión y limpieza

- Se añaden pruebas de matriz, escáner, Pandoc y manifiesto de motores.
- `verify_project.sh` comprueba que Calibre y Ghostscript no vuelvan a aparecer en las rutas activas.
- ZEUVE se eleva a 0.11.0, build 36; el Conversor universal se eleva a 0.3.0.
- Se regenera `ZEUVE.xcodeproj` desde el generador aprobado.
- Se retiran archivos `.DS_Store`, AppleDouble `._*` y `__MACOSX` del proyecto de trabajo.
- Se actualizan README, documentación de compilación, arquitectura, alcance, Conversor, decisiones y changelog.
- Los informes y entradas históricas se conservan sin reescribir su contexto original.

## Protección del original

El archivo `/mnt/data/ZEUVE_Swift_0.10.4.zip` no se modificó. Todo el trabajo se realizó sobre una extracción independiente. Su SHA-256 comprobado es `6eeff3a98e864ed3ddc2e4d834835267a8ec32caeb5ec8a548453da9019783cf`.
