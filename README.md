# AiCouncilIOS

App iOS native (SwiftUI) hỏi 1 câu, gửi song song tới nhiều AI (qua OpenRouter — 1 API key dùng
chung cho GPT/Claude/Gemini/...), rồi để chúng **tự phản biện chéo** trước khi tổng hợp thành 1
câu trả lời cuối. App cá nhân, không liên quan TraSuaApp, cài qua Sideloadly như `AppMobileIOS`.

## Luồng debate (2 vòng)

1. **Vòng 1** — mỗi model được chọn nhận đúng câu hỏi gốc, trả lời độc lập, song song (không
   thấy câu trả lời của model khác).
2. **Vòng 2** — mỗi model nhận lại: câu hỏi gốc + toàn bộ câu trả lời vòng 1 của TẤT CẢ model
   (có đánh dấu câu nào là của chính nó), được yêu cầu chỉ ra sai sót/thiếu sót rồi đưa ra câu
   trả lời đã tinh chỉnh.
3. **Tổng hợp** — 1 model "trọng tài" (chọn trong Cài đặt) đọc toàn bộ câu trả lời vòng 2, đối
   chiếu, nêu rõ điểm còn bất đồng (nếu có), rồi chốt 1 câu trả lời cuối cùng.

## Cấu trúc code

- `Prefs.swift` — lưu API key + danh sách model + model tổng hợp (UserDefaults).
- `OpenRouterClient.swift` — gọi `POST /api/v1/chat/completions` của OpenRouter.
- `DebateEngine.swift` — `ObservableObject` điều phối 2 vòng + tổng hợp, chạy song song bằng
  `TaskGroup`.
- `ContentView.swift` — màn hình chính: ô nhập câu hỏi, nút hỏi, hiển thị câu trả lời tổng hợp +
  từng model (mở rộng xem vòng 1/vòng 2).
- `SettingsView.swift` — nhập API key, sửa danh sách model (mỗi dòng 1 model slug OpenRouter),
  chọn model tổng hợp.

## Cấu hình cần làm trước khi dùng

1. Tạo API key tại [openrouter.ai/keys](https://openrouter.ai/keys), nạp tiền (trả theo token,
   rẻ hơn trả riêng từng hãng vì không cần subscribe nhiều nơi).
2. Mở app → nút bánh răng góc phải → dán API key → sửa danh sách model nếu muốn (mặc định GPT-5 +
   Claude Sonnet 4.5 + Gemini 2.5 Pro) → chọn model tổng hợp → Lưu.

Model slug xem tại [openrouter.ai/models](https://openrouter.ai/models) — đổi được bất cứ lúc nào
mà không cần build lại app.

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
