import Foundation
import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }
    
    public var flag: String {
        switch self {
        case .spanish: return "🇩🇴"
        case .english: return "🇬🇧"
        }
    }
}

public class Localization: ObservableObject {
    public static let shared = Localization()
    
    /// Stored preference: "system", "es", or "en". Defaults to "system".
    @AppStorage("languageMode") public var languageMode: String = "system" {
        didSet {
            objectWillChange.send()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // Detect and react to macOS system language/locale changes in real time
        NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Detect the primary language of the macOS system
    public static func detectSystemLanguage() -> String {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferred.hasPrefix("es") {
            return "es"
        }
        return "en"
    }
    
    /// The active language code ("es" or "en") resolved from user preference or macOS system
    public var currentLanguage: String {
        if languageMode == "system" {
            return Localization.detectSystemLanguage()
        }
        return languageMode
    }
    
    public var isSpanish: Bool {
        return currentLanguage == "es"
    }
    
    public var isSystemMode: Bool {
        return languageMode == "system"
    }
    
    /// Cycles through: system -> (opposite of system) -> system
    public func toggleLanguage() {
        if languageMode == "system" {
            // If system is currently Spanish, switch explicitly to English; otherwise Spanish
            let sys = Localization.detectSystemLanguage()
            languageMode = (sys == "es") ? "en" : "es"
        } else if languageMode == "es" {
            languageMode = "en"
        } else {
            languageMode = "system"
        }
    }
    
    public func setLanguageMode(_ mode: String) {
        languageMode = mode
    }
    
    public func text(es: String, en: String) -> String {
        return (currentLanguage == "es") ? es : en
    }
}

// Convenience global helper
public func tr(es: String, en: String) -> String {
    return Localization.shared.text(es: es, en: en)
}
