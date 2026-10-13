import 'dart:convert';
import 'package:uuid/uuid.dart';

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
/// Cách sử dụng khi có backend:
/// 1. Gửi request đến backend của bạn
/// 2. Backend ký request với VNPay secret key
/// 3. Backend trả về payment URL
/// 4. Mở URL trong browser/webview
/// 
/// Tài liệu: https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html
class VNPayService {
  static final VNPayService instance = VNPayService._internal();
  VNPayService._internal();

  // Sandbox URL cho test (thay bằng production URL khi release)
  // Production: https://支付.vnpayment.vn/vnpaypc/vpcpay.html
  static const String _sandboxUrl = 'https://sandbox.vnpayment.vn/tryitnow/Home/VnPaySession';
  
  // Demo merchant info (thay bằng credentials thật của bạn)
  static const String _demoMerchantCode = 'DEMO_VNPAY';
  static const String _demoSecretKey = 'DEMO_SECRET_KEY';

  /// Tạo payment URL theo chuẩn VNPay
  /// 
  /// Tham số bắt buộc theo tài liệu VNPay:
  /// - vnp_Amount: Số tiền (Nhân 100 cho VND, không có decimal)
  /// - vnp_Command: Mã lệnh (pay)
  /// - vnp_CurrCode: Mã tiền tệ (VND)
  /// - vnp_IpAddr: IP của khách hàng
  /// - vnp_Locale: Ngôn ngữ (vn/en)
  /// - vnp_Merchant: Mã merchant
  /// - vnp_OrderInfo: Thông tin mô tả đơn hàng
  /// - vnp_ReturnUrl: URL callback
  /// - vnp_TxnRef: Mã giao dịch (unique, không trùng lặp)
  /// - vnp_Version: Phiên bản API
  String createPaymentUrl({
    required int amount,        // Số tiền VND (VD: 50000)
    required String orderInfo,  // Mô tả đơn hàng
    required String ipAddress,   // IP khách hàng
    required String returnUrl,  // URL callback
    String locale = 'vn',
  }) {
    final txnRef = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
    
    // Tạo map parameters theo chuẩn VNPay
    final params = {
      'vnp_Amount': (amount * 100).toString(), // VNPay yêu cầu nhân 100
      'vnp_Command': 'pay',
      'vnp_CurrCode': 'VND',
      'vnp_IpAddr': ipAddress,
      'vnp_Locale': locale,
      'vnp_Merchant': _demoMerchantCode,
      'vnp_OrderInfo': orderInfo,
      'vnp_ReturnUrl': returnUrl,
      'vnp_TxnRef': txnRef,
      'vnp_Version': '2.1.0',
    };

    // Tạo query string đã sort theo alphabet
    final sortedKeys = params.keys.toList()..sort();
    final queryParts = sortedKeys.map((k) {
      final value = Uri.encodeComponent(params[k]!);
      return '$k=$value';
    });
    final queryString = queryParts.join('&');

    // Tạo secure hash (trong thực tế dùng HMAC SHA-512 với secret key ở backend)
    final secureHash = _generateSecureHash(queryString);

    return '$_sandboxUrl?$queryString&vnp_SecureHash=$secureHash';
  }

  /// Generate secure hash cho request
  /// NOTE: Trong production, hash phải được tạo ở backend với secret key thật
  String _generateSecureHash(String data) {
    // Demo hash - trong thực tế dùng HMAC SHA-512
    // import 'package:crypto/crypto.dart';
    // final key = utf8.encode(_secretKey);
    // final bytes = utf8.encode(data);
    // final hmacSha512 = Hmac(sha512, key);
    // return hmacSha512.convert(bytes).toString();
    
    // Demo: simple hash for testing
    final combined = '$data&vnp_SecureHashType=SHA256&vnp_SecureHash=$_demoSecretKey';
    return combined.hashCode.toRadixString(16).padLeft(64, '0');
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
    
    final responseCode = params['vnp_ResponseCode'] ?? params['vnp_ResponseId'] ?? '';
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
  /// VNPay QR yêu cầu định dạng: https://qr.vnpayment.vn?data=...
  String createQRCodeData({
    required int amount,
    required String orderInfo,
    required String merchantCode,
  }) {
    final qrData = {
      'accountId': merchantCode,
      'accountName': 'Manga Vault',
      'acqId': '970436', // VNPay QR code
      'amount': amount.toString(),
      'currencyCode': 'VND',
      'merchantId': merchantCode,
      'orderId': '${DateTime.now().millisecondsSinceEpoch}',
      'purpose': 'NAPCOIN',
      'signature': '',
    };
    
    final jsonStr = jsonEncode(qrData);
    return 'https://qr.vnpayment.vn?data=${Uri.encodeComponent(jsonStr)}&v=2.1.0';
  }
}
