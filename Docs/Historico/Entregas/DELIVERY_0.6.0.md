# Entrega ZEUVE 0.6.0

ZEUVE 0.6.0 build 20 añade el Conversor universal 0.1.0 como cuarto módulo oficial. El proyecto incluye núcleo de conversión, interfaz, ajustes, preajustes, historial, ZIP cifrado con contraseña temporal, pruebas, documentación y scripts para preparar los motores.

## Estado de la entrega

El código y las pruebas lógicas están implementados. La aplicación `.app` no se ha compilado ni abierto porque el entorno disponible no es macOS Apple Silicon.

LibreOffice no está incrustado físicamente en este ZIP generado desde Linux. Antes de compilar la aplicación debe ejecutarse en un Mac Apple Silicon `Scripts/prepare_engines_macos.sh`. El script descarga la versión oficial fijada, verifica su SHA-256, monta el DMG, conserva la firma oficial y publica todo el conjunto de motores de forma transaccional. El usuario final no tendrá que instalar LibreOffice por separado cuando la aplicación se empaquete con los motores preparados.

## Protección de datos

- Los originales recibidos permanecen intactos.
- Las contraseñas de ZIP viven únicamente en memoria y no se guardan.
- Las imágenes elegidas para crear vídeo no se incluyen en preajustes.
- El ZIP final excluye `.build`, cachés, temporales, registros y archivos sintéticos de prueba.
