import Foundation

public enum ChatAnalytics {
    public static let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "es_ES")
        value.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        return value
    }()
}
