# Manga Vault - Ứng Dụng Quản Lý Truyện Tranh (Flutter & Dart)

Ứng dụng quản lý truyện tranh di động được xây dựng bằng **Flutter & Dart**, áp dụng kiến trúc **Feature-First kết hợp Clean Architecture** và quản lý trạng thái bằng **Provider**. Dự án được thiết kế chuyên biệt nhằm phục vụ mục tiêu **dễ bảo trì, dễ mở rộng, và tối ưu cho kiểm thử tự động (Unit Test / Integration Test)**.

---

## 🏛️ Kiến Trúc Hệ Thống (Architecture Overview)

Dự án áp dụng mô hình **Feature-First Clean Architecture**:
- Mỗi chức năng (Feature) là một module độc lập, tự đóng gói toàn bộ nghiệp vụ, dữ liệu và giao diện của nó.
- Tầng **Core** tập trung các tiện ích dùng chung (Theme, Network, Constants, Storage, Reusable Widgets).
- Các tầng tuân theo quy tắc phụ thuộc một chiều (**Dependency Rule**): `Presentation` ➡️ `Domain` ⬅️ `Data`.

### 📂 Sơ Đồ Cây Thư Mục Chi Tiết

```
lib/
├── core/                                # [CORE LAYER] Các thành phần dùng chung toàn app
│   ├── constants/                       # Hằng số hệ thống
│   │   ├── api_endpoints.dart           # Cấu hình URL endpoint REST API
│   │   ├── app_colors.dart              # Bảng màu chuẩn Material 3 Dark & Cyber Anime
│   │   └── app_constants.dart           # Thể loại mẫu, danh sách trạng thái, cache keys
│   ├── network/                         # Tầng kết nối mạng
│   │   ├── api_client.dart              # REST Client bọc thư viện http (GET, POST, PUT, DELETE)
│   │   └── api_exception.dart           # Phân loại ngoại lệ (Network, Server, NotFound, Cache)
│   ├── storage/                         # Quản lý bộ nhớ đệm ngoại tuyến
│   │   └── local_storage_service.dart   # Service bọc SharedPreferences (JSON & String caching)
│   ├── theme/                           # Giao diện ứng dụng
│   │   └── app_theme.dart               # Cấu hình ThemeData Material 3 chuẩn Dark Theme
│   ├── utils/                           # Tiện ích bổ trợ
│   │   ├── formatters.dart              # Format điểm rating, tiến độ chapter, ngày tháng
│   │   └── validators.dart              # Form Validators (kiểm tra rỗng, số dương, điểm rating)
│   └── widgets/                         # Reusable UI Components
│       ├── custom_button.dart           # Nút bấm tích hợp loading indicator
│       ├── custom_text_field.dart       # Ô nhập liệu có validation & label
│       ├── empty_state_view.dart        # Màn hình thông báo trạng thái rỗng
│       ├── error_view.dart              # Màn hình báo lỗi có nút thử lại
│       └── loading_indicator.dart       # Vòng xoay tải dữ liệu phong cách hiện đại
│
├── features/                            # [FEATURE MODULES] Phân chia theo từng tính năng
│   │
│   ├── manga/                           # MODULE: Quản lý truyện (CRUD, Đọc, Danh sách)
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── manga_local_datasource.dart    # Cache danh sách truyện bằng JSON Local
│   │   │   │   └── manga_remote_datasource.dart   # Mock REST API / Gọi HTTP backend thật
│   │   │   ├── models/
│   │   │   │   └── manga_model.dart               # DTO chuyển đổi qua lại JSON <-> Entity
│   │   │   └── repositories/
│   │   │       └── manga_repository_impl.dart     # Kết hợp Remote + Cache & lọc dữ liệu
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── manga.dart                     # Thực thể Manga thuần túy
│   │   │   │   └── manga_filter.dart              # Tiêu chí lọc & sắp xếp (MangaFilter, MangaSortBy)
│   │   │   └── repositories/
│   │   │       └── manga_repository.dart          # Hợp đồng trừu tượng (Interface)
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── manga_provider.dart            # Quản lý State CRUD bằng ChangeNotifier
│   │       ├── screens/
│   │       │   ├── manga_list_screen.dart         # Trang chủ, Banner nổi bật, Grid/List view
│   │       │   ├── manga_detail_screen.dart       # Chi tiết truyện, cập nhật chapter, xóa, sửa
│   │       │   └── manga_form_screen.dart         # Thêm mới / Cập nhật truyện có form validation
│   │       └── widgets/
│   │           ├── manga_card.dart                # Thẻ hiển thị truyện (Grid card & List item)
│   │           ├── manga_status_badge.dart        # Huy hiệu trạng thái (Ongoing, Completed, Hiatus)
│   │           └── star_rating_bar.dart           # Thanh hiển thị sao và điểm đánh giá
│   │
│   ├── search_filter/                   # MODULE: Tìm kiếm thời gian thực & Lọc nâng cao
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── search_filter_provider.dart    # State quản lý từ khóa, thể loại, rating, sort
│   │       ├── screens/
│   │       │   └── manga_search_screen.dart       # Giao diện tìm kiếm tức thì
│   │       └── widgets/
│   │           └── filter_bottom_sheet.dart       # Modal lọc đa tiêu chí (Thể loại, Trạng thái, Slider)
│   │
│   └── favorites_reviews/               # MODULE: Bộ sưu tập yêu thích & Đánh giá cá nhân
│       ├── data/
│       │   ├── datasources/
│       │   │   └── user_interaction_local_datasource.dart # Lưu trữ danh sách favorite & reviews
│       │   ├── models/
│       │   │   └── review_model.dart              # Model DTO đánh giá cá nhân
│       │   └── repositories/
│       │       └── user_interaction_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── review.dart                    # Entity đánh giá & ghi chú
│       │   └── repositories/
│       │       └── user_interaction_repository.dart
│       └── presentation/
│           ├── providers/
│           │   └── favorites_provider.dart        # Quản lý State yêu thích và review
│           ├── screens/
│           │   └── favorites_screen.dart          # Màn hình danh sách truyện yêu thích
│           └── widgets/
│               ├── favorite_button.dart           # Nút trái tim tương tác
│               └── review_dialog.dart             # Hộp thoại chấm điểm 5 sao & ghi chú cảm nhận
│
├── app.dart                             # Cấu hình MultiProvider, Route và ThemeData
├── main_screen.dart                     # Bottom Navigation Bar điều hướng (Thư viện / Tìm kiếm / Yêu thích)
└── main.dart                            # Điểm khởi chạy App (Dependency Injection & Khởi tạo Service)
```

---

## 🚀 Các Tính Năng Đã Triển Khai Hoàn Thiện

1. **Quản lý CRUD Truyện Tranh Toàn Diện**:
   - **Xem danh sách**: Hỗ trợ chuyển đổi linh hoạt giữa dạng lưới 2 cột (**Grid**) và danh sách ngang (**List**). Banner "Truyện nổi bật" với các tác phẩm đình đám (One Piece, Solo Leveling, Frieren...).
   - **Thêm mới**: Form nhập liệu với kiểm tra hợp lệ chặt chẽ, chọn nhiều thể loại bằng Chip, chọn trạng thái, xem trước ảnh bìa thời gian thực (**Live Cover Preview**).
   - **Chỉnh sửa**: Cập nhật thông tin chi tiết từng tác phẩm.
   - **Xóa**: Hộp thoại cảnh báo xác nhận trước khi xóa an toàn.
   - **Theo dõi tiến độ đọc**: Thanh phần trăm hoàn thành, nút bấm tăng/giảm nhanh (+1 / -1 chapter).

2. **Tìm kiếm thời gian thực & Bộ lọc đa tiêu chí**:
   - Tìm kiếm nhanh theo tên truyện, tên gốc tiếng Nhật/Hàn, hoặc tên tác giả.
   - Bộ lọc nâng cao:
     - Lọc theo từng thể loại truyện tranh.
     - Lọc theo trạng thái xuất bản (*Đang ra*, *Hoàn thành*, *Tạm ngưng*).
     - Thanh kéo trượt điểm đánh giá tối thiểu (*Slider Rating*).
     - Sắp xếp linh hoạt: Đánh giá cao nhất, Mới cập nhật, Tên A-Z, Số chapter nhiều nhất.

3. **Bộ sưu tập yêu thích & Đánh giá cá nhân**:
   - Thêm/bỏ yêu thích nhanh chóng bằng icon trái tim kèm badge hiển thị số lượng tức thời trên thanh điều hướng.
   - Đánh giá cá nhân 1-5 sao và lưu trữ ghi chú, cảm nhận riêng cho từng tác phẩm.

4. **Cơ chế Lưu trữ & Ngoại tuyến (Offline-First / Cache Fallback)**:
   - Tự động lưu trữ danh sách truyện và tương tác người dùng vào bộ nhớ máy (`SharedPreferences`).
   - Sẵn sàng chuyển đổi giữa Mock API và REST Server thật thông qua `ApiClient`.

---

## 🧪 Kiểm Thử Tự Động (Unit Testing)

Tất cả các thành phần cốt lõi đều được kiểm thử thành công:
```bash
flutter test
```
Kết quả kiểm thử:
- ✅ `Validators Unit Tests`: Kiểm tra tính hợp lệ của chuỗi rỗng, số âm, điểm rating hợp lệ.
- ✅ `Manga Entity & Model Tests`: Đảm bảo độ chính xác của logic tính toán tỉ lệ đọc (`readingProgressPercentage`), trạng thái hoàn thành (`isCompleted`), và quá trình tuần tự hóa dữ liệu JSON (`fromJson` / `toJson`).

---

## 💻 Hướng Dẫn Chạy Ứng Dụng

1. Tải các gói thư viện:
   ```bash
   flutter pub get
   ```
2. Kiểm tra chất lượng mã nguồn:
   ```bash
   flutter analyze
   ```
3. Chạy ứng dụng trên thiết bị giả lập hoặc máy thật:
   ```bash
   flutter run
   ```
