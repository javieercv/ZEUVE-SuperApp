# Entrega — ZEUVE 0.9.0

Fecha: 4 de agosto de 2026.

## Contenido

La entrega contiene el proyecto completo y actualizado de ZEUVE 0.9.0, build 28, con:

- código fuente de todos los módulos;
- Descargador universal 0.5.0 integrado;
- recursos y motores incluidos en la versión recibida;
- pruebas automáticas;
- scripts de preparación, verificación, compilación y empaquetado;
- proyecto Xcode regenerado;
- documentación, decisiones, changelog e informes.

## Protección del original

El ZIP `ZEUVE_Swift_0.8.0.zip` no se modifica. El trabajo se realiza sobre una copia separada y el resultado se publica como un nuevo ZIP con raíz única `ZEUVE_Swift_0.9.0`.

## Exclusiones del ZIP

El empaquetado limpio excluye `.build`, DerivedData, cachés, logs, temporales, `.DS_Store`, `__MACOSX`, `xcuserdata`, estados locales de Xcode, credenciales y archivos privados.

## Estado

Implementación completada en código y validada mediante las pruebas disponibles en Linux. El target del Descargador universal compila en configuración Release. La compilación Release completa fue interrumpida por el límite temporal del entorno y la compilación y apertura nativa permanecen pendientes de un Mac Apple Silicon, tal como se detalla en `Docs/TEST_RESULTS_0.9.0.md`.

## Limitaciones

- La compatibilidad real depende de yt-dlp y de la estructura de cada página.
- No se rastrean subpáginas.
- No existe navegador automatizado.
- No se elude DRM.
- No se han ejecutado descargas reales por Internet en esta entrega.
- No se incluye una `.app` compilada ni abierta.
