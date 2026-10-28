import 'coin_package.dart';

/// Immutable payment snapshot returned by the authenticated payment server.
class PaymentOrder {
  final String id;
  final String transferCode;
  final CoinPackage package;
  final String promoCode;
  final int amount;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? paidAt;
  final String bankBin;
  final String accountNumber;
  final String accountName;

  const PaymentOrder({
    required this.id,
    required this.transferCode,
    required this.package,
    required this.promoCode,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.paidAt,
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['createdAt'] as String).toLocal();
    final pkg = json['package'] as Map<String, dynamic>;
    return PaymentOrder(
      id: json['id'] as String,
      transferCode: json['transferCode'] as String,
      package: CoinPackage(
        id: pkg['id'] as String,
        name: pkg['name'] as String,
        coins: (pkg['coins'] as num).toInt(),
        bonusCoins: (pkg['bonusCoins'] as num).toInt(),
        price: (pkg['price'] as num).toDouble(),
        createdAt: created,
      ),
      promoCode: json['promoCode'] as String,
      amount: (json['amount'] as num).toInt(),
      status: json['status'] as String,
      createdAt: created,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String).toLocal(),
      bankBin: json['bankBin'] as String,
      accountNumber: json['accountNumber'] as String,
      accountName: json['accountName'] as String,
    );
  }

  static const defaultBankCode = 'STB';
  static const defaultBankBin = '970403';
  static const defaultAccountNumber = '070118746463';
  static const defaultAccountName = 'NGO VIET TRINH';

  /// VietQR dùng mã ngân hàng STB cho Sacombank (BIN 970403).
  String get vietQrBankCode {
    final code = bankBin.trim().toUpperCase();
    if (code.isEmpty || code == '970403' || code == 'STB') return defaultBankCode;
    return bankBin;
  }

  /// Ảnh VietQR chuẩn. img.vietqr.io yêu cầu BIN số (970403),
  /// không dùng mã chữ STB để tránh bị từ chối.
  static String vietQrImageUrl({
    required int amount,
    required String transferCode,
    String accountNumber = defaultAccountNumber,
    String accountName = defaultAccountName,
  }) {
    final params =
        'amount=$amount'
        '&addInfo=${Uri.encodeComponent(transferCode)}'
        '&accountName=${Uri.encodeComponent(accountName)}';
    return 'https://img.vietqr.io/image/$defaultBankBin-$accountNumber-compact2.png?$params';
  }

  /// Ảnh QR SePay dùng làm nguồn dự phòng khi img.vietqr.io bị chặn.
  static String sepayQrImageUrl({
    required int amount,
    required String transferCode,
    String accountNumber = defaultAccountNumber,
  }) {
    return 'https://qr.sepay.vn/img?bank=Sacombank&acc=$accountNumber'
        '&template=compact&amount=$amount&des=${Uri.encodeComponent(transferCode)}';
  }

  static String vietQrUrl({
    required int amount,
    required String transferCode,
    String bankCode = defaultBankCode,
    String accountNumber = defaultAccountNumber,
    String accountName = defaultAccountName,
  }) => vietQrImageUrl(
    amount: amount,
    transferCode: transferCode,
    accountNumber: accountNumber,
    accountName: accountName,
  );

  List<String> get qrImageCandidates => [
    vietQrImageUrl(
      amount: amount,
      transferCode: transferCode,
      accountNumber: accountNumber,
      accountName: accountName,
    ),
    sepayQrImageUrl(amount: amount, transferCode: transferCode, accountNumber: accountNumber),
  ];

  String get qrUrl => qrImageCandidates.first;
}
