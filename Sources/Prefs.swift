import Foundation

/// Lưu API key OpenRouter + danh sách model trong UserDefaults. Đây là app cá nhân cài qua
/// Sideloadly (không phát hành App Store), nên UserDefaults là đủ — không cần Keychain.
enum Prefs {
    private static let defaults = UserDefaults.standard

    static let minModels = 2
    static let maxModels = 5

    private enum Key {
        static let apiKey = "openRouterApiKey"
        static let models = "selectedModels"
        static let synthesizer = "synthesizerModel"
    }

    static var apiKey: String {
        get { defaults.string(forKey: Key.apiKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.apiKey) }
    }

    /// Model slug OpenRouter, vd "openai/gpt-5", mỗi dòng 1 model.
    static var models: [String] {
        get {
            let raw = defaults.string(forKey: Key.models) ?? defaultModels.joined(separator: "\n")
            return raw
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set { defaults.set(newValue.joined(separator: "\n"), forKey: Key.models) }
    }

    static var synthesizerModel: String {
        get { defaults.string(forKey: Key.synthesizer) ?? defaultModels[0] }
        set { defaults.set(newValue, forKey: Key.synthesizer) }
    }

    static let defaultModels = [
        "openai/gpt-5",
        "anthropic/claude-sonnet-4.5",
        "google/gemini-2.5-pro",
    ]
}
