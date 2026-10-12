# Manga Vault - Ứng Dụng Quản Lý Truyện Tranh (Flutter & Dart)

Ứng dụng quản lý truyện tranh di động viết bằng **Flutter & Dart**, sử dụng kiến trúc phân lớp cơ bản (Model - Service - Screen), lưu trữ CSDL quan hệ Offline chuẩn mực bằng **SQLite (`sqflite`)**, hỗ trợ đa nền tảng (Android, iOS, Windows).

---

## 📂 Cấu Trúc Thư Mục Cốt Lõi

```
lib/
├── models/
│   ├── manga.dart              # Model dữ liệu Manga (Mapping SQLite Map, validation)
│   └── user.dart               # Model Người dùng & Phân quyền (Admin, Staff, Reader, Guest)
├── services/
│   ├── database_helper.dart    # SQLite Database (Quản lý kết nối, tạo bảng, CRUD raw/query, seed data)
│   ├── services.dart           # MangaService: Xử lý CRUD truyện tương tác với SQLite
│   ├── auth_service.dart       # AuthService: Đăng ký/đăng nhập/phân quyền lưu vào SQLite
│   └── theme_service.dart      # Quản lý giao diện Sáng/Tối
├── screens/
│   ├── home_screen.dart        # Màn hình chính (Danh sách truyện, Tìm kiếm, Tab Yêu thích)
│   ├── detail_screen.dart      # Xem chi tiết, cập nhật tiến độ đọc, sửa/xóa
│   ├── form_screen.dart        # Form thêm mới / chỉnh sửa truyện
│   ├── login_screen.dart       # Đăng nhập & chế độ Khách
│   ├── register_screen.dart    # Đăng ký tài khoản mới
│   ├── forgot_password_screen.dart # Quên mật khẩu qua OTP
│   └── user_management_screen.dart # Quản trị viên phân quyền tài khoản
├── widgets/
│   └── manga_card.dart         # Card hiển thị truyện
└── main.dart                   # Điểm khởi chạy ứng dụng (Khởi tạo SQLite DB & Theme)
```

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

2. **Bảng `users`**:
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
