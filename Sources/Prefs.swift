import Foundation

/// 1 AI cố định trong hội đồng: nhãn hiển thị + slug model OpenRouter thật sẽ gọi.
struct CouncilModel {
    let label: String
    let slug: String
}

/// Lưu API key OpenRouter trong UserDefaults. Đây là app cá nhân cài qua Sideloadly (không phát
/// hành App Store), nên UserDefaults là đủ — không cần Keychain.
enum Prefs {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let apiKey = "openRouterApiKey"
    }

    static var apiKey: String {
        get { defaults.string(forKey: Key.apiKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.apiKey) }
    }

    /// 3 AI cố định trả lời độc lập. Dùng slug dạng "~vendor/model-latest" (rolling alias của
    /// OpenRouter) để tự động trỏ tới bản mới nhất của mỗi hãng, khỏi phải sửa code khi có model mới.
    static let councilModels = [
        CouncilModel(label: "Claude", slug: "~anthropic/claude-sonnet-latest"),
        CouncilModel(label: "Gemini", slug: "~google/gemini-pro-latest"),
        CouncilModel(label: "ChatGPT", slug: "openai/gpt-chat-latest"),
    ]

    /// Model "trọng tài" tổng hợp câu trả lời cuối — cố định Claude Opus (tier cao nhất).
    static let synthesizerModel = "~anthropic/claude-opus-latest"
}
