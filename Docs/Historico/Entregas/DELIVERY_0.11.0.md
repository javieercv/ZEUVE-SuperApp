# Entrega — ZEUVE 0.11.0

Fecha: 6 de agosto de 2026.

## Contenido

La entrega contiene el proyecto fuente completo de ZEUVE 0.11.0, incluidos:

- código fuente de todos los módulos;
- recursos y motores conservados;
- pruebas Swift y Python;
- proyecto Xcode regenerado;
- scripts de preparación, firma, verificación y empaquetado;
- documentación completa, decisiones y changelog;
- informes de implementación y pruebas de 0.11.0.

## Elementos retirados

- Calibre y toda su integración activa.
- Ghostscript y toda su integración activa.
- Conversión de EPUB, MOBI, AZW/AZW3, FB2 y EPS.
- Licencias y recursos empaquetados de ambos motores.
- Archivos de sistema `.DS_Store`, `._*` y `__MACOSX`.
- Directorios generados de compilación, cachés y datos locales de Xcode en el ZIP final.

## Funciones conservadas

- Detección clara de ebooks y EPS como formatos no compatibles.
- Clasificación de ebooks y EPS en el Organizador.
- Pandoc para TXT, Markdown y HTML.
- Resto de módulos, motores y comportamientos aprobados, sin cambios funcionales intencionados.

## Versión

- Aplicación: 0.10.4 → 0.11.0.
- Build interno: 35 → 36.
- Conversor universal: 0.2.2 → 0.3.0.

## Limitación de la entrega

La aplicación no se compiló ni abrió con Xcode en macOS Apple Silicon dentro de este entorno. El informe de pruebas detalla la validación lógica realizada y las comprobaciones pendientes.
