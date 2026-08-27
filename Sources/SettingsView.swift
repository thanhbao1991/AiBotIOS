import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = Prefs.apiKey
    @State private var modelsText = Prefs.models.joined(separator: "\n")
    @State private var synthesizer = Prefs.synthesizerModel

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("OpenRouter API key", text: $apiKey)
                } header: {
                    Text("API key")
                } footer: {
                    Text("Lấy tại openrouter.ai/keys. 1 key dùng chung được cho GPT/Claude/Gemini/... Chỉ lưu trên máy này (UserDefaults).")
                }

                Section {
                    TextEditor(text: $modelsText)
                        .frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Danh sách model (mỗi dòng 1 model)")
                } footer: {
                    Text("Dùng đúng model slug của OpenRouter, vd openai/gpt-5, anthropic/claude-sonnet-4.5, google/gemini-2.5-pro. Xem danh sách đầy đủ tại openrouter.ai/models.")
                }

                Section {
                    Picker("Model tổng hợp câu trả lời cuối", selection: $synthesizer) {
                        ForEach(currentModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                } footer: {
                    Text("Model này sẽ đọc câu trả lời (đã phản biện) của tất cả model khác rồi chốt 1 câu trả lời cuối cùng.")
                }
            }
            .navigationTitle("Cài đặt")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") { save() }.bold()
                }
            }
        }
    }

    private var currentModels: [String] {
        let list = modelsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return list.isEmpty ? [synthesizer] : list
    }

    private func save() {
        Prefs.apiKey = apiKey
        let models = currentModels
        Prefs.models = models
        Prefs.synthesizerModel = models.contains(synthesizer) ? synthesizer : (models.first ?? synthesizer)
        dismiss()
    }
}
