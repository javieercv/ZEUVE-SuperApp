# Entrega — ZEUVE 0.9.1

## Resumen

ZEUVE 0.9.1 actualiza el Descargador universal a 0.5.1. Los vídeos encontrados al analizar una página se descargan como originales, mientras que los enlaces directos conservan todas las opciones de formato y calidad. Se añaden nombres limpios y procedencia opcional.

## Versiones

- ZEUVE anterior: 0.9.0, build 28.
- ZEUVE nueva: 0.9.1, build 29.
- Descargador universal anterior: 0.5.0.
- Descargador universal nuevo: 0.5.1.

## Contenido

El ZIP contiene el proyecto completo, fuentes, recursos, pruebas, scripts, manifiestos, documentación, proyecto Xcode y motores ya presentes en la versión recibida. No contiene `.build`, DerivedData, cachés, logs, credenciales, temporales ni datos privados.

## Cambios principales

- política individual `directContent` / `pageDiscovered`;
- descarga original sin transformación para vídeos encontrados en páginas;
- operaciones mixtas;
- nombres sin IDs técnicos y numeración desde `(1)`;
- procedencia opcional incrustada sin recodificación;
- fecha opcional y «De dónde» de macOS independiente;
- ayudas contextuales y ajustes centralizados;
- compatibilidad con datos anteriores;
- nuevas pruebas funcionales, unitarias y estáticas.

## Limitaciones

No se añade navegador automatizado. La compatibilidad continúa dependiendo de yt-dlp y de lo que la página exponga sin interacciones JavaScript complejas. La validación visual, de firma y del atributo extendido requiere macOS Apple Silicon.
