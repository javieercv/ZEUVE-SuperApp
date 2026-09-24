# Informe de implementación — ZEUVE 0.20.1.0

## Alcance

Inspector multimedia 0.7.1 corrige controles incoherentes de preview, pausa destructiva de vídeo, colisiones de identidad, fullscreen y cancelación de edición. También sustituye la heurística espectral sesgada por acumuladores acotados y métricas separadas.

## Implementación

`MultimediaPreviewControlResolver` decide estado/acción por identidad solicitada, confirmada y transporte global. Vídeo tiene generación propia, selección por identidad completa y pausa que conserva fuente/frame. La ventana propietaria se obtiene mediante `NSViewRepresentable` débil. Al descartar edición, `MultimediaPreviewSessionOwnershipResolver` conserva pausadas solo sesiones totalmente originales.

El análisis descarta silencio, acumula histogramas de rolloff/banda y ocupación por bin sobre toda la señal, mide cobertura temporal y agrupa anomalías contiguas conservando las más representativas. UI, ayuda e informes schema 3 exponen rolloff, banda efectiva, caída persistente, ventanas útiles y truncado.

No se añaden red, motores, dependencias, permisos ni cambios destructivos sobre originales.
