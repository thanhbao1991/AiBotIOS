import Foundation

struct ModelAnswer: Identifiable {
    let id = UUID()
    let label: String
    var answer: String?
    var error: String?
}

/// Điều phối luồng 1 vòng: 3 AI cố định (Prefs.councilModels) nhận câu hỏi (kèm ảnh/file nếu có)
/// và trả lời độc lập, song song. Sau đó Claude Opus (Prefs.synthesizerModel) đọc cả 3 câu trả
/// lời rồi tổng hợp/đánh giá thành 1 câu trả lời cuối.
@MainActor
final class DebateEngine: ObservableObject {
    @Published var answers: [ModelAnswer] = []
    @Published var finalAnswer: String?
    @Published var isRunning = false
    @Published var stageText: String = "Sẵn sàng"
    @Published var errorMessage: String?

    func run(question: String, attachments: [Attachment]) async {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        isRunning = true
        errorMessage = nil
        finalAnswer = nil
        let models = Prefs.councilModels
        answers = models.map { ModelAnswer(label: $0.label) }

        stageText = "Đang hỏi \(models.map(\.label).joined(separator: ", "))..."
        await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
            for (idx, model) in models.enumerated() {
                group.addTask {
                    do {
                        let text = try await OpenRouterClient.complete(
                            model: model.slug,
                            messages: [ChatMessage(role: "user", text: question, attachments: attachments)]
                        )
                        return (idx, .success(text))
                    } catch {
                        return (idx, .failure(error))
                    }
                }
            }
            for await (idx, result) in group {
                switch result {
                case .success(let text): answers[idx].answer = text
                case .failure(let err): answers[idx].error = err.localizedDescription
                }
            }
        }

        stageText = "Claude Opus đang tổng hợp câu trả lời cuối..."
        let synthPrompt = Self.synthesisPrompt(question: question, answers: answers)
        do {
            finalAnswer = try await OpenRouterClient.complete(
                model: Prefs.synthesizerModel,
                messages: [ChatMessage(role: "user", text: synthPrompt)]
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        stageText = "Xong"
        isRunning = false
    }

    private static func synthesisPrompt(question: String, answers: [ModelAnswer]) -> String {
        var text = "Câu hỏi gốc: \(question)\n\n"
        text += "Dưới đây là câu trả lời độc lập của từng AI cho câu hỏi trên:\n\n"
        for a in answers {
            guard let content = a.answer else { continue }
            text += "--- \(a.label) ---\n\(content)\n\n"
        }
        text += """
        Vai trò của bạn là trọng tài đánh giá: đối chiếu các câu trả lời trên, chỉ ra điểm đúng/ \
        sai/mâu thuẫn của từng câu, giữ lại phần đúng nhất, loại bỏ phần sai hoặc không có căn cứ, \
        rồi viết MỘT câu trả lời cuối cùng, rõ ràng, chính xác nhất cho câu hỏi gốc. Nếu các AI \
        còn bất đồng ở điểm nào, nêu rõ bất đồng đó và cho biết bạn nghiêng về phương án nào, vì sao.
        """
        return text
    }
}
