/// Các hàm kiểm tra hợp lệ dữ liệu (Form Validators)
class Validators {
  Validators._();

  static String? required(String? value, [String fieldName = 'Trường này']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String fieldName = 'Giá trị']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    final number = int.tryParse(value.trim());
    if (number == null || number < 0) {
      return '$fieldName phải là số nguyên không âm';
    }
    return null;
  }

  static String? rating(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Điểm đánh giá không được để trống';
    }
    final number = double.tryParse(value.trim());
    if (number == null || number < 0 || number > 10) {
      return 'Điểm đánh giá phải từ 0.0 đến 10.0';
    }
    return null;
  }

  static String? validUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Cho phép để trống, sẽ dùng placeholder
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Đường dẫn ảnh phải bắt đầu bằng http:// hoặc https://';
    }
    return null;
  }
}
