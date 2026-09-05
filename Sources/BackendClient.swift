import Foundation

enum BackendError: LocalizedError {
    case missingApiKey
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Chưa nhập khoá truy cập backend (vào Cài đặt)."
        case .httpError(let code, let body):
            return "Lỗi HTTP \(code): \(body)"
        }
    }
}

/// 1 file/ảnh đính kèm gửi kèm câu hỏi.
struct Attachment: Identifiable, Equatable {
    let id = UUID()
    let filename: String
    let mimeType: String
    let base64: String

    var isImage: Bool { mimeType.hasPrefix("image/") }
}

struct JobAnswer: Decodable {
    let label: String
    let answer: String?
    let error: String?
}

struct JobDetail: Decodable {
    let id: String
    let question: String
    let status: String
    let answers: [JobAnswer]
    let finalAnswer: String?
    let errorMessage: String?
    let createdAt: String
}

struct JobSummary: Decodable, Identifiable {
    let id: String
    let question: String
    let status: String
    let finalAnswer: String?
    let createdAt: String
}

/// Gọi backend trung gian (VPS) — backend mới thật sự gọi OpenRouter, app chỉ gửi câu hỏi và
/// theo dõi tiến độ (poll) nên mất kết nối/chuyển app giữa chừng không làm mất câu trả lời.
enum BackendClient {
    private static func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) throws -> URLRequest {
        let apiKey = Prefs.backendApiKey.trimmingCharacters(in: .whitespaces)
        guard !apiKey.isEmpty else { throw BackendError.missingApiKey }

        var request = URLRequest(url: URL(string: Prefs.backendBaseURL + path)!)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.httpError(0, "no response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw BackendError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    static func ask(question: String, attachments: [Attachment]) async throws -> String {
        let attachmentsJSON = attachments.map { ["filename": $0.filename, "mimeType": $0.mimeType, "base64": $0.base64] }
        let req = try request("/api/ask", method: "POST", body: ["question": question, "attachments": attachmentsJSON])
        let data = try await send(req)
        struct Resp: Decodable { let jobId: String }
        return try JSONDecoder().decode(Resp.self, from: data).jobId
    }

    /// Bỏ qua bước hỏi 3 AI — gửi thẳng câu trả lời user tự dán để Claude Opus tổng hợp.
    static func synthesizeOnly(question: String, answers: [(label: String, answer: String)]) async throws -> String {
        let answersJSON = answers.map { ["label": $0.label, "answer": $0.answer] }
        let req = try request("/api/synthesize", method: "POST", body: ["question": question, "answers": answersJSON])
        let data = try await send(req)
        struct Resp: Decodable { let jobId: String }
        return try JSONDecoder().decode(Resp.self, from: data).jobId
    }

    static func fetchJob(id: String) async throws -> JobDetail {
        let req = try request("/api/jobs/\(id)")
        let data = try await send(req)
        return try JSONDecoder().decode(JobDetail.self, from: data)
    }

    static func fetchHistory(limit: Int = 50) async throws -> [JobSummary] {
        let req = try request("/api/jobs?limit=\(limit)")
        let data = try await send(req)
        return try JSONDecoder().decode([JobSummary].self, from: data)
    }
}
