import Foundation

struct ModelAnswer: Identifiable {
    let id = UUID()
    let model: String
    var rounds: [String] = []
    var error: String?
}

/// Điều phối luồng N vòng tranh luận (N do user chọn trong Cài đặt): vòng 1 mỗi model trả lời
/// độc lập, các vòng sau mỗi model đọc câu trả lời mới nhất của TẤT CẢ model (kể cả của chính
/// nó) rồi phản biện/tinh chỉnh, cuối cùng 1 model "trọng tài" tổng hợp thành câu trả lời cuối.
@MainActor
final class DebateEngine: ObservableObject {
    @Published var answers: [ModelAnswer] = []
    @Published var finalAnswer: String?
    @Published var isRunning = false
    @Published var stageText: String = "Sẵn sàng"
    @Published var errorMessage: String?

    func run(question: String, models: [String], synthesizer: String, roundCount: Int) async {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !models.isEmpty else { return }
        let roundCount = max(1, roundCount)

        isRunning = true
        errorMessage = nil
        finalAnswer = nil
        answers = models.map { ModelAnswer(model: $0) }

        for round in 0..<roundCount {
            stageText = round == 0
                ? "Vòng 1/\(roundCount): đang hỏi từng AI độc lập..."
                : "Vòng \(round + 1)/\(roundCount): đang cho các AI phản biện chéo..."

            let snapshot = answers
            await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
                for (idx, entry) in snapshot.enumerated() {
                    // Chỉ model đã trả lời đủ các vòng trước mới tiếp tục vòng này.
                    guard entry.rounds.count == round else { continue }
                    let model = entry.model
                    let prompt = round == 0
                        ? question
                        : Self.critiquePrompt(question: question, answers: snapshot, selfModel: model)
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
                    case .success(let text): answers[idx].rounds.append(text)
                    case .failure(let err): answers[idx].error = err.localizedDescription
                    }
                }
            }
        }

        stageText = "Đang tổng hợp câu trả lời cuối..."
        let synthPrompt = Self.synthesisPrompt(question: question, answers: answers)
        do {
            finalAnswer = try await OpenRouterClient.complete(
                model: synthesizer,
                messages: [ChatMessage(role: "user", content: synthPrompt)]
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        stageText = "Xong"
        isRunning = false
    }

    private static func critiquePrompt(question: String, answers: [ModelAnswer], selfModel: String) -> String {
        var text = "Câu hỏi gốc: \(question)\n\n"
        text += "Dưới đây là câu trả lời mới nhất từ nhiều AI khác nhau cho câu hỏi trên (bao gồm cả câu trả lời của chính bạn):\n\n"
        for a in answers {
            guard let latest = a.rounds.last else { continue }
            let label = a.model == selfModel ? "\(a.model) (đây là câu trả lời của chính bạn)" : a.model
            text += "--- \(label) ---\n\(latest)\n\n"
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
        text += "Nhiều AI đã trả lời độc lập rồi phản biện chéo nhiều vòng. Dưới đây là câu trả lời mới nhất của từng AI:\n\n"
        for a in answers {
            guard let latest = a.rounds.last else { continue }
            text += "--- \(a.model) ---\n\(latest)\n\n"
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
