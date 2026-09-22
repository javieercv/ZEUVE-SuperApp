# Documentación de ZEUVE

Esta carpeta separa la documentación operativa —la que se consulta para diseñar, desarrollar, validar y mantener ZEUVE— de las evidencias históricas de cada entrega. Empieza aquí para localizar la fuente adecuada sin recorrer el historial.

## Consulta rápida

| Necesidad | Ubicación |
| --- | --- |
| Arquitectura, alcance, seguridad, compilación y pruebas | `Fundamentos/` |
| Desarrollo de módulos, API, checklist y plantillas | `Modulos/Desarrollo/` |
| Comportamiento y límites de cada módulo integrado | `Modulos/Funcionales/` |
| Preparación, empaquetado y gestión de motores | `Motores/` |
| Ejemplos JSON del contrato de módulos | `Modulos/Ejemplos/` |
| Entregas, informes de implementación, resultados de QA, hashes y compatibilidad de versiones anteriores | `Historico/` |

## Documentación vigente

- [Fundamentos](Fundamentos/): arquitectura, alcance funcional, seguridad, compilación, pruebas y contexto de trabajo.
- [Desarrollo de módulos](Modulos/Desarrollo/): guía, API, checklist, ejemplos documentados e instrucciones para asistentes.
- [Documentación funcional de módulos](Modulos/Funcionales/): Organizador/limpiador, descargador, conversor, analizador de chats, comparador de Instagram e Inspector multimedia.
- [Motores](Motores/): gestión y empaquetado de motores, además de las rutas legacy que se mantienen como referencia de compatibilidad.

## Histórico

Los documentos de `Historico/` conservan su contenido como registro de su entrega original. No deben usarse como especificación vigente cuando exista una fuente equivalente en `Fundamentos/`, `Modulos/` o `Motores/`.

- `Entregas/`: notas de entrega por versión.
- `Implementacion/`: informes de implementación por versión.
- `Pruebas/`: resultados de pruebas por versión.
- `HashesMotores/`, `Compatibilidad/` e `Informes/`: evidencias técnicas y reportes puntuales.

## Convención para nueva documentación

1. Coloca documentación operativa en la categoría temática correspondiente, no en la raíz de `Docs`.
2. Conserva los nombres de archivos estables y descriptivos; las rutas se enlazan desde este índice y desde los documentos de contexto.
3. Para una entrega, añade sus evidencias a las subcarpetas pertinentes de `Historico/`.
4. Actualiza este índice y las referencias de entrada (`README.md` y `AGENTS.md`) cuando se añada una categoría o una fuente de consulta principal.
