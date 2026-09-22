import SwiftUI

struct MultimediaEmptyView: View {
    let chooseSingle: () -> Void
    let chooseMultiple: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Arrastra uno o varios archivos de audio o vídeo aquí")
                .font(.title3.weight(.semibold))
            Text("Un archivo abre el Inspector normal; varios preparan un lote. La inspección comienza siempre en modo de solo lectura.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)
            HStack(spacing: 10) {
                Button("Seleccionar archivo", action: chooseSingle)
                    .buttonStyle(.borderedProminent)
                Button("Analizar varios archivos…", action: chooseMultiple)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary))
        .accessibilityElement(children: .contain)
    }
}
