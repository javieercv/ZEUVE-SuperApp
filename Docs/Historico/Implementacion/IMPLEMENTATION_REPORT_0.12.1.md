# Informe de implementación — ZEUVE 0.12.1

## Resultado

El preset incluido «Mejor calidad compatible» utiliza «Original sin convertir» en todo el Descargador universal. Esto permite aplicarlo indistintamente a fotografías, vídeos, audio, galerías y carruseles sin convertirlos a un tipo de contenido distinto.

## Migración

El esquema de presets pasa de 2 a 3. Al cargar los ajustes, ZEUVE reconoce la copia incluida antigua por su nombre y su configuración de vídeo genérico y modifica únicamente su modo a Original. Conserva identificador, favorito, resto de opciones y posición en la lista.

Los presets personales con otro nombre se migran de esquema sin cambiar sus ajustes. Una configuración llamada «Mejor calidad compatible» pero diferenciada mediante una resolución concreta tampoco se confunde con la antigua copia incluida.

## Presets específicos

«Vídeo 1080p», «Vídeo 720p» y «Vídeo con subtítulos en español» fijan expresamente el modo Vídeo. «Colección completa» hereda Original para conservar todos sus tipos de contenido.

No se añaden dependencias, motores, permisos, conexiones ni cambios de privacidad. ZEUVE queda en 0.12.1, build 43, y el Descargador universal en 0.7.1.
