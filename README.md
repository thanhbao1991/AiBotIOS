# AiCouncilIOS

App iOS native (SwiftUI) hỏi 1 câu (kèm ảnh/file nếu muốn), gửi song song tới 3 AI cố định qua
OpenRouter — **Claude, Gemini, ChatGPT** — mỗi AI trả lời độc lập, rồi **Claude Opus** đọc cả 3
câu trả lời để đánh giá/tổng hợp thành 1 câu trả lời cuối. App cá nhân, không liên quan TraSuaApp,
cài qua Sideloadly như `AppMobileIOS`.

## Luồng (1 vòng)

1. **Hỏi song song** — Claude, Gemini, ChatGPT (`Prefs.councilModels`, slug dạng rolling alias
   `~vendor/model-latest` tự trỏ bản mới nhất) mỗi model nhận đúng câu hỏi gốc + ảnh/file đính
   kèm (nếu có), trả lời độc lập, không thấy câu trả lời của nhau.
2. **Tổng hợp** — Claude Opus (`Prefs.synthesizerModel`) đọc cả 3 câu trả lời, đối chiếu, chỉ ra
   điểm đúng/sai/mâu thuẫn, nêu rõ bất đồng còn lại (nếu có), rồi chốt 1 câu trả lời cuối cùng.

Bộ 3 AI trả lời + AI trọng tài là **cố định trong code** (`Prefs.swift`), không chỉnh được trong
app — sửa `Prefs.councilModels`/`Prefs.synthesizerModel` rồi build lại nếu muốn đổi.

## Đính kèm ảnh/file

Nút "Ảnh" (PhotosPicker, tối đa 5 ảnh/lần) và "File" (fileImporter, mọi loại file) trong màn hình
chính. Ảnh gửi dạng `image_url` (base64 data URI), file khác gửi dạng `file` (base64) — theo chuẩn
multimodal của OpenRouter, cả 3 AI đều nhận được cùng nội dung đính kèm.

## Copy / lưu kết quả

Câu trả lời tổng hợp có 2 nút: **Copy** (chép vào clipboard) và **Lưu file** (`ShareLink` xuất file
`.txt` — lưu vào Files, gửi qua AirDrop/Mail/... tuỳ chọn trong share sheet của iOS).

## Cấu trúc code

- `Prefs.swift` — lưu API key (UserDefaults) + 3 model cố định + model tổng hợp cố định.
- `OpenRouterClient.swift` — gọi `POST /api/v1/chat/completions`, `ChatMessage` hỗ trợ đính kèm
  (text/image_url/file) qua `Attachment`.
- `DebateEngine.swift` — `ObservableObject` điều phối 1 vòng hỏi song song (`TaskGroup`) + tổng hợp.
- `ContentView.swift` — màn hình chính: ô nhập câu hỏi, đính kèm ảnh/file, nút hỏi, hiển thị câu
  trả lời tổng hợp (copy/lưu file) + từng AI (mở rộng xem chi tiết).
- `SettingsView.swift` — chỉ còn nhập API key + hiển thị (read-only) 3 model cố định.

## Cấu hình cần làm trước khi dùng

1. Tạo API key tại [openrouter.ai/keys](https://openrouter.ai/keys), nạp tiền (trả theo token,
   rẻ hơn trả riêng từng hãng vì không cần subscribe nhiều nơi).
2. Mở app → nút bánh răng góc phải → dán API key → Lưu.

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
