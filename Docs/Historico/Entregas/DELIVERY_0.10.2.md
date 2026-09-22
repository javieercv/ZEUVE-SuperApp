# Entrega ZEUVE 0.10.2

## Resumen

ZEUVE 0.10.2 corrige el segundo fallo detectado con Instagram: una respuesta ambigua de Instaloader ya no se presenta como «el perfil no existe», el fallback a `gallery-dl` se ejecuta realmente y la interfaz puede solicitar una sesión aunque el perfil no haya podido comprobarse previamente.

## Estado

La corrección de código, integración, pruebas sintéticas, versionado y documentación está completada. La suite disponible en Linux pasa sin fallos.

La validación final permanece pendiente en macOS Apple Silicon porque el motor `instaloader-zeuve 4.15.2-zeuve.2` debe generarse y firmarse en esa plataforma. El ejecutable `.1` defectuoso se ha retirado deliberadamente del proyecto para que no vuelva a empaquetarse.

## Compilación en Mac

La compilación recomendada es:

```bash
Scripts/build_macos.sh
```

También puede abrirse el proyecto Xcode. La fase previa comprobará los motores sociales y, si falta `instaloader-zeuve` o conserva la revisión `.1`, ejecutará `Scripts/prepare_social_engines_macos.sh`. Esta preparación requiere conexión a Internet y Python únicamente en el Mac de desarrollo para obtener las versiones fijadas y generar los binarios autosuficientes. El usuario final no tendrá que instalar Python.

La compilación se detendrá si no puede producirse y validarse la revisión `.2`, evitando otra aplicación que anuncie soporte de Instagram con un motor incorrecto.

## Protección y limpieza

La entrega se genera desde una copia del ZIP 0.10.1. El original y los registros reales no se modifican ni se incluyen. El paquete excluye cachés, compilaciones, logs, cookies, sesiones, credenciales, archivos personales, `__MACOSX`, `.DS_Store` y estados privados de Xcode.

## Versiones

- Aplicación: ZEUVE 0.10.2.
- Build interno: 33.
- Descargador universal: 0.6.2.
- Ayudante especializado: instaloader-zeuve 4.15.2-zeuve.2.

## Validación del ZIP

El paquete completo se abrió y recorrió con `unzip -t` sin errores. También se comprobó que no contiene cachés, logs, datos privados ni el ejecutable `.1` retirado, y que conserva el proyecto, las pruebas, los scripts y los tres informes de la versión 0.10.2.

## Limitación conocida

La entrega contiene el proyecto completo y el mecanismo obligatorio de regeneración, pero no contiene un ejecutable `.2` que haya sido generado y probado en este entorno. La primera comprobación real debe realizarse en Mac Apple Silicon y acompañarse de un nuevo registro si Instagram continúa rechazando la consulta o la sesión.
