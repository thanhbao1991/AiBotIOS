import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @StateObject private var engine = DebateEngine()
    @State private var question = ""
    @State private var showSettings = false
    @State private var showHistory = false
    @FocusState private var questionFocused: Bool

    @State private var attachments: [Attachment] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var attachError: String?

    @State private var finalFileURL: URL?
    @State private var copiedFeedback = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextEditor(text: $question)
                        .focused($questionFocused)
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

                    if !attachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(attachments) { a in
                                    AttachmentChip(attachment: a) {
                                        attachments.removeAll { $0.id == a.id }
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        PhotosPicker(selection: $photoPickerItems, maxSelectionCount: 5, matching: .images) {
                            Label("Ảnh", systemImage: "photo")
                        }
                        .onChange(of: photoPickerItems) { items in
                            Task { await addImages(items) }
                        }

                        Button(action: { showFileImporter = true }) {
                            Label("File", systemImage: "paperclip")
                        }
                    }
                    .font(.subheadline)

                    if let attachError {
                        Text(attachError).font(.caption).foregroundColor(.red)
                    }

                    HStack {
                        Button(action: ask) {
                            Label("Hỏi hội đồng AI", systemImage: "bubble.left.and.bubble.right")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(engine.isRunning || question.trimmingCharacters(in: .whitespaces).isEmpty)

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

                    ForEach(engine.answers) { answer in
                        AnswerCardView(answer: answer)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                addFiles(result)
            }
            .onChange(of: engine.finalAnswer) { newValue in
                finalFileURL = newValue.flatMap(writeFinalAnswerFile)
                copiedFeedback = false
            }
            .task {
                engine.resumeIfNeeded()
            }
        }
    }

    private func ask() {
        questionFocused = false
        engine.run(question: question, attachments: attachments)
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

    private func addImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            attachments.append(Attachment(filename: "image.jpg", mimeType: "image/jpeg", base64: data.base64EncodedString()))
        }
        photoPickerItems = []
    }

    private func addFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            attachError = error.localizedDescription
        case .success(let urls):
            attachError = nil
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else {
                    attachError = "Không đọc được file \(url.lastPathComponent)"
                    continue
                }
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                attachments.append(Attachment(filename: url.lastPathComponent, mimeType: mime, base64: data.base64EncodedString()))
            }
        }
    }
}

struct AttachmentChip: View {
    let attachment: Attachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: attachment.isImage ? "photo" : "doc")
            Text(attachment.filename)
                .font(.caption)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct AnswerCardView: View {
    let answer: ModelAnswer
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                if let text = answer.answer {
                    Text(text).textSelection(.enabled)
                }
                if let error = answer.error {
                    Text("Lỗi: \(error)").foregroundColor(.red).font(.caption)
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text(answer.label).font(.subheadline).bold()
                Spacer()
                if answer.answer == nil && answer.error == nil {
                    ProgressView().scaleEffect(0.7)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
