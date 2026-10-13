import 'package:flutter/material.dart';
import '../models/coin_transaction.dart';
import '../services/wallet_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final WalletService _wallet = WalletService.instance;

  TransactionType? _filterType;
  TransactionStatus? _filterStatus;
  DateTimeRange? _dateRange;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_onChange);
    _wallet.refreshTransactions();
  }

  @override
  void dispose() {
    _wallet.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String _formatCoins(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  List<CoinTransaction> get _filtered {
    var list = _wallet.transactions;
    if (_filterType != null) {
      list = list.where((t) => t.type == _filterType).toList();
    }
    if (_filterStatus != null) {
      list = list.where((t) => t.status == _filterStatus).toList();
    }
    if (_dateRange != null) {
      list = list.where((t) {
        return t.createdAt.isAfter(_dateRange!.start.subtract(const Duration(seconds: 1))) &&
            t.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((t) => t.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  /// Tổng kết giao dịch trong danh sách đang lọc
  Map<String, num> get _summary {
    int totalIn = 0;
    int totalOut = 0;
    int countSuccess = 0;
    for (final t in _filtered) {
      if (t.status != TransactionStatus.completed) continue;
      if (t.amount > 0) {
        totalIn += t.amount;
      } else {
        totalOut += -t.amount;
      }
      countSuccess++;
    }
    return {'in': totalIn, 'out': totalOut, 'count': _filtered.length, 'success': countSuccess};
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final list = _filtered;
    final s = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _wallet.refreshTransactions(),
          ),
        ],
      ),
      body: Column(
        children: [
          // =========== SUMMARY CARDS ===========
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.south_west_rounded,
                    label: 'Tổng nạp',
                    value: _formatCoins(s['in'] as int),
                    color: const Color(0xFF00B894),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.north_east_rounded,
                    label: 'Tổng chi',
                    value: _formatCoins(s['out'] as int),
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.receipt_long_rounded,
                    label: 'Số GD',
                    value: s['count'].toString(),
                    color: const Color(0xFF6C5CE7),
                  ),
                ),
              ],
            ),
          ),

          // =========== FILTERS ===========
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo mô tả...',
                hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFF1F3F7),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  label: 'Loại: ${_filterType?.label ?? "Tất cả"}',
                  selected: _filterType != null,
                  onTap: _showTypePicker,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Trạng thái: ${_filterStatus?.label ?? "Tất cả"}',
                  selected: _filterStatus != null,
                  onTap: _showStatusPicker,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: _dateRange == null
                      ? 'Khoảng thời gian'
                      : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                  selected: _dateRange != null,
                  onTap: _pickDateRange,
                ),
                if (_filterType != null || _filterStatus != null || _dateRange != null || _search.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Xóa lọc',
                    selected: false,
                    onTap: () {
                      setState(() {
                        _filterType = null;
                        _filterStatus = null;
                        _dateRange = null;
                        _search = '';
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          // =========== LIST ===========
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có giao dịch nào',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nạp coins để bắt đầu mua sắm',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildTransactionTile(list[i], isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
      backgroundColor: selected ? const Color(0xFF6C5CE7) : null,
      side: BorderSide(color: selected ? const Color(0xFF6C5CE7) : Theme.of(context).dividerColor),
      onPressed: onTap,
    );
  }

  void _showTypePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.clear_rounded),
              title: const Text('Tất cả loại'),
              onTap: () {
                setState(() => _filterType = null);
                Navigator.pop(ctx);
              },
            ),
            ...TransactionType.values.map(
              (t) => ListTile(
                leading: Icon(_iconForType(t), color: _colorForType(t)),
                title: Text(t.label),
                selected: _filterType == t,
                onTap: () {
                  setState(() => _filterType = t);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.clear_rounded),
              title: const Text('Tất cả trạng thái'),
              onTap: () {
                setState(() => _filterStatus = null);
                Navigator.pop(ctx);
              },
            ),
            ...TransactionStatus.values.map(
              (s) => ListTile(
                leading: Icon(_iconForStatus(s), color: _colorForStatus(s)),
                title: Text(s.label),
                selected: _filterStatus == s,
                onTap: () {
                  setState(() => _filterStatus = s);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(CoinTransaction tx, bool isDark) {
    final typeColor = _colorForType(tx.type);
    final statusColor = _colorForStatus(tx.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconForType(tx.type), color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.type.label,
                            style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.status.label,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${tx.amount > 0 ? '+' : ''}${_formatCoins(tx.amount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tx.amount > 0 ? const Color(0xFF00B894) : Colors.redAccent,
                    ),
                  ),
                  Text(
                    'coins',
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(tx.createdAt),
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (tx.paymentMethod != null) ...[
                const Icon(Icons.payment_rounded, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  tx.paymentMethod!,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(width: 12),
              const Icon(Icons.account_balance_wallet_rounded, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Số dư: ${_formatCoins(tx.coinsAfter)}',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForType(TransactionType t) {
    switch (t) {
      case TransactionType.deposit:
        return Icons.south_west_rounded;
      case TransactionType.purchase:
        return Icons.shopping_cart_rounded;
      case TransactionType.refund:
        return Icons.replay_rounded;
      case TransactionType.bonus:
        return Icons.card_giftcard_rounded;
      case TransactionType.spending:
        return Icons.remove_circle_rounded;
    }
  }

  Color _colorForType(TransactionType t) {
    switch (t) {
      case TransactionType.deposit:
        return const Color(0xFF00B894);
      case TransactionType.purchase:
        return Colors.redAccent;
      case TransactionType.refund:
        return Colors.blue;
      case TransactionType.bonus:
        return Colors.orange;
      case TransactionType.spending:
        return Colors.deepPurple;
    }
  }

  IconData _iconForStatus(TransactionStatus s) {
    switch (s) {
      case TransactionStatus.pending:
        return Icons.hourglass_top_rounded;
      case TransactionStatus.completed:
        return Icons.check_circle_rounded;
      case TransactionStatus.failed:
        return Icons.error_rounded;
      case TransactionStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Color _colorForStatus(TransactionStatus s) {
    switch (s) {
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.completed:
        return const Color(0xFF00B894);
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
