import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = Prefs.apiKey
    @State private var models = Prefs.models
    @State private var synthesizer = Prefs.synthesizerModel
    @State private var showPicker = false

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
                    ForEach(models, id: \.self) { model in
                        Text(model)
                    }
                    .onDelete { models.remove(atOffsets: $0) }

                    Button(action: { showPicker = true }) {
                        Label("Chọn model", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Model tham gia (\(models.count)/\(Prefs.maxModels))")
                } footer: {
                    Text("Chọn tối thiểu \(Prefs.minModels), tối đa \(Prefs.maxModels) model bất kỳ trong danh sách OpenRouter (kể cả model free).")
                }

                if !models.isEmpty {
                    Section {
                        Picker("Model tổng hợp câu trả lời cuối", selection: $synthesizer) {
                            ForEach(models, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                    } footer: {
                        Text("Model này sẽ đọc câu trả lời (đã phản biện) của tất cả model khác rồi chốt 1 câu trả lời cuối cùng.")
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") { save() }
                        .bold()
                        .disabled(models.count < Prefs.minModels)
                }
            }
            .sheet(isPresented: $showPicker) {
                ModelPickerView(selected: $models)
            }
            .onChange(of: models) { newModels in
                if !newModels.isEmpty, !newModels.contains(synthesizer) {
                    synthesizer = newModels[0]
                }
            }
        }
    }

    private func save() {
        Prefs.apiKey = apiKey
        Prefs.models = models
        Prefs.synthesizerModel = models.contains(synthesizer) ? synthesizer : (models.first ?? synthesizer)
        dismiss()
    }
}
