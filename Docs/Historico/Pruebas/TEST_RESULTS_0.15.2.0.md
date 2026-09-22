# Resultados de pruebas — ZEUVE 0.15.2.0

Fecha: 9 de septiembre de 2026.

## Suite automática

`./Scripts/run_tests.sh` terminó con código 0:

- XCTest: **215**, 0 fallos.
- Swift Testing: **120**, 0 fallos.
- Python ScriptTests: **83**, 0 fallos.
- Total: **418**, 0 fallos.

Las tres regresiones nuevas verifican que la limpieza termine antes del siguiente arranque, que A→B→C autorice únicamente C y que stop invalide un reemplazo pendiente. Los verificadores exigen además `replaceSource`, el gate generacional, recursos capturados, `requestedPreviewSourceID`, **Cargando…** y el uso intacto de `defaultPreferences.allowedFFTSizes`.

## Prueba real macOS

Se ejecutó `MultimediaAudioPreviewService` real con FFmpeg empaquetado y AVAudioEngine sobre:

`MZ_1972_Ep01.El nacimiento de un robot milagroso.Audio Jap,Es Tve1,Es Mex Sdi Media.mkv`

Resultados observados:

- A(stream 1) inició en 10 s y avanzó con reproducción real.
- A→B(stream 2) conservó el instante; B quedó en reproducción.
- B→C(stream 3)→D(stream 4) invalidó C con `CancellationError`; D quedó activa y conservó el instante capturado.
- D→A volvió correctamente a la primera pista.
- A pausada→B arrancó B desde la posición pausada.
- una fuente con duración declarada menor limitó el playhead al final válido.
- original→audio externo temporal inició la fuente externa desde 0,4 s.
- stop final dejó estado idle y `ExternalProcessRunner.activeProcessID == nil`.

## Build nativa

`./Scripts/build_macos.sh Release` terminó con `BUILD SUCCEEDED`. Xcode compiló SwiftUI/AppKit/AVFoundation en Swift 6, firmó `ZEUVE.app`, validó Hardened Runtime y comprobó los motores empaquetados. Se mantiene un aviso previo, fuera de esta corrección, por una constante `height` sin usar en `MultimediaWaveformView.swift`.
