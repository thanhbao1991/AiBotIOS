import SwiftUI

/// Cho user tự chọn tối thiểu 2, tối đa 5 model từ toàn bộ danh sách model OpenRouter (kể cả
/// model free) — thay vì phải gõ tay slug model như trước.
struct ModelPickerView: View {
    @Binding var selected: [String]
    @Environment(\.dismiss) private var dismiss

    @State private var allModels: [OpenRouterModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var query = ""

    private var filtered: [OpenRouterModel] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return allModels }
        return allModels.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Đang tải danh sách model...")
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage).foregroundColor(.red).multilineTextAlignment(.center)
                        Button("Thử lại") { Task { await load() } }
                    }
                    .padding()
                } else {
                    List(filtered) { model in
                        Button(action: { toggle(model.id) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.name).foregroundColor(.primary)
                                    Text(model.id)
                                        .font(.caption)
                                        .foregroundColor(model.id.hasSuffix(":free") ? .green : .secondary)
                                }
                                Spacer()
                                if selected.contains(model.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                                }
                            }
                        }
                        .disabled(!selected.contains(model.id) && selected.count >= Prefs.maxModels)
                    }
                    .searchable(text: $query, prompt: "Tìm model (vd gpt, claude, free...)")
                }
            }
            .navigationTitle("Chọn model (\(selected.count)/\(Prefs.maxModels))")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selected.count < Prefs.minModels {
                    Text("Cần chọn tối thiểu \(Prefs.minModels) model.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(.bar)
                }
            }
        }
        .task { await load() }
    }

    private func toggle(_ id: String) {
        if let idx = selected.firstIndex(of: id) {
            selected.remove(at: idx)
        } else if selected.count < Prefs.maxModels {
            selected.append(id)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            allModels = try await OpenRouterClient.fetchModels()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
