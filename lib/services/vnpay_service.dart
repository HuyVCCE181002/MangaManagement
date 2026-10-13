import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Kết quả thanh toán VNPay
class VNPayResult {
  final bool success;
  final String? transactionId;
  final String? orderId;
  final String? message;
  final String? paymentMethod;
  final DateTime? transactionTime;

  const VNPayResult({
    required this.success,
    this.transactionId,
    this.orderId,
    this.message,
    this.paymentMethod,
    this.transactionTime,
  });
}

/// Dữ liệu thanh toán VNPay
class VNPayRequest {
  final String vnpAmount;       // Số tiền (VD: 100000 = 100,000 VND)
  final String vnpOrderInfo;    // Thông tin đơn hàng
  final String vnpTxnRef;       // Mã giao dịch (unique)
  final String vnpIpAddr;       // IP người dùng
  final String vnpLocale;       // Ngôn ngữ (vn/en)
  final String vnpCurrCode;      // Mã tiền tệ (VND)
  final String vnpVersion;      // Phiên bản API (2.1.0)
  final String vnpCommand;      // Lệnh (pay)
  final String vnpMerchantCode; // Mã merchant (TMF hoặc mã của bạn)
  final String vnpReturnUrl;    // URL callback sau thanh toán

  const VNPayRequest({
    required this.vnpAmount,
    required this.vnpOrderInfo,
    required this.vnpTxnRef,
    required this.vnpIpAddr,
    this.vnpLocale = 'vn',
    this.vnpCurrCode = 'VND',
    this.vnpVersion = '2.1.0',
    this.vnpCommand = 'pay',
    required this.vnpMerchantCode,
    required this.vnpReturnUrl,
  });
}

/// Service tích hợp VNPay
/// 
/// Credentials SANDBOX (môi trường test):
/// - Terminal ID: HZBIDWN6
/// - Secret Key: GLYKLVYUQNLXBXJLMFRLGNMYZWLSDDLZ
/// - Payment URL: https://sandbox.vnpayment.vn/paymentv2/vpcpay.html
/// - Merchant Admin: https://sandbox.vnpayment.vn/merchantv2/
/// 
/// Tài liệu: https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html
class VNPayService {
  static final VNPayService instance = VNPayService._internal();
  VNPayService._internal();

  // ============== CREDENTIALS THẬT (SANDBOX) ==============
  /// Terminal ID / Mã Website
  static const String _tmnCode = 'HZBIDWN6';
  
  /// Secret Key / Chuỗi bí mật tạo checksum
  static const String _hashSecret = 'GLYKLVYUQNLXBXJLMFRLGNMYZWLSDDLZ';
  
  /// URL thanh toán môi trường TEST
  static const String _vnpayUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
  
  /// Return URL (sau khi thanh toán, VNPay redirect về đây)
  static const String _returnUrl = 'mangavault://vnpay-callback';
  
  /// Getter công khai để dùng ở nơi khác nếu cần
  static String get terminalId => _tmnCode;
  static String get sandboxUrl => _vnpayUrl;
  
  /// Tạo payment URL theo chuẩn VNPay
  /// 
  /// Tham số bắt buộc theo tài liệu VNPay:
  /// - vnp_Amount: Số tiền (Nhân 100 cho VND, không có decimal)
  /// - vnp_Command: Mã lệnh (pay)
  /// - vnp_CurrCode: Mã tiền tệ (VND)
  /// - vnp_IpAddr: IP của khách hàng
  /// - vnp_Locale: Ngôn ngữ (vn/en)
  /// - vnp_TmnCode: Mã merchant (Terminal ID)
  /// - vnp_OrderInfo: Thông tin mô tả đơn hàng
  /// - vnp_ReturnUrl: URL callback
  /// - vnp_TxnRef: Mã giao dịch (unique, không trùng lặp)
  /// - vnp_Version: Phiên bản API
  String createPaymentUrl({
    required int amount,        // Số tiền VND (VD: 50000)
    required String orderInfo,  // Mô tả đơn hàng
    required String ipAddress,   // IP khách hàng
    String? returnUrl,          // URL callback (optional)
    String locale = 'vn',
  }) {
    final txnRef = '${DateTime.now().millisecondsSinceEpoch}';
    
    // Tạo map parameters theo chuẩn VNPay
    final params = {
      'vnp_Version': '2.1.0',
      'vnp_Command': 'pay',
      'vnp_TmnCode': _tmnCode,
      'vnp_Amount': (amount * 100).toString(), // VNPay yêu cầu nhân 100
      'vnp_CurrCode': 'VND',
      'vnp_TxnRef': txnRef,
      'vnp_OrderInfo': orderInfo,
      'vnp_OrderType': 'other',
      'vnp_Locale': locale,
      'vnp_ReturnUrl': returnUrl ?? _returnUrl,
      'vnp_IpAddr': ipAddress,
      'vnp_CreateDate': _formatVNPayDate(DateTime.now()),
    };

    // Tạo secure hash bằng HMAC SHA-512
    final secureHash = _generateSecureHash(params);

    // Build URL với secure hash
    params['vnp_SecureHash'] = secureHash;
    final sortedKeys = params.keys.toList()..sort();
    final queryParts = sortedKeys.map((k) {
      final value = Uri.encodeComponent(params[k]!);
      return '$k=$value';
    });

    return '$_vnpayUrl?${queryParts.join('&')}';
  }

  /// Generate secure hash bằng HMAC SHA-512
  /// Theo chuẩn VNPay: sort params by key, build query string, hash với secret key
  String _generateSecureHash(Map<String, String> params) {
    // Loại bỏ vnp_SecureHash nếu có (chỉ hash các params khác)
    final filteredParams = Map<String, String>.from(params)
      ..remove('vnp_SecureHash')
      ..remove('vnp_SecureHashType');

    // Sort keys theo alphabet
    final sortedKeys = filteredParams.keys.toList()..sort();
    
    // Build query string
    final queryParts = sortedKeys.map((k) {
      final value = Uri.encodeComponent(filteredParams[k]!);
      return '$k=$value';
    });
    final queryString = queryParts.join('&');

    // HMAC SHA-512
    final key = utf8.encode(_hashSecret);
    final bytes = utf8.encode(queryString);
    final hmacSha512 = Hmac(sha512, key);
    return hmacSha512.convert(bytes).toString();
  }

  /// Verify secure hash từ VNPay return URL
  bool verifySecureHash(Map<String, String> params) {
    final receivedHash = params['vnp_SecureHash'];
    if (receivedHash == null) return false;

    final calculatedHash = _generateSecureHash(params);
    return receivedHash.toLowerCase() == calculatedHash.toLowerCase();
  }

  /// Format ngày theo chuẩn VNPay: yyyyMMddHHmmss
  String _formatVNPayDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }

  /// Xử lý return URL từ VNPay
  /// 
  /// Parse các tham số trả về:
  /// - vnp_ResponseCode: Mã phản hồi (00 = thành công)
  /// - vnp_TransactionNo: Số giao dịch VNPay
  /// - vnp_TxnRef: Mã giao dịch merchant
  /// - vnp_Amount: Số tiền
  /// - vnp_BankCode: Mã ngân hàng
  /// - vnp_PayDate: Thời gian thanh toán
  VNPayResult parseReturnUrl(Uri uri) {
    final params = uri.queryParameters;
    return parseReturnParams(params);
  }

  /// Xử lý params từ deep link callback (Android/iOS)
  VNPayResult parseReturnParams(Map<String, String> params) {
    // Verify secure hash trước khi xử lý
    final hashValid = verifySecureHash(params);
    if (!hashValid) {
      return const VNPayResult(
        success: false,
        message: 'Chữ ký không hợp lệ! Giao dịch có thể bị giả mạo.',
      );
    }
    
    final responseCode = params['vnp_ResponseCode'] ?? '';
    final isSuccess = responseCode == '00';
    
    return VNPayResult(
      success: isSuccess,
      transactionId: params['vnp_TransactionNo'],
      orderId: params['vnp_TxnRef'],
      message: _getResponseMessage(responseCode),
      paymentMethod: params['vnp_CardType'] ?? params['vnp_BankCode'],
      transactionTime: _parseVNPayDate(params['vnp_PayDate']),
    );
  }

  /// Parse ngày VNPay (yyyyMMddHHmmss)
  DateTime? _parseVNPayDate(String? dateStr) {
    if (dateStr == null || dateStr.length != 14) return null;
    try {
      return DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
        int.parse(dateStr.substring(8, 10)),
        int.parse(dateStr.substring(10, 12)),
        int.parse(dateStr.substring(12, 14)),
      );
    } catch (e) {
      return null;
    }
  }

  /// Lấy thông điệp từ response code
  String _getResponseMessage(String code) {
    final messages = {
      '00': 'Giao dịch thành công',
      '07': 'Trừ tiền thành công. Giao dịch bị nghi ngờ (liên quan đến lừa đảo, gian lận)',
      '09': 'Giao dịch không thành công do: Thẻ/Tài khoản của khách hàng chưa đăng ký dịch vụ',
      '10': 'Giao dịch không thành công do: Khách hàng xác thực thông tin thẻ/tài khoản không đúng quá 3 lần',
      '11': 'Giao dịch không thành công do: Đã hết hạn chờ thanh toán',
      '12': 'Giao dịch không thành công do: Thẻ/Tài khoản bị khóa',
      '13': 'Giao dịch không thành công do: Nhập sai mật khẩu thanh toán quá 3 lần',
      '24': 'Giao dịch không thành công do: Khách hàng hủy giao dịch',
      '51': 'Giao dịch không thành công do: Tài khoản không đủ số dư',
      '65': 'Giao dịch không thành công do: Tài khoản đã vượt quá hạn mức ngày',
      '91': 'Giao dịch không thành công do: Ngân hàng hỗ trợ thanh toán đang bảo trì',
      '99': 'Có lỗi không xác định',
    };
    return messages[code] ?? 'Mã lỗi không xác định: $code';
  }

  /// Tạo QR code data cho VNPay
  /// Format QR theo chuẩn VietQR/Napas 247 (chuẩn ngân hàng VN)
  String createQRCodeData({
    required int amount,
    required String orderInfo,
  }) {
    // Sử dụng Terminal ID thật của bạn
    final qrData = {
      'accountId': _tmnCode,
      'accountName': 'MANGA VAULT',
      'acqId': '970436', // VNPay QR code
      'amount': amount.toString(),
      'currencyCode': 'VND',
      'merchantId': _tmnCode,
      'orderId': '${DateTime.now().millisecondsSinceEpoch}',
      'purpose': 'NAP_COIN_MANGA_VAULT',
      'note': orderInfo,
    };
    
    final jsonStr = jsonEncode(qrData);
    return 'https://qr.vnpayment.vn?data=${Uri.encodeComponent(jsonStr)}&v=2.1.0';
  }

  /// Lấy Terminal ID (dùng cho test QR scanning)
  String getMerchantCode() => _tmnCode;
}
