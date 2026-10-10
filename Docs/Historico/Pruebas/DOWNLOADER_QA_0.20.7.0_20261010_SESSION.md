# QA de sesión de Instagram — 10/10/2026

Base remota sincronizada `63f7a2bea2f8210a004f5d106c3205d221607e64`, sin cambios locales ni remotos. Misma app Debug 0.20.7.0/build 73 y datos aislados de QA. Sin cambios de código ni correcciones. El usuario autoriza importar exclusivamente cookies de Instagram de Brave, usar la cuenta iniciada para consultar el perfil indicado, recordar en Llavero, reiniciar y retirar después solo la sesión QA. Se comunica previamente el fallo de saneamiento P-12. No se publican identificadores de cuenta, cookies, títulos privados, multimedia ni logs brutos.

Antes de comenzar se consulta solo existencia del item común `com.zeuve.instagram-session/default`: ausente. No se lee ni sobrescribe una sesión previa. Las capturas AX omiten los valores de todos los TextEditor.

## Registro individual

- **D-34 — ❌:** Contraste con el perfil concreto indicado por el usuario, sin sesión: análisis finaliza con 0 elementos, «Activa más secciones» y descarga deshabilitada; tampoco aparece el panel de sesión. Se mantiene el fallo previo; no demuestra ausencia de contenido ni que sea privado. Cuenta/perfil no se publican.

- **D-48 — ⚠️:** Exportación explícita mediante el motor incluido desde Brave, filtrada a Instagram, exit 0; se comprueban cantidad, dominio y presencia de sesión sin mostrar valores. El panel «Importar sesión» no aparece ni para el perfil ni para una destacada que el navegador puede ver. Cobertura del motor sí, importación nativa por ese botón no verificable; no se marca OK.

- **D-47 — ❌:** Selector nativo: archivo Netscape válido exportado por motor incluido (8 cookies de Instagram, sessionid presente, 848 bytes, 0600), existente y legible. Dos selecciones; en la segunda se confirma fila cookies.txt seleccionada antes de aceptar. ZEUVE rechaza «El archivo cookies.txt ya no está disponible» y conserva «No se utilizan». No se atribuye al primer intento ambiguo; segundo fallo reproducido con selección comprobada.

- **D-47 — ❌:** Tercer intento con exportación nueva en /private/tmp reproduce el rechazo. Causa probable respaldada: el exportador incluido genera una cookie de sesión con expiración vacía; NetscapeCookieFile exige Int64 en esa columna y lanza el mismo error de archivo «no disponible». No es ausencia del fichero ni permisos 0600 ni Sandbox (entitlements sin App Sandbox). Se prepara una copia QA con expiración de sesión 0 para continuar; no se cambia producto ni la exportación original.

- **D-47 — ❌:** Contraste: el mismo selector acepta la copia QA con la única caducidad vacía convertida a 0 y muestra cookies-normalized.txt, sin alertas. Refuerza incompatibilidad exportador/lector; la selección funciona con ese formato, pero se mantiene fallo para la exportación original.

- **D-44 — ⚠️:** Sesión real autorizada exportada de Brave y archivo normalizado aceptado por UI. En Brave se abre una destacada del perfil objetivo (reproductor Pausar/Reproducir disponible); cuenta con acceso confirmado, sin publicar contenido. ZEUVE registra sesión aportada sí, pero el análisis del perfil no acaba en ≈180 s; Cancelar desde UI. No se confirma validación de sesión por el motor ni catálogo autenticado. No se clasifica como ausencia de contenido.

- **D-46 — ⚠️:** La UI acepta y utiliza cookies-normalized.txt como archivo de sesión (8 cookies, campo de expiración de sesión 0), pero el archivo original generado por el motor se rechaza (D-47). No se consigue catálogo tras ≈180 s; importación/preparación de archivo comprobadas, acceso efectivo y pegado de texto Netscape en panel de sesión no verificados.

- **D-44 — ⚠️:** Segundo recorrido nativo con el enlace directo de una destacada accesible en Brave, conservando cookies-normalized.txt: análisis finaliza con 0 elementos, descarga deshabilitada y sin panel de sesión. Log: sesión aportada sí; fallback sin resultados, no consta validación efectiva. No se descarga ni publica contenido privado. Se mantiene parcial, con bloqueo de integración/consulta sin atribuir toda la causa al origen.

- **P-11 — ✅:** Tras usar la sesión real autorizada en análisis de perfil (cancelado ≈180 s) y destacada directa (terminada sin resultados), se auditan 202 entradas del log QA frente a los 8 valores reales de cookies: 0 coincidencias. Comprobación acotada a estos recorridos; no certifica una descarga autenticada correcta ni invalida el fallo sintético de P-12. Valores y log bruto no se publican.

## Cierre y límites

Estado acumulado: **639 requisitos; 613 OK, 9 fallidos, 8 parciales, 9 sin probar; 630 ejecutados**. Nuevos recorridos: D-47 fallido; D-44/D-46/D-48 parciales; P-11 OK en las operaciones de análisis documentadas. D-34 conserva el fallo anterior. No hay correcciones de producto.

Los seis tipos de catálogo están activados en Ajustes: Fotos, Vídeos, Reels, Stories, Destacadas y Foto de perfil. El perfil autorizado tiene cinco destacadas accesibles en Brave y cero publicaciones; se comprueba apertura y control de reproducción de una destacada sin copiar contenido ni títulos a Git. No se usa la cuenta de acceso como objetivo de descarga.

Quedan sin ejecución efectiva **D-40/D-41/D-42/D-43/D-56**: falta catálogo utilizable; la ausencia de publicaciones/Reels en el origen aportado tampoco permite aceptación positiva de esas secciones. **D-45/D-49/D-50/D-51**: no aparece el panel para pegar/importar/recordar, no se guarda ninguna sesión mediante ese flujo, y reinicio/reset sobre Llavero vacío no ejecutaría el requisito. No se inyecta una sesión o estado interno para fingir una prueba manual. Los permisos ya están concedidos; ahora el límite es el recorrido de UI/consulta, no falta de autorización.

Contraste de formato: el archivo exportado existe y tiene 0600; contiene ocho filas Instagram y una expiración vacía. El lector requiere un Int64. El rechazo se reproduce con fila seleccionada comprobada y en dos ubicaciones. La copia QA cambia únicamente esa expiración a 0 y el selector la acepta: fuerte evidencia de incompatibilidad del exportador con el lector y mensaje de error engañoso, sin corregir ninguno. D-48 no certifica el botón nativo de importación, aunque el motor sí se ejecutó expresamente.

P-11 se contrasta también sobre cadenas JSON decodificadas y variantes escapadas/desescapadas de los ocho valores: cero coincidencias en las 202 entradas. No certifica descargas autenticadas ni todas las ramas futuras; P-12 sigue fallido por canarios sintéticos de la ronda anterior. No se imprimen cookies, cabeceras, correo, usuario de sesión ni logs brutos.

Cierre operativo: se quita el archivo de sesión seleccionado desde UI y se vuelve al modo Simple. App cerrada normalmente, exit 0; no quedan motores. Se eliminan las tres copias locales propias de cookies (original, nueva exportación de contraste y copia normalizada); no son recuperables desde QA, pero la sesión original de Brave permanece intacta. No se ha creado ni borrado un item del Llavero: existencia final exit 44. Se cierra únicamente la pestaña creada para QA, conservando la del usuario. No se descargan nuevos medios privados ni se alteran los 44 archivos QA anteriores.

Incidencias del control, separadas de producto: helper AX usaba inicialmente un nombre reservado de AppleScript y se corrigió solo en el controlador; el primer salto del selector no confirmó la fila, por lo que no se usa aislado como evidencia. Los siguientes intentos sí confirman fila y reproducen el rechazo. Un parser auxiliar omitió al principio filas #HttpOnly_; se corrigió la lectura de comprobación antes de determinar las ocho cookies. Ninguna cookie se omitió de la exportación ni de la auditoría final.
