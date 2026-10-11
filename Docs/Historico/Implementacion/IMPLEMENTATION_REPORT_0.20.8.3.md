# Implementación — ZEUVE 0.20.8.3

Fecha: 12/10/2026. Base remota sincronizada: `b2c4fa7fc3b5347b6e28bb136ad5ff886865190d`, sin cambios locales previos. Marketing 0.20.8, revisión 3/build 77; Descargador 0.7.7; adaptador propio 4.15.3-zeuve.6 sobre Instaloader 4.15.3.

## Alcance aprobado

El usuario aprueba la sesión opcional plegada para perfiles públicos o consultas bloqueadas, conservando el panel desplegado en contenido protegido. Aprueba separadamente `/USUARIO/embed/` como respaldo público anónimo. No se añaden dependencias, cookies personales, servicios terceros ni la inserción individual de publicaciones.

## Resultado implementado

- `DownloadAnalysis` calcula la presentación de sesión sin cambiar su formato Codable. La vista distingue panel requerido y DisclosureGroup opcional, plegado al aparecer.
- El parser conserva biografía y avisos únicos. Las restricciones de Stories/destacadas no bloquean las fotos públicas disponibles.
- El helper decodifica únicamente `contextJSON` y exige tipo Profile, usuario, owner_id, enlace canónico y propietario público de cada publicación. Con metadata previa comprueba también el ID conocido. No ejecuta scripts ni recorre recomendaciones.
- Usa el respaldo cuando falla el lookup anónimo o el feed no ofrece publicaciones; no lo usa para una operación con sesión aportada ni para un perfil privado. Un feed vacío confirmado sin error no activa el respaldo.
- Extrae fotos con extensión real y recursos de mayor resolución disponible, valida HTTPS y conserva ordinales originales del carrusel. Omite vídeos sin URL de reproducción, duplicados y datos malformados.
- El respaldo se consulta como máximo una vez por catálogo, también si falla. Emite muestra parcial finita, recuento local, cursor limitado a la muestra y avisos de publicaciones/vídeos ausentes. El servicio devuelve esa muestra sin repetir el feed con gallery-dl.
- Se reconstruye el ejecutable ARM64 propio y se actualiza su manifiesto/hash; el upstream y dependencias permanecen iguales.

## UI y estabilidad

Durante la QA, dos recorridos de desplazamiento bloquearon la composición de SwiftUI con CPU de ≈100 %. Se sustituyó el contenedor exterior LazyVStack por VStack para mantener montadas las tarjetas estáticas; la cuadrícula y lista del catálogo conservan su carga perezosa. No cambia selección, opciones ni distribución aprobada. La repetición nativa y sus resultados se documentan en el informe de QA.

## Seguridad, errores y límites

La sesión sigue siendo expresa. El respaldo comprueba la ausencia de usuario autenticado y sessionid personal antes de consultar. Rechazos, redirecciones de identidad, respuestas sobredimensionadas y contextos inválidos no producen recursos. La cancelación y el presupuesto de análisis existente siguen deteniendo el proceso. Las URLs firmadas permanecen en memoria; los archivos se validan y publican con el contrato vigente. No hay migraciones SQLite, permisos nuevos, proxy, navegador automatizado ni ZIP.

[Investigación y fuentes](INSTAGRAM_PUBLIC_ACCESS_RESEARCH_20261012.md), [verificación](../Pruebas/TEST_RESULTS_0.20.8.3.md) y [QA nativa](../Pruebas/DOWNLOADER_QA_0.20.8.3_20261012.md).
