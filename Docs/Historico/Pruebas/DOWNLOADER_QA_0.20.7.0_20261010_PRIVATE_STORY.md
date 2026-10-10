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
