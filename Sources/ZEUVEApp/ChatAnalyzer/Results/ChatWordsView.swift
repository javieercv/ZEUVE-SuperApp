import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatWordsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    "Palabras y emojis",
                    subtitle: "Frecuencias calculadas sobre los mensajes incluidos",
                    topic: ZEUVEHelpTopics.chatWordsOverview
                )
                HStack {
                    HelpToggleRow(
                        "Incluir palabras vacías",
                        topic: ZEUVEHelpTopics.chatStopWords,
                        isOn: $model.operationSettings.includeStopWords
                    )
                    Spacer()
                    HelpLabel("Multimedia", topic: ZEUVEHelpTopics.chatMultimedia)
                    Picker("", selection: $model.operationSettings.multimediaDefinition) {
                        ForEach(MultimediaDefinition.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 280)
                }
                if model.operationSettings.multimediaDefinition == .configurable {
                    HelpGroupBox("Categorías consideradas multimedia", topic: ZEUVEHelpTopics.chatMultimedia) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                            ForEach(ChatContentType.allCases.filter { $0 != .text && $0 != .system }) { type in
                                Toggle(type.displayName, isOn: Binding(
                                    get: { model.operationSettings.configurableMultimediaTypes.contains(type) },
                                    set: { enabled in
                                        if enabled { model.operationSettings.configurableMultimediaTypes.insert(type) }
                                        else { model.operationSettings.configurableMultimediaTypes.remove(type) }
                                    }
                                ))
                            }
                        }
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    HelpGroupBox("Palabras frecuentes", topic: ZEUVEHelpTopics.chatWordFrequency) {
                        FrequencyRows(title: nil, items: model.wordsSnapshot.words)
                    }
                    .frame(maxWidth: .infinity)
                    HelpGroupBox("Frases de dos palabras", topic: ZEUVEHelpTopics.chatBigrams) {
                        FrequencyRows(title: nil, items: model.wordsSnapshot.bigrams)
                    }
                    .frame(maxWidth: .infinity)
                    HelpGroupBox("Emojis", topic: ZEUVEHelpTopics.chatEmojiFrequency) {
                        FrequencyRows(title: nil, items: model.wordsSnapshot.emojis)
                    }
                    .frame(maxWidth: .infinity)
                }
                HelpGroupBox("Por participante", topic: ZEUVEHelpTopics.chatParticipantFrequency) {
                    ForEach(model.wordsSnapshot.participants) { participant in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(participant.name).font(.headline)
                            Text("Palabras: " + participant.words.map { "\($0.value) (\($0.count))" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Emojis: " + participant.emojis.map { "\($0.value) (\($0.count))" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                HelpGroupBox("Tipos de contenido", topic: ZEUVEHelpTopics.chatContentTypes) {
                    ForEach(ChatContentType.allCases) { type in
                        if let count = model.wordsSnapshot.contentCounts[type], count > 0 {
                            LabeledContent(type.displayName, value: count.formatted())
                        }
                    }
                }
            }
            .padding(26)
        }
    }
}

