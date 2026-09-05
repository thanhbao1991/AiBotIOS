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

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct OpenRouterModel: Identifiable, Decodable, Hashable {
    var id: String
    let name: String
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
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
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

    /// Lấy toàn bộ danh sách model OpenRouter đang hỗ trợ (kể cả model free), để user chọn tuỳ ý.
    static func fetchModels() async throws -> [OpenRouterModel] {
        let apiKey = Prefs.apiKey.trimmingCharacters(in: .whitespaces)
        guard !apiKey.isEmpty else { throw OpenRouterError.missingApiKey }

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterError.emptyResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OpenRouterError.httpError(http.statusCode, text)
        }

        struct ModelsResponse: Decodable { let data: [OpenRouterModel] }
        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        // Model trả phí lên đầu (thường chất lượng cao/ổn định hơn), model free xuống cuối.
        return decoded.data.sorted { a, b in
            let aFree = a.id.hasSuffix(":free")
            let bFree = b.id.hasSuffix(":free")
            if aFree != bFree { return !aFree }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
