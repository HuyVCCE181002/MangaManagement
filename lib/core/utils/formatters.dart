/// Các hàm định dạng hiển thị số liệu, ngày tháng và văn bản
class Formatters {
  Formatters._();

  static String rating(double rating) {
    return rating.toStringAsFixed(1);
  }

  static String chapters(int current, int total) {
    if (total <= 0) {
      return 'Chap $current / ?';
    }
    return 'Chap $current / $total';
  }

  static String date(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$day/$month/$year';
  }

  static String timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} năm trước';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} tháng trước';
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }
}
