import Foundation

/// Lưu cấu hình app trong UserDefaults. App cá nhân cài qua Sideloadly (không phát hành App
/// Store), nên UserDefaults là đủ — không cần Keychain.
enum Prefs {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let backendApiKey = "backendApiKey"
        static let currentJobId = "currentJobId"
    }

    /// Backend trung gian (VPS) thật sự gọi OpenRouter — app chỉ là giao diện gửi câu hỏi + xem
    /// kết quả, nên mất kết nối/chuyển app giữa chừng không làm mất câu trả lời đang xử lý.
    static let backendBaseURL = "https://tsbot.denncoffee.uk"

    /// Khoá xác thực với backend (header X-Api-Key) — khác với API key OpenRouter, khoá đó giờ
    /// chỉ nằm trên VPS, app không cần biết.
    static var backendApiKey: String {
        get { defaults.string(forKey: Key.backendApiKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.backendApiKey) }
    }

    /// Job đang xử lý dở (nếu có) — lưu lại để app relaunch/chuyển app xong quay lại vẫn theo
    /// dõi tiếp đúng job đó thay vì phải hỏi lại từ đầu.
    static var currentJobId: String? {
        get { defaults.string(forKey: Key.currentJobId) }
        set { defaults.set(newValue, forKey: Key.currentJobId) }
    }

    /// Chỉ để hiển thị thông tin trong Cài đặt — model thật cố định trên backend.
    static let councilLabels = ["Claude", "Gemini", "ChatGPT"]
    static let synthesizerLabel = "Claude Opus"
}
