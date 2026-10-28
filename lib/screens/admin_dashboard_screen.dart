import 'package:flutter/material.dart';
import '../models/admin_stats.dart';
import '../models/chapter.dart';
import '../models/coin_package.dart';
import '../models/coin_transaction.dart';
import '../models/manga.dart';
import '../models/user.dart';
import '../services/admin_stats_service.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminDashboardStats? _stats;
  Object? _error;
  bool _loading = true;
  int? _days;
  DateTimeRange? _customRange;

  DateTime? get _since {
    if (_customRange != null) {
      final s = _customRange!.start;
      return DateTime(s.year, s.month, s.day);
    }
    if (_days == null) return null;
    return DateTime.now().subtract(Duration(days: _days!));
  }

  DateTime? get _until {
    if (_customRange == null) return null;
    final e = _customRange!.end;
    return DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (AuthService.instance.currentUser.role != UserRole.admin) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await AdminStatsService.instance.load(
        since: _since,
        until: _until,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _format(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _days = null;
    });
    await _load();
  }

  void _selectDays(int? days) {
    setState(() {
      _days = days;
      _customRange = null;
    });
    _load();
  }

  void _openDrill(String title, String target) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminDrillScreen(
          title: title,
          target: target,
          since: _since,
          until: _until,
          format: _format,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard quản trị')),
        body: const Center(
          child: Text('Chỉ quản trị viên mới xem được dashboard.'),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard quản trị'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _days == null && _customRange == null,
                  onSelected: (_) => _selectDays(null),
                ),
                ChoiceChip(
                  label: const Text('7 ngày'),
                  selected: _days == 7,
                  onSelected: (_) => _selectDays(7),
                ),
                ChoiceChip(
                  label: const Text('30 ngày'),
                  selected: _days == 30,
                  onSelected: (_) => _selectDays(30),
                ),
                ChoiceChip(
                  label: const Text('90 ngày'),
                  selected: _days == 90,
                  onSelected: (_) => _selectDays(90),
                ),
                ChoiceChip(
                  label: Text(
                    _customRange == null
                        ? 'Tùy chọn'
                        : '${_customRange!.start.day}/${_customRange!.start.month}–${_customRange!.end.day}/${_customRange!.end.month}',
                  ),
                  selected: _customRange != null,
                  onSelected: (_) => _pickCustomRange(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bộ lọc thời gian chỉ áp dụng cho nạp, doanh thu, mở khóa và giao dịch. Tài khoản, manga, chapter, thể loại, số dư ví là tồn kho hiện tại.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorState(
                message: 'Không tải được số liệu. $_error',
                onRetry: _load,
              )
            else if (_stats == null)
              const _EmptyState()
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _stats!.catalogSource == 'aspnet-catalog'
                      ? 'Nguồn catalog: API C# localhost:5080. KPI nạp/mở khóa lấy từ SQLite. Phân quyền admin chạy trên thiết bị, không phải bảo mật server-side.'
                      : 'Nguồn catalog: SQLite cục bộ (API tắt hoặc không phản hồi). KPI nạp/mở khóa lấy từ SQLite. Phân quyền admin chạy trên thiết bị, không phải bảo mật server-side.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tồn kho hiện tại',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _KpiCard(
                    title: 'Tài khoản',
                    value: _format(_stats!.totalUsers),
                    subtitle:
                        '${_stats!.activeUsers} hoạt động / ${_stats!.deactivatedUsers} vô hiệu',
                    onTap: () => _openDrill('Tài khoản', 'users'),
                  ),
                  _KpiCard(
                    title: 'Theo vai trò (active)',
                    value: _format(
                      _stats!.adminCount +
                          _stats!.staffCount +
                          _stats!.readerCount,
                    ),
                    subtitle:
                        'Admin ${_stats!.adminCount} • Staff ${_stats!.staffCount} • Reader ${_stats!.readerCount}',
                    onTap: () => _openDrill('Tài khoản', 'users'),
                  ),
                  _KpiCard(
                    title: 'Truyện',
                    value: _format(_stats!.totalMangas),
                    subtitle:
                        '${_stats!.visibleMangas} đang hiện / ${_stats!.hiddenMangas} ẩn',
                    onTap: () => _openDrill('Truyện', 'mangas'),
                  ),
                  _KpiCard(
                    title: 'Chương',
                    value: _format(_stats!.totalChapters),
                    subtitle: '${_stats!.lockedChapters} chương trả phí',
                    onTap: () => _openDrill('Chương trả phí', 'chapters'),
                  ),
                  _KpiCard(
                    title: 'Thể loại',
                    value: _format(_stats!.totalGenres),
                    subtitle: 'Đếm từ bảng genres',
                  ),
                  _KpiCard(
                    title: 'Số dư ví',
                    value: _format(_stats!.walletBalance),
                    subtitle:
                        'Kiếm ${_format(_stats!.totalEarned)} • tiêu ${_format(_stats!.totalSpent)} xu',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Phát sinh trong kỳ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _KpiCard(
                    title: 'Doanh thu đã xác nhận',
                    value: '${_format(_stats!.revenueVnd)} đ',
                    subtitle:
                        '${_stats!.completedDeposits} nạp completed • không gồm pending/failed',
                    onTap: () => _openDrill('Nạp thành công', 'deposits'),
                  ),
                  _KpiCard(
                    title: 'Xu đã cộng',
                    value: _format(_stats!.coinsCredited),
                    subtitle: _stats!.completedDeposits == 0
                        ? 'Chưa có nạp thành công'
                        : 'TB ${_format(_stats!.averageRevenuePerDeposit.round())} đ / nạp',
                    onTap: () => _openDrill('Nạp thành công', 'deposits'),
                  ),
                  _KpiCard(
                    title: 'Giao dịch nạp',
                    value: _format(
                      _stats!.completedDeposits +
                          _stats!.failedDeposits +
                          _stats!.pendingDeposits,
                    ),
                    subtitle:
                        'OK ${_stats!.completedDeposits} • fail ${_stats!.failedDeposits} • chờ ${_stats!.pendingDeposits}',
                    onTap: () => _openDrill('Giao dịch nạp', 'all_deposits'),
                  ),
                  _KpiCard(
                    title: 'Mở khóa chương',
                    value: _format(_stats!.unlockCount),
                    subtitle:
                        '${_format(_stats!.coinsSpentOnUnlocks)} xu đã chi (không phải doanh thu VND)',
                    onTap: () => _openDrill('Mở khóa chương', 'unlocks'),
                  ),
                ],
              ),
              if (_stats!.alerts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Cảnh báo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._stats!.alerts.map(
                  (alert) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFE17055),
                      ),
                      title: Text(alert.title),
                      subtitle: Text(alert.detail),
                      onTap: () => _openDrill(alert.title, alert.target),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _ChartCard(
                title: 'Doanh thu nạp xu theo ngày (VND, completed)',
                child: _stats!.revenueByDay.every((p) => p.revenueVnd == 0)
                    ? const _EmptyState(message: 'Chưa có doanh thu trong kỳ.')
                    : _BarChart(
                        values: _stats!.revenueByDay
                            .map((p) => p.revenueVnd.toDouble())
                            .toList(),
                        labels: _stats!.revenueByDay.map((p) => p.day).toList(),
                      ),
              ),
              _ChartCard(
                title: 'Giao dịch theo trạng thái',
                child: _stats!.transactionsByStatus.isEmpty
                    ? const _EmptyState(message: 'Chưa có giao dịch trong kỳ.')
                    : _HBarChart(data: _stats!.transactionsByStatus),
              ),
              _ChartCard(
                title: 'Tài khoản theo vai trò',
                child: _HBarChart(data: _stats!.usersByRole),
              ),
              _ChartCard(
                title: 'Manga theo thể loại',
                child: _stats!.mangasByGenre.isEmpty
                    ? const _EmptyState(message: 'Chưa có truyện.')
                    : _HBarChart(data: _stats!.mangasByGenre),
              ),
              _ChartCard(
                title: 'Xu đã tiêu mở khóa theo ngày',
                child: _stats!.unlockSpendByDay.every((p) => p.coins == 0)
                    ? const _EmptyState(
                        message: 'Chưa có lượt mở khóa trong kỳ.',
                      )
                    : _BarChart(
                        values: _stats!.unlockSpendByDay
                            .map((p) => p.coins.toDouble())
                            .toList(),
                        labels: _stats!.unlockSpendByDay
                            .map((p) => p.day)
                            .toList(),
                        color: const Color(0xFFE17055),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                'Top chương được mở khóa',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_stats!.topUnlockedChapters.isEmpty)
                const _EmptyState(message: 'Chưa có lượt mở khóa.')
              else
                ..._stats!.topUnlockedChapters.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${item.mangaTitle} · Chap ${item.chapterNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(item.chapterTitle),
                    trailing: Text(
                      '${item.unlocks} lượt · ${_format(item.coinsSpent)} xu',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _openDrill('Mở khóa chương', 'unlocks'),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Giao dịch gần đây',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_stats!.recentTransactions.isEmpty)
                const _EmptyState(message: 'Chưa có giao dịch nào.')
              else
                ..._stats!.recentTransactions.map(
                  (tx) => _TransactionTile(tx: tx, format: _format),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminDrillScreen extends StatefulWidget {
  final String title;
  final String target;
  final DateTime? since;
  final DateTime? until;
  final String Function(int) format;
  const _AdminDrillScreen({
    required this.title,
    required this.target,
    required this.since,
    required this.until,
    required this.format,
  });

  @override
  State<_AdminDrillScreen> createState() => _AdminDrillScreenState();
}

class _AdminDrillScreenState extends State<_AdminDrillScreen> {
  final _items = <Object>[];
  bool _loading = true;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (AuthService.instance.currentUser.role != UserRole.admin) {
        throw StateError('Chỉ quản trị viên mới xem được dashboard.');
      }
      final db = DatabaseHelper.instance;
      final offset = _items.length;
      List<Object> next;
      switch (widget.target) {
        case 'users':
          next = await db.queryAdminUsers(limit: 20, offset: offset);
          break;
        case 'mangas':
          next = await db.queryAdminMangas(limit: 20, offset: offset);
          break;
        case 'chapters':
          next = await db.queryAdminChapters(
            lockedOnly: true,
            limit: 20,
            offset: offset,
          );
          break;
        case 'invalid_chapters':
          next = await db.queryAdminChapters(
            invalidPremium: true,
            limit: 20,
            offset: offset,
          );
          break;
        case 'packages':
          next = await db.queryAdminPackages(
            active: false,
            limit: 20,
            offset: offset,
          );
          break;
        case 'deposits':
          next = await db.queryAdminTransactions(
            type: 'deposit',
            statuses: const ['completed'],
            since: widget.since,
            until: widget.until,
            limit: 20,
            offset: offset,
          );
          break;
        case 'failed':
          next = await db.queryAdminTransactions(
            type: 'deposit',
            statuses: const ['failed', 'cancelled'],
            since: widget.since,
            until: widget.until,
            limit: 20,
            offset: offset,
          );
          break;
        case 'stale_pending':
        case 'pending':
          next = await db.queryAdminTransactions(
            type: 'deposit',
            statuses: const ['pending'],
            until: widget.target == 'stale_pending'
                ? DateTime.now().subtract(const Duration(minutes: 60))
                : widget.until,
            since: widget.target == 'stale_pending' ? null : widget.since,
            limit: 20,
            offset: offset,
          );
          break;
        case 'unlocks':
          next = await db.queryAdminTransactions(
            type: 'purchase',
            statuses: const ['completed'],
            since: widget.since,
            until: widget.until,
            limit: 20,
            offset: offset,
          );
          break;
        default:
          next = await db.queryAdminTransactions(
            type: 'deposit',
            since: widget.since,
            until: widget.until,
            limit: 20,
            offset: offset,
          );
      }
      if (!mounted) return;
      setState(() {
        _items.addAll(next);
        _hasMore = next.length >= 20;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null && _items.isEmpty
          ? _ErrorState(message: '$_error', onRetry: _loadMore)
          : _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const _EmptyState(message: 'Không có dữ liệu.')
          : ListView.builder(
              itemCount: _items.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return TextButton(
                    onPressed: _loading ? null : _loadMore,
                    child: Text(_loading ? 'Đang tải…' : 'Tải thêm'),
                  );
                }
                final item = _items[index];
                if (item is CoinTransaction) {
                  return _TransactionTile(tx: item, format: widget.format);
                }
                if (item is AppUser) {
                  return ListTile(
                    title: Text(item.displayName),
                    subtitle: Text(
                      '${item.username} • ${item.role.label} • ${item.isActive ? 'hoạt động' : 'vô hiệu'}',
                    ),
                  );
                }
                if (item is Manga) {
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.genre} • ${item.isHidden ? 'ẩn' : 'hiện'}',
                    ),
                  );
                }
                if (item is Chapter) {
                  return ListTile(
                    title: Text('Chap ${item.chapterNumber}: ${item.title}'),
                    subtitle: Text(
                      'Giá ${item.price} • ${item.isLocked ? 'khóa' : 'mở'}',
                    ),
                  );
                }
                if (item is CoinPackage) {
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.totalCoins} xu • ${item.price.round()}đ • ${item.isActive ? 'active' : 'tắt'}',
                    ),
                  );
                }
                return ListTile(title: Text(item.toString()));
              },
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  const _BarChart({
    required this.values,
    required this.labels,
    this.color = const Color(0xFF6C5CE7),
  });

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _BarPainter(values: values, max: max, color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final double max;
  final Color color;
  _BarPainter({required this.values, required this.max, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || max <= 0) return;
    final paint = Paint()..color = color;
    final barWidth = size.width / (values.length * 1.6);
    for (var i = 0; i < values.length; i++) {
      final h = (values[i] / max) * (size.height - 4);
      final x = i * (size.width / values.length) + barWidth * 0.3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.values != values || old.max != max;
}

class _HBarChart extends StatelessWidget {
  final Map<String, int> data;
  const _HBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final max = data.values.fold<int>(0, (m, v) => v > m ? v : m);
    if (max <= 0) return const _EmptyState(message: 'Không có dữ liệu.');
    return Column(
      children: data.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(e.key, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: e.value / max,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text('${e.value}'),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final CoinTransaction tx;
  final String Function(int) format;
  const _TransactionTile({required this.tx, required this.format});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        tx.amount >= 0
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        color: tx.status == TransactionStatus.completed
            ? (tx.amount >= 0
                  ? const Color(0xFF00B894)
                  : const Color(0xFFE17055))
            : Colors.grey,
      ),
      title: Text(tx.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${tx.type.label} • ${tx.status.label} • ${tx.userId}'),
      trailing: Text(
        '${tx.amount > 0 ? '+' : ''}${format(tx.amount)} xu',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({this.message = 'Chưa có dữ liệu thống kê.'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 56, color: Color(0xFFD63031)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
