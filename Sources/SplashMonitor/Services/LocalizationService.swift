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
    
    @AppStorage("appLanguage") public var currentLanguage: String = "es" {
        didSet {
            objectWillChange.send()
        }
    }
    
    public var isSpanish: Bool {
        currentLanguage == "es"
    }
    
    public func toggleLanguage() {
        currentLanguage = (currentLanguage == "es") ? "en" : "es"
    }
    
    public func text(es: String, en: String) -> String {
        return (currentLanguage == "es") ? es : en
    }
}

// Convenience global helper
public func tr(es: String, en: String) -> String {
    return Localization.shared.text(es: es, en: en)
}
