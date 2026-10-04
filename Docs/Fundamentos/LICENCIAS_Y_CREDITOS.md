# Licencias y créditos — ZEUVE 0.20.6.0

Este documento explica cómo se separan el código propio de ZEUVE, los componentes del sistema y el software de terceros utilizado o empaquetado por el proyecto.

La lista consolidada de software de terceros y sus avisos se mantiene en [`../../THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md). Los textos legales originales se conservan en [`../../Resources/Engines/licenses/`](../../Resources/Engines/licenses/).

## 1. Código propio de ZEUVE

El repositorio contiene el código específico de ZEUVE: aplicación, módulos, contratos internos, almacenamiento, coordinación de operaciones, integración de motores, UI, pruebas y scripts propios del proyecto.

Actualmente **no existe un archivo `LICENSE` general para ZEUVE**. Por tanto, esta documentación no elige ni presupone una licencia para el código propio del proyecto. Esa decisión queda reservada al propietario de ZEUVE.

Crear en el futuro un `LICENSE`, cambiar el modelo de licencia o definir condiciones de redistribución del código propio será una decisión independiente y explícita. No debe hacerse como consecuencia automática de que el repositorio sea público o de que ZEUVE use componentes open source.

## 2. Software del sistema

ZEUVE es una aplicación nativa para macOS y utiliza tecnologías del sistema de Apple, entre ellas Swift, SwiftUI, AppKit y Foundation.

La configuración SwiftPM actual no declara paquetes Swift remotos de terceros. Sí existen targets de tipo `systemLibrary` para enlazar con bibliotecas proporcionadas por el sistema:

- `CSQLite` → SQLite del sistema;
- `CLibArchive` → libarchive del sistema.

Estos componentes se distinguen de los motores externos que ZEUVE empaqueta bajo `Resources/Engines/`.

## 3. Motores y componentes de terceros

La fuente canónica de motores empaquetables es [`../../Resources/Engines/engines.json`](../../Resources/Engines/engines.json). En la instantánea actual figuran como requeridos:

- yt-dlp;
- Deno;
- FFmpeg;
- FFprobe;
- gallery-dl;
- instaloader-zeuve.

Pandoc puede incorporarse como motor opcional del Conversor cuando la preparación aprobada lo incluya. Calibre, Ghostscript y LibreOffice están retirados de la configuración vigente.

Las versiones concretas, propósito, procedencia y archivo de licencia de cada motor deben obtenerse del registry real, no de una lista paralela mantenida manualmente.

## 4. Dónde están las licencias

La estructura documental es deliberadamente separada:

- [`../../THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md): inventario consolidado, créditos y referencias rápidas;
- [`../../Resources/Engines/licenses/`](../../Resources/Engines/licenses/): textos completos de licencia y avisos upstream;
- [`../../Resources/Engines/engines.json`](../../Resources/Engines/engines.json): versión, procedencia, propósito y `licenseFile` de los motores registrados;
- [`../Motores/`](../Motores/): preparación, empaquetado, firma y gestión operativa de motores.

Los textos upstream no deben reescribirse para “adaptarlos” a ZEUVE. Se conservan como documentos de sus respectivos proyectos.

## 5. Créditos

ZEUVE utiliza o puede empaquetar software desarrollado por terceros. Entre los proyectos principales se encuentran FFmpeg/FFprobe, yt-dlp, Deno, gallery-dl e Instaloader.

También se conservan avisos de componentes que pueden formar parte de bundles o compilaciones, como browser-cookie3, LAME, libwebp, Opus y x264.

Los autores, contribuidores, copyrights, marcas y nombres de dichos proyectos siguen perteneciendo a sus respectivos titulares. ZEUVE no presenta esos componentes como código propio.

La relación detallada y los enlaces a sus licencias se mantienen en [`../../THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md).

## 6. FFmpeg requiere una comprobación especial

FFmpeg puede distribuirse bajo términos distintos según las opciones de compilación y las bibliotecas externas activadas. La documentación upstream conservada en el repositorio distingue entre configuraciones LGPL y configuraciones que activan GPL u otras condiciones.

El registry actual de ZEUVE referencia `licenses/ffmpeg/COPYING.GPLv2` para FFmpeg y FFprobe. Por ello, antes de una distribución debe verificarse la configuración real del binario y las bibliotecas enlazadas, y comprobar que los avisos y obligaciones de redistribución corresponden exactamente a esa compilación.

No debe cambiarse la configuración de FFmpeg, añadir una biblioteca o sustituir el binario sin revisar al mismo tiempo las implicaciones de licencia y empaquetado.

## 7. Código generado o asistido por IA

El uso de herramientas como ChatGPT o Codex para ayudar a crear, revisar o modificar código no convierte automáticamente el código resultante en una dependencia externa del proyecto ni sustituye la obligación de revisar su procedencia.

Cuando se incorpore código tomado o adaptado expresamente de una fuente externa identificable, debe registrarse su procedencia y licencia si corresponde. Las soluciones generadas específicamente para ZEUVE deben seguir sometiéndose a revisión técnica y de procedencia cuando exista alguna duda razonable.

Esta distinción es importante: **inspirarse en una función, flujo o patrón de UX no equivale a incorporar el código fuente de otro proyecto**. Si se incorpora material literal o adaptado de un tercero, sí debe quedar documentado.

## 8. Recursos, iconos, tipografías y otros materiales

El inventario actual se centra principalmente en código, motores y bibliotecas. No debe asumirse que un recurso visual o documental queda cubierto por la licencia de un motor.

Si en el futuro se añaden:

- iconos de terceros;
- tipografías no suministradas por el sistema;
- imágenes, sonidos o vídeos;
- plantillas;
- datasets;
- fragmentos de código adaptados;
- documentación reproducida de otra fuente;

se debe registrar su origen, autoría y condiciones de uso antes de una distribución pública o comercial.

## 9. Regla de mantenimiento

Cuando se añada, retire o actualice un componente externo, la misma modificación debe revisar, según corresponda:

1. `Resources/Engines/engines.json`;
2. `Resources/Engines/licenses/`;
3. `THIRD_PARTY_NOTICES.md`;
4. la documentación de motores afectada;
5. los scripts de preparación, verificación y empaquetado;
6. la evidencia de entrega cuando se prepare una versión distribuible.

Una limpieza del proyecto no puede borrar avisos o textos de licencia necesarios para los componentes que sigan distribuyéndose.

## 10. Qué falta decidir

El punto pendiente más importante es la **licencia del propio proyecto ZEUVE**. Hasta que el propietario la decida, no se añadirá un `LICENSE` general ni se declarará ZEUVE como MIT, GPL, Apache, propietario u otra modalidad.

Cuando se tome esa decisión deberá revisarse su compatibilidad con la forma concreta en que se distribuyen los componentes de terceros, especialmente los componentes copyleft incluidos en los motores empaquetados.

## 11. Alcance de esta documentación

Este documento y `THIRD_PARTY_NOTICES.md` son un inventario técnico y de cumplimiento documental basado en el repositorio actual. Ayudan a mantener trazabilidad, atribuciones y textos de licencia, pero no sustituyen asesoramiento jurídico específico para una futura distribución comercial o pública.
