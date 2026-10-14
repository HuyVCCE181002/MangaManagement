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

  String get qrUrl => Uri.https(
    'img.vietqr.io',
    '/image/$bankBin-$accountNumber-compact2.png',
    {'amount': '$amount', 'addInfo': transferCode, 'accountName': accountName},
  ).toString();
}
