# Manga Vault - Ứng Dụng Quản Lý Truyện Tranh (Flutter & Dart)

Ứng dụng quản lý truyện tranh di động nhỏ gọn, dễ hiểu, viết bằng **Flutter & Dart**, sử dụng kiến trúc phân lớp cơ bản (Model - Service - Screen) không dùng thêm thư viện State Management cồng kềnh, lưu trữ offline bằng **SharedPreferences**.

---

## 📂 Cấu Trúc Thư Mục Tinh Gọn (4 Thư Mục Cốt Lõi)

Dự án được gộp toàn bộ xử lý nghiệp vụ vào tầng Service, giao diện cập nhật trực quan bằng `setState`:

```
lib/
├── models/
│   └── manga.dart              # Model dữ liệu Manga (JSON serialization, helper methods)
├── services/
│   └── manga_service.dart      # Xử lý toàn bộ logic CRUD, tìm kiếm, lưu SharedPreferences
├── screens/
│   ├── home_screen.dart        # Màn hình chính (Danh sách truyện, Tìm kiếm, Tab Yêu thích)
│   ├── manga_detail_screen.dart # Xem chi tiết, cập nhật tiến độ đọc, sửa/xóa
│   └── manga_form_screen.dart   # Form thêm mới / chỉnh sửa truyện
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

---

## 🧪 Kiểm Thử (Unit Tests)

Chạy lệnh:
```bash
flutter test
```
Tất cả các bài test kiểm tra model và serialization đều vượt qua.
