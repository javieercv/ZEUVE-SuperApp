#!/usr/bin/env python3
"""Punto de entrada estable para empaquetar gallery-dl dentro de ZEUVE."""
import gallery_dl

if __name__ == "__main__":
    raise SystemExit(gallery_dl.main())
