<div align="center">

# ZEUVE

### Una superapp modular para macOS

Herramientas distintas, una sola aplicación, con especial cuidado por la privacidad, los archivos originales y la experiencia de uso.

<br>

![Versión](https://img.shields.io/badge/ZEUVE-0.20.7.0-2f81f7?style=flat-square)
![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-nativo-000000?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)
![Telemetría](https://img.shields.io/badge/telemetr%C3%ADa-no-2ea043?style=flat-square)

<br>

**[Módulos](#módulos)** · **[Principios](#principios)** · **[Desarrollo](#desarrollo)** · **[Documentación](#documentación)**

</div>

---

## Qué es ZEUVE

**ZEUVE** es una aplicación nativa y modular para **macOS 14+ en Apple Silicon** que reúne herramientas de organización, descarga, análisis, conversión, inspección multimedia y mantenimiento dentro de una única interfaz.

El proyecto está pensado para crecer por módulos sin perder una experiencia común: navegación compartida, historial, ajustes centralizados, operaciones coordinadas y criterios de seguridad coherentes en toda la aplicación.

> [!IMPORTANT]
> **Privacidad primero.** ZEUVE no incorpora telemetría ni analítica. Las funciones que no necesitan Internet trabajan localmente y las que sí necesitan red limitan su uso al necesario para la operación.

---

## Módulos

| | Módulo | Función principal | Documentación |
|:--:|---|---|:--:|
| 📁 | **Organizador** | Organización y tratamiento de archivos | [Ver](Docs/Modulos/Funcionales/ORGANIZER.md) |
| ⬇️ | **Descargador universal** | Descarga de contenido desde fuentes compatibles | [Ver](Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER.md) |
| 💬 | **Analizador de chats** | Análisis local de conversaciones exportadas | [Ver](Docs/Modulos/Funcionales/CHAT_ANALYZER.md) |
| 🔄 | **Conversor universal** | Conversión de archivos entre formatos compatibles | [Ver](Docs/Modulos/Funcionales/UNIVERSAL_CONVERTER.md) |
| 👥 | **Comparador de seguidores de Instagram** | Comparación local de listas exportadas | [Ver](Docs/Modulos/Funcionales/INSTAGRAM_FOLLOWERS_COMPARATOR.md) |
| 🎬 | **Inspector multimedia** | Inspección, análisis y edición estructural segura | [Ver](Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md) |
| 🧹 | **Limpiador** | Inventario, residuos, limpieza segura y desinstalación asistida | [Ver](Docs/Modulos/Funcionales/CLEANER.md) |

ZEUVE también dispone de **Historial**, ajustes centralizados y personalización del orden y los atajos de los módulos.

---

## Principios

### 🔒 Privacidad y control

- Sin telemetría ni analítica.
- Minimización de datos y registros.
- Uso de red únicamente cuando la función lo requiere.
- Ajustes persistentes centralizados.

### 🛡️ Protección de archivos

- Los originales se protegen y no se sobrescriben silenciosamente.
- Los resultados se publican mediante flujos seguros.
- Las operaciones destructivas requieren revisión y protecciones específicas.
- Los resultados relevantes se validan antes de considerarse correctos.

### ⚙️ Arquitectura y operaciones

- Arquitectura modular con componentes compartidos.
- Operaciones pesadas coordinadas y cancelables.
- Motores externos ejecutados con argumentos separados y validados.
- Sin comandos de shell interpolados para ejecutar motores.

---

## Plataforma

| Componente | Estado |
|---|---|
| **Sistema** | macOS 14 o posterior |
| **Arquitectura** | Apple Silicon |
| **Lenguaje** | Swift 6 |
| **Interfaz** | SwiftUI + AppKit cuando es necesario |
| **Seguridad** | Hardened Runtime |
| **Sandbox** | Sin App Sandbox en la fase actual |

### Motores

Algunas funciones utilizan motores locales incluidos o preparados para ZEUVE, como **FFmpeg** y **FFprobe**.

Los motores no se descargan ni actualizan automáticamente al abrir la aplicación. Su preparación, validación y empaquetado forman parte del proceso controlado de construcción de ZEUVE.

---

## Desarrollo

Desde la carpeta raíz del proyecto:

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
./Scripts/build_macos.sh Release
```

> [!NOTE]
> La validación final de Xcode, firma, Hardened Runtime, SwiftUI/AppKit y motores ARM64 debe realizarse en un Mac Apple Silicon compatible.

---

## Documentación

La documentación técnica y funcional se mantiene fuera del README para que esta página siga siendo una portada clara del proyecto.

### **[→ Abrir el índice completo de documentación](Docs/INDEX.md)**

Desde ahí se puede acceder a:

- arquitectura, alcance, seguridad, compilación y pruebas;
- documentación funcional de cada módulo;
- desarrollo y API de módulos;
- motores y empaquetado;
- licencias, créditos y avisos de software de terceros;
- informes de implementación;
- resultados de pruebas;
- entregas e histórico de versiones.

### Licencias y créditos

La documentación distingue el código propio de ZEUVE de los componentes externos y conserva los textos legales originales de los motores y dependencias empaquetados.

**[→ Licencias y créditos](Docs/Fundamentos/LICENCIAS_Y_CREDITOS.md)** · **[→ Avisos de software de terceros](THIRD_PARTY_NOTICES.md)**

Para consultar la evolución del proyecto:

### **[→ Ver el histórico de ZEUVE](Docs/Historico/)**

---

<div align="center">

### ZEUVE 0.20.7.0

Desarrollo activo para macOS · Apple Silicon

Nueve parciales locales corregidos y comprobados desde la interfaz: reglas del Organizador, AAC/favoritos, OCR, revisión de planes y portada MOV. [QA manual](Docs/Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005.md) y [evidencia técnica](Docs/Historico/Pruebas/TEST_RESULTS_0.20.7.0.md). El [cierre de volumen y sincronía](Docs/Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005_AUDIO_VIDEO.md) completó el alcance local el 05/10/2026. La [QA del Descargador del 09/10/2026](Docs/Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261009.md) añade comprobaciones remotas en Debug. La [continuación del 10/10/2026](Docs/Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010.md) cierra Twitch, orden del carrusel y rechazo de directos, amplía carpetas y conserva los límites remotos. El [remate posterior](Docs/Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010_CONTINUATION.md) acepta la repetición completa, registra fallo de galería EroMe y demuestra persistencia de canarios de credenciales en un error de log. La [QA de sesión autorizada](Docs/Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010_SESSION.md) comprueba exportación limitada a Instagram, rechazo del archivo original por caducidad vacía, aceptación de una copia normalizada y ausencia de cookies en los logs de esos análisis. El catálogo sigue sin resolverse y no aparece el panel para pegar/recordar sesión. El [contraste con otro perfil público](Docs/Historico/Pruebas/DOWNLOADER_QA_0.20.7.0_20261010_PUBLIC_PROFILE.md) confirma contenido visible en navegador, perfil vacío en ZEUVE y enlaces concretos operativos (publicación de 17 elementos y Reel descargado/verificado), sin modificar estados de aceptación. La checklist actual (`Cheklist Manual de aceptacion de ZEUVE.md`) registra 630 pruebas ejecutadas: 613 OK, 9 fallidas y 8 parciales; 9 permanecen sin probar. Probada no significa correcta ni aceptación completa de Release. Todo estado sin OK pertenece al Descargador o a su autenticación. La [QA manual de 0.20.6.0](Docs/Historico/Pruebas/MANUAL_QA_0.20.6.0_20261004.md) conserva los 22 IDs revalidados anteriormente.

</div>
