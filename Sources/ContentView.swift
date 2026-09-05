import SwiftUI

struct ContentView: View {
    @StateObject private var engine = DebateEngine()
    @State private var question = ""
    @State private var showSettings = false
    @State private var runTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextEditor(text: $question)
                        .frame(minHeight: 90)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .overlay(
                            Group {
                                if question.isEmpty {
                                    Text("Nhập câu hỏi...")
                                        .foregroundColor(.secondary)
                                        .padding(16)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )

                    HStack {
                        Button(action: ask) {
                            Label("Hỏi hội đồng AI", systemImage: "bubble.left.and.bubble.right")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(engine.isRunning || question.trimmingCharacters(in: .whitespaces).isEmpty || Prefs.models.count < Prefs.minModels)

                        if engine.isRunning {
                            ProgressView()
                            Text(engine.stageText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if Prefs.models.count < Prefs.minModels {
                        Text("Cần chọn tối thiểu \(Prefs.minModels) model trong Cài đặt.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if let error = engine.errorMessage {
                        Text(error).foregroundColor(.red).font(.callout)
                    }

                    if let final = engine.finalAnswer {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Câu trả lời tổng hợp", systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text(final)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(10)
                    }

                    ForEach(engine.answers) { answer in
                        AnswerCardView(answer: answer, roundCount: Prefs.rounds)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Council")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func ask() {
        let q = question
        runTask?.cancel()
        runTask = Task {
            await engine.run(
                question: q,
                models: Prefs.models,
                synthesizer: Prefs.synthesizerModel,
                roundCount: Prefs.rounds
            )
        }
    }
}

struct AnswerCardView: View {
    let answer: ModelAnswer
    let roundCount: Int
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(answer.rounds.enumerated()), id: \.offset) { i, text in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i == 0 ? "Vòng 1 (trả lời độc lập)" : "Vòng \(i + 1) (sau phản biện chéo)")
                            .font(.caption).bold().foregroundColor(.secondary)
                        Text(text).textSelection(.enabled)
                    }
                }
                if let error = answer.error {
                    Text("Lỗi: \(error)").foregroundColor(.red).font(.caption)
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text(answer.model).font(.subheadline).bold()
                Spacer()
                if answer.rounds.isEmpty && answer.error == nil {
                    ProgressView().scaleEffect(0.7)
                } else if answer.rounds.count < roundCount && answer.error == nil {
                    Text("đang phản biện...").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
