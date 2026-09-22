# Informe de implementación 0.10.1

## Incidencia corregida

La versión 0.10.0 declaraba `gallery-dl` e `instaloader-zeuve`, pero el ZIP fuente conservaba marcadores vacíos y una compilación normal podía generar una aplicación sin esos ejecutables. Los perfiles de Instagram fallaban después de resolver los motores y las stories terminaban dependiendo de yt-dlp, que podía exigir autenticación sin ofrecer una explicación específica.

## Cambios realizados

- `YouTubeURLValidator` conserva la plataforma Instagram y el tipo perfil/publicación/story aunque el usuario seleccione «Página web».
- `YouTubeAnalysisService` registra la disponibilidad real de los dos motores sociales y registra también el fallo de catálogo de perfiles.
- `YouTubeErrorClassifier` reconoce los mensajes habituales de autenticación de Instagram y propone sesión temporal o `cookies.txt`.
- `build_macos.sh` comprueba los motores sociales y los prepara automáticamente cuando faltan.
- `prepare_social_engines_macos.sh` elimina restos anteriores, genera ejecutables ARM64 autosuficientes, valida versiones y actualiza el manifiesto.
- `refresh_social_engine_manifest.py` calcula tamaños y SHA-256 reales y sustituye las licencias `NOT_PROVIDED`.
- El proyecto Xcode incorpora una fase previa que bloquea una build con motores de Instagram ausentes.
- Se añadieron pruebas de regresión para clasificación, autenticación, preparación, manifiesto y protección de Xcode.

## Alcance protegido

No se modificaron el Organizador, el Analizador de chats, el Conversor universal ni el Comparador de seguidores. Las sesiones continúan siendo temporales por defecto y no se escriben en logs, historial, presets o metadatos.

## Limitación del entorno

El trabajo lógico y las pruebas Swift/Python se realizaron en Linux x86_64. Los ejecutables PyInstaller ARM64 solo pueden generarse, firmarse y ejecutarse en macOS Apple Silicon. Por ello, el ZIP incluye el proyecto completo y el flujo automático de preparación, pero no presenta como generados unos binarios macOS que este entorno no puede producir ni validar.
