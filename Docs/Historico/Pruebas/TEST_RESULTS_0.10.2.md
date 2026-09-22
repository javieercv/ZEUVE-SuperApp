# Resultados de pruebas ZEUVE 0.10.2

Fecha: 5 de agosto de 2026.  
Entorno disponible: Linux x86_64, Swift 6.2.1 y Python 3.

## Pruebas superadas

- Suite XCTest de Swift: 165 pruebas ejecutadas, 0 fallos.
- Suite Swift Testing: 45 pruebas ejecutadas, 0 fallos.
- Suite Python `Tests/ScriptTests`: 42 pruebas ejecutadas, 0 fallos.
- Compilación Swift en configuración Release: completada correctamente.
- Verificación integral `Scripts/verify_project.sh`: completada correctamente.
- Sintaxis Python de los helpers y scripts modificados: validada.
- Sintaxis Bash de los scripts de preparación y compilación modificados: validada.

## Regresiones específicas de Instagram

Se añadieron o ampliaron pruebas para comprobar que:

- `Profile … does not exist` se clasifica como consulta no concluyente, no como confirmación de perfil ausente;
- una sesión aportada pero no validada conserva una acción útil para volver a autenticar;
- los errores de autenticación producen un resultado visible que activa la tarjeta de sesión;
- los errores desconocidos continúan propagándose y no se ocultan;
- el formato antiguo `profile_unavailable` de 0.10.1 se interpreta de manera segura;
- el servicio contiene y ejecuta el camino real de fallback a `gallery-dl`;
- stories y otros contenidos pueden terminar en un resultado de autenticación accionable;
- los registros visibles solo contienen estados booleanos y clasificaciones seguras;
- Xcode y `build_macos.sh` preparan o rechazan motores ausentes;
- `check_social_engines.py` rechaza expresamente `instaloader-zeuve 4.15.2-zeuve.1`;
- el actualizador del manifiesto fija `4.15.2-zeuve.2` y conserva las entradas no relacionadas.

## Incidencia de prueba no relacionada

En la primera repetición completa apareció un único fallo intermitente en la prueba antigua del Conversor universal `encryptedZIPUsesOnlyTheProvidedInMemoryPassword`: la expectativa esperaba un error y esa ejecución no lo recibió. No se modificó el Conversor porque no forma parte de esta corrección. La misma prueba pasó al ejecutarse de forma aislada y una segunda ejecución completa volvió a superar las 45 pruebas Swift Testing. Se registra esta inestabilidad previa sin presentarla como corregida.

## Privacidad y originales

Las pruebas utilizaron datos sintéticos para sesiones y respuestas del ayudante. No se incorporaron cookies, tokens, credenciales, nombres de cuentas autenticadas ni el JSONL real al código o a las pruebas permanentes. El ZIP 0.10.1 aportado por el usuario permanece intacto y separado de la copia de trabajo.

## Verificaciones del paquete final

El ZIP final se validó adicionalmente con estos resultados:

- `unzip -t`: sin errores en los datos comprimidos;
- ausencia de `.build`, `.swiftpm`, `__pycache__`, `.pyc`, logs, `__MACOSX`, `.DS_Store` y datos privados;
- presencia del proyecto completo, documentación, pruebas y scripts;
- ausencia del binario obsoleto `instaloader-zeuve 4.15.2-zeuve.1`;
- entrada de manifiesto fijada en `4.15.2-zeuve.2`, pendiente de regeneración ARM64;
- huella SHA-256 calculada externamente para comprobar la entrega.

## Pruebas no realizadas

No se han podido realizar en este entorno:

- generación PyInstaller del motor ARM64 `instaloader-zeuve 4.15.2-zeuve.2`;
- firma y verificación de arquitectura del nuevo ejecutable;
- compilación y apertura de la aplicación mediante Xcode en macOS;
- prueba real de un perfil, publicación, reel o story de Instagram;
- validación real de sesión pegada, `cookies.txt` o importación desde navegador;
- comprobación manual de la tarjeta de sesión y del flujo de fallback en SwiftUI;
- verificación de Gatekeeper, VoiceOver, cancelación y limpieza en el entorno objetivo.

Por ello, el código y las regresiones están verificados, pero no se afirma todavía que la descarga real de Instagram haya quedado validada en macOS.
