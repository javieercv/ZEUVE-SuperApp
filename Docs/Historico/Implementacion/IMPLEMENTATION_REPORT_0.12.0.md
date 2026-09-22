# Informe de implementación — ZEUVE 0.12.0

## Resultado

El Descargador universal deja en manos del usuario la definición de «Por defecto de la plataforma». Ajustes incorpora una sección Plataformas donde se editan los perfiles de los orígenes integrados y se crean reglas propias para otros dominios.

## Modelo y resolución

- `UniversalDownloadProfiles` almacena perfiles incorporados y reglas personalizadas con un esquema Codable local.
- Los valores de fábrica se usan para instalaciones nuevas y restauración: YouTube comienza en MP3 a 320 kb/s; los demás orígenes conservan el original de máxima calidad.
- La primera migración copia los valores generales existentes a los perfiles incorporados, evitando modificar preferencias previas.
- La precedencia es manual, dominio personalizado, plataforma incorporada, página web y fábrica.
- El host más específico gana y la coincidencia de subdominios es una elección explícita por regla.
- El plan de descarga captura ajustes por elemento para que los lotes mixtos y las operaciones en curso sean estables.

## Interfaz y privacidad

La nueva pantalla permite seleccionar una plataforma incorporada, editar sus opciones, aplicar un preset y restaurar una o todas. Las reglas personalizadas se crean mediante nombre opcional, enlace o dominio e inclusión de subdominios; después pueden editarse, desactivarse o eliminarse.

Solo se guarda el dominio normalizado. Rutas, consultas, fragmentos, credenciales, puertos y URLs firmadas se descartan. Las reglas no contienen sesiones, cookies, proxy, carpeta de salida ni selecciones exactas de pistas.

## Compatibilidad y entrega

No se añaden motores, paquetes, servicios, permisos ni APIs. La aplicación queda en ZEUVE 0.12.0, build 42, con Descargador universal 0.7.0, dentro de la carpeta activa original y sin generar ZIP.
