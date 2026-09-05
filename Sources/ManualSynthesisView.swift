import SwiftUI
import UIKit

/// Tab 2: bỏ qua bước hỏi 3 AI, user tự hỏi ở chỗ khác rồi dán câu trả lời vào đây — chỉ chạy
/// bước Claude Opus tổng hợp/đánh giá.
struct ManualSynthesisView: View {
    @StateObject private var engine = DebateEngine()
    @State private var question = ""
    @State private var claudeAnswer = ""
    @State private var geminiAnswer = ""
    @State private var chatGptAnswer = ""
    @FocusState private var focusedField: Field?

    @State private var finalFileURL: URL?
    @State private var copiedFeedback = false

    private enum Field: Hashable { case question, claude, gemini, chatgpt }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    labeledEditor("Câu hỏi", text: $question, minHeight: 60, focus: .question)
                    labeledEditor("Claude", text: $claudeAnswer, minHeight: 80, focus: .claude)
                    labeledEditor("Gemini", text: $geminiAnswer, minHeight: 80, focus: .gemini)
                    labeledEditor("ChatGPT", text: $chatGptAnswer, minHeight: 80, focus: .chatgpt)

                    HStack {
                        Button(action: synthesize) {
                            Label("Tổng hợp", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(engine.isRunning || !canSubmit)

                        if engine.isRunning {
                            ProgressView()
                            Text(engine.stageText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = engine.errorMessage {
                        Text(error).foregroundColor(.red).font(.callout)
                    }

                    if let final = engine.finalAnswer {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Câu trả lời tổng hợp (Claude Opus)", systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text(final)
                                .textSelection(.enabled)

                            HStack(spacing: 16) {
                                Button(action: copyFinal) {
                                    Label(copiedFeedback ? "Đã copy" : "Copy", systemImage: "doc.on.doc")
                                }
                                if let finalFileURL {
                                    ShareLink(item: finalFileURL) {
                                        Label("Lưu file", systemImage: "square.and.arrow.down")
                                    }
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .onChange(of: engine.finalAnswer) { newValue in
                finalFileURL = newValue.flatMap(writeFinalAnswerFile)
                copiedFeedback = false
            }
        }
    }

    private var canSubmit: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty &&
            [claudeAnswer, geminiAnswer, chatGptAnswer].contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func synthesize() {
        focusedField = nil
        let pairs: [(label: String, answer: String)] = zip(Prefs.councilLabels, [claudeAnswer, geminiAnswer, chatGptAnswer])
            .compactMap { label, text in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : (label, trimmed)
            }
        engine.runSynthesisOnly(question: question, answers: pairs)
    }

    private func copyFinal() {
        guard let final = engine.finalAnswer else { return }
        UIPasteboard.general.string = final
        copiedFeedback = true
    }

    private func writeFinalAnswerFile(_ text: String) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-council-\(formatter.string(from: Date())).txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    @ViewBuilder
    private func labeledEditor(_ label: String, text: Binding<String>, minHeight: CGFloat, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).bold()
            TextEditor(text: text)
                .focused($focusedField, equals: focus)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
}
