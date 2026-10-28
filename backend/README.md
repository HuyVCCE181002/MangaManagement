# Xác minh chuyển khoản Sacombank qua SePay

Backend dùng Node.js 24 và SQLite tích hợp trong Node, không cần npm install. Tiền thật chỉ được ghi nhận qua webhook SePay đã xác thực. Không có endpoint giả lập thành công.

## Chạy tại máy hiện tại

Từ thư mục project:

```powershell
node backend/setup.js
node --env-file=backend/.env backend/server.js
```

Ở terminal khác:

```powershell
flutter run -d chrome --dart-define=PAYMENT_BACKEND_URL=http://127.0.0.1:8787
```

Hoặc chạy `powershell -ExecutionPolicy Bypass -File start-payment-backend.ps1` để khởi động backend trong nền. Khóa webhook ngẫu nhiên được tạo trong `backend/.env` (đã gitignore), không đưa vào Flutter hoặc commit.

Để tạo URL webhook HTTPS tạm cho máy này, chạy:

```powershell
powershell -ExecutionPolicy Bypass -File start-sepay-webhook.ps1
```

Script tải cloudflared từ release Cloudflare chính thức, kiểm tra SHA-256, chạy tunnel trong nền và in URL `/webhooks/sepay`. URL được lưu ở `backend/.data/webhook-url.txt`. Giữ máy và tunnel chạy trong lúc kiểm tra thanh toán; khi tạo tunnel mới, cần cập nhật URL mới trong SePay. Đây là Quick Tunnel cho kiểm tra; khi vận hành lâu dài dùng hosting hoặc tunnel có domain cố định.

## Kết nối tiền thật

1. Chủ tài khoản đăng nhập SePay và [liên kết Sacombank bằng API Banking](https://docs.sepay.vn/ket-noi-sacombank-api.html) với STK **070118746463**. Việc xác nhận/OTP phải thực hiện trên hệ thống của ngân hàng/SePay; không gửi mật khẩu hoặc OTP vào ứng dụng này.
2. Chạy backend trên hosting có HTTPS hoặc dùng tunnel HTTPS tới cổng 8787. SePay không thể gọi localhost của máy bạn. Nếu deploy, dùng Node 24, ổ lưu trữ bền vững cho `backend/.data/payments.sqlite`, đặt `HOST=0.0.0.0`, cấu hình `ALLOWED_ORIGINS` bằng domain frontend. Không dùng ổ tạm sẽ mất sổ giao dịch sau khi restart.
3. Trong [cấu hình webhook SePay](https://docs.sepay.vn/tich-hop-webhooks.html), chọn **Có tiền vào**, tài khoản Sacombank này và URL **https://<domain-backend>/webhooks/sepay**. Chọn xác thực **API Key**, nhập đúng giá trị `SEPAY_WEBHOOK_KEY` trong `backend/.env`. Server kiểm tra header `Authorization: Apikey <key>`.
4. Sau khi đã liên kết và cấu hình webhook, đặt `PAYMENT_RECEIPTS_ENABLED=true` trong `backend/.env` rồi restart backend. Chạy Flutter với `--dart-define=PAYMENT_BACKEND_URL=https://<domain-backend>`. Tạo đơn mới rồi chuyển đúng số tiền và nội dung mã MANGA hiển thị. App tự cập nhật mỗi 3 giây. Mặc định cờ này là false để ngăn chuyển tiền khi kết nối chưa sẵn sàng.
5. Nếu tiền đã chuyển ở các phiên trước khi backend này tồn tại, không chuyển thêm chỉ để mở khóa coin. Cần đối soát giao dịch cũ với sao kê/SePay và mã đơn cũ; server không thể suy ra một khoản chuyển tiền từ thao tác bấm nút trên app.

Nếu chưa liên kết ngân hàng và cấu hình webhook, chạy backend đơn thuần **không thể** xác nhận tiền đã vào tài khoản.

## API và dữ liệu

- `POST /sessions`: tạo tài khoản thanh toán khi dùng lần đầu hoặc đăng nhập bằng username/password. Server sinh user ID riêng, băm mật khẩu bằng scrypt; phiên có hạn và giới hạn thử đăng nhập. Các tài khoản có sẵn phải dùng đúng mật khẩu đã tạo, không tin ID/role do Flutter gửi.
- `POST /payments/orders`: yêu cầu Bearer token và Idempotency-Key. Client chỉ gửi `packageId` và `promoCode`. Server tính giá/coin/thưởng từ `backend/catalog.json`, tạo mã MANGA duy nhất và hạn 10 phút trước khi QR xuất hiện.
- `GET /payments/orders`, `GET /payments/orders/:id`: chỉ chủ đơn được truy cập. App khôi phục đơn đang chờ và các khoản đã xác minh khi tải lại.
- `DELETE /payments/orders/:id`: hủy đơn chưa hoàn tất trước khi đổi thông tin.
- `POST /webhooks/sepay`: dùng payload SePay thật gồm id, gateway, accountNumber, transferType, transferAmount, content/code, transactionDate và referenceCode. Chỉ tiền **in** từ Sacombank, đúng tài khoản, đúng mã, đúng số tiền và chuyển trong hạn mới được cộng.
- Sự kiện ngân hàng và sổ cộng coin dùng UNIQUE + transaction SQLite. Webhook trùng không cộng lại. Callback gửi trễ vẫn được đối soát theo thời điểm chuyển khoản, không phải thời điểm nhận callback.
- Khoản sai số tiền, sai nội dung, đến sau hạn hoặc không có đơn được lưu trong `bank_events` để đối soát, không bị coi là thành công.
- `GET /health` chỉ xác nhận backend chạy và có cấu hình khóa; không khẳng định ngân hàng đã liên kết.

Danh mục gói trên server được khởi tạo đúng giá/bonus hiện có. Khi quản trị thay đổi gói ở database offline, cần cập nhật danh mục server qua thao tác quản trị tin cậy; tuyệt đối không cho frontend tự sửa giá để xác nhận thanh toán.

Sổ **nạp** coins trên server là nguồn xác nhận tiền thật. Database Flutter chỉ là cache để hiển thị và giữ chức năng đọc/mua hiện tại. Auth, phân quyền và chi tiêu của ứng dụng hiện còn offline; trước khi triển khai hệ thống thương mại đầy đủ, cần chuyển cả auth/chi tiêu/danh mục quản trị sang server. Không coi số dư SQLite trong trình duyệt là số dư tài chính đáng tin cậy.

## Kiểm tra

```powershell
node --test backend/test/payments.test.js
flutter test --no-pub
flutter build web --no-pub
```

Webhook trong bộ test dùng database memory và khóa test riêng, không tạo xác nhận giả trong database vận hành.
