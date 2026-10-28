# Manga Vault - Ứng Dụng Quản Lý Truyện Tranh (Flutter & Dart)

Ứng dụng quản lý truyện tranh viết bằng **Flutter & Dart**, backend **ASP.NET Core / C#**, lưu dữ liệu bằng **SQLite**. Lớp Flutter vẫn có SQLite trên thiết bị để chạy được khi API chưa bật.

---

## 📂 Cấu Trúc Thư Mục Cốt Lõi

```
lib/
├── models/
│   ├── manga.dart              # Model dữ liệu Manga (Mapping SQLite Map, validation)
│   ├── genre.dart              # Model thể loại
│   └── user.dart               # Model Người dùng & Phân quyền (Admin, Staff, Reader, Guest)
├── services/
│   ├── database_helper.dart    # SQLite Database (Quản lý kết nối, tạo bảng, CRUD raw/query, seed data)
│   ├── services.dart           # MangaService: Xử lý CRUD truyện tương tác với SQLite
│   ├── genre_service.dart      # Nghiệp vụ thể loại
│   ├── backend_api_service.dart # Gọi REST API C#; tự dùng SQLite cục bộ khi API tắt
│   ├── auth_service.dart       # AuthService: Đăng ký/đăng nhập/phân quyền lưu vào SQLite
│   └── theme_service.dart      # Quản lý giao diện Sáng/Tối
├── screens/
│   ├── home_screen.dart        # Màn hình chính (Danh sách truyện, Tìm kiếm, Tab Yêu thích)
│   ├── genre_management_screen.dart # Staff quản lý thể loại
│   ├── detail_screen.dart      # Xem chi tiết, cập nhật tiến độ đọc, sửa/xóa
│   ├── form_screen.dart        # Form thêm mới / chỉnh sửa truyện
│   ├── login_screen.dart       # Đăng nhập & chế độ Khách
│   ├── register_screen.dart    # Đăng ký tài khoản mới
│   ├── forgot_password_screen.dart # Quên mật khẩu qua OTP
│   └── user_management_screen.dart # Quản trị viên phân quyền tài khoản
├── widgets/
│   └── manga_card.dart         # Card hiển thị truyện
└── main.dart                   # Điểm khởi chạy ứng dụng (Khởi tạo SQLite DB & Theme)

backend/MangaManagement.Api/    # ASP.NET Core REST API, lưu manga/genre/chapter bằng SQLite
```

## Chạy ứng dụng và backend

Mở hai terminal tại thư mục gốc của repository.

Terminal 1 – backend (cần cài .NET 8 SDK):

```powershell
dotnet run --project .\backend\MangaManagement.Api\MangaManagement.Api.csproj -- --urls http://0.0.0.0:5080
```

Terminal 2 – Flutter:

```powershell
flutter pub get
flutter run -d chrome
```

Flutter web/Windows gọi `http://localhost:5080/api`; Android emulator gọi `http://10.0.2.2:5080/api`. Nếu backend không chạy, các nghiệp vụ manga/thể loại/chapter đọc tiếp tục dùng SQLite cục bộ.

Cổng dịch vụ: `5080` là ASP.NET Core manga API (mặc định bind `127.0.0.1:5080` qua `Program.cs`/`launchSettings.json`, override bằng `--urls` hoặc `ASPNETCORE_URLS`/`BACKEND_API_URL`); `8787` là payment backend Node (`backend/server.js`, cấu hình trong `backend/.env`, override bằng `--dart-define=PAYMENT_BACKEND_URL=`); `8085` là WebSocket thông báo chạy trong app (`NotificationServerService.startServer`, override bằng `--dart-define=NOTIFICATION_WS_URL=`). Trên Flutter web không mở socket `ws://127.0.0.1:8085` mà dùng web bus trong bộ nhớ, nên `ERR_CONNECTION_REFUSED` trên web là bình thường. Khi payment backend trả `503` ở `POST /payments/orders`, app hiển thị QR offline kèm hướng dẫn bật `PAYMENT_RECEIPTS_ENABLED=true` + webhook SePay; app không tự cộng xu khi chưa có biên lai server xác minh.

Tài khoản demo cục bộ: `staff / staff123` để quản lý thể loại và manga; `admin / admin123` có thể xóa manga vĩnh viễn. Staff ẩn/hiện truyện, Admin xóa vĩnh viễn. Backend demo nhận vai trò qua header nội bộ `X-User-Role`; cơ chế này chỉ phục vụ bài tập/local mock, không thay cho xác thực khi triển khai thật.

## Phạm vi backlog của Lê Huỳnh Thiện Hưng

- UC-11–14: xem, thêm, sửa, xóa thể loại.
- UC-15–18: duyệt, thêm, sửa, ẩn/xóa manga. Staff quản lý nội dung; xóa vĩnh viễn vẫn theo quyền Admin có sẵn trong ứng dụng.
- UC-24–26: tìm kiếm/lọc manga, xem chi tiết, đọc chapter. Màn hình chi tiết và trình đọc chapter hiện có được giữ lại và dùng dữ liệu từ API khi backend đang chạy.

---

## 🗄️ Cấu Trúc Cơ Sở Dữ Liệu SQLite (`manga_vault.db`)

1. **Bảng `mangas`**:
   - `id` (TEXT PRIMARY KEY)
   - `title` (TEXT NOT NULL)
   - `author` (TEXT NOT NULL)
   - `description` (TEXT)
   - `cover_url` (TEXT NOT NULL)
   - `genre` (TEXT NOT NULL)
   - `status` (TEXT NOT NULL)
   - `total_chapters` (INTEGER)
   - `current_chapter` (INTEGER)
   - `rating` (REAL)
   - `is_favorite` (INTEGER - 0/1)
   - `is_hidden` (INTEGER - 0/1, ẩn khỏi độc giả)

2. **Bảng `genres`**: `id`, `name` (UNIQUE), `created_at`.

3. **Bảng `users`**:
   - `id` (TEXT PRIMARY KEY)
   - `username` (TEXT UNIQUE NOT NULL)
   - `display_name` (TEXT NOT NULL)
   - `password` (TEXT NOT NULL)
   - `role` (TEXT NOT NULL: 'admin' | 'staff' | 'reader')

---

## ⚡ Các Tính Năng Chính

1. **Cơ sở dữ liệu SQLite chuẩn đồ án PRM393**:
   - Tự động nạp dữ liệu mẫu ban đầu (Seed data: One Piece, Solo Leveling, Admin/Staff/Reader accounts).
   - Truy vấn CSDL chuẩn CRUD, lưu trữ vĩnh viễn trên thiết bị.
   - Hỗ trợ chạy mượt trên cả Android emulator, thiết bị thật và Windows Desktop (`sqflite_common_ffi`).
2. **Quản lý CRUD truyện tranh**:
   - Thêm truyện mới (kèm validation tên, tác giả, số chapter, điểm số).
   - Xem chi tiết và cập nhật số chapter đang đọc.
   - Chỉnh sửa thông tin truyện tranh.
   - Xóa truyện (phân quyền cho Admin).
3. **Phân quyền người dùng (RBAC)**:
   - Admin: Toàn quyền thêm, sửa, xóa truyện và quản lý tài khoản/phân quyền user.
   - Staff: Thêm và chỉnh sửa nội dung truyện.
   - Reader: Đọc truyện, theo dõi tiến độ, lưu yêu thích.
   - Guest: Xem danh mục truyện ở chế độ đọc thử.
4. **Tìm kiếm & Bộ lọc tức thì**:
   - Tìm kiếm nhanh theo tên truyện hoặc tác giả.
   - Lọc theo thể loại dạng chip ngang (Action, Adventure, Fantasy, Comedy...).

---

## 🧪 Kiểm Thử (Unit Tests)

Chạy lệnh:
```bash
flutter test
```
Tất cả các bài test kiểm tra model và serialization đều vượt qua.
