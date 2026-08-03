# Artefactos y hashes de motores — ZEUVE 0.2.0

Estos hashes protegen las descargas utilizadas por `Scripts/prepare_engines_macos.sh`.

| Artefacto | Versión | SHA-256 |
|---|---:|---|
| `yt-dlp_macos` | 2026.06.09 | `b82c3626952e6c14eaf654cc565866775ffd0b9ffb7021628ac59b42c2f4f244` |
| `deno-aarch64-apple-darwin.zip` | 2.9.0 | `2d11cf0505d4600a4492de8d07456a7a5e7eedebf68bdcbcb9092f520fcde0f1` |
| `ffmpeg-8.1.2.tar.xz` | 8.1.2 | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` |
| `opus-1.5.2.tar.gz` | 1.5.2 | `65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1` |
| `lame-3.100.tar.gz` | 3.100 | `ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e` |

## Hashes de ejecutables finales

Los hashes finales no pueden fijarse antes de compilar FFmpeg y copiar los artefactos en macOS. El script genera automáticamente:

```text
Resources/Engines/engines.json
```

Ese archivo contiene el SHA-256 y tamaño real de:

- `yt-dlp/yt-dlp`;
- `deno/deno`;
- `ffmpeg/ffmpeg`;
- `ffmpeg/ffprobe`.

La verificación falla si un archivo cambia después de generar el manifiesto.
