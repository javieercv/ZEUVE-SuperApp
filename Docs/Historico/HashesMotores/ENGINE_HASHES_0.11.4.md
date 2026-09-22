# Integridad de motores — ZEUVE 0.11.4

## yt-dlp 2026.08.19

La distribución utilizada es `yt-dlp_macos.zip` 2026.08.19 publicada por el proyecto oficial. Antes de extraerla se comprobó el SHA-256 publicado:

```text
07e54b0865303c864006925913bce2604f8ee8cc6f18699bac9c309f9328a6d8  yt-dlp_macos.zip
```

Después de copiar la distribución descomprimida a `Resources/Engines/yt-dlp`, el manifiesto registra:

```text
Ejecutable SHA-256: 4f54eb67e4e96c7c3ffa49dd5deb81bc348bbb495080889b47d157d5c6d74443
Tamaño ejecutable: 10596144 bytes
Árbol SHA-256: cf470f85a034067963bec05223087297de658224753a6fc2dd92e33e89b23d37
Tamaño del árbol: 130010634 bytes
Archivos del árbol: 134
```

`Scripts/verify_engines_macos.sh` comprueba estos valores, la versión, arquitectura, permisos, firma y dependencias antes de compilar. Los demás motores conservan las versiones y huellas declaradas en `Resources/Engines/engines.json`.
