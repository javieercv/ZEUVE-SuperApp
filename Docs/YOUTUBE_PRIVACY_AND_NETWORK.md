# Privacidad y red del Descargador

## Cuándo se utiliza Internet

Solo tras una acción explícita:

- **Analizar**: obtiene metadatos y formatos.
- **Descargar**: obtiene los streams y archivos seleccionados.

Abrir ZEUVE, navegar por el módulo, consultar historial, presets o diagnóstico no inicia una operación de red.

## Destinos previsibles

La operación puede contactar con dominios gestionados por YouTube y Google para páginas, miniaturas y medios. Entre ellos pueden aparecer `youtube.com`, `youtu.be`, `ytimg.com` y `googlevideo.com`. Los nombres concretos pueden cambiar porque la infraestructura no la controla ZEUVE.

No se añaden servicios de analítica, publicidad, actualización, logs ni APIs externas.

## Datos enviados

- URL seleccionada por el usuario.
- Parámetros técnicos necesarios para la descarga.
- Cookies solo cuando el usuario selecciona expresamente un `cookies.txt`.
- Proxy solo cuando el usuario lo activa.

## Datos recibidos

- Metadatos del contenido.
- Formatos y subtítulos.
- Miniaturas.
- Streams multimedia.
- Mensajes de disponibilidad o restricción.

## Cookies

- Desactivadas por defecto.
- Solo archivo `cookies.txt` seleccionado manualmente.
- No se copia ni se modifica.
- No se recuerda su ruta.
- No se almacena en presets, historial o logs.
- No se muestran argumentos con la ruta.
- No se leen bases de datos de Safari, Chrome o Firefox.

## Proxy

- Desactivado por defecto.
- Solo afecta a la operación actual.
- No modifica el proxy de macOS.
- Las credenciales permanecen en memoria.
- No se guardan en Keychain, presets, historial o logs.

## Historial y logs

Se guardan IDs canónicos y títulos, no la URL completa. Se eliminan de cualquier registro:

- URLs de `googlevideo`;
- firmas y parámetros temporales;
- cookies y tokens;
- cabeceras privadas;
- usuario o contraseña del proxy;
- líneas de comando completas.

## JSON informativo

La opción visible no utiliza `--write-info-json`. ZEUVE genera un documento propio con campos limitados: ID, tipo, título, playlist, índice, modo, resumen de formato y fecha. El JSON de playlist contiene únicamente ID, índice, título y estado de los elementos seleccionados.
