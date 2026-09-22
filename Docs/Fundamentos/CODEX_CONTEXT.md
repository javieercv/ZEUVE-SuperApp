# Contexto para Codex en ZEUVE 0.13.1.0

Este documento resume cómo se mantiene el contexto operativo del proyecto entre ChatGPT y Codex en la versión activa 0.13.1.0.

## Archivos que controlan el comportamiento

- `AGENTS.md`: instrucciones que Codex lee al arrancar dentro de esta versión.
- `SUPERAPP_PROJECT_RULES.md`: reglas permanentes del proyecto y flujo obligatorio de aprobacion.
- `PROJECT_DECISIONS.md`: decisiones aprobadas de producto, privacidad, plataforma, modulos y motores.
- `../../.agents/skills/`: skills locales del workspace para activar flujos repetibles de ZEUVE.

## Como mantener el contexto

`Docs/INDEX.md` es la entrada de la documentación: `Fundamentos/` contiene las reglas operativas, `Modulos/` la información de desarrollo y de cada herramienta, `Motores/` la documentación de los ejecutables locales y `Historico/` conserva las evidencias por versión. No añadas documentos sueltos a la raíz de `Docs`.

Cuando una conversacion de ChatGPT contenga una decision permanente, no la dejes solo en el chat. Conviertela en una de estas piezas:

- Una regla general en `SUPERAPP_PROJECT_RULES.md`.
- Una decision aprobada en `PROJECT_DECISIONS.md`.
- Alcance o exclusion funcional en `Docs/Fundamentos/FUNCTIONAL_SCOPE.md`.
- Guia tecnica en el documento del módulo correspondiente dentro de `Docs/Modulos/`.
- Skill local si es un flujo repetible que Codex debe ejecutar de forma consistente.

## Como trabajar con chats antiguos

Si quieres traer una conversacion antigua de ChatGPT, pega aqui solo el resumen durable:

- Decision aprobada.
- Motivo o restriccion importante.
- Archivos o modulos afectados.
- Comportamiento que debe preservarse.
- Pruebas o validaciones esperadas.

Evita pegar transcripciones completas salvo que sean necesarias para reconstruir una decision. Codex funciona mejor con reglas y decisiones condensadas que con historial largo.

## Estado actual 0.13.0

El contexto operativo debe reflejar siempre la carpeta activa y la documentación vigente de ZEUVE 0.13.1.0. `README.md` define el estado de la entrega y `PROJECT_DECISIONS.md` conserva tanto las decisiones actuales como las históricas, indicando expresamente cuándo una decisión posterior sustituye a otra.

La actualización de estos archivos de contexto no modifica por sí misma el producto, el código funcional, los scripts de build, los motores ni las reglas históricas. Su objetivo es que Codex detecte correctamente:

- cuál es la versión activa;
- qué documentos debe leer;
- qué decisiones siguen vigentes y cuáles son históricas;
- qué cambios requieren aprobación del usuario;
- qué flujos repetibles de ZEUVE existen como skills.

## Novedad 0.13.0

Inspector multimedia es el sexto módulo built-in. Su arquitectura y límites están en `Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md`. La inspección FFprobe común vive en `ZEUVEEngines/MediaInspection`.


## Versionado activo desde 0.13.1.0

La versión de aplicación usa cuatro componentes `MAJOR.MINOR.PATCH.REVISION`. No debe copiarse el cuarto componente a `MARKETING_VERSION`; el generador Xcode mantiene tres componentes y `ZEUVEReleaseRevision` aporta la revisión visible. Los manifests de módulos siguen usando SemVer de tres componentes.
