# Entrega — ZEUVE 0.4.0

Fecha: 2 de julio de 2026.

## Resumen

ZEUVE 0.4.0 centraliza toda la configuración persistente en el apartado general Ajustes. La pantalla permite seleccionar General, Organizador de archivos o Descargador de YouTube. El Descargador organiza su configuración en Predeterminados, Presets y Diagnóstico.

Las herramientas conservan únicamente las decisiones necesarias para la operación actual. No se han añadido ruedas, botones ni ventanas independientes de ajustes dentro de los módulos.

## Cambios principales

- Nueva navegación central de Ajustes por aplicación y módulo.
- Valores predeterminados persistentes separados de la operación actual.
- Gestión completa de presets dentro de Ajustes.
- Diagnóstico de motores únicamente dentro de Ajustes.
- Selector rápido de presets conservado en el Descargador.
- Restauración segura de valores predeterminados por módulo.
- Opción para olvidar carpetas recientes sin modificar archivos.
- Reglas, decisiones y documentación de módulos actualizadas para futuras implementaciones.

## Compatibilidad

- Los valores previos del Organizador guardados bajo `organizer.options` se leen como migración inicial cuando todavía no existe `organizer.defaultOptions`.
- Los presets existentes del Descargador se conservan.
- Las selecciones exactas de pistas, las cookies y el proxy siguen siendo opciones por operación y no se guardan como ajustes generales.
- Cambiar valores predeterminados no modifica silenciosamente una operación ya preparada o en curso.

## Versión

- Versión anterior: 0.3.0, build 11.
- Versión nueva: 0.4.0, build 12.
- Motivo: nueva arquitectura visible de ajustes y preferencias por módulo compatible con el funcionamiento anterior.

## Pruebas

- 71 pruebas Swift superadas.
- 11 pruebas Python superadas.
- Análisis sintáctico de todas las vistas SwiftUI/AppKit afectadas.
- Validaciones estáticas de centralización, persistencia y ausencia de accesos duplicados.
- Compilación SwiftPM Release completada correctamente.
- Proyecto Xcode regenerado.
- Validación de documentación, manifiestos, scripts y arquitectura de ajustes completada.

Los detalles completos se encuentran en `Docs/TEST_RESULTS_0.4.0.md`.

## Limitaciones

No se ha compilado ni abierto `ZEUVE.app` mediante Xcode en este entorno. La compilación SwiftPM Release sí se completó correctamente, pero no sustituye la compilación del objetivo macOS ni su apertura visual. La apariencia, accesibilidad, firma y flujo manual final deben comprobarse en un Mac Apple Silicon.
