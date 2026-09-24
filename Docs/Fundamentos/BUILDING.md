# Compilación para macOS — ZEUVE 0.20.2.0

## Validación adicional requerida por Inspector multimedia 0.7.2

Además de las regresiones existentes, validar manualmente en macOS la respuesta de Play/Pausa, seek, saltos y cambio de pista con audio, vídeo y A/V, comprobando que no reaparecen saltos de identidad, frames perdidos ni procesos FFmpeg huérfanos.

## Validación heredada de Inspector multimedia 0.7.1

La entrega conserva FFmpeg/FFprobe `8.1.2`; no cambia su preparación, firma ni packaging. El preview puede aprovechar VideoToolbox ya habilitado en el FFmpeg empaquetado y debe degradar a software si el stream/hardware no es compatible. No se incorpora libass, por lo que ASS/SSA avanzado no forma parte de la garantía visual.

Además de la suite portable, una entrega definitiva debe validarse en macOS Apple Silicon con Xcode para comprobar SwiftUI/AppKit, `AVAudioEngine`, `CVPixelBuffer`/superficie de vídeo, VideoToolbox, Vision OCR, fullscreen, reproducción A/V, motores Mach-O ARM64, Hardened Runtime, firma y publicación final. Un PASS en Linux no sustituye esas comprobaciones.

El proyecto Xcode debe regenerarse con `python3 Scripts/generate_xcode_project.py`; para 0.20.2.0 el marketing version es `0.20.2`, `CURRENT_PROJECT_VERSION` es `68`, el manifest del Inspector es `0.7.2` y el del Limpiador es `0.1.0`.

## Entorno objetivo

- macOS 14 Sonoma o posterior.
- Apple Silicon ARM64.
- Xcode compatible con Swift 6.
- Hardened Runtime activado.
- App Sandbox desactivado en esta etapa.

## Motores incluidos y opcionales

La copia fuente registra los motores locales bajo `Resources/Engines/`. yt-dlp, Deno, FFmpeg, FFprobe, gallery-dl e instaloader-zeuve son obligatorios. La compilación valida lo incluido localmente y no prepara motores en segundo plano.

Pandoc 3.10 permanece como motor opcional del Conversor para TXT, Markdown y HTML. Calibre y Ghostscript están retirados: ningún script debe descargarlos, registrarlos, firmarlos o copiarlos a la aplicación.

## Preparación

```bash
bash Scripts/prepare_engines_macos.sh
bash Scripts/verify_engines_macos.sh Resources/Engines
```

La preparación general:

- usa versiones fijadas y artefactos verificados;
- compila FFmpeg/FFprobe 8.1.2 con libmp3lame, libopus, libx264 y libwebp estáticos;
- puede incorporar Pandoc 3.10 si el artefacto local está disponible;
- actualiza `engines.json` con rutas, versiones, hashes, tamaños, licencias y disponibilidad reales;
- publica el conjunto únicamente después de superar la verificación;
- no prepara Calibre ni Ghostscript.

La preparación social se ejecuta manualmente con `Scripts/prepare_social_engines_macos.sh`; tanto `build_macos.sh` como Xcode detienen la compilación si esos ejecutables faltan o están obsoletos.

Los scripts de `Scripts/*.sh` y los ejecutables obligatorios de `Resources/Engines/` deben conservar el bit ejecutable en la copia fuente. La fase Xcode **Firmar motores incluidos** también restaura la copia empaquetada cuando una compilación incremental conserva un motor sin permiso de ejecución antes de validar y firmar/verificar los motores incluidos.

## Compilación por Terminal

```bash
./Scripts/build_macos.sh Release
```

El script:

1. valida los motores locales declarados;
2. genera el proyecto Xcode desde `Scripts/generate_xcode_project.py`;
3. limpia el producto anterior y compila para macOS ARM64;
4. copia los recursos verificados;
5. conserva las firmas oficiales de yt-dlp y Deno, incluidas las autorizaciones JIT de Deno;
6. firma FFmpeg, FFprobe, Pandoc, gallery-dl e instaloader-zeuve cuando están presentes;
7. ejecuta `verify_packaged_engines_macos.sh` y `codesign --verify --deep --strict` sobre la aplicación final.

## Pruebas de código y proyecto

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
```

`verify_project.sh` mantiene ese comando como entrada única, pero delega las comprobaciones estructurales en `Scripts/verify/*.py` por dominio. Ejecuta la suite Swift, la compilación release, las regresiones Python, validación documental, parseo automático de todos los Swift de `ZEUVEApp`, regeneración Xcode y la comprobación de coherencia entre productos SwiftPM, generador y `.pbxproj`.

En macOS Apple Silicon invoca `Scripts/verify_app_macos.sh`, que valida los motores, regenera/verifica de nuevo la integración Xcode y ejecuta `xcodebuild` Debug ARM64 real. Fuera de macOS Apple Silicon esa etapa se informa como omitida; el parseo sintáctico portable no se considera equivalente a una compilación de la aplicación.

## Validación final obligatoria en Mac Apple Silicon

Antes de considerar validada la versión 0.14.0.0 deben comprobarse:

- compilación Xcode ARM64;
- firma y Hardened Runtime;
- apertura real de la aplicación;
- diagnóstico y ejecución de FFmpeg/FFprobe y de cualquier motor opcional incluido;
- conversiones TXT ↔ Markdown ↔ HTML con archivos sintéticos;
- rechazo claro de EPUB, MOBI, AZW/AZW3, FB2 y EPS;
- ausencia de Calibre y Ghostscript dentro de la aplicación empaquetada;
- funcionamiento de ImageIO, PDFKit y VideoToolbox;
- Descargador con casos autorizados de YouTube, TikTok y los motores sociales incluidos, incluida la ruta `gallery-dl` → `yt-dlp` cuando el primer intento termina vacío;
- Instagram público sin sesión con una foto, un vídeo, un Reel, un carrusel de fotos y un carrusel mixto;
- para cada carrusel, número total de elementos, orden, tipo, extensión real, archivos no vacíos y ausencia de recodificación;
- prioridad anónima `instaloader-zeuve` → `gallery-dl` → `yt-dlp` → descubrimiento genérico, incluidos fallos vacíos o incompletos y limpieza entre intentos;
- errores públicos ambiguos que no deben activar una sesión y un caso privado autorizado que solo la use cuando sea realmente necesaria;
- un lote mixto que conserve por defecto los originales de máxima calidad en todas las plataformas, incluido YouTube;
- opciones manuales «Vídeo» y «Solo audio» anulando correctamente la política automática.

Las pruebas reales dependientes de servicios externos deben registrar fecha, tipo de contenido, motores recorridos y resultado. No deben incorporar a informes permanentes cookies, tokens, cabeceras, nombres de cuentas, URLs privadas ni URLs firmadas de CDN. Una prueba histórica no garantiza compatibilidad futura y debe repetirse antes de una entrega afectada por cambios externos.

## Limpieza segura del entorno local

La herramienta oficial para artefactos dentro de la carpeta del proyecto es `python3 Scripts/clean_project.py`. Sin `--apply` solo simula; `python3 Scripts/clean_project.py --apply` elimina únicamente objetivos regenerables conocidos y vuelve a verificar que los motores obligatorios sigan presentes. Los logs solo se incluyen con `--include-logs`.

Con Xcode cerrado cuando sea posible, pueden eliminarse `.build`, `build`, `.swiftpm`, `xcuserdata`, `DerivedData`, cachés y `.DS_Store`: son resultados regenerables y la siguiente compilación puede tardar más.

Antes de borrar debe inspeccionarse la ruta exacta. `DerivedData` vive fuera del proyecto y puede contener datos de otros proyectos, por lo que no debe limpiarse globalmente sin autorización expresa. `Resources/Engines`, `engines.json`, licencias y binarios fijados no son cachés y deben conservarse.

Tras la limpieza se comprueba que la fuente y los motores siguen presentes. Si se elimina `build` o `DerivedData`, cualquier aplicación que estuviera allí deja de formar parte del estado actual de la carpeta y debe recompilarse antes de volver a declararla disponible.

## Carpeta de trabajo y empaquetado opcional

```bash
python3 Scripts/package_release.py  # solo cuando se solicite expresamente
```

La entrega normal mantiene actualizada esta única carpeta activa y no crea otra carpeta versionada. Si se trabaja desde ChatGPT web o desde un entorno remoto que no sea el ordenador del usuario, cada entrega de proyecto modificado debe incluir un ZIP limpio del proyecto completo actualizado salvo indicación expresa en contrario. Si se trabaja directamente en el ordenador del usuario, el ZIP solo se genera cuando se solicita expresamente. Todo ZIP debe excluir `.build`, `build`, DerivedData, cachés, temporales, registros, credenciales, `.DS_Store`, `._*`, `__MACOSX` y datos locales de Xcode.

## Validación adicional de Inspector multimedia 0.13.2.0

El Inspector no añade motores. Reutiliza los FFmpeg/FFprobe ya exigidos por el proyecto. En macOS Apple Silicon, además de la validación general, debe comprobarse que el target `MultimediaInspectorModule` enlaza correctamente, que `ZEUVEApp` compila con Accelerate/AppKit/ImageIO y que `⌘6` abre el módulo (`⌘7` queda para Historial).

La validación funcional recomendada usa MKV/MP4/MOV/WebM y audio independiente, ejecuta remux con pistas externas, cancelación y conflictos, y prueba espectrograma multicanal, planificación adaptativa, cambio de pista/parámetros y exportación PNG.


## Versionado de bundle desde 0.13.1.0

ZEUVE mantiene una versión canónica de cuatro componentes en `VERSION`. Xcode no recibe cuatro componentes en `MARKETING_VERSION`: usa únicamente `MAJOR.MINOR.PATCH`, mientras `INFOPLIST_KEY_ZEUVEReleaseRevision` aporta `REVISION`. `CURRENT_PROJECT_VERSION` continúa como build interno independiente. Los verificadores deben comprobar la coherencia entre las tres piezas antes de dar una entrega por válida.


## Validación adicional de Inspector multimedia 0.14.0.0

En macOS Apple Silicon debe comprobarse además la compilación y uso real de `AVAudioEngine`/`AVAudioPlayerNode`: reproducir audio independiente, seleccionar al menos dos streams de un contenedor multiaudio, pausar/reanudar, seek, saltos, volumen, audio externo del draft, clic desde espectrograma y detención al cambiar/cerrar archivo. La validación portable no sustituye esta prueba nativa.

## Validación adicional de Inspector multimedia 0.15.0.0

En macOS Apple Silicon deben comprobarse de forma manual además de la suite automática:

1. abrir un audio/vídeo, usar **Analizar otro archivo…** y **Cerrar análisis** sin reiniciar ZEUVE;
2. verificar confirmación de descarte con un borrador sucio;
3. reproducir varias pistas y confirmar que el cambio conserva el instante;
4. scrub de la waveform bipolar y sincronía visual con el playhead del espectrograma;
5. estilos de waveform y preferencias tras reiniciar una sesión;
6. navegación por capítulos;
7. análisis/cancelación de sonoridad con FFmpeg empaquetado;
8. exportación TXT/MD/JSON y ausencia de rutas/fingerprints en el informe;
9. restauración de Ajustes del Inspector y restauración global.

El build macOS real es obligatorio para validar AVAudioEngine/SwiftUI y el filtro EBU R128 de la versión FFmpeg empaquetada.


## Validación adicional de Inspector multimedia 0.15.8.0

En macOS Apple Silicon debe comprobarse además la navegación temporal compartida: generar la waveform/espectrograma, hacer zoom desde ambos conjuntos de controles y verificar que muestran el mismo intervalo; desplazar a izquierda/derecha y restaurar **Vista completa**; confirmar que el playhead y el seek se mantienen correctos al reproducir/pausar; abrir un archivo con capítulos y verificar marcadores/títulos/tiempos; y repetir el cambio rápido entre pistas para asegurar que no reaparecen las regresiones 0.15.2–0.15.6.

La validación debe confirmar también que el zoom/pan no inicia un nuevo FFmpeg/FFT y que la interfaz SwiftUI permanece fluida con archivos largos. La compilación nativa sigue siendo necesaria para validar Canvas, gestos, hover y AVAudioEngine.

## Validación adicional de Inspector multimedia 0.15.9.0

En macOS Apple Silicon deben probarse archivos mono/estéreo/multicanal con silencios reales, audio fuerte sin clipping y señales con saturación conocida. Confirmar los valores predeterminados (-60 dBFS / 0,5 s), que el silencio exige todos los canales, que los eventos se muestran como **Posible clipping**, que waveform y espectrograma coinciden con zoom/pan, que la cancelación libera la operación y que el flujo mono-pista sigue el orden espectrograma → señal → sonoridad. Con archivos de varias pistas, confirmar que el análisis permanece manual.

## Validación adicional de Inspector multimedia 0.16.0.0

En macOS Apple Silicon, además de las regresiones 0.15.x:

1. usar un archivo de una pista y confirmar que la sonoridad automática muestra también la curva temporal sin una segunda pasada visible;
2. hacer zoom/pan y verificar que espectrograma, mapa LUFS y playhead abarcan el mismo intervalo; hacer clic en la curva y comprobar seek;
3. con dos pistas, seleccionar A/B y alternar reproduciendo y pausado: debe conservar instante/estado y no debe cambiar la selección del espectrograma;
4. repetir con duraciones diferentes y con cambios A/B rápidos;
5. confirmar que **Completar análisis A/B** solo calcula datos ausentes y no ejecuta dos análisis pesados a la vez;
6. exportar TXT, Markdown y JSON y revisar que schema 2 incorpora señal/timeline disponibles sin rutas completas, fingerprints ni IDs internos;
7. repetir Play/Pausa desde Pistas, Espectrograma y reproductor inferior para detectar regresiones del transporte compartido.

## Validación adicional de 0.17.0.0

Tras compilar en macOS Apple Silicon, validar al menos un MKV con capítulos y attachments: editar título/tiempo de capítulo, añadir y eliminar capítulos, añadir/eliminar/extraer un attachment, editar metadatos y comprobar Undo/Redo. El resultado debe reabrirse en el Inspector y coincidir con el plan sin recodificación de vídeo/audio.

Al distribuir o recomprimir el proyecto deben preservarse los bits ejecutables de `Scripts/*.sh` y de los motores empaquetados. La fase de firma también repara una copia de motor que exista pero haya perdido `+x`; aun así, el ZIP fuente debe conservar los permisos Unix originales.


## Validación adicional del Inspector multimedia 0.18.0.0

En macOS Apple Silicon con Xcode, además de las regresiones anteriores:

1. seleccionar y arrastrar varios WAV/FLAC/MP4/MKV y confirmar que se abre el modo lote;
2. ejecutar los cuatro presets incluidos y verificar que la cola procesa un solo elemento/fase pesada cada vez;
3. incluir archivos con 0, 1 y 2+ pistas de audio y comprobar que el caso multitrack recibe aviso sin selección automática;
4. incluir un archivo corrupto y confirmar que los siguientes continúan;
5. cancelar durante señal/sonoridad/espectrograma y comprobar que los resultados ya publicados permanecen y los pendientes quedan cancelados;
6. reintentar solo los fallidos conservando la configuración del lote;
7. exportar informes/PNG a una carpeta con conflictos y confirmar nombres seguros sin sobrescritura;
8. revisar Ajustes del Inspector, crear/editar/duplicar/eliminar/restaurar presets y comprobar persistencia tras reiniciar la app;
9. restaurar valores predeterminados del Inspector y confirmar que preferencias y presets vuelven al estado incluido sin borrar archivos ni historial;
10. abrir después un archivo individual y repetir Play/Pausa, A/B, waveform, espectrograma, edición y Undo/Redo para detectar regresiones.

Al recomprimir o distribuir el proyecto deben seguir preservándose los bits ejecutables de `Scripts/*.sh` y `Resources/Engines/**`.

## Validación adicional del Inspector multimedia 0.18.1.0

En macOS Apple Silicon, recorrer **Ajustes → Inspector multimedia** y las vistas Resumen, Pistas, Espectrograma, Metadatos y Lote. Confirmar que los iconos de información aparecen junto a opciones/métricas técnicas, abren el popover compartido, son navegables por teclado/VoiceOver y no inician análisis ni cambian el estado del archivo. Revisar también modo claro/oscuro y tamaños de ventana estrechos.


## Nota de integración 0.20.0.0

ZEUVE 0.20.0.0 incorpora el producto SwiftPM `CleanerModule`. El módulo no necesita motores externos ni preparación adicional: depende únicamente de `ZEUVECore`, `ZEUVEStorage` y `ZEUVEOperations`. Los comandos de build, tests, verificación y empaquetado de este documento no cambian.

La validación funcional específica de Papelera, Security.framework, Spotlight, Full Disk Access y apertura de Ajustes del Sistema requiere macOS 14+ Apple Silicon. Las suites portables deben usar providers y raíces temporales y no escanear ubicaciones reales del equipo de test.
