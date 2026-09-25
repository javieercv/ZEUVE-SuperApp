# Comparador de seguidores de Instagram 0.1.0 — ZEUVE 0.20.5.0

## Identidad

- Nombre visible: **Comparador de seguidores de Instagram**.
- Identificador: `com.zeuve.instagram-followers`.
- Versión del módulo: `0.1.0`.
- ZEUVE mínimo declarado: `0.8.0`.
- Tecnología: Swift 6 y SwiftUI.
- Ejecución: módulo oficial `builtIn`.
- Dependencias nuevas: ninguna.

## Objetivo

El módulo compara una exportación concreta de Instagram y calcula:

- cuentas seguidas que no siguen al usuario;
- cuentas que siguen al usuario y que el usuario no sigue;
- seguimiento mutuo.

Los resultados representan el estado recogido por Meta al generar la exportación. No son una consulta en tiempo real.

## Entradas compatibles

### ZIP completo

El módulo inspecciona el catálogo del ZIP sin extraerlo por completo. Localiza por sufijo:

- `connections/followers_and_following/following.json`;
- `connections/followers_and_following/followers_<número>.json`.

Puede existir una carpeta raíz arbitraria. Debe existir exactamente un `following.json` y al menos un archivo de seguidores. Todos los `followers_*.json` se ordenan por su número y se aceptan huecos en la numeración.

### JSON separados

Modo avanzado para seleccionar:

- un `following.json`;
- uno o varios `followers_<número>.json`.

Los nombres incompatibles, secuencias duplicadas o archivos repetidos se rechazan antes del análisis.

## Interpretación JSON

Para cada relación se aplica este orden:

1. `string_list_data[].value`;
2. nombre extraído de `href`, incluida la ruta `/_u/`;
3. `title`;
4. `media_list_data` como compatibilidad heredada.

`following.json` debe contener un objeto con `relationships_following`. Los archivos de seguidores deben contener un array raíz. Se diferencian JSON malformados de JSON válidos con estructura incompatible. Un archivo vacío pero estructuralmente válido es aceptado.

## Normalización y comparación

- se eliminan espacios y `@` iniciales;
- la clave se compara sin distinguir mayúsculas;
- se conservan puntos y guiones bajos;
- se rechazan valores vacíos, URL completas y nombres incompatibles;
- se eliminan duplicados dentro de un archivo y entre varios archivos de seguidores;
- se conserva una representación visible del nombre de usuario.

## Seguridad ZIP

Se rechazan:

- rutas absolutas, traversal y componentes nulos;
- enlaces simbólicos;
- ZIP cifrados;
- entradas duplicadas o que solo difieren por mayúsculas;
- múltiples exportaciones mezcladas;
- profundidad excesiva;
- demasiadas entradas;
- tamaños comprimidos o descomprimidos excesivos;
- relaciones de compresión sospechosas;
- JSON relevantes por encima de los límites estructurales.

Solo se leen los JSON necesarios mediante libarchive. No se extrae el resto de la exportación.

## Interfaz

La pantalla de importación incluye:

- selector entre ZIP completo y JSON separados;
- selección mediante paneles nativos;
- arrastrar y soltar;
- catálogo previo de los archivos detectados;
- guía para solicitar la exportación a Meta;
- aviso de privacidad.

El análisis no comienza automáticamente. El usuario debe revisar el catálogo y pulsar **Analizar exportación**.

La pantalla de resultados incluye:

- totales de seguidos y seguidores;
- tres categorías seleccionables;
- búsqueda parcial con espera breve de 180 ms;
- orden A–Z o Z–A;
- estados vacíos;
- apertura manual del perfil público;
- aviso de que la exportación no representa necesariamente el estado actual.

La búsqueda y el orden trabajan sobre el resultado en memoria y no vuelven a abrir el ZIP ni los JSON.

## Exportación

Se admite TXT o CSV para:

- toda la categoría seleccionada;
- solo los resultados visibles tras la búsqueda.

El usuario ve el número de cuentas antes de elegir ubicación. El CSV contiene `username`, `category` y `url`. La escritura utiliza un archivo temporal en la carpeta elegida y publicación final segura. El reemplazo solo puede producirse tras la confirmación del panel nativo de macOS.

## Privacidad e historial

No se guardan permanentemente:

- nombres de usuario;
- listas;
- búsquedas;
- URLs de perfiles;
- rutas completas de entrada;
- contenido JSON.

El historial guarda únicamente fecha, tipo de entrada, número de archivos de seguidores, totales agregados, duración, advertencias y si se exportó algún resultado.

## Red

Todo funciona offline salvo **Abrir en Instagram**, que se ejecuta únicamente tras pulsar manualmente el botón de una cuenta. El módulo no declara permiso de red, no inicia sesión, no utiliza cookies, tokens, API, scraping ni navegador integrado.

## Cancelación y temporales

El análisis usa el coordinador global de operaciones. La cancelación se comprueba durante la lectura ZIP, interpretación y comparación. No se publican resultados parciales. No se crean copias permanentes ni se modifica ningún original.

## Fallo exclusivo de historial

Una comparación completada conserva sus resultados aunque falle únicamente el guardado del historial. La interfaz muestra un aviso en lugar de marcar la comparación como fallida y el log asociado conserva solo el tipo técnico del error, sin nombres de usuario, rutas ni listas. `OperationCoordinator` se finaliza igualmente.
