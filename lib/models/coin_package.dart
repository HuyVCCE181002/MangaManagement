/// Gói nạp coins - do Admin quản lý
class CoinPackage {
  final String id;
  final String name;         // "Gói Starter", "Gói Pro", "Gói VIP"
  final int coins;           // Số coins nhận được
  final double price;        // Giá tiền (VNĐ)
  final int bonusCoins;      // Coins thưởng thêm (nếu có)
  final bool isActive;       // Đang bán hay không
  final bool isFeatured;     // Hiển thị nổi bật
  final int sortOrder;       // Thứ tự sắp xếp
  final DateTime createdAt;

  const CoinPackage({
    required this.id,
    required this.name,
    required this.coins,
    required this.price,
    this.bonusCoins = 0,
    this.isActive = true,
    this.isFeatured = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  /// Tổng coins nhận được (base + bonus)
  int get totalCoins => coins + bonusCoins;

  /// Giá mỗi coin (VNĐ)
  double get pricePerCoin {
    if (totalCoins <= 0) return 0;
    return price / totalCoins;
  }

  /// Phần trăm bonus
  int get bonusPercentage {
    if (coins <= 0) return 0;
    return ((bonusCoins / coins) * 100).round();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'coins': coins,
      'price': price,
      'bonus_coins': bonusCoins,
      'is_active': isActive ? 1 : 0,
      'is_featured': isFeatured ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CoinPackage.fromMap(Map<String, dynamic> map) {
    return CoinPackage(
      id: map['id'] as String,
      name: map['name'] as String,
      coins: (map['coins'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      bonusCoins: (map['bonus_coins'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      isFeatured: map['is_featured'] == 1 || map['is_featured'] == true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  CoinPackage copyWith({
    String? id,
    String? name,
    int? coins,
    double? price,
    int? bonusCoins,
    bool? isActive,
    bool? isFeatured,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CoinPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      coins: coins ?? this.coins,
      price: price ?? this.price,
      bonusCoins: bonusCoins ?? this.bonusCoins,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
