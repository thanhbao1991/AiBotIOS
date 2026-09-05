# AiCouncilIOS

App iOS native (SwiftUI) hỏi 1 câu (kèm ảnh/file nếu muốn), gửi song song tới 3 AI cố định —
**Claude, Gemini, ChatGPT** — mỗi AI trả lời độc lập, rồi **Claude Opus** đọc cả 3 câu trả lời để
đánh giá/tổng hợp thành 1 câu trả lời cuối. App cá nhân, không liên quan TraSuaApp, cài qua
Sideloadly như `AppMobileIOS`.

**App chỉ là giao diện** — toàn bộ việc gọi OpenRouter (3 AI + Opus tổng hợp) chạy trên backend
trung gian `AiBotBackend` (VPS Contabo, xem repo `D:\Code\AiBotBackend`). App gửi câu hỏi lên rồi
poll tiến độ; nếu app bị chuyển nền/mất kết nối giữa chừng, job vẫn chạy tiếp trên server — quay
lại app vẫn thấy đúng kết quả, không phải hỏi lại (đỡ tốn token).

## Luồng

1. App `POST /api/ask` lên backend, backend trả `jobId` ngay, xử lý nền.
2. Backend gọi song song Claude/Gemini/ChatGPT, rồi Claude Opus tổng hợp — lưu tiến độ vào SQLite.
3. App poll `GET /api/jobs/{jobId}` mỗi ~2s để cập nhật UI, cho tới khi `status == "done"`.
4. `jobId` đang dở lưu trong `Prefs.currentJobId` — app relaunch/mở lại tự động poll tiếp
   (`DebateEngine.resumeIfNeeded()`), không mất câu hỏi đang xử lý.
5. Lịch sử toàn bộ câu hỏi/trả lời nằm trên backend (`GET /api/jobs`), xem lại qua nút đồng hồ
   góc trái (`HistoryView.swift`).

## Đính kèm ảnh/file

Nút "Ảnh" (PhotosPicker, tối đa 5 ảnh/lần) và "File" (fileImporter, mọi loại file) — gửi kèm câu
hỏi lên backend dưới dạng base64, backend chuyển thành `image_url`/`file` theo chuẩn multimodal
của OpenRouter.

## Copy / lưu kết quả

Câu trả lời tổng hợp có 2 nút: **Copy** (chép vào clipboard) và **Lưu file** (`ShareLink` xuất file
`.txt` — lưu vào Files, gửi qua AirDrop/Mail/... tuỳ chọn trong share sheet của iOS).

## Cấu trúc code

- `Prefs.swift` — lưu khoá truy cập backend (UserDefaults) + URL backend + job đang dở.
- `BackendClient.swift` — gọi `AiBotBackend` (`/api/ask`, `/api/jobs`, `/api/jobs/{id}`).
- `DebateEngine.swift` — `ObservableObject` gửi câu hỏi + poll tiến độ, tự resume job dở khi mở app.
- `ContentView.swift` — màn hình chính: ô nhập câu hỏi (ẩn bàn phím khi bấm Hỏi), đính kèm ảnh/
  file, hiển thị câu trả lời tổng hợp (copy/lưu file) + từng AI.
- `HistoryView.swift` — danh sách + chi tiết các câu hỏi đã hỏi (lấy từ backend).
- `SettingsView.swift` — chỉ còn nhập khoá truy cập backend + hiển thị (read-only) 3 model cố định.

## Cấu hình cần làm trước khi dùng

1. Deploy `AiBotBackend` lên VPS trước (xem README của repo đó).
2. Mở app → nút bánh răng góc phải → dán khoá truy cập backend (khớp `API_KEY` trên server) → Lưu.

## Build (không cần Mac)

CI (`.github/workflows/build-ios.yml`) chạy trên macOS runner của GitHub Actions, build ra
`AiCouncilIOS-unsigned.ipa` — **CHƯA KÝ** (cố ý, để khỏi phải nhét Apple ID vào GitHub Secrets).

1. Push repo này lên GitHub.
2. Tab **Actions** → chạy workflow "Build unsigned iOS IPA" (hoặc tự chạy khi push lên `main`).
3. Xong, vào job → tải artifact `AiCouncilIOS-unsigned-ipa`.

## Cài lên iPhone bằng Sideloadly (Windows, không cần Mac)

Giống hệt quy trình của `AppMobileIOS` — xem README của repo đó (cần iTunes bản .exe cổ điển +
Sideloadly, ký lại mỗi 7 ngày với Apple ID miễn phí).

## Đổi icon

`Assets.xcassets/AppIcon.appiconset/` hiện là icon placeholder tự sinh (chữ "AI" nền gradient
xanh-tím) — thay bằng ảnh riêng nếu muốn.
