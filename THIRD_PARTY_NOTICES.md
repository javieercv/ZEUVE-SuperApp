# ZEUVE — Avisos de software de terceros

Este documento reúne los avisos y referencias de licencia del software de terceros que ZEUVE puede incluir o utilizar en su distribución actual.

**Estado documental:** ZEUVE 0.20.7.0.

> La fuente técnica de verdad sobre los motores empaquetables es [`Resources/Engines/engines.json`](Resources/Engines/engines.json). Los textos legales completos se conservan en [`Resources/Engines/licenses/`](Resources/Engines/licenses/). Este archivo sirve como índice y aviso consolidado; no sustituye los textos de licencia originales.

## Alcance y licencia del código propio de ZEUVE

Este archivo **no concede una licencia sobre el código propio de ZEUVE**.

Actualmente el repositorio no declara una licencia general del proyecto mediante un archivo `LICENSE`. La elección de una licencia para el código propio de ZEUVE queda pendiente de una decisión expresa del propietario del proyecto. Hasta que exista esa decisión, los avisos siguientes se limitan al software de terceros y a sus respectivas condiciones.

La disponibilidad pública del repositorio y este inventario de terceros no deben interpretarse como una modificación de los derechos aplicables al código propio de ZEUVE.

## Motores externos de la instantánea actual

| Componente | Versión registrada | Uso en ZEUVE | Licencia/aviso conservado | Texto completo |
| --- | --- | --- | --- | --- |
| **yt-dlp** | 2026.08.19 | Análisis y descarga de contenido público o autorizado desde plataformas compatibles | Unlicense para el proyecto principal; el bundle conserva además avisos de sus dependencias | [`LICENSE`](Resources/Engines/licenses/yt-dlp/LICENSE) · [`THIRD_PARTY_LICENSES.txt`](Resources/Engines/licenses/yt-dlp/THIRD_PARTY_LICENSES.txt) |
| **Deno** | 2.9.0 | Ejecución de los desafíos JavaScript que yt-dlp puede requerir para YouTube | MIT | [`LICENSE.md`](Resources/Engines/licenses/deno/LICENSE.md) |
| **FFmpeg** | 8.1.2 | Procesamiento, conversión y edición multimedia | La licencia efectiva depende de la configuración de compilación. El registro actual referencia GPL v2 y ZEUVE conserva la documentación upstream correspondiente | [`COPYING.GPLv2`](Resources/Engines/licenses/ffmpeg/COPYING.GPLv2) · [`LICENSE.md`](Resources/Engines/licenses/ffmpeg/LICENSE.md) |
| **FFprobe** | 8.1.2 | Inspección y validación multimedia | Forma parte de la misma compilación/licenciamiento de FFmpeg | [`COPYING.GPLv2`](Resources/Engines/licenses/ffmpeg/COPYING.GPLv2) · [`LICENSE.md`](Resources/Engines/licenses/ffmpeg/LICENSE.md) |
| **gallery-dl** | 1.32.9 | Descarga de fotografías, vídeos, carruseles, álbumes y galerías compatibles | GNU GPL v2 | [`LICENSE`](Resources/Engines/licenses/gallery-dl/LICENSE) |
| **instaloader-zeuve** | 4.15.3-zeuve.2 | Resolución de publicaciones y contenido compatible de Instagram | Basado en Instaloader; licencia MIT del proyecto upstream incluida | [`LICENSE`](Resources/Engines/licenses/instaloader/LICENSE) |

Las versiones y rutas anteriores se corresponden con la instantánea registrada actualmente en `Resources/Engines/engines.json`. Si cambia el registro, este documento debe revisarse en la misma modificación documental.

## Licencias adicionales conservadas con los bundles o compilaciones

La carpeta de licencias contiene además avisos de componentes que pueden formar parte de bundles, dependencias transitivas o compilaciones de los motores anteriores. Su presencia documental no implica por sí sola que cada componente esté cargado directamente por el código Swift de ZEUVE.

| Componente | Licencia identificada en el texto conservado | Texto completo |
| --- | --- | --- |
| **browser-cookie3** | GNU LGPL v3 | [`LICENSE`](Resources/Engines/licenses/browser-cookie3/LICENSE) |
| **LAME** | GNU Library General Public License v2 | [`COPYING`](Resources/Engines/licenses/lame/COPYING) |
| **libwebp** | licencia permisiva tipo BSD | [`COPYING`](Resources/Engines/licenses/libwebp/COPYING) |
| **Opus** | licencia permisiva tipo BSD | [`COPYING`](Resources/Engines/licenses/opus/COPYING) |
| **x264** | GNU GPL v2 | [`COPYING`](Resources/Engines/licenses/x264/COPYING) |

En particular, FFmpeg puede cambiar de régimen de licencia según las opciones y bibliotecas activadas durante su compilación. Por ello, para una distribución final no debe deducirse la licencia únicamente del nombre «FFmpeg»: deben comprobarse la configuración real del binario, las bibliotecas enlazadas y los textos que acompañan a esa compilación.

## Componentes opcionales

**Pandoc** continúa soportado por el Conversor como motor opcional, pero no figura en la instantánea requerida actual de `Resources/Engines/engines.json`. Si una entrega incorpora Pandoc u otro motor opcional, su versión, procedencia y licencia deben registrarse antes de distribuir esa entrega y su texto de licencia debe acompañar al componente.

Calibre, Ghostscript y LibreOffice están retirados de la configuración actual de ZEUVE y no forman parte de este inventario vigente.

## Frameworks y bibliotecas del sistema

ZEUVE utiliza APIs y frameworks del sistema de Apple, entre ellos Swift, SwiftUI, AppKit y Foundation. `Package.swift` no declara paquetes Swift remotos de terceros en la instantánea actual.

El proyecto sí contiene puentes de sistema para utilizar las bibliotecas disponibles en macOS, entre ellas SQLite (`CSQLite`) y libarchive (`CLibArchive`). Estos puentes deben distinguirse de los motores externos que ZEUVE empaqueta dentro de `Resources/Engines/`.

## Créditos de proyectos externos

ZEUVE reconoce y agradece el trabajo de los proyectos y comunidades cuyos componentes hacen posibles determinadas funciones de la aplicación, entre ellos:

- [FFmpeg](https://ffmpeg.org/) y FFprobe;
- [yt-dlp](https://github.com/yt-dlp/yt-dlp);
- [Deno](https://deno.com/);
- [gallery-dl](https://github.com/mikf/gallery-dl);
- [Instaloader](https://instaloader.github.io/);
- los autores y contribuidores de las bibliotecas incluidas en los bundles o compilaciones de dichos motores.

Las marcas, nombres de proyectos y copyrights pertenecen a sus respectivos titulares. Su inclusión aquí es únicamente informativa y de atribución.

## Reglas para futuras entregas

Antes de distribuir una nueva versión de ZEUVE debe comprobarse, como mínimo, que:

1. `Resources/Engines/engines.json` refleja exactamente los motores y versiones realmente empaquetados.
2. Cada motor distribuido conserva el texto de licencia y los avisos que le correspondan.
3. `Resources/Engines/licenses/` se empaqueta junto con los motores cuando la entrega incluya dichos componentes.
4. Las dependencias transitivas y bibliotecas enlazadas de cada binario están identificadas y cubiertas por los avisos correspondientes.
5. La configuración real de FFmpeg/FFprobe se revisa junto con sus obligaciones de redistribución; no se asume una licencia genérica independiente de la compilación.
6. Cualquier componente opcional incorporado a una entrega se añade también a este inventario.
7. La limpieza del repositorio o del paquete nunca elimina licencias, avisos o atribuciones que sigan siendo necesarios.
8. Si se incorporan recursos gráficos, tipografías, plantillas, código adaptado u otros materiales de terceros, su procedencia y condiciones deben añadirse a la documentación antes de distribuirlos.

## Fuentes documentales relacionadas

- [`Docs/Fundamentos/LICENCIAS_Y_CREDITOS.md`](Docs/Fundamentos/LICENCIAS_Y_CREDITOS.md)
- [`Resources/Engines/README.md`](Resources/Engines/README.md)
- [`Docs/Motores/UNIVERSAL_DOWNLOADER_ENGINE_PACKAGING.md`](Docs/Motores/UNIVERSAL_DOWNLOADER_ENGINE_PACKAGING.md)
- [`Docs/Motores/ENGINE_MANAGEMENT.md`](Docs/Motores/ENGINE_MANAGEMENT.md)
- [`Resources/Engines/engines.json`](Resources/Engines/engines.json)

Este documento es un inventario técnico y documental del proyecto. No sustituye una revisión jurídica cuando ZEUVE vaya a distribuirse públicamente o comercialmente bajo unas condiciones concretas.
