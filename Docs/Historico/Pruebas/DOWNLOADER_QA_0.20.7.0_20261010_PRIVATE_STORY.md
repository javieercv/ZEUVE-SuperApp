# QA de Story privada autorizada — 10/10/2026

Base sincronizada `072bc957c3c573228caf3f2d9742323a82a3e512`, sin cambios locales ni remotos. Misma app Debug 0.20.7.0/build 73, datos aislados. Sin correcciones de código/motores. El usuario mantiene la sesión de Brave, aporta una Story activa privada y autoriza su uso para las pruebas; se confirma el material disponible antes de empezar. Reddit se aplaza expresamente: D-17 conserva parcial, no se convierte en OK/no aplicable. No hay enlace de publicación/Reel privado.

Item de Llavero de Instagram/ZEUVE ausente antes de iniciar (solo existencia, exit 44). No se accede a contraseñas, correo ni cookies de otros dominios. Las capturas AX de ZEUVE omiten TextEditor. Identificadores de cuenta, URL privada, contenido, cookies y logs brutos quedan fuera de Git.

## Registro individual

- **D-11 — ⚠️:** Story activa privada aportada y acceso en Brave confirmado por control Pausar/Reproducir. Análisis nativo de la URL aportada sin sesión finaliza con 0 elementos, motor yt-dlp, «Activa más secciones» y descarga deshabilitada. No aparece el panel de sesión; no se considera perfil vacío ni Story inexistente. Se continúa con archivo de sesión autorizado; cobertura de Stories sigue parcial.

- **D-48 — ⚠️:** Exportación explícita del motor incluido desde Brave completada (exit 0): 8 cookies, solo dominios Instagram y sessionid presente; archivo temporal modo 0600. No equivale al botón nativo «Importar sesión», que sigue sin aparecer. Una fila de sesión lleva caducidad vacía; se prepara solo una copia QA con 0 para continuar, sin corregir producto.

## Pausa por control del entorno

Antes de seleccionar la copia normalizada y repetir el análisis con sesión, System Events deja de exponer ventanas de ZEUVE. El proceso QA continúa activo y macOS informa `CGSSessionScreenIsLocked=Yes`. Se solicita desbloquear el Mac; no se intenta eludir el bloqueo. Esto es un impedimento de control del entorno, no una prueba fallida de ZEUVE. La Story **con sesión no se ha analizado en esta ronda**; exportar el archivo no demuestra que ZEUVE lo haya utilizado ni validado.

Auditoría de privacidad acotada: 226 entradas de logs QA, 8 valores reales de cookies, 0 coincidencias. No se amplía la aceptación de P-11 a una descarga autenticada ni se invalida P-12. El item común de Instagram/ZEUVE sigue ausente en el Llavero (consulta solo de existencia, exit 44). Se eliminan las dos copias temporales de cookies generadas en esta ronda; no se altera la sesión original de Brave ni los 45 archivos multimedia QA acumulados. El proceso QA y la pestaña de Story creada para pruebas permanecen abiertos para reanudar; no se ha seleccionado el archivo en la app.

Estados conservados: 639 IDs, 613 OK, 9 fallidas, 8 parciales y 9 pendientes; 630 ejecutadas. Próximo paso: con el Mac desbloqueado, exportar otra copia temporal limitada a Instagram, seleccionar la copia normalizada por el selector nativo y analizar la misma Story. Si aparece el panel, comprobar pegado/recuerdo/reinicio/reset sin simular resultados; si no aparece, documentar el bloqueo real. Reddit queda aplazado por instrucción expresa; no se requiere ahora una publicación privada adicional.

## Reanudación tras desbloqueo

El usuario confirma desbloqueo. Estado limpio, fetch y HEAD/origin/main iguales a `f8e157b87443c1526b86feb27a8e20997168face`; sin cambios remotos nuevos. System Events vuelve a exponer la ventana. Nueva exportación limitada a Instagram mediante el motor incluido, exit 0. Se normaliza solo una caducidad vacía en copia QA propia. El item de Llavero continúa ausente antes de analizar (exit 44). No se modifica código ni sesión original del navegador.

- **D-46 — ⚠️:** Tras desbloqueo, nueva copia QA normalizada seleccionada por NSOpenPanel, verificando nombre de fila y selección antes de aceptar. ZEUVE muestra cookies-normalized.txt y deshabilita la opción de navegador mientras el archivo está seleccionado. Importación/preparación comprobadas; no se confunde con el archivo original incompatible ni con pegado en panel. Se inicia análisis nativo de la misma Story con ese archivo.

- **D-44 — ⚠️:** Reanudación: la misma Story privada activa se analiza desde UI con cookies-normalized.txt aceptado. Finaliza con 0 elementos, motor yt-dlp, «Activa más secciones», descarga deshabilitada y sin panel de sesión. Logs: sesión aportada sí, fallback gallery-dl con resultados 0; no consta validación efectiva. No se descarga contenido privado ni se certifica acceso autenticado; se mantiene parcial.

### Interpretación de la Story directa

Observación: el navegador con sesión reproduce la Story; ZEUVE devuelve una galería vacía, tanto sin archivo como con archivo seleccionado. La presencia de `sesion_aportada=sí` al inicio indica material disponible, no que las peticiones posteriores lo utilicen ni que el servidor lo valide.

Evidencia de código vigente, sin modificaciones: `InstagramCatalogCommandBuilder.directArguments` solo extrae identificadores tras p/reel/reels/tv, no stories. `UniversalDownloadAnalysisService.analyze` prueba enlaces concretos primero anónimamente incluso con sesión disponible; si ese recorrido devuelve un análisis, lo acepta sin exigir elementos. `analyzeConcreteInstagramAnonymously` devuelve el resultado de gallery-dl sin comprobar que su catálogo no esté vacío. Solo se reintenta con sesión si los errores confirman contenido privado. El panel nativo en `UniversalDownloaderView` exige `requiresAuthentication=true`.

Hipótesis respaldada, no validación efectiva de sesión: una Story no soportada por el builder directo cae en un resultado anónimo vacío que no reclama autenticación; por eso ni se ofrece el panel ni se demuestra acceso con las cookies aportadas. Los logs y la UI encajan con esta cadena, pero no muestran toda respuesta del servidor: no se afirma que las cookies sean inválidas ni que toda la causa remota sea de ZEUVE. El aviso «Activa más secciones» sigue siendo engañoso con las seis secciones activadas. Se inicia un contraste por el perfil del mismo objetivo para intentar obtener Stories mediante la ruta de catálogo.

- **D-44 — ⚠️:** Último contraste con Story activa: consulta nativa del perfil del mismo objetivo, conservando archivo de sesión normalizado. No devuelve catálogo ni panel tras ≈184 s; se cancela desde UI. Estado deja de estar ocupado y procesos del motor terminan. No confirma validación de sesión, no se considera perfil sin contenido y no ejecuta los requisitos de pegado/recuerdo/reinicio/reset. Se mantiene parcial sin corregir producto.

- **P-11 — ✅:** Reanudación con sesión real autorizada: Story directa finalizada sin resultados y perfil cancelado ≈184 s. Tras cierre normal de app, auditoría de 234 entradas de log contra los 8 valores reales de cookies y variantes escapadas/desescapadas: 0 coincidencias. Alcance solo estos análisis, sin descarga privada ni sesión efectivamente validada; P-12 sigue fallido por canarios sintéticos. No se guardó item de Llavero (existencia final exit 44).

## Cierre de la reanudación

El bloqueo del Mac queda resuelto; el límite final es el recorrido de consulta/UI de ZEUVE y los motores. La Story directa no ofrece contenido ni panel aun con el archivo aceptado. La ruta de perfil se cancela a ≈184 s sin resultados, no termina por sí sola ni demuestra un error definitivo del servidor. No se certifica autenticación efectiva ni se responsabiliza al usuario de falta de acceso o de una Story inexistente.

Continúan **D-40/D-41/D-42/D-43/D-56 sin probar** por falta de catálogo/paginación utilizables. **D-45/D-49/D-50/D-51 sin probar** porque no aparece el panel para pegar/recordar y no se crea una sesión mediante ese flujo que permita comprobar recuperación/borrado. Reiniciar o resetear con Llavero vacío no probaría esos requisitos. D-44/D-46/D-48 siguen parciales; D-47 conserva el fallo del archivo original. No se marcan OK por la copia normalizada ni por el éxito de exportación CLI. Reddit mantiene D-17 parcial y se aplaza expresamente; no se solicita ahora publicación/Reel privado adicional.

Cierre normal de la app QA (exit 0), sin procesos de motores. Se eliminan solo las dos nuevas copias propias de cookies de esta reanudación; no son recuperables desde QA, pero Brave mantiene la sesión original. Se cierran dos pestañas creadas para QA (Story activa y destacada de la ronda anterior), conservando la pestaña original del usuario. No se guarda ni borra ningún item de Llavero; permanece ausente. Sin nuevas descargas; los 45 archivos multimedia QA previos se conservan. No hay cambios de producto, motores, empaquetado ni permisos.

La incidencia de control inicial (Mac bloqueado) se distingue de los resultados de producto; una consulta de pestañas por ID devolvía vacío y se resolvió inventariando pestañas, sin atribuirlo a ZEUVE. Estados finales: **639 IDs, 613 OK, 9 fallidas, 8 parciales, 9 pendientes; 630 ejecutadas**. Cada comprobación individual se anotó al concluir. Solo se verifican/publican documentos; no se repite la batería de código por una modificación exclusivamente documental sobre la misma base de producto.
