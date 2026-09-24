# Organizador de archivos

## Estado

`OrganizerModule` 0.1.4 forma parte de ZEUVE como módulo built-in para macOS. Su identificador estable es `com.zeuve.organizer`, pertenece a la categoría visible **Archivos** y su atajo predeterminado es `⌘1`.

El módulo trabaja sobre una carpeta elegida explícitamente por el usuario. Genera primero una vista previa completa y solo mueve los elementos seleccionados después de una confirmación.

## Objetivo

El Organizador clasifica archivos por categoría y formato, permite revisar el plan antes de ejecutarlo y evita sobrescrituras silenciosas.

Su flujo principal es:

```text
carpeta seleccionada
        ↓
análisis y clasificación
        ↓
vista previa revisable
        ↓
selección de operaciones
        ↓
confirmación
        ↓
revalidación
        ↓
movimiento seguro
        ↓
historial / deshacer
```

## Interfaz

La vista principal permite:

- seleccionar una carpeta mediante selector nativo;
- arrastrar una carpeta sobre la herramienta;
- reutilizar carpetas recientes;
- elegir nivel de organización;
- activar o desactivar la agrupación de archivos relacionados;
- incluir subcarpetas;
- configurar la política de conflictos;
- incluir archivos y carpetas ocultos;
- analizar la carpeta y revisar la vista previa;
- seleccionar o excluir operaciones antes de ejecutar;
- exportar la planificación a CSV;
- cancelar una operación en curso;
- abrir la carpeta al terminar;
- deshacer una organización válida desde el resultado o el historial.

Las preferencias persistentes del módulo se administran desde los Ajustes centralizados de ZEUVE. Las opciones de la operación actual permanecen en la herramienta.

## Niveles de organización

### Simple

Agrupa los archivos únicamente por categoría general.

Ejemplos:

```text
Imágenes/foto.jpg
Documentos/manual.pdf
Audio/cancion.flac
```

### Detallado

Añade una carpeta de formato dentro de la categoría.

Ejemplos:

```text
Imágenes/JPG-JPEG/foto.jpg
Documentos/PDF/manual.pdf
Audio/FLAC/cancion.flac
```

Las reglas incorporadas cubren imágenes, vídeo, audio, documentos, datos, comprimidos, instaladores, código, diseño y fuentes. Las extensiones sin regla conocida se clasifican en **Otros** usando su extensión; los archivos sin extensión usan `SIN_EXTENSION`.

También pueden existir reglas personalizadas persistidas en los Ajustes del Organizador.

## Archivos relacionados

Cuando **Agrupar archivos con el mismo nombre** está activo, archivos con el mismo nombre base y extensiones distintas pueden mantenerse juntos.

Si pertenecen a la misma categoría:

```text
proyecto.pdf
proyecto.docx
        ↓
Documentos/proyecto/
```

Si pertenecen a categorías distintas:

```text
portada.pdf
portada.png
        ↓
Relacionados/portada/
```

La agrupación puede desactivarse para que cada archivo siga únicamente su clasificación normal.

## Carpetas y análisis recursivo

Por defecto se analiza la carpeta seleccionada. La opción **Incluir subcarpetas** permite recorrer también su contenido interno.

El Organizador:

- no sigue enlaces simbólicos;
- no recorre paquetes de macOS como aplicaciones, bundles, frameworks o fototecas;
- evita volver a procesar sus propias carpetas de categorías cuando trabaja recursivamente desde la raíz seleccionada;
- puede omitir archivos y carpetas ocultos;
- ignora determinados archivos de sistema y temporales.

Las ubicaciones críticas del sistema, como `/`, `/System`, `/Library`, `/Applications`, `/usr`, `/bin`, `/sbin` y `/private`, no se aceptan como carpetas organizables.

## Conflictos

El Organizador nunca sobrescribe silenciosamente un archivo existente.

Las políticas disponibles son:

- **Renombrar automáticamente**: busca un nombre libre seguro, por ejemplo `foto_2.jpg`;
- **Omitir**: excluye el archivo conflictivo del plan;
- **Revisar conflictos**: mantiene el conflicto visible para su revisión antes de ejecutar.

El destino se vuelve a comprobar al ejecutar. Si aparece un archivo nuevo después de generar la vista previa, la operación se detiene antes de sobrescribirlo.

## Protección de archivos

Cada operación conserva un fingerprint del archivo de origen generado durante la planificación.

Antes de mover archivos, el ejecutor comprueba que el plan sigue siendo válido. Si un origen ha cambiado desde la vista previa, el plan se invalida y no se ejecuta parcialmente.

La ejecución crea únicamente las carpetas necesarias y mueve los archivos seleccionados. No elimina ni reemplaza archivos existentes como mecanismo de resolución de conflictos.

## Cancelación y rollback

El análisis y la ejecución son cancelables y respetan `OperationCoordinator`.

Si una ejecución se cancela después de haber movido algunos archivos, el Organizador intenta revertir los movimientos completados antes de devolver el control. No deja deliberadamente una operación a medias como estado normal.

## Historial y deshacer

Las operaciones completadas se integran en el historial de ZEUVE.

El Undo es verificable:

- comprueba que el archivo organizado sigue siendo el mismo;
- no restaura sobre una ruta original ocupada;
- no sobrescribe archivos nuevos;
- conserva carpetas creadas por ZEUVE si contienen elementos ajenos;
- marca la operación como no deshacible cuando ya no puede revertirse de forma segura.

Un fallo secundario al guardar el historial no convierte en fallida una organización que ya terminó correctamente; se informa mediante una advertencia controlada.

## CSV de planificación

La vista previa puede exportarse a CSV. El archivo distingue operaciones incluidas y excluidas para que el usuario pueda revisar o conservar el plan fuera de la aplicación.

Exportar el plan no mueve archivos ni modifica la carpeta analizada.

## Permisos declarados

El manifiesto del módulo declara únicamente:

- `readUserSelectedFiles`;
- `writeUserSelectedFolder`;
- `openExternalApplications`.

No existe acceso de red como parte del Organizador.

## Integración

El módulo utiliza:

- `OrganizerModule` para modelos, reglas, planificación, ejecución e historial;
- `ZEUVEApp/Organizer` para ViewModel e interfaz SwiftUI;
- `ZEUVEOperations` para coordinación de operaciones pesadas;
- `ZEUVEStorage` para preferencias e historial;
- `BuiltInModuleCatalog` para identidad, navegación, Ajustes, historial y atajo.

Las claves persistentes propias del módulo se concentran en `OrganizerStorageKeys`.

## Garantías cubiertas por pruebas

Las pruebas actuales cubren, entre otros casos:

- clasificación simple y detallada;
- equivalencias de extensiones;
- agrupación de relacionados;
- reglas personalizadas;
- carpetas grandes;
- conflictos y renombrado seguro;
- recorrido recursivo;
- archivos ocultos y temporales;
- symlinks y paquetes de macOS;
- invalidación por cambios posteriores a la vista previa;
- aparición de destinos conflictivos;
- cancelación antes y durante la ejecución;
- rollback de movimientos completados;
- Undo seguro;
- preservación de contenido ajeno;
- exportación CSV;
- persistencia separada entre defaults y opciones legacy.
