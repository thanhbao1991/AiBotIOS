import SwiftUI

/// Danh sách câu hỏi/câu trả lời cũ đã hỏi — lấy từ backend (VPS), backend lưu lại mọi job nên
/// xem lại được bất cứ lúc nào, kể cả sau khi cài lại app.
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var jobs: [JobSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selected: JobSummary?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage).foregroundColor(.red).multilineTextAlignment(.center)
                        Button("Thử lại") { Task { await load() } }
                    }
                    .padding()
                } else if jobs.isEmpty {
                    Text("Chưa có câu hỏi nào.").foregroundColor(.secondary)
                } else {
                    List(jobs) { job in
                        Button(action: { selected = job }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.question).lineLimit(2).foregroundColor(.primary)
                                HStack {
                                    Text(job.status == "done" ? "Xong" : "Đang xử lý...")
                                        .font(.caption)
                                        .foregroundColor(job.status == "done" ? .secondary : .orange)
                                    Spacer()
                                    Text(job.createdAt.prefix(16).replacingOccurrences(of: "T", with: " "))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lịch sử")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            .sheet(item: $selected) { job in
                HistoryDetailView(jobId: job.id)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            jobs = try await BackendClient.fetchHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct HistoryDetailView: View {
    let jobId: String
    @Environment(\.dismiss) private var dismiss
    @State private var job: JobDetail?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let job {
                        Text(job.question).font(.headline).textSelection(.enabled)

                        if let final = job.finalAnswer, !final.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Câu trả lời tổng hợp (Claude Opus)", systemImage: "checkmark.seal.fill")
                                    .font(.subheadline).bold().foregroundColor(.green)
                                Text(final).textSelection(.enabled)
                            }
                            .padding()
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(10)
                        }

                        ForEach(job.answers, id: \.label) { a in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(a.label).font(.subheadline).bold()
                                if let answer = a.answer {
                                    Text(answer).textSelection(.enabled)
                                } else if let error = a.error {
                                    Text("Lỗi: \(error)").foregroundColor(.red).font(.caption)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    } else if let errorMessage {
                        Text(errorMessage).foregroundColor(.red)
                    } else {
                        ProgressView()
                    }
                }
                .padding()
            }
            .navigationTitle("Chi tiết")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .task {
            do { job = try await BackendClient.fetchJob(id: jobId) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}
