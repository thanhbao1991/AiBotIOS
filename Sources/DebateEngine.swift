import Foundation

struct ModelAnswer: Identifiable {
    let id = UUID()
    let model: String
    var round1: String?
    var round2: String?
    var error: String?
}

/// Điều phối luồng 2 vòng: (1) mỗi model trả lời độc lập, (2) mỗi model đọc câu trả lời của
/// TẤT CẢ model (kể cả của chính nó) rồi phản biện/tinh chỉnh, sau đó 1 model "trọng tài" tổng
/// hợp thành câu trả lời cuối.
@MainActor
final class DebateEngine: ObservableObject {
    enum Stage: String {
        case idle = "Sẵn sàng"
        case round1 = "Vòng 1: đang hỏi từng AI độc lập..."
        case round2 = "Vòng 2: đang cho các AI phản biện chéo..."
        case synthesis = "Đang tổng hợp câu trả lời cuối..."
        case done = "Xong"
    }

    @Published var answers: [ModelAnswer] = []
    @Published var finalAnswer: String?
    @Published var isRunning = false
    @Published var stage: Stage = .idle
    @Published var errorMessage: String?

    func run(question: String, models: [String], synthesizer: String) async {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !models.isEmpty else { return }

        isRunning = true
        errorMessage = nil
        finalAnswer = nil
        answers = models.map { ModelAnswer(model: $0) }

        stage = .round1
        await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
            for (idx, model) in models.enumerated() {
                group.addTask {
                    do {
                        let text = try await OpenRouterClient.complete(
                            model: model,
                            messages: [ChatMessage(role: "user", content: question)]
                        )
                        return (idx, .success(text))
                    } catch {
                        return (idx, .failure(error))
                    }
                }
            }
            for await (idx, result) in group {
                switch result {
                case .success(let text): answers[idx].round1 = text
                case .failure(let err): answers[idx].error = err.localizedDescription
                }
            }
        }

        stage = .round2
        let round1Snapshot = answers
        await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
            for (idx, entry) in round1Snapshot.enumerated() {
                guard entry.round1 != nil else { continue }
                let model = entry.model
                let prompt = Self.critiquePrompt(question: question, answers: round1Snapshot, selfModel: model)
                group.addTask {
                    do {
                        let text = try await OpenRouterClient.complete(
                            model: model,
                            messages: [ChatMessage(role: "user", content: prompt)]
                        )
                        return (idx, .success(text))
                    } catch {
                        return (idx, .failure(error))
                    }
                }
            }
            for await (idx, result) in group {
                switch result {
                case .success(let text): answers[idx].round2 = text
                case .failure(let err): answers[idx].error = err.localizedDescription
                }
            }
        }

        stage = .synthesis
        let synthPrompt = Self.synthesisPrompt(question: question, answers: answers)
        do {
            finalAnswer = try await OpenRouterClient.complete(
                model: synthesizer,
                messages: [ChatMessage(role: "user", content: synthPrompt)]
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        stage = .done
        isRunning = false
    }

    private static func critiquePrompt(question: String, answers: [ModelAnswer], selfModel: String) -> String {
        var text = "Câu hỏi gốc: \(question)\n\n"
        text += "Dưới đây là các câu trả lời độc lập từ nhiều AI khác nhau cho câu hỏi trên (bao gồm cả câu trả lời của chính bạn):\n\n"
        for a in answers {
            guard let r1 = a.round1 else { continue }
            let label = a.model == selfModel ? "\(a.model) (đây là câu trả lời của chính bạn)" : a.model
            text += "--- \(label) ---\n\(r1)\n\n"
        }
        text += """
        Hãy đọc kỹ tất cả câu trả lời trên, chỉ ra điểm sai/thiếu sót/mâu thuẫn (kể cả trong câu \
        trả lời của chính bạn nếu có), rồi đưa ra câu trả lời đã được tinh chỉnh, chính xác nhất \
        mà bạn có thể đưa ra bây giờ.
        """
        return text
    }

    private static func synthesisPrompt(question: String, answers: [ModelAnswer]) -> String {
        var text = "Câu hỏi gốc: \(question)\n\n"
        text += "Nhiều AI đã trả lời độc lập rồi phản biện chéo nhau. Dưới đây là câu trả lời đã tinh chỉnh (sau phản biện) của từng AI:\n\n"
        for a in answers {
            guard let content = a.round2 ?? a.round1 else { continue }
            text += "--- \(a.model) ---\n\(content)\n\n"
        }
        text += """
        Vai trò của bạn là trọng tài tổng hợp: đối chiếu các câu trả lời trên, giữ lại phần đúng/ \
        nhất quán, loại bỏ phần sai hoặc không có căn cứ, rồi viết MỘT câu trả lời cuối cùng, rõ \
        ràng, chính xác nhất cho câu hỏi gốc. Nếu các AI còn bất đồng ở điểm nào, nêu rõ bất đồng \
        đó và cho biết bạn nghiêng về phương án nào, vì sao.
        """
        return text
    }
}
