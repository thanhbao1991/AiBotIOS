import Foundation

struct ModelAnswer: Identifiable {
    let id = UUID()
    let label: String
    var answer: String?
    var error: String?
}

/// Gửi câu hỏi lên backend (VPS) rồi poll tiến độ — backend mới thật sự chạy 3 AI (Claude/
/// Gemini/ChatGPT) song song + Claude Opus tổng hợp. Nhờ vậy nếu app bị chuyển nền/mất kết nối
/// giữa chừng, job vẫn chạy tiếp trên server; app quay lại chỉ cần poll lại đúng job đó, không
/// tốn token hỏi lại từ đầu.
@MainActor
final class DebateEngine: ObservableObject {
    @Published var answers: [ModelAnswer] = []
    @Published var finalAnswer: String?
    @Published var isRunning = false
    @Published var stageText: String = "Sẵn sàng"
    @Published var errorMessage: String?

    private var pollTask: Task<Void, Never>?

    func run(question: String, attachments: [Attachment]) {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        pollTask?.cancel()
        isRunning = true
        errorMessage = nil
        finalAnswer = nil
        answers = Prefs.councilLabels.map { ModelAnswer(label: $0) }
        stageText = "Đang gửi câu hỏi..."

        pollTask = Task {
            do {
                let jobId = try await BackendClient.ask(question: question, attachments: attachments)
                Prefs.currentJobId = jobId
                await poll(jobId: jobId)
            } catch {
                errorMessage = error.localizedDescription
                isRunning = false
            }
        }
    }

    /// Gọi lúc app khởi động/mở lại — nếu có job đang dở (chưa done) từ lần trước, tiếp tục
    /// theo dõi thay vì bỏ quên.
    func resumeIfNeeded() {
        guard let jobId = Prefs.currentJobId else { return }
        isRunning = true
        stageText = "Đang tải lại tiến độ..."
        pollTask?.cancel()
        pollTask = Task { await poll(jobId: jobId) }
    }

    private func poll(jobId: String) async {
        while !Task.isCancelled {
            do {
                let job = try await BackendClient.fetchJob(id: jobId)
                answers = job.answers.map { ModelAnswer(label: $0.label, answer: $0.answer, error: $0.error) }
                if job.status == "done" {
                    finalAnswer = job.finalAnswer?.isEmpty == false ? job.finalAnswer : nil
                    errorMessage = job.errorMessage
                    stageText = "Xong"
                    isRunning = false
                    Prefs.currentJobId = nil
                    return
                } else {
                    let doneCount = job.answers.filter { $0.answer != nil || $0.error != nil }.count
                    stageText = doneCount < job.answers.count
                        ? "Đang hỏi \(job.answers.map(\.label).joined(separator: ", "))... (\(doneCount)/\(job.answers.count))"
                        : "Claude Opus đang tổng hợp câu trả lời cuối..."
                }
            } catch {
                stageText = "Mất kết nối, đang thử lại..."
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}
