/// Các loại giao dịch trong hệ thống ví
enum TransactionType {
  deposit, // Nạp tiền (mua coins)
  purchase, // Mua truyện / chương
  refund, // Hoàn tiền
  bonus, // Thưởng coins miễn phí
  spending; // Chi tiêu khác

  String get label {
    switch (this) {
      case TransactionType.deposit:
        return 'Nạp Coins';
      case TransactionType.purchase:
        return 'Mua hàng';
      case TransactionType.refund:
        return 'Hoàn tiền';
      case TransactionType.bonus:
        return 'Thưởng';
      case TransactionType.spending:
        return 'Chi tiêu';
    }
  }

  String get iconName {
    switch (this) {
      case TransactionType.deposit:
        return 'arrow_upward';
      case TransactionType.purchase:
        return 'shopping_cart';
      case TransactionType.refund:
        return 'replay';
      case TransactionType.bonus:
        return 'card_giftcard';
      case TransactionType.spending:
        return 'remove_circle';
    }
  }
}

/// Trạng thái giao dịch
enum TransactionStatus {
  pending, // Đang xử lý
  completed, // Thành công
  failed, // Thất bại
  cancelled; // Đã hủy

  String get label {
    switch (this) {
      case TransactionStatus.pending:
        return 'Đang xử lý';
      case TransactionStatus.completed:
        return 'Thành công';
      case TransactionStatus.failed:
        return 'Thất bại';
      case TransactionStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

/// Giao dịch trong hệ thống ví
class CoinTransaction {
  final String id;
  final String userId;
  final String walletId;
  final TransactionType type;
  final int amount; // Số coins (+ nạp/thưởng, - chi tiêu)
  final int coinsBefore; // Số dư trước giao dịch
  final int coinsAfter; // Số dư sau giao dịch
  final String description;
  final String? paymentMethod; // "Momo", "ZaloPay", "Banking", "Card"
  final String? packageId;
  final int? paymentAmount;
  final TransactionStatus status;
  final DateTime createdAt;

  const CoinTransaction({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.coinsBefore,
    required this.coinsAfter,
    required this.description,
    this.paymentMethod,
    this.packageId,
    this.paymentAmount,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'wallet_id': walletId,
      'type': type.name,
      'amount': amount,
      'coins_before': coinsBefore,
      'coins_after': coinsAfter,
      'description': description,
      'payment_method': paymentMethod,
      'package_id': packageId,
      'payment_amount': paymentAmount,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CoinTransaction.fromMap(Map<String, dynamic> map) {
    return CoinTransaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      walletId: map['wallet_id'] as String? ?? '',
      type: TransactionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TransactionType.deposit,
      ),
      amount: (map['amount'] as num).toInt(),
      coinsBefore: (map['coins_before'] as num).toInt(),
      coinsAfter: (map['coins_after'] as num).toInt(),
      description: map['description'] as String? ?? '',
      paymentMethod: map['payment_method'] as String?,
      packageId: map['package_id'] as String?,
      paymentAmount: (map['payment_amount'] as num?)?.toInt(),
      status: TransactionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TransactionStatus.completed,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  CoinTransaction copyWith({
    String? id,
    String? userId,
    String? walletId,
    TransactionType? type,
    int? amount,
    int? coinsBefore,
    int? coinsAfter,
    String? description,
    String? paymentMethod,
    String? packageId,
    int? paymentAmount,
    TransactionStatus? status,
    DateTime? createdAt,
  }) {
    return CoinTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      coinsBefore: coinsBefore ?? this.coinsBefore,
      coinsAfter: coinsAfter ?? this.coinsAfter,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      packageId: packageId ?? this.packageId,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
