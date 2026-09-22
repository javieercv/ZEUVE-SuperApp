import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatFilterPanel: View {
    @ObservedObject var model: ChatAnalyzerViewModel

    var body: some View {
        Form {
            Section("Fechas") {
                Toggle("Limitar fecha inicial", isOn: Binding(get: { model.filter.startDate != nil }, set: { model.filter.startDate = $0 ? startOfDay(model.firstTimelineMessage ?? Date()) : nil }))
                if model.filter.startDate != nil { DatePicker("Desde", selection: Binding(get: { model.filter.startDate ?? Date() }, set: { model.filter.startDate = startOfDay($0) }), displayedComponents: .date) }
                Toggle("Limitar fecha final", isOn: Binding(get: { model.filter.endDate != nil }, set: { model.filter.endDate = $0 ? endOfDay(model.lastTimelineMessage ?? Date()) : nil }))
                if model.filter.endDate != nil { DatePicker("Hasta", selection: Binding(get: { model.filter.endDate ?? Date() }, set: { model.filter.endDate = endOfDay($0) }), displayedComponents: .date) }
            }
            Section("Plataformas") {
                ForEach(ChatPlatform.allCases) { platform in
                    Toggle(platform.displayName, isOn: setBinding(platform, in: $model.filter.platforms))
                }
            }
            Section("Participantes") {
                ForEach(model.participantNames, id: \.self) { name in Toggle(name, isOn: setBinding(name, in: $model.filter.participants)) }
            }
            Section("Tipos de contenido") {
                ForEach(ChatContentType.allCases) { type in
                    Toggle(type.displayName, isOn: setBinding(type, in: $model.filter.contentTypes))
                }
            }
            Section("Días de la semana") {
                ForEach(1...7, id: \.self) { day in
                    Toggle(weekdayName(day), isOn: setBinding(day, in: $model.filter.weekdays))
                }
            }
            Section("Horario") {
                Picker("Desde", selection: optionalHour($model.filter.startHour)) { Text("Sin límite").tag(-1); ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } }
                Picker("Hasta", selection: optionalHour($model.filter.endHour)) { Text("Sin límite").tag(-1); ForEach(0..<24, id: \.self) { Text(String(format: "%02d:59", $0)).tag($0) } }
                Text("Si la hora inicial es posterior a la final, el intervalo atraviesa la medianoche.").font(.caption).foregroundStyle(.secondary)
            }
            Section { Button("Restablecer todos los filtros") { model.filter = ChatFilter() }.disabled(model.filter.activeCount == 0) }
        }.formStyle(.grouped).padding(8)
    }

    private func setBinding<T: Hashable>(_ value: T, in set: Binding<Set<T>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { enabled in
            if enabled { set.wrappedValue.insert(value) } else { set.wrappedValue.remove(value) }
        })
    }

    private func optionalHour(_ value: Binding<Int?>) -> Binding<Int> {
        Binding(get: { value.wrappedValue ?? -1 }, set: { value.wrappedValue = $0 < 0 ? nil : $0 })
    }

    private func startOfDay(_ date: Date) -> Date { ChatAnalytics.calendar.startOfDay(for: date) }
    private func endOfDay(_ date: Date) -> Date {
        let start = ChatAnalytics.calendar.startOfDay(for: date)
        return ChatAnalytics.calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-0.001) ?? date
    }
}

