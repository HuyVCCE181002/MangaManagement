import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/coin_package.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/coin_package_service.dart';
import 'transaction_history_screen.dart';
import 'deposit_screen.dart';

/// Màn hình Ví Coins cho Reader/Staff/Admin
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final AuthService _auth = AuthService.instance;
  final WalletService _wallet = WalletService.instance;
  final CoinPackageService _pkgService = CoinPackageService.instance;
  Timer? _packageRefreshTimer;

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_onChange);
    _auth.addListener(_onChange);
    _pkgService.addListener(_onChange);
    _refresh();
    // A reader may already have WalletScreen open while an Admin updates the
    // shared local database. Refresh the active catalog without requiring a
    // manual navigation or app restart.
    _packageRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _auth.isLoggedIn) _pkgService.loadAll();
    });
  }

  @override
  void dispose() {
    _wallet.removeListener(_onChange);
    _auth.removeListener(_onChange);
    _pkgService.removeListener(_onChange);
    _packageRefreshTimer?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_auth.isLoggedIn) {
      await _wallet.loadWallet(_auth.currentUser.id);
      try {
        await _wallet.recoverServerPayments(_auth.currentUser);
      } catch (_) {
        // Cached wallet remains available if the payment server is offline.
      }
      await _pkgService.loadAll();
    }
  }

  String _formatCoins(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  String _formatVnd(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = _auth.currentUser;

    if (user.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ví Coins')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 80, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('Bạn cần đăng nhập để sử dụng Ví Coins',
                    style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text(
                  'Độc giả có thể nạp coins, mua truyện và theo dõi lịch sử giao dịch.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final balance = _wallet.balance;
    final totalEarned = _wallet.totalEarned;
    final totalSpent = _wallet.totalSpent;
    final packages = _pkgService.packages.where((p) => p.isActive).toList();
    final featured = packages.where((p) => p.isFeatured).toList();
    final regular = packages.where((p) => !p.isFeatured).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví Coins'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =============== HEADER CARD ===============
                  _buildBalanceCard(isDark, user, balance, totalEarned, totalSpent),
                  const SizedBox(height: 20),

                  // =============== ACTION BUTTONS ===============
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.add_circle_rounded,
                          label: 'Nạp Coins',
                          color: const Color(0xFF6C5CE7),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DepositScreen()),
                            );
                            _refresh();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.history_rounded,
                          label: 'Lịch sử',
                          color: const Color(0xFF00B894),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                            );
                            _refresh();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // =============== FEATURED PACKAGES ===============
                  if (featured.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Gói nạp nổi bật',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 175,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: featured.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _buildFeaturedPackageCard(featured[i]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // =============== ALL PACKAGES ===============
                  Text(
                    'Tất cả gói nạp',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (regular.isEmpty && featured.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Chưa có gói nạp nào khả dụng.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: regular.map((p) => _buildPackageGridCard(p)).toList(),
                    ),
                  const SizedBox(height: 24),

                  // =============== RECENT TRANSACTIONS (Top 3) ===============
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giao dịch gần đây',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (_wallet.transactions.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                            );
                          },
                          child: const Text('Xem tất cả'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_wallet.transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161924) : const Color(0xFFF1F3F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Chưa có giao dịch nào.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _wallet.transactions.take(3).map((tx) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildTxIcon(tx.type.name, isDark),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDateTime(tx.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${tx.amount > 0 ? '+' : ''}${_formatCoins(tx.amount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: tx.amount > 0 ? const Color(0xFF00B894) : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    bool isDark,
    AppUser user,
    int balance,
    int totalEarned,
    int totalSpent,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ví của ${user.displayName}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.role.label,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Số dư hiện tại',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCoins(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('coins', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Sao chép số dư',
                icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: balance.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép số dư vào bộ nhớ tạm'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.south_west_rounded,
                  label: 'Tổng nạp',
                  value: _formatCoins(totalEarned),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.north_east_rounded,
                  label: 'Tổng chi',
                  value: _formatCoins(totalSpent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedPackageCard(CoinPackage pkg) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DepositScreen(initialPackageId: pkg.id)),
        );
        _refresh();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFB300).withValues(alpha: 0.15),
              const Color(0xFFFF6B6B).withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('HOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pkg.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCoins(pkg.totalCoins),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('coins', style: TextStyle(fontSize: 11)),
              ],
            ),
            if (pkg.bonusCoins > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+${_formatCoins(pkg.bonusCoins)} thưởng (${pkg.bonusPercentage}%)',
                  style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatVnd(pkg.price)}đ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Nạp ngay',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageGridCard(CoinPackage pkg) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DepositScreen(initialPackageId: pkg.id)),
        );
        _refresh();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2E3440)
                : const Color(0xFFE2E5EE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF6C5CE7), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pkg.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              _formatCoins(pkg.coins),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF6C5CE7)),
            ),
            if (pkg.bonusCoins > 0)
              Text(
                '+${_formatCoins(pkg.bonusCoins)} bonus',
                style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatVnd(pkg.price)}đ',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF6C5CE7)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxIcon(String type, bool isDark) {
    IconData icon;
    Color color;
    switch (type) {
      case 'deposit':
        icon = Icons.south_west_rounded;
        color = const Color(0xFF00B894);
        break;
      case 'purchase':
        icon = Icons.shopping_cart_rounded;
        color = Colors.redAccent;
        break;
      case 'refund':
        icon = Icons.replay_rounded;
        color = Colors.blue;
        break;
      case 'bonus':
        icon = Icons.card_giftcard_rounded;
        color = Colors.orange;
        break;
      default:
        icon = Icons.swap_horiz_rounded;
        color = Colors.grey;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
