import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/coin_package.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/coin_package_service.dart';

/// Phương thức thanh toán
class PaymentMethod {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final String feeText;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.feeText,
  });
}

class DepositScreen extends StatefulWidget {
  final String? initialPackageId;
  const DepositScreen({super.key, this.initialPackageId});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final AuthService _auth = AuthService.instance;
  final WalletService _wallet = WalletService.instance;
  final CoinPackageService _pkgService = CoinPackageService.instance;

  CoinPackage? _selectedPackage;
  PaymentMethod? _selectedMethod;
  String _promoCode = '';
  int _promoDiscountPercent = 0;
  bool _isProcessing = false;

  static const List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'momo',
      name: 'Ví MoMo',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFAE2070),
      description: 'Thanh toán qua ví điện tử MoMo',
      feeText: 'Miễn phí giao dịch',
    ),
    PaymentMethod(
      id: 'zalopay',
      name: 'ZaloPay',
      icon: Icons.qr_code_2_rounded,
      color: Color(0xFF0068FF),
      description: 'Quét QR ZaloPay để thanh toán',
      feeText: 'Miễn phí giao dịch',
    ),
    PaymentMethod(
      id: 'banking',
      name: 'Chuyển khoản Ngân hàng',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF0984E3),
      description: 'Internet Banking / QR Ngân hàng',
      feeText: 'Miễn phí giao dịch',
    ),
    PaymentMethod(
      id: 'card',
      name: 'Thẻ tín dụng / Ghi nợ',
      icon: Icons.credit_card_rounded,
      color: Color(0xFF00B894),
      description: 'Visa, MasterCard, JCB, Napas',
      feeText: 'Phí 1.5% giá trị giao dịch',
    ),
    PaymentMethod(
      id: 'vnpay',
      name: 'VNPay QR',
      icon: Icons.qr_code_scanner_rounded,
      color: Color(0xFFEE0033),
      description: 'Quét QR VNPay - hỗ trợ 40+ ngân hàng',
      feeText: 'Miễn phí giao dịch',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pkgService.addListener(_onChange);
    _wallet.addListener(_onChange);
    _initData();
  }

  @override
  void dispose() {
    _pkgService.removeListener(_onChange);
    _wallet.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _initData() async {
    await _pkgService.loadAll();
    if (widget.initialPackageId != null) {
      final pkg = _pkgService.packages.firstWhere(
        (p) => p.id == widget.initialPackageId,
        orElse: () => _pkgService.packages.first,
      );
      setState(() => _selectedPackage = pkg);
    } else if (_pkgService.packages.isNotEmpty) {
      setState(() => _selectedPackage = _pkgService.packages.first);
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

  double get _finalPrice {
    if (_selectedPackage == null) return 0;
    final base = _selectedPackage!.price;
    return base * (1 - _promoDiscountPercent / 100);
  }

  int get _totalCoins {
    if (_selectedPackage == null) return 0;
    return _selectedPackage!.totalCoins;
  }

  void _applyPromoCode() {
    final code = _promoCode.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _promoDiscountPercent = 0);
      return;
    }
    // Mã promo giả lập
    final promos = {
      'MANGA10': 10,
      'WELCOME': 15,
      'VIP20': 20,
    };
    if (promos.containsKey(code)) {
      setState(() => _promoDiscountPercent = promos[code]!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Áp dụng mã "$code" thành công! Giảm $_promoDiscountPercent%'),
          backgroundColor: const Color(0xFF00B894),
        ),
      );
    } else {
      setState(() => _promoDiscountPercent = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã khuyến mãi không hợp lệ hoặc đã hết hạn.'),
          backgroundColor: Color(0xFFD63031),
        ),
      );
    }
  }

  Future<void> _confirmDeposit() async {
    if (_selectedPackage == null) {
      _showSnack('Vui lòng chọn gói coins muốn nạp.', false);
      return;
    }
    if (_selectedMethod == null) {
      _showSnack('Vui lòng chọn phương thức thanh toán.', false);
      return;
    }
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final res = await _wallet.depositCoins(
      userId: _auth.currentUser.id,
      package: _selectedPackage!,
      paymentMethod: _selectedMethod!.name,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (res.success) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFF00B894),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nạp Coins Thành Công!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                res.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Số dư mới:', style: TextStyle(fontSize: 13)),
                    Text(
                      '${_formatCoins(_wallet.balance)} coins',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Quay về wallet
              },
              child: const Text('Về Ví'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _promoCode = '';
                  _promoDiscountPercent = 0;
                });
              },
              child: const Text('Nạp tiếp', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _showSnack(res.message, false);
    }
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF00B894) : const Color(0xFFD63031),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final packages = _pkgService.packages.where((p) => p.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nạp Coins'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 6),
                Text(
                  'Số dư: ${_formatCoins(_wallet.balance)} coins',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: packages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Hiện chưa có gói nạp nào.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ====== BƯỚC 1: CHỌN GÓI ======
                      _buildStepHeader(1, 'Chọn gói coins'),
                      const SizedBox(height: 10),
                      _buildPackagesGrid(packages),
                      const SizedBox(height: 22),

                      // ====== BƯỚC 2: PHƯƠNG THỨC THANH TOÁN ======
                      _buildStepHeader(2, 'Phương thức thanh toán'),
                      const SizedBox(height: 10),
                      ..._paymentMethods.map((m) => _buildPaymentMethodTile(m, isDark)),
                      const SizedBox(height: 22),

                      // ====== BƯỚC 3: MÃ KHUYẾN MÃI ======
                      _buildStepHeader(3, 'Mã khuyến mãi (tùy chọn)'),
                      const SizedBox(height: 10),
                      _buildPromoField(isDark),
                      const SizedBox(height: 22),

                      // ====== BƯỚC 4: TÓM TẮT & XÁC NHẬN ======
                      if (_selectedPackage != null) _buildSummaryCard(isDark),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _confirmDeposit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                          ),
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_rounded),
                          label: Text(
                            _isProcessing
                                ? 'Đang xử lý...'
                                : _selectedPackage == null
                                    ? 'Chọn gói để tiếp tục'
                                    : 'Thanh toán ${_formatVnd(_finalPrice)}đ',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shield_rounded, color: Color(0xFF00B894), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Giao dịch được bảo mật & mã hóa SSL',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildStepHeader(int step, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF6C5CE7),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPackagesGrid(List<CoinPackage> packages) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.05,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: packages.map((p) {
        final isSelected = _selectedPackage?.id == p.id;
        return InkWell(
          onTap: () => setState(() => _selectedPackage = p),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6C5CE7).withValues(alpha: 0.1)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6C5CE7)
                    : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2E3440)
                        : const Color(0xFFE2E5EE)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (p.isFeatured)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('HOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                      ),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF6C5CE7), size: 18),
                  ],
                ),
                const Spacer(),
                Text(
                  _formatCoins(p.coins),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
                if (p.bonusCoins > 0)
                  Text(
                    '+${_formatCoins(p.bonusCoins)} thưởng',
                    style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 6),
                Text(
                  '${_formatVnd(p.price)}đ',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod m, bool isDark) {
    final isSelected = _selectedMethod?.id == m.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = m),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? m.color.withValues(alpha: 0.08) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? m.color
                  : (isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(m.icon, color: m.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.description,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.feeText,
                      style: TextStyle(fontSize: 10, color: m.color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: m.color, size: 22)
              else
                Icon(Icons.radio_button_unchecked_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoField(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => _promoCode = v,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(20),
            ],
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Nhập mã (VD: MANGA10, WELCOME, VIP20)',
              prefixIcon: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF6C5CE7)),
              filled: true,
              fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFF1F3F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _applyPromoCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final pkg = _selectedPackage!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D29) : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TÓM TẮT ĐƠN HÀNG',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6C5CE7)),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow('Gói nạp', pkg.name),
          _buildSummaryRow('Coins cơ bản', '${_formatCoins(pkg.coins)} coins'),
          if (pkg.bonusCoins > 0)
            _buildSummaryRow('Coins thưởng', '+${_formatCoins(pkg.bonusCoins)} coins', valueColor: Colors.green),
          const Divider(height: 20),
          _buildSummaryRow('Tổng coins nhận', '${_formatCoins(_totalCoins)} coins', isBold: true),
          const SizedBox(height: 6),
          _buildSummaryRow('Giá gốc', '${_formatVnd(pkg.price)}đ'),
          if (_promoDiscountPercent > 0)
            _buildSummaryRow(
              'Giảm giá ($_promoDiscountPercent%)',
              '-${_formatVnd(pkg.price * _promoDiscountPercent / 100)}đ',
              valueColor: Colors.green,
            ),
          const Divider(height: 20),
          _buildSummaryRow('Thành tiền', '${_formatVnd(_finalPrice)}đ', isBold: true, valueColor: const Color(0xFF6C5CE7)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
