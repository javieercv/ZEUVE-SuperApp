# Resultados de pruebas — ZEUVE 0.20.8.0

11/10/2026 · macOS Apple Silicon/Xcode · marketing 0.20.8/build 74 · Descargador 0.7.4. Base remota `36947e228f5d732da6a24a302fa8a3fc008101f9`.

## Regresiones automáticas sin red

Fixtures propios y cookies exclusivamente sintéticas; no se leen valores de sesiones reales.

- Round trip Netscape con caducidad vacía, cero y futura; rechazo de caducidad malformada y archivo sin cookies. El original y el temporal mantienen el contenido.
- Galería con dos imágenes, VTT y audio `num=0`: tres recursos primarios, identidad de audio y filtro aplicado antes del rango de una coincidencia, extensión efectiva del archivo.
- Metadatos de directorio pertenecen a su publicación, no a la última del catálogo.
- yt-dlp sin contenido no anuncia éxito; referencia diferida de playlist plana sigue disponible.
- FFprobe real sobre JPEG renombrado a MP3 lo rechaza; MP4 sintético de solo audio se acepta; VTT solo se rechaza. Validación estructurada de vídeo sin audio y portada adjunta.
- Canarios de URL privada, identificador y error no sobreviven a los metadatos de diagnóstico; avisos del parser de Instagram no copian el texto remoto. Un test del servicio con motores sustitutos sintéticos ejecuta éxito, error y fallback y comprueba los archivos JSONL reales: sin canarios ni URLs privadas; no realiza red.
- Variantes de X comparten identidad y conservan la resolución mayor; vídeos distintos permanecen separados. Se conserva el selector de gallery-dl tras agregación.
- EroMe incluye imagen original y vídeo en orden, excluye avatar y poster; el parser genérico de otras páginas no amplía imágenes.
- Formas concretas de Tumblr aceptadas; perfiles/rutas de navegación rechazados.
- Presupuesto cancela una operación pendiente. Stories de perfil público llevan requisito de sesión y un fallo de sección mantiene estado parcial.
- Ayudante Python: fallback anónimo invalida la marca de sesión, no intenta Stories sin sesión, captura un fallo al crear el iterador, emite foto ya resuelta antes del fallo y aplica el timeout configurado.

## Verificación de entrega

- `./Scripts/run_tests.sh`: suites Swift y 118 tests Python sin fallos; integraciones opt-in sin fixtures externos permanecen omitidas.
- `ZEUVE_SWIFT_JOBS=4 ./Scripts/verify_project.sh`: pasa suites Swift, SwiftPM Release, verificadores, documentación, políticas/manifiestos, parseo de 80 archivos de app, coherencia Xcode y build Debug real.
- 14 regresiones focalizadas nuevas pasan, incluida la ejecución real de FFprobe y el test de privacidad del servicio. La suite completa final del Descargador pasa 117 tests, sin fallos.
- El ayudante propio se reconstruye para ARM64 con versiones fijadas y se comprueba versión, hash y tamaño del manifest. Los demás motores conservan sus binarios originales.
- `git diff --check`: sin problemas.

Los primeros recorridos detectaron expectativas de versión anteriores en comprobadores/pruebas y una referencia a Ajustes fuera de ámbito en el ViewModel. Se corrigen antes de repetir la verificación Xcode, que pasa con el código final. El respaldo de perfiles queda marcado explícitamente como parcial. Persisten warnings previos de Sendable/Vision del Inspector y de metadata AppIntents; no se afirma compilación sin avisos.

`./Scripts/build_macos.sh Release`: pasa la compilación Xcode Release, comprobación de todos los motores empaquetados y `codesign --verify --deep --strict`. Info.plist confirma marketing 0.20.8/build 74. La app permanece en el directorio de build; no se abre ni se utiliza para pruebas manuales.

## Aceptación manual reservada

No se inicia UI ni funcionamiento remoto real. El usuario debe indicar cuándo empezar. La checklist conserva 639 IDs: 613 OK, 9 fallidas, 8 parciales y 9 pendientes. No se reclasifica ningún resultado por pruebas automáticas. Reddit en línea sigue aplazado; perfiles, sesión efectiva, Stories/destacadas, Threads y correspondencia de descargas con el origen requieren evidencia real. La firma de desarrollo no equivale a notarización ni distribución certificada.

Consulta [implementación](../Implementacion/IMPLEMENTATION_REPORT_0.20.8.0.md) y [entrega](../Entregas/DELIVERY_0.20.8.0.md).
