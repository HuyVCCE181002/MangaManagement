/// Cấu hình mốc thưởng điểm danh hàng ngày
class CheckInRewardConfig {
  final int day;
  final int coins;
  final String title;
  final bool isSpecial;

  const CheckInRewardConfig({
    required this.day,
    required this.coins,
    required this.title,
    this.isSpecial = false,
  });
}

/// Bảng mốc thưởng 7 ngày liên tiếp
const List<CheckInRewardConfig> kWeeklyCheckInRewards = [
  CheckInRewardConfig(day: 1, coins: 10, title: 'Ngày 1'),
  CheckInRewardConfig(day: 2, coins: 15, title: 'Ngày 2'),
  CheckInRewardConfig(day: 3, coins: 20, title: 'Ngày 3'),
  CheckInRewardConfig(day: 4, coins: 30, title: 'Ngày 4'),
  CheckInRewardConfig(day: 5, coins: 45, title: 'Ngày 5'),
  CheckInRewardConfig(day: 6, coins: 60, title: 'Ngày 6'),
  CheckInRewardConfig(day: 7, coins: 100, title: 'Ngày 7 (Quà VIP)', isSpecial: true),
];

/// Thống kê điểm danh của người dùng
class UserCheckInStats {
  final String userId;
  final String lastCheckInDate; // YYYY-MM-DD
  final int currentStreak; // 1 đến 7
  final int totalCheckIns;
  final int totalRewardCoins;
  final DateTime updatedAt;

  const UserCheckInStats({
    required this.userId,
    required this.lastCheckInDate,
    required this.currentStreak,
    required this.totalCheckIns,
    required this.totalRewardCoins,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'last_check_in_date': lastCheckInDate,
      'current_streak': currentStreak,
      'total_check_ins': totalCheckIns,
      'total_reward_coins': totalRewardCoins,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserCheckInStats.fromMap(Map<String, dynamic> map) {
    return UserCheckInStats(
      userId: map['user_id'] as String? ?? '',
      lastCheckInDate: map['last_check_in_date'] as String? ?? '',
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      totalCheckIns: (map['total_check_ins'] as num?)?.toInt() ?? 0,
      totalRewardCoins: (map['total_reward_coins'] as num?)?.toInt() ?? 0,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserCheckInStats copyWith({
    String? userId,
    String? lastCheckInDate,
    int? currentStreak,
    int? totalCheckIns,
    int? totalRewardCoins,
    DateTime? updatedAt,
  }) {
    return UserCheckInStats(
      userId: userId ?? this.userId,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      currentStreak: currentStreak ?? this.currentStreak,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      totalRewardCoins: totalRewardCoins ?? this.totalRewardCoins,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static UserCheckInStats empty(String userId) {
    return UserCheckInStats(
      userId: userId,
      lastCheckInDate: '',
      currentStreak: 0,
      totalCheckIns: 0,
      totalRewardCoins: 0,
      updatedAt: DateTime.now(),
    );
  }
}

/// Lịch sử từng lần điểm danh
class DailyCheckInHistoryItem {
  final String id;
  final String userId;
  final String checkInDate; // YYYY-MM-DD
  final int streakDay;
  final int rewardCoins;
  final DateTime createdAt;

  const DailyCheckInHistoryItem({
    required this.id,
    required this.userId,
    required this.checkInDate,
    required this.streakDay,
    required this.rewardCoins,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'check_in_date': checkInDate,
      'streak_day': streakDay,
      'reward_coins': rewardCoins,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DailyCheckInHistoryItem.fromMap(Map<String, dynamic> map) {
    return DailyCheckInHistoryItem(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      checkInDate: map['check_in_date'] as String? ?? '',
      streakDay: (map['streak_day'] as num?)?.toInt() ?? 1,
      rewardCoins: (map['reward_coins'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
