# Manga Vault - Ứng Dụng Quản Lý Truyện Tranh (Flutter & Dart)

Ứng dụng quản lý truyện tranh di động nhỏ gọn, dễ hiểu, viết bằng **Flutter & Dart**, sử dụng kiến trúc phân lớp cơ bản (Model - Service - Screen) không dùng thêm thư viện State Management cồng kềnh, lưu trữ offline bằng **SharedPreferences**.

---

## 📂 Cấu Trúc Thư Mục Tinh Gọn (4 Thư Mục Cốt Lõi)

Dự án được gộp toàn bộ xử lý nghiệp vụ vào tầng Service, giao diện cập nhật trực quan bằng `setState`:

```
lib/
├── models/
│   ├── manga.dart              # Model dữ liệu Manga (JSON serialization, helper methods)
│   └── genre.dart              # Model dữ liệu Genre
├── services/
│   ├── services.dart           # CRUD truyện, tìm kiếm và lưu SharedPreferences
│   └── genre_service.dart      # Mock API CRUD thể loại (dữ liệu trong bộ nhớ)
├── screens/
│   ├── home_screen.dart        # Danh sách truyện, tìm kiếm, yêu thích và lối vào quản lý thể loại
│   ├── detail_screen.dart      # Xem chi tiết, cập nhật tiến độ đọc, sửa/xóa truyện
│   ├── form_screen.dart        # Form thêm mới / chỉnh sửa truyện
│   ├── genre_list_screen.dart  # Xem, cập nhật và xóa thể loại
│   └── genre_form_screen.dart  # Thêm mới / cập nhật thể loại
├── widgets/
│   └── manga_card.dart         # Card hiển thị truyện
└── main.dart                   # Điểm khởi chạy ứng dụng (Theme & MaterialApp)
```

---

## ⚡ Các Tính Năng Chính

1. **Quản lý CRUD truyện tranh**:
   - Thêm truyện mới (kèm validation tên, tác giả, số chapter, điểm số).
   - Xem chi tiết và cập nhật số chapter đang đọc (+1 / -1 chap tiện lợi).
   - Chỉnh sửa thông tin truyện tranh.
   - Xóa truyện (có popup xác nhận an toàn).
2. **Tìm kiếm & Bộ lọc tức thì**:
   - Tìm kiếm nhanh theo tên truyện hoặc tác giả.
   - Lọc theo thể loại dạng chip ngang (Action, Adventure, Fantasy, Comedy...).
3. **Danh sách yêu thích (Favorites)**:
   - Nút thả tim yêu thích, gom vào Tab riêng biệt.
4. **Lưu trữ dữ liệu Offline**:
   - Tự động lưu vào máy bằng `SharedPreferences`. Tắt app mở lại vẫn giữ nguyên dữ liệu.
5. **Quản lý thể loại**:
   - Xem danh sách, thêm, cập nhật và xóa thể loại qua mock API trong Dart.
   - Dữ liệu thể loại mẫu được khởi tạo trong `GenreService` và đặt lại khi khởi động lại ứng dụng.
   - Actor theo backlog UC-03.1–UC-03.4: **Staff**. Dự án hiện chưa có chức năng đăng nhập/phân quyền.

---

## 🧪 Kiểm Thử (Unit Tests)

Chạy lệnh:
```bash
flutter test
```
Tất cả các bài test kiểm tra model và serialization đều vượt qua.
