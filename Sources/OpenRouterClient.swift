import Foundation

enum OpenRouterError: LocalizedError {
    case missingApiKey
    case httpError(Int, String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Chưa nhập API key OpenRouter (vào Cài đặt)."
        case .httpError(let code, let body):
            return "Lỗi HTTP \(code): \(body)"
        case .emptyResponse:
            return "Model không trả về nội dung."
        }
    }
}

/// 1 file/ảnh đính kèm gửi kèm câu hỏi tới AI, mã hoá base64 để nhét vào content đa phương thức.
struct Attachment: Identifiable, Equatable {
    let id = UUID()
    let filename: String
    let mimeType: String
    let base64: String

    var isImage: Bool { mimeType.hasPrefix("image/") }
}

struct ChatMessage {
    let role: String
    let text: String
    var attachments: [Attachment] = []

    /// Nội dung gửi lên OpenRouter: chuỗi thuần nếu không có đính kèm, hoặc mảng part (text +
    /// image_url/file) theo chuẩn multimodal của OpenRouter khi có đính kèm.
    var contentJSON: Any {
        guard !attachments.isEmpty else { return text }
        var parts: [[String: Any]] = [["type": "text", "text": text]]
        for a in attachments {
            let dataUri = "data:\(a.mimeType);base64,\(a.base64)"
            if a.isImage {
                parts.append(["type": "image_url", "image_url": ["url": dataUri]])
            } else {
                parts.append(["type": "file", "file": ["filename": a.filename, "file_data": dataUri]])
            }
        }
        return parts
    }
}

/// Gọi OpenRouter (https://openrouter.ai) — 1 API key dùng chung cho GPT/Claude/Gemini/... qua
/// endpoint tương thích chuẩn OpenAI chat completions.
enum OpenRouterClient {
    static func complete(model: String, messages: [ChatMessage]) async throws -> String {
        let apiKey = Prefs.apiKey.trimmingCharacters(in: .whitespaces)
        guard !apiKey.isEmpty else { throw OpenRouterError.missingApiKey }

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("uk.denncoffee.aicouncilios", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("AI Council", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.contentJSON] },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterError.emptyResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OpenRouterError.httpError(http.statusCode, text)
        }

        struct CompletionResponse: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String? }
                let message: Msg
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw OpenRouterError.emptyResponse
        }
        return content
    }
}
