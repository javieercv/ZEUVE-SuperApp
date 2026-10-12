# Utilidades rápidas — ZEUVE 0.21.0.0

Fuente funcional vigente de los servicios residentes. La aceptación de esta entrega está **EN VALIDACIÓN**; código integrado y tests automáticos no certifican hardware o aplicaciones externas. La [evidencia de pruebas](../Historico/Pruebas/TEST_RESULTS_0.21.0.0.md) registra exclusivamente lo ejecutado.

## Aplicación residente

ZEUVE conserva una sola aplicación y proceso, presencia normal en Dock y un icono de barra de menús. Cerrar la ventana mantiene el proceso y las utilidades activadas; Salir solicita detener servicios, cancelar tareas propias, retirar proveedores/atajos y terminar motores. Abrir ZEUVE o Ajustes desde barra de menús recupera la interfaz.

`ResidentRuntime` inicia almacenamiento, catálogo y servicios desde el ciclo de aplicación. `AppModel` se construye al abrir la ventana principal; el arranque de sesión/Servicios no necesita inicializar todos los módulos. El modelo ya abierto puede conservarse al cerrar su ventana: la reducción de memoria debe medirse, no deducirse de esta división.

El inicio con macOS utiliza `SMAppService.mainApp`, es opcional y está desactivado por defecto. La UI distingue preferencia solicitada, estado de registro y aprobación del sistema. Un fallo de registro/almacenamiento se muestra. No se cambia silenciosamente a una app sólo de barra de menús.

## Contrato y persistencia

`QuickUtilitiesCatalog` y `QuickUtilityID` definen nueve identificadores estables, independientes de `BuiltInModuleCatalog`. `QuickUtilityService` posee sus recursos y ofrece start/stop/reset async. `QuickUtilitiesCoordinator` mantiene solicitud persistida y estado efectivo separado: desactivada, activando, activa, desactivando, requiere permiso, no disponible o error.

La preferencia `quickUtilities.activation.v1` y opciones versionadas pasan por `SettingsRepository`, sin almacenes paralelos. Cada opción valida schema y valores antes de alcanzar una API. El almacenamiento ausente/dañado no autoriza activación. Parada y reset liberan servicios antes de cambiar opciones; errores de persistencia o limpieza permanecen visibles. Los servicios ligeros no monopolizan `OperationCoordinator`.

La propiedad de recursos se agrupa en `AudioRoutingCoordinator`, `InputEventTapBroker` y `WindowServicesBackend`. No se crean agentes externos ni dependencias descargadas. La UI de la familia vive en Ajustes > Utilidades rápidas, con ayuda y estados; no añade nueve módulos a la barra lateral.

## Permisos y atajos

Accesibilidad se usa para eventos modificadores y AX de ventanas. Captura del audio del sistema se solicita por Core Audio al crear una ruta elegida. No se pide micrófono ni Grabación de pantalla para estas funciones. Las autorizaciones se solicitan con acciones concretas; el inicio no presenta un conjunto indiscriminado de permisos. Denegación o revocación afecta sólo a las funciones dependientes.

`GlobalShortcutRegistry` utiliza `RegisterEventHotKey` con registro exclusivo y handler Carbon, comprueba duplicados en ZEUVE/navegación y combinaciones activas del sistema mediante `CopySymbolicHotKeys`. Libera registros al parar. No monitoriza globalmente el teclado. No puede detectar todos los atajos particulares de otras apps ni controladores; `CopySymbolicHotKeys` tampoco identifica qué acción representa cada entrada.

Los grabadores de atajos son monitores locales armados explícitamente. Los atajos de utilidades guardan keycode físico y modificadores, sin texto escrito; al cambiar distribución de teclado deben revisarse. ⌘Tab nativo se conserva. El selector usa ⌥Tab por defecto, con elección personalizable compatible.

## Audio: mezclador por aplicación

`ApplicationAudioMixerService` descubre procesos con salida real y metadatos disponibles, muestra aplicaciones compatibles y permite volumen 0–100 %/mute. La ruta se adquiere al ajustar explícitamente una fuente de la sesión; niveles guardados no autorizan capturar una aplicación recién abierta tras reiniciar.

`CoreAudioRoutingBackend` crea un Process Tap privado por fuente y un dispositivo agregado privado que reproduce la señal procesada. El tap usa `mutedWhenTapped`: silencia la salida original mientras ZEUVE lee la señal, evitando sumarla de nuevo. `AudioGainProcessor` aplica ganancia/rampa sobre ambos canales; no cambia el volumen maestro ni guarda PCM.

Compatibilidad concreta: macOS 14.2+, PCM Float32 estéreo y una única ruta de salida con formatos/tasas coherentes. Se rechazan dispositivos con streams de entrada —incluidos dispositivos combinados entrada/salida— para impedir que el agregado alcance micrófono. No se cambia el formato del dispositivo para forzar compatibilidad. Se excluyen ZEUVE, aplicaciones de llamada conocidas y procesos que estén usando entrada.

Cambios de salida/proceso, suspensión o errores detectados retiran las rutas afectadas; se revalida identidad antes de crear una nueva. Stop destruye los IOProc, agregados y taps que pertenecen a la utilidad detenida. Un fallo de destrucción conserva estado de error y recursos bajo propiedad para reintentar, sin declarar éxito. La denegación de captura se muestra cuando Core Audio la devuelve; la revocación real del permiso necesita QA y no se deduce de una señal silenciosa.

`AudioRoutingCoordinator` distingue propietarios `mixer` y `callDiagnostic`. Detener el mezclador no retira una ruta de diagnóstico; detener la prueba no cambia el volumen ni las rutas del mezclador. Una fuente con ganancias incompatibles entre propietarios se rechaza antes de alterar preferencias o audio. Volver al 100 % libera la ruta propia del mezclador, pero conserva una reproducción al 100 % solicitada por el diagnóstico. La parada global y Salir retiran los recursos de ambos propietarios y esperan las tareas de control propias.

## Audio: protección durante llamadas

Objetivo vigente: evitar atenuación de fuentes compatibles durante FaceTime/otras llamadas sin grabar conversaciones o alterar permanentemente la salida. **No está completada ni descartada.** Falta reproducir el problema real con FaceTime/altavoces, distinguir ducking de cambios de dispositivo/perfil Bluetooth/volumen y validar una solución eficaz con medidas.

La activación normal de `CallAudioProtectionService` sigue mostrando no disponible y el motivo pendiente; ninguna preferencia declara protección eficaz. Existe un diagnóstico funcional integrado en Ajustes para intentar la hipótesis de volver a reproducir fuentes compatibles mediante una ruta propia, sin convertir esa prueba en protección aceptada.

El usuario prepara una llamada de FaceTime y música o vídeo, busca fuentes seguras, las selecciona y pulsa **Probar ruta durante FaceTime**. La prueba fuerza Process Taps/rutas privadas a ganancia 1 incluso cuando el mezclador dejaría el 100 % en la salida original. No abre llamadas, modifica volumen maestro, cambia salida predeterminada ni captura micrófono. Excluye fuentes de llamada, ZEUVE y aplicaciones con entrada activa; rechaza fuentes que el mezclador controla con otra ganancia. Admite hasta ocho fuentes elegidas. **Detener prueba** retira únicamente sus recursos. No se activa, recupera o persiste automáticamente; sigue ejecutándose hasta detenerla o salir, aunque se cierre la vista.

La UI diferencia búsqueda, ruta de prueba en ejecución, parada y errores del estado de protección normal. El runtime dispone de una notificación de ciclo de diagnóstico independiente de los callbacks de la vista, para reflejar sus recursos residentes. La apertura, cambios nativos y tareas pendientes tienen propietario y se cancelan/esperan al cerrar; cambios de fuente/salida requieren selección explícita de nuevo.

Mientras la prueba recibe buffers muestra RMS agregado de entrada y salida y un contador de callbacks. Sólo conserva el último agregado en RAM mediante atómicos; no conserva muestras PCM, resultados en ajustes, historial o logs. Las cifras son niveles internos de la ruta, **no una medición del sonido físico ni prueba de eficacia**. Una señal cero no permite distinguir silencio legítimo de una captura revocada.

La comparación real debe empezar con FaceTime y altavoces internos, antes/durante/después de la llamada y alternando salida original/ruta de prueba. Después se contrastan AirPods, cambios de salida, suspensión, permisos y cierre inesperado. Crear un tap o ver RMS de entrada/salida iguales no demuestra que la salida física conserve volumen. La eficacia y esa QA siguen pendientes; cualquier imposibilidad que cambie el alcance se consulta de forma localizada, conservando el objetivo aprobado.

## Entrada: rueda discreta

`ScrollDirectionService` modifica sólo eventos de rueda discretos por medio del tap compartido de sesión. Vertical y horizontal son configurables; se invierten conjuntamente las representaciones líneas, puntos y fixed-point pertinentes. Eventos continuos, gestos, atributos de evento y fases conservan su comportamiento. Datos desconocidos/no finitos o que desbordan pasan intactos.

La opción invierte la dirección que ya entrega macOS; no modifica sus preferencias. Para trackpad natural/rueda clásica se mantiene la opción del trackpad en macOS y se corrige la rueda compatible. Las combinaciones inversas siguen la misma relación con el ajuste del sistema.

La clasificación discreto/continuo no certifica ratón/trackpad ni identidad física. No se ofrecen perfiles por dispositivo, Magic Mouse universal o garantías sobre eventos suavizados por software del fabricante. Se aplica a todas las ruedas discretas compatibles. Logitech G305 con receptor LIGHTSPEED USB es el primer hardware de validación, todavía sujeto a QA física.

El callback transforma el mismo evento y lo devuelve; no reinserta scroll. El broker usa un run loop fuera de MainActor y máscaras mínimas sin keyDown/keyUp. Stop espera retirada del source, invalidación de puerto/timer y finalización del worker. Comprueba permisos espaciadamente sólo mientras está activo; timeout/revocación detienen con estado visible, sin reactivación ciega.

## Entrada: botones adicionales

`AdditionalMouseButtonsService` captura explícitamente un botón durante un máximo de 15 segundos y muestra su índice real. La captura conserva la acción original y no ejecuta la asignación de ZEUVE. Primario, secundario y central —índices 0, 1 y 2— están protegidos. Sólo índices 3–31 admiten asignación, sin dar por expuestos botones de firmware como DPI.

Las asignaciones son globales por índice y pueden afectar a otro ratón con el mismo botón. No se confunden con perfiles físicos. Se consumen pares de eventos propiedad del servicio y se emiten atajos completos press/release con marca de origen propia. No se mantienen teclas pulsadas ni se leen contenidos del teclado. Ante entrada segura se omite la acción.

Presets: Atrás/Adelante para navegadores compatibles mediante ⌘←/⌘→, Mission Control mediante ⌃↑ y Escritorio mediante F11. Cada preset requiere que la aplicación/sistema tenga esa combinación configurada; una combinación enviada no prueba que se haya ejecutado su acción. Puede grabarse otra combinación explícita, validada contra funciones fundamentales/destructivas. No se usan códigos privados de Spaces/Mission Control.

`CGGetEventTapList` detecta otros filtros modificadores visibles y muestra un aviso técnico; no certifica incompatibilidad ni descubre todos los drivers. Si G HUB/u otra herramienta remapea los mismos botones, deben comprobarse posibles acciones duplicadas. ZEUVE no instala controladores, no toma el dispositivo en exclusiva y no cambia configuración de firmware.

## Ventanas: selector textual

`WindowSwitcherService` y backend AX enumeran ventanas utilizables y muestran aplicación/título temporalmente. Se filtran superficies no utilizables y se mantienen referencias verificadas mientras existe la sesión. La selección se confirma explícitamente con teclado; cancelar cierra el panel sin activar una ventana. Aplicaciones que terminan, minimizadas y falta de AX se revalidan.

El backend manda AX off-main con timeout y observadores bajo propiedad compartida. No solicita pantalla, genera miniaturas ni usa APIs privadas de Spaces. Pantalla completa, otras Spaces o apps que rechazan AX pueden impedir activación; debe mostrarse la limitación en vez de prometer control universal.

## Ventanas: distribuciones

`WindowLayoutsService` guarda perfiles con posiciones relativas, pantallas y slots por aplicación. No persiste títulos, documentos, rutas, referencias AX o PIDs como una identidad duradera. Un slot se asocia a una ventana elegida y compatible en la sesión; después de reiniciar se requiere reasociación explícita. Ventanas ambiguas no se emparejan por índice ni por título.

Restauración manual adapta/clampa geometrías a pantallas disponibles, cuenta restauradas/omitidas/fallidas y admite cancelación. Se verifica la topología durante el proceso y se detiene si cambia. La restauración automática está desactivada por defecto y exige opción expresa, perfil/topología compatibles y asociaciones vigentes; no reasocia ventanas arbitrariamente al reconectar un monitor.

## Finder: crear archivos

`NewFileUtilityService` presenta un `NSSavePanel` desde ZEUVE o recibe una carpeta seleccionada en Finder mediante `NSServices`. El servicio exige una sola carpeta válida; no obtiene silenciosamente la carpeta frontal. El menú Servicios depende de la selección, registro macOS y aplicación host; el host puede mostrar las acciones directamente o agrupadas bajo ZEUVE; no se promete un menú contextual universal ni se añade Finder Sync/otra extensión.

Formatos iniciales: txt, Markdown, JSON con `{}` visible, CSV o vacío de extensión permitida. Plantillas explícitas mantienen nombre, extensión y contenido en Ajustes. La validación rechaza nombres ocultos, separadores/control, longitud excesiva y extensiones fuera de la lista autorizada. Restablecer opciones conserva plantillas personalizadas.

`SafeNewFilePublisher` fija los descriptores de directorio y usa `O_NOFOLLOW` y temporales exclusivos. En APFS publica el contenido completo mediante `fclonefileat` desde el descriptor propio, sin depender de un nombre temporal sustituible. En sistemas sin clonación crea el destino exclusivamente y lo escribe por descriptor; allí puede verse durante la escritura. Nunca sustituye un existente. Rechaza componentes symlink, atiende cancelación y limpia sólo objetos propios con identidad de inode/dispositivo confirmada. Errores de permisos/conflictos/espacio se muestran. Las plantillas de más de 1 MiB reservan `OperationCoordinator` y atienden su cancelación. Las plantillas se cargan al usar la utilidad o sus opciones, no al iniciar el residente.

## Productividad: bandeja y selección de texto

La bandeja flotante conserva únicamente URLs locales en RAM. Incorporar/retirar referencias no copia, mueve ni elimina archivos. Deduplica, admite hasta 500 referencias y comprueba existencia; al desactivar/salir se vacía. El arrastre de salida entrega referencias al destino externo, que decide copiar/mover según su comportamiento; ZEUVE no valida ni atribuye esa operación a su propio publicador.

`TextActionsUtilityService` ofrece mayúsculas/minúsculas, espacios, unión de líneas y limpieza acotada de invisibles. `QuickUtilitiesServicesProvider` opera sobre el pasteboard de Servicios entregado explícitamente por la aplicación host, devuelve texto plano y deja al host reemplazar la selección si lo permite. Rechaza RTF/RTFD/HTML suministrados por el host antes de devolver contenido; no aplana documentos, vigila el portapapeles general o fuerza campos protegidos. No guarda selección en logs/historial.

## Compatibilidad y aceptación

| Plataforma | Estado de compatibilidad | Validación requerida |
| --- | --- | --- |
| macOS 14.0–14.1 | Base residente/API estimada; mezclador no disponible | QA de ciclo, entrada, ventanas y Servicios pendiente por plataforma |
| macOS 14.2+ | Process Taps públicos dentro de límites | Pruebas de salida/formato/dispositivo y permisos |
| macOS 15 | APIs estimadas compatibles | Ensayo real pendiente en esa versión |
| macOS 26 | Entorno local de desarrollo disponible | Sólo pruebas documentadas cuentan como verificadas |
| macOS 27 | SDK de compilación disponible en Xcode local | Runtime físico pendiente cuando exista entorno disponible |

No se certifica toda la matriz por compilar con un SDK. Las mediciones CPU/RSS/latencias, audio real, ratón G305, pantallas externas y hosts Servicios se añaden a la evidencia cuando se ejecuten. Quedan fuera brillo externo avanzado, capturas flotantes, reposo por reglas, drivers/KEXT, root/helpers privilegiados, plugins externos y reapertura del Descargador.

## Fuentes oficiales de diseño

- [Apple: Process Taps](https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps): creación/captura y autorización desde macOS 14.2; no afirma protección universal frente a ducking.
- [Apple: SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice): registro y aprobación efectiva de inicio.
- [Apple: CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent) y [resolución continua](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventiscontinuous): eventos y datos, sin identidad física universal de ratón.
- [Apple: IOHIDElementGetDevice](https://developer.apple.com/documentation/iokit/1564139-iohidelementgetdevice): dispositivo del elemento HID; no vínculo garantizado a un evento Quartz.
- [Apple: Mission Control](https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/mac): atajos configurables por el usuario.
- [Apple: Servicios](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html): proveedor y selección entregada por aplicaciones compatibles.
- [Logitech: G305](https://support.logi.com/hc/en-150/articles/360023303254-G305-LIGHTSPEED-Wireless-Gaming-Mouse-Technical-Specifications): receptor LIGHTSPEED USB y botones estándar, sin certificar remapeo de ZEUVE.

Los encabezados públicos del SDK local también se contrastaron para Carbon/HIToolbox, Quartz, NSEvent e IOKit. No hay API privada ni código reutilizado de ElfiSariña en estos servicios.
