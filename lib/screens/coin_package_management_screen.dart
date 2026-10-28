import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/coin_package.dart';
import '../services/coin_package_service.dart';

class CoinPackageManagementScreen extends StatefulWidget {
  const CoinPackageManagementScreen({super.key});

  @override
  State<CoinPackageManagementScreen> createState() =>
      _CoinPackageManagementScreenState();
}

class _CoinPackageManagementScreenState
    extends State<CoinPackageManagementScreen> {
  final CoinPackageService _service = CoinPackageService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChange);
    _service.loadAll();
  }

  @override
  void dispose() {
    _service.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String _formatVnd(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  String _formatCoins(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  void _showPackageForm({CoinPackage? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _PackageFormDialog(
        existing: existing,
        onSubmit: (data) async {
          Navigator.pop(ctx);
          if (existing == null) {
            final res = await _service.createPackage(
              name: data.name,
              coins: data.coins,
              price: data.price,
              bonusCoins: data.bonusCoins,
              isActive: data.isActive,
              isFeatured: data.isFeatured,
              sortOrder: data.sortOrder,
            );
            _showSnack(res.message, res.success);
          } else {
            final updated = existing.copyWith(
              name: data.name,
              coins: data.coins,
              price: data.price,
              bonusCoins: data.bonusCoins,
              isActive: data.isActive,
              isFeatured: data.isFeatured,
              sortOrder: data.sortOrder,
            );
            final res = await _service.updatePackage(updated);
            _showSnack(res.message, res.success);
          }
        },
      ),
    );
  }

  void _confirmDelete(CoinPackage pkg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            const Text('Xác nhận gỡ gói'),
          ],
        ),
        content: Text(
          'Nếu gói "${pkg.name}" đã có giao dịch, hệ thống sẽ tạm dừng thay vì xóa để giữ lịch sử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _service.deletePackage(pkg.id);
              _showSnack(res.message, res.success);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(CoinPackage pkg) async {
    final res = await _service.toggleActive(pkg.id);
    _showSnack(res.message, res.success);
  }

  Future<void> _toggleFeatured(CoinPackage pkg) async {
    final res = await _service.toggleFeatured(pkg.id);
    _showSnack(res.message, res.success);
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success
            ? const Color(0xFF00B894)
            : const Color(0xFFD63031),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final packages = _service.packages;

    final totalActive = packages.where((p) => p.isActive).length;
    final totalFeatured = packages.where((p) => p.isFeatured).length;
    final maxPrice = packages.isEmpty
        ? 0.0
        : packages.map((p) => p.price).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Gói Coins'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _service.loadAll(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tạo gói mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showPackageForm(),
      ),
      body: Column(
        children: [
          // ====== STATS BAR ======
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem('Tổng gói', packages.length.toString()),
                ),
                Container(width: 1, height: 32, color: Colors.white24),
                Expanded(
                  child: _buildStatItem('Đang bán', totalActive.toString()),
                ),
                Container(width: 1, height: 32, color: Colors.white24),
                Expanded(
                  child: _buildStatItem('Nổi bật', totalFeatured.toString()),
                ),
                Container(width: 1, height: 32, color: Colors.white24),
                Expanded(
                  child: _buildStatItem('Giá cao nhất', _formatVnd(maxPrice)),
                ),
              ],
            ),
          ),

          // ====== LIST ======
          Expanded(
            child: packages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có gói coins nào',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showPackageForm(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tạo gói đầu tiên'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: packages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _buildPackageCard(packages[i], isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildPackageCard(CoinPackage pkg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pkg.isActive
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE)),
          width: pkg.isFeatured ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pkg.isActive
                      ? const Color(0xFF6C5CE7).withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.monetization_on_rounded,
                  color: pkg.isActive ? const Color(0xFF6C5CE7) : Colors.grey,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pkg.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: pkg.isActive
                                  ? null
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (pkg.isFeatured) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                        if (!pkg.isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TẠM DỪNG',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatCoins(pkg.coins)} coins'
                      '${pkg.bonusCoins > 0 ? " + ${_formatCoins(pkg.bonusCoins)} bonus" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatVnd(pkg.price)}đ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                  if (pkg.bonusCoins > 0)
                    Text(
                      '+${pkg.bonusPercentage}% bonus',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              // Toggle Active
              Expanded(
                child: Row(
                  children: [
                    Switch(
                      value: pkg.isActive,
                      onChanged: (_) => _toggleActive(pkg),
                      activeThumbColor: const Color(0xFF00B894),
                    ),
                    const SizedBox(width: 4),
                    const Text('Bán', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              // Toggle Featured
              IconButton(
                tooltip: pkg.isFeatured ? 'Bỏ nổi bật' : 'Đánh dấu nổi bật',
                icon: Icon(
                  pkg.isFeatured
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: pkg.isFeatured ? const Color(0xFFFFB300) : Colors.grey,
                ),
                onPressed: () => _toggleFeatured(pkg),
              ),
              // Edit
              IconButton(
                tooltip: 'Sửa',
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF6C5CE7)),
                onPressed: () => _showPackageForm(existing: pkg),
              ),
              // Delete
              IconButton(
                tooltip: 'Xóa',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                onPressed: () => _confirmDelete(pkg),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackageFormData {
  final String name;
  final int coins;
  final double price;
  final int bonusCoins;
  final bool isActive;
  final bool isFeatured;
  final int sortOrder;

  _PackageFormData({
    required this.name,
    required this.coins,
    required this.price,
    required this.bonusCoins,
    required this.isActive,
    required this.isFeatured,
    required this.sortOrder,
  });
}

class _PackageFormDialog extends StatefulWidget {
  final CoinPackage? existing;
  final void Function(_PackageFormData) onSubmit;

  const _PackageFormDialog({this.existing, required this.onSubmit});

  @override
  State<_PackageFormDialog> createState() => _PackageFormDialogState();
}

class _PackageFormDialogState extends State<_PackageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _coins;
  late final TextEditingController _price;
  late final TextEditingController _bonus;
  late final TextEditingController _sort;
  late bool _isActive;
  late bool _isFeatured;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _coins = TextEditingController(
      text: widget.existing?.coins.toString() ?? '',
    );
    _price = TextEditingController(
      text: widget.existing?.price.toStringAsFixed(0) ?? '',
    );
    _bonus = TextEditingController(
      text: widget.existing?.bonusCoins.toString() ?? '0',
    );
    _sort = TextEditingController(
      text: widget.existing?.sortOrder.toString() ?? '0',
    );
    _isActive = widget.existing?.isActive ?? true;
    _isFeatured = widget.existing?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _coins.dispose();
    _price.dispose();
    _bonus.dispose();
    _sort.dispose();
    super.dispose();
  }

  String _previewCoins() {
    final c = int.tryParse(_coins.text) ?? 0;
    final b = int.tryParse(_bonus.text) ?? 0;
    return (c + b).toString();
  }

  String _previewPrice() {
    final p = double.tryParse(_price.text) ?? 0;
    return p
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.existing == null
                            ? Icons.add_box_rounded
                            : Icons.edit_rounded,
                        color: const Color(0xFF6C5CE7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.existing == null
                          ? 'Tạo gói coins mới'
                          : 'Chỉnh sửa gói coins',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Tên gói *',
                    hintText: 'VD: Gói Starter, Gói Pro',
                    prefixIcon: Icon(Icons.label_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên gói'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _coins,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Coins cơ bản *',
                          prefixIcon: Icon(Icons.monetization_on_rounded),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Sai định dạng';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _bonus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Coins thưởng',
                          prefixIcon: Icon(Icons.card_giftcard_rounded),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Giá tiền (VNĐ) *',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0) return 'Sai định dạng';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sort,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Thứ tự hiển thị',
                    prefixIcon: Icon(Icons.sort_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Đang bán'),
                  subtitle: const Text(
                    'Hiển thị cho người dùng',
                    style: TextStyle(fontSize: 11),
                  ),
                  activeThumbColor: const Color(0xFF00B894),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _isFeatured,
                  onChanged: (v) => setState(() => _isFeatured = v),
                  title: const Text('Gói nổi bật'),
                  subtitle: const Text(
                    'Hiển thị ở mục HOT trên Ví',
                    style: TextStyle(fontSize: 11),
                  ),
                  activeThumbColor: const Color(0xFFFFB300),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Coins nhận',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _previewCoins(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00B894),
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 36, color: Colors.grey),
                      Column(
                        children: [
                          const Text('Giá bán', style: TextStyle(fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            '${_previewPrice()}đ',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C5CE7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          widget.onSubmit(
                            _PackageFormData(
                              name: _name.text,
                              coins: int.parse(_coins.text),
                              price: double.parse(_price.text),
                              bonusCoins: int.tryParse(_bonus.text) ?? 0,
                              isActive: _isActive,
                              isFeatured: _isFeatured,
                              sortOrder: int.tryParse(_sort.text) ?? 0,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          widget.existing == null ? 'Tạo gói' : 'Cập nhật',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
