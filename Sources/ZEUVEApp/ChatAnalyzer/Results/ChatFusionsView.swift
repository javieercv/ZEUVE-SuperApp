import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatFusionsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    "Fusión de identidades",
                    subtitle: "Une nombres que pertenecen a la misma persona solo durante este análisis",
                    topic: ZEUVEHelpTopics.chatFusionsOverview
                )
                GroupBox {
                    Label("La fusión no modifica los archivos ni elimina el autor original. Recalcula estadísticas, conversaciones, respuestas y búsquedas.", systemImage: "lock.shield")
                }
                HelpGroupBox("Participantes", topic: ZEUVEHelpTopics.chatFusionParticipants) {
                    ForEach(model.participantNames, id: \.self) { name in
                        Toggle(name, isOn: Binding(
                            get: { model.fusionSelection.contains(name) },
                            set: { enabled in
                                if enabled { model.fusionSelection.insert(name) }
                                else { model.fusionSelection.remove(name) }
                            }
                        ))
                    }
                }
                HStack {
                    HelpLabel("Nombre común", topic: ZEUVEHelpTopics.chatFusionName)
                    TextField("Nombre común", text: $model.fusionName).textFieldStyle(.roundedBorder)
                    Button("Fusionar seleccionados") { model.mergeSelectedIdentities() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.fusionSelection.count < 2 || model.fusionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                HelpGroupBox("Fusiones activas", topic: ZEUVEHelpTopics.chatActiveFusions) {
                    if model.identityMap.isEmpty {
                        Text("No hay fusiones activas.").foregroundStyle(.secondary)
                    } else {
                        ForEach(Dictionary(grouping: model.identityMap.keys, by: { model.identityMap[$0] ?? $0 }).keys.sorted(), id: \.self) { merged in
                            LabeledContent(
                                merged,
                                value: Dictionary(grouping: model.identityMap.keys, by: { model.identityMap[$0] ?? $0 })[merged, default: []].sorted().joined(separator: ", ")
                            )
                        }
                    }
                }
                HStack {
                    HelpLabel("Deshacer", topic: ZEUVEHelpTopics.chatUndoFusions)
                    Button("Deshacer última fusión") { model.undoFusion() }
                        .disabled(model.fusionHistory.isEmpty)
                    Button("Restablecer todas", role: .destructive) { model.resetFusions() }
                        .disabled(model.identityMap.isEmpty)
                }
            }
            .padding(26)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

