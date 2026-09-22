import Foundation
import ZEUVEStorage
public enum CleanerStorageKeys{public static let preferences="cleaner.preferences"}
public struct CleanerSettingsStore:Sendable{let settings:SettingsRepository?;public init(settings:SettingsRepository?){self.settings=settings};public func load()->CleanerPreferences{(try? settings?.value(forKey:CleanerStorageKeys.preferences,as:CleanerPreferences.self)) ?? .default};public func save(_ p:CleanerPreferences)throws{try settings?.set(p,forKey:CleanerStorageKeys.preferences)};public func restoreDefaults()throws{try settings?.set(CleanerPreferences.default,forKey:CleanerStorageKeys.preferences)}}
