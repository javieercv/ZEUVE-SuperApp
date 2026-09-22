# Informe de implementación 0.10.2

Fecha: 5 de agosto de 2026.

## Incidencia reproducida

El registro real aportado después de probar ZEUVE 0.10.1 confirmó que los motores sociales ya estaban disponibles, pero `instaloader-zeuve` terminaba con código 21 y el texto `Profile mar.rullan does not exist.`. La aplicación trataba esa respuesta como una confirmación de que el perfil no existía, cerraba el análisis y no mostraba una vía útil para aportar una sesión. Además, el flujo especial de perfiles llamaba directamente a Instaloader y no ejecutaba el fallback a `gallery-dl` que figuraba en el router general.

## Corrección aplicada

### Clasificación segura de respuestas de Instagram

`Scripts/engine_helpers/instagram_catalog.py` eleva su revisión a `4.15.2-zeuve.2` y separa los posibles resultados de una consulta de perfil:

- autenticación requerida;
- sesión aportada pero no validada;
- consulta ambigua o incompleta;
- petición bloqueada o limitada;
- fallo de consulta no identificado.

Una respuesta vacía, un error GraphQL o el mensaje de Instaloader «Profile … does not exist» dejan de presentarse automáticamente como prueba de que el perfil no existe. El ayudante devuelve un error estructurado y minimizado, sin cookies, tokens ni el nombre de la cuenta autenticada.

### Sesión y privacidad

El ayudante distingue mediante valores booleanos si se aportó una sesión y si pudo validarse. La aplicación registra únicamente:

- motor ejecutado;
- fallback utilizado;
- sesión aportada: sí/no;
- sesión validada: sí/no;
- clasificación segura del fallo.

No se guardan el contenido de las cookies, tokens, cabeceras privadas, credenciales ni el usuario de la sesión.

### Fallback real de perfiles

`YouTubeAnalysisService` intenta primero el catálogo especializado de Instaloader. Cuando el resultado es no concluyente o requiere autenticación, ejecuta realmente `gallery-dl` como segundo motor. Si tampoco puede resolver el perfil, conserva un resultado de autenticación que permite a la interfaz mostrar la tarjeta para pegar una sesión temporal o seleccionar un archivo `cookies.txt`, en lugar de terminar con «el perfil no existe».

El mismo tratamiento se aplica a stories y otros contenidos de Instagram cuando todos los motores terminan por falta de autenticación o con una respuesta no concluyente.

### Interfaz

La tarjeta de sesión ya no depende de haber identificado previamente un perfil privado. También aparece cuando Instagram no permite comprobar el perfil, rechaza la sesión o exige autenticación antes de devolver sus datos. El texto visible explica que el resultado no confirma que el perfil haya desaparecido.

### Protección frente al motor obsoleto

El ZIP 0.10.1 contenía un ejecutable `instaloader-zeuve` ARM64 con el ayudante anterior integrado. Ese ejecutable se eliminó de la copia fuente 0.10.2 y su entrada en `Resources/Engines/engines.json` queda marcada como pendiente para `4.15.2-zeuve.2`.

`check_social_engines.py`, `build_macos.sh` y la fase previa de Xcode detectan tanto un motor ausente como una revisión `4.15.2-zeuve.1` obsoleta. En macOS Apple Silicon se ejecuta `prepare_social_engines_macos.sh`, se genera la revisión nueva, se validan sus versiones y se actualizan tamaño y SHA-256 antes de copiar recursos. Si la preparación no termina correctamente, la compilación se detiene para impedir que se genere otra aplicación con el ayudante defectuoso.

## Archivos modificados

- `Scripts/engine_helpers/instagram_catalog.py`
- `Scripts/check_social_engines.py`
- `Scripts/refresh_social_engine_manifest.py`
- `Scripts/prepare_social_engines_macos.sh`
- `Scripts/prepare_engines_macos.sh`
- `Scripts/generate_xcode_project.py`
- `Scripts/verify_project.sh`
- `Sources/YouTubeDownloaderModule/Parsing/InstagramCatalogParser.swift`
- `Sources/YouTubeDownloaderModule/Parsing/YouTubeErrorClassifier.swift`
- `Sources/YouTubeDownloaderModule/Operations/YouTubeAnalysisService.swift`
- `Sources/ZEUVEApp/YouTubeDownloader/YouTubeDownloaderView.swift`
- `Sources/ZEUVEApp/SettingsView.swift`
- `Sources/YouTubeDownloaderModule/Discovery/UniversalPageDiscovery.swift`
- `Sources/YouTubeDownloaderModule/Resources/manifest.json`
- `Resources/Engines/engines.json`
- `ZEUVE.xcodeproj/project.pbxproj`
- `Tests/YouTubeDownloaderModuleTests/UniversalSocialDownloaderTests.swift`
- `Tests/YouTubeDownloaderModuleTests/YouTubeFilesStorageAndManifestTests.swift`
- `Tests/ScriptTests/test_social_engine_preparation_policy.py`
- `Tests/ScriptTests/test_universal_downloader_page_policy.py`
- `README.md`
- `Docs/BUILDING.md`
- `Docs/UNIVERSAL_DOWNLOADER.md`
- `PROJECT_DECISIONS.md`
- `CHANGELOG.md`
- `VERSION`

## Archivo nuevo

- `Tests/ScriptTests/test_instagram_catalog_helper.py`

## Archivo retirado de la copia fuente

- `Resources/Engines/instaloader/instaloader-zeuve`, revisión `4.15.2-zeuve.1`.

No se elimina una función aprobada: el archivo se retira porque contiene el ayudante que produjo el error real y debe regenerarse en Mac con la revisión `.2` antes de compilar la aplicación.

## Alcance no modificado

No se han alterado el Organizador, el Analizador de chats, el Conversor universal ni el Comparador de seguidores de Instagram. Tampoco se han cambiado las políticas de contenido adulto, las carpetas de salida, el historial, la publicación segura de archivos o la gestión general de motores ajenos a Instagram.

## Limitación del entorno

La lógica Swift y Python se ha compilado y probado en Linux x86_64. Este entorno no puede generar, firmar, abrir ni ejecutar el binario PyInstaller macOS ARM64 actualizado. Tampoco se ha realizado una prueba real contra Instagram desde la aplicación nativa. La comprobación final debe hacerse en un Mac Apple Silicon después de que la fase de compilación genere `instaloader-zeuve 4.15.2-zeuve.2`.
