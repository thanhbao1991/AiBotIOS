import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = Prefs.apiKey

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
                    ForEach(Prefs.councilModels, id: \.slug) { model in
                        HStack {
                            Text(model.label)
                            Spacer()
                            Text(model.slug).font(.caption).foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("3 AI trả lời độc lập")
                }

                Section {
                    Text(Prefs.synthesizerModel).font(.caption).foregroundColor(.secondary)
                } header: {
                    Text("AI trọng tài tổng hợp")
                } footer: {
                    Text("Bộ 3 AI trả lời + AI trọng tài là cố định, không chỉnh được trong app.")
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

    private func save() {
        Prefs.apiKey = apiKey
        dismiss()
    }
}
