# Flujo de repositorio — ZEUVE

Este documento define la política permanente de sincronización, trabajo y publicación del repositorio de ZEUVE. Complementa `SUPERAPP_PROJECT_RULES.md` y se aplica a cualquier agente, chat, Codex o entorno de desarrollo que modifique el proyecto.

## Principio obligatorio

El repositorio remoto de ZEUVE debe mantenerse como punto común de continuidad entre trabajos.

**Antes de empezar cualquier trabajo sobre el proyecto, debe obtenerse y comprobarse la última versión disponible del repositorio remoto. Al terminar un trabajo que haya producido cambios, esos cambios deben quedar publicados de nuevo en el repositorio remoto después de las verificaciones correspondientes.**

Esta regla se aplica también a cambios únicamente documentales, scripts, pruebas, contexto de agentes y mantenimiento interno.

## Antes de empezar

1. Identificar el repositorio y la rama de trabajo correctos.
2. Consultar el estado remoto y obtener la versión más reciente antes de analizar o modificar archivos.
3. Si se trabaja en una copia local existente, comprobar primero su estado y preservar cualquier cambio local no comprometido. Nunca ejecutar una actualización que descarte trabajo existente.
4. Sincronizar la copia local con el remoto mediante un avance seguro. No forzar una actualización si existen divergencias o cambios locales que puedan perderse.
5. Registrar o poder identificar el commit de partida para saber exactamente sobre qué estado se realizó el trabajo.
6. Solo después de esta sincronización deben inspeccionarse los archivos reales, preparar el plan y, cuando proceda, comenzar la implementación tras la aprobación del usuario.

Si no es posible acceder al repositorio remoto, no debe afirmarse que se está trabajando sobre la última versión. Para modificar el proyecto en esas condiciones se requiere una instrucción expresa del usuario que autorice trabajar temporalmente sobre una copia concreta.

Si el usuario proporciona un ZIP o una carpeta diferente, primero debe comprobarse el estado actual del repositorio. Una copia proporcionada por el usuario solo sustituye al repositorio como fuente de verdad cuando el usuario lo indique expresamente o cuando se confirme que contiene cambios posteriores que todavía no están publicados.

## Durante el trabajo

- Trabajar sobre la copia sincronizada y mantener una única carpeta activa del proyecto.
- No borrar, resetear ni sobrescribir cambios locales o remotos ajenos al encargo.
- No usar `force-push`, no reescribir historial compartido y no mover referencias remotas de forma destructiva sin autorización expresa del usuario.
- No aprovechar una tarea para subir cambios no relacionados.
- Mantener los commits limitados a bloques lógicos y describir con claridad su contenido.
- Si durante el trabajo se detecta que el remoto ha cambiado de forma relevante, revisar esos cambios antes de continuar cuando puedan afectar al área en curso.

## Antes de publicar el resultado

Después de implementar y ejecutar las pruebas o verificaciones posibles:

1. Comprobar de nuevo el estado del repositorio remoto.
2. Confirmar que no han aparecido commits nuevos desde el punto de partida que entren en conflicto con el trabajo realizado.
3. Si existen cambios remotos nuevos, integrarlos de forma segura antes de publicar. Nunca sobrescribirlos para imponer la copia local.
4. Revisar el diff final y confirmar que solo contiene cambios pertenecientes al encargo aprobado.
5. Ejecutar las pruebas y verificadores aplicables después de cualquier integración necesaria.
6. Crear el commit o los commits correspondientes si el entorno trabaja mediante Git local.
7. Subir el resultado al repositorio remoto.
8. Verificar que el commit final está realmente presente en el remoto.

Una tarea con cambios no se considera entregada mientras el resultado mantenido no haya quedado actualizado en el repositorio remoto, salvo que exista una imposibilidad técnica declarada o el usuario haya indicado expresamente que no desea publicar todavía.

## Casos sin cambios

Una revisión, auditoría o consulta que no modifique archivos también debe partir de la última versión del repositorio. Si no se producen cambios, no es necesario crear un commit vacío ni realizar un push.

## Entornos con integración directa de GitHub

Cuando el entorno edita GitHub mediante una integración o API en lugar de una copia Git local, la misma regla se aplica conceptualmente:

- volver a obtener el estado remoto actual antes de editar;
- usar los identificadores/SHA actuales de los archivos o commits para impedir sobrescrituras accidentales;
- no escribir sobre una versión que haya cambiado desde la lectura;
- comprobar el repositorio después de la escritura y confirmar que el cambio quedó publicado.

En este caso, una escritura confirmada directamente sobre el repositorio remoto equivale a la fase de commit/push, pero no elimina la obligación de comprobar primero la versión actual.

## Commits e historial

- Los mensajes de commit deben ser breves y descriptivos.
- Los cambios distintos deben separarse cuando ello mejore la trazabilidad; no es obligatorio crear un commit por archivo.
- No se crean commits vacíos únicamente para registrar que se realizó una revisión.
- No se modifica, aplasta, rebasea ni fuerza historial remoto ya compartido sin autorización expresa.
- Las ramas, pull requests o estrategias de integración adicionales pueden utilizarse cuando el trabajo o el usuario lo requieran, pero esta política no obliga a crear una rama para cada cambio.

## Informe final

Cuando se hayan realizado cambios, el informe final debe indicar como mínimo:

- que el trabajo partió del estado remoto actualizado;
- si se detectaron o integraron cambios remotos durante el trabajo;
- que los cambios finales fueron publicados en el repositorio;
- el commit final o identificador equivalente cuando esté disponible;
- cualquier limitación que haya impedido sincronizar, probar o publicar.

No debe afirmarse que el repositorio está actualizado si no se ha verificado realmente.