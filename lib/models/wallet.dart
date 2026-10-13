/// Ví coins của một user
class Wallet {
  final String id;
  final String userId;
  final int balance;          // Số coins hiện tại
  final int totalEarned;      // Tổng số coins đã nạp (lifetime)
  final int totalSpent;       // Tổng số coins đã tiêu
  final DateTime createdAt;
  final DateTime updatedAt;

  const Wallet({
    required this.id,
    required this.userId,
    this.balance = 0,
    this.totalEarned = 0,
    this.totalSpent = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'total_earned': totalEarned,
      'total_spent': totalSpent,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      totalEarned: (map['total_earned'] as num?)?.toInt() ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Wallet copyWith({
    String? id,
    String? userId,
    int? balance,
    int? totalEarned,
    int? totalSpent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      totalEarned: totalEarned ?? this.totalEarned,
      totalSpent: totalSpent ?? this.totalSpent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
