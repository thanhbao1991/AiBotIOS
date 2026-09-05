import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backendApiKey = Prefs.backendApiKey

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Khoá truy cập backend", text: $backendApiKey)
                } header: {
                    Text("Khoá truy cập")
                } footer: {
                    Text("Backend trung gian tại \(Prefs.backendBaseURL) thật sự gọi OpenRouter — chỉ cần khoá này để xác thực với backend, không cần API key OpenRouter nữa.")
                }

                Section {
                    ForEach(Prefs.councilLabels, id: \.self) { label in
                        Text(label)
                    }
                } header: {
                    Text("3 AI trả lời độc lập")
                }

                Section {
                    Text(Prefs.synthesizerLabel)
                } header: {
                    Text("AI trọng tài tổng hợp")
                } footer: {
                    Text("Bộ 3 AI trả lời + AI trọng tài là cố định trên backend, không chỉnh được trong app.")
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
        Prefs.backendApiKey = backendApiKey
        dismiss()
    }
}
