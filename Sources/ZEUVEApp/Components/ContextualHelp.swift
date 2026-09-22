import SwiftUI

struct ContextualHelpTopic: Sendable {
    let title: String
    let explanation: String
    let recommendation: String?

    init(_ title: String, explanation: String, recommendation: String? = nil) {
        self.title = title
        self.explanation = explanation
        self.recommendation = recommendation
    }
}

struct ContextualHelpButton: View {
    let topic: ContextualHelpTopic
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Más información sobre \(topic.title)")
        .accessibilityLabel("Información sobre \(topic.title)")
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 10) {
                Label(topic.title, systemImage: "info.circle.fill")
                    .font(.headline)
                Text(topic.explanation)
                    .fixedSize(horizontal: false, vertical: true)
                if let recommendation = topic.recommendation {
                    Divider()
                    Label(recommendation, systemImage: "lightbulb")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(width: 340, alignment: .leading)
        }
    }
}

struct HelpLabel: View {
    let text: String
    let topic: ContextualHelpTopic

    init(_ text: String, topic: ContextualHelpTopic) {
        self.text = text
        self.topic = topic
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
            ContextualHelpButton(topic: topic)
        }
    }
}

enum ZEUVEHelpTopics {}


struct HelpPickerRow<Selection: Hashable, Content: View>: View {
    let title: String
    let topic: ContextualHelpTopic
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        topic: ContextualHelpTopic,
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.topic = topic
        _selection = selection
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            HelpLabel(title, topic: topic)
            Spacer(minLength: 12)
            Picker("", selection: $selection, content: content)
                .labelsHidden()
                .frame(maxWidth: 360)
        }
    }
}

struct HelpToggleRow: View {
    let title: String
    let topic: ContextualHelpTopic
    @Binding var isOn: Bool

    init(_ title: String, topic: ContextualHelpTopic, isOn: Binding<Bool>) {
        self.title = title
        self.topic = topic
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: 6) {
            Toggle(title, isOn: $isOn)
            ContextualHelpButton(topic: topic)
        }
    }
}

struct HelpStepperRow: View {
    let title: String
    let topic: ContextualHelpTopic
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(_ title: String, topic: ContextualHelpTopic, value: Binding<Int>, in range: ClosedRange<Int>) {
        self.title = title
        self.topic = topic
        _value = value
        self.range = range
    }

    var body: some View {
        HStack(spacing: 6) {
            Stepper(title, value: $value, in: range)
            ContextualHelpButton(topic: topic)
        }
    }
}
