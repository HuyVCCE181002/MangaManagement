import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/coin_package.dart';
import '../models/coin_transaction.dart';
import '../models/payment_order.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/coin_package_service.dart';
import '../services/payment_verification_service.dart';
import 'transaction_history_screen.dart';

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

enum _DepositFlowState {
  selectPackage,
  selectPaymentMethod,
  awaitingPayment,
  verifyingPayment,
  paymentSuccess,
  paymentFailed,
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
  final PaymentVerificationService _verification =
      PaymentVerificationService.instance;

  CoinPackage? _selectedPackage;
  PaymentMethod? _selectedMethod;
  String _promoCode = '';
  final _promoController = TextEditingController();
  int _promoDiscountPercent = 0;
  _DepositFlowState _flowState = _DepositFlowState.selectPackage;
  bool _isCheckingStatus = false;
  bool _isCreatingOrder = false;
  PaymentOrder? _serverOrder;
  String? _requestKey;
  String? _paymentError;
  Duration _timeRemaining = const Duration(minutes: 10);
  Timer? _expiryTimer;
  Timer? _verificationTimer;

  CoinTransaction? get _pendingTransaction =>
      _wallet.transactions.where((tx) => tx.id == _serverOrder?.id).firstOrNull;
  String? get _transferCode => _serverOrder?.transferCode;
  String get _draftKey => 'manga_payment_order_${_auth.currentUser.id}';

  int get _currentStep {
    switch (_flowState) {
      case _DepositFlowState.selectPackage:
        return 0;
      case _DepositFlowState.selectPaymentMethod:
        return 1;
      case _DepositFlowState.awaitingPayment:
      case _DepositFlowState.verifyingPayment:
      case _DepositFlowState.paymentSuccess:
      case _DepositFlowState.paymentFailed:
        return 2;
    }
  }

  static const List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'banking',
      name: 'Chuyển khoản ngân hàng',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF0984E3),
      description: 'Quét mã QR VietQR để chuyển khoản',
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
    _promoController.dispose();
    _expiryTimer?.cancel();
    _verificationTimer?.cancel();
    _pkgService.removeListener(_onChange);
    _wallet.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String get _dynamicQrUrl => _serverOrder!.qrUrl;

  void _startTimers() {
    _expiryTimer?.cancel();
    _verificationTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _serverOrder == null) return;
      final remaining = _serverOrder!.expiresAt.difference(DateTime.now());
      setState(
        () => _timeRemaining = remaining.isNegative ? Duration.zero : remaining,
      );
      if (_timeRemaining == Duration.zero) {
        _expiryTimer?.cancel();
        _refreshPaymentStatus(silent: true);
      }
    });
    _verificationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_serverOrder?.status == 'pending') {
        _refreshPaymentStatus(silent: true);
      }
    });
  }

  void _adoptOrder(PaymentOrder order) {
    _serverOrder = order;
    _selectedPackage = order.package;
    _selectedMethod = _paymentMethods.single;
    _promoCode = order.promoCode;
    _promoController.text = order.promoCode;
    _promoDiscountPercent = order.promoCode.isEmpty
        ? 0
        : ((1 - order.amount / order.package.price) * 100).round();
    _timeRemaining = order.expiresAt.difference(DateTime.now());
    if (_timeRemaining.isNegative) _timeRemaining = Duration.zero;
  }

  Future<void> _initData() async {
    await _pkgService.loadAll();
    await _wallet.loadWallet(_auth.currentUser.id);
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_draftKey);
    _requestKey = prefs.getString('${_draftKey}_request');
    try {
      final orders = await _verification.getOrders(_auth.currentUser);
      for (final order in orders.where((o) => o.status == 'completed')) {
        await _wallet.syncServerPayment(_auth.currentUser, order.id);
      }
      final restored =
          orders.where((o) => o.id == saved).firstOrNull ??
          orders.where((o) => o.status == 'pending').firstOrNull;
      if (!mounted) return;
      if (restored != null && restored.status != 'cancelled') {
        setState(() {
          _adoptOrder(restored);
          _flowState = restored.status == 'pending'
              ? _DepositFlowState.verifyingPayment
              : restored.status == 'completed'
              ? _DepositFlowState.paymentSuccess
              : _DepositFlowState.paymentFailed;
        });
        if (restored.status == 'completed') {
          final tx = await _wallet.syncServerPayment(
            _auth.currentUser,
            restored.id,
          );
          await _openSuccessScreen(tx);
        } else if (restored.status == 'pending') {
          _startTimers();
        }
        return;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _paymentError = error.toString());
    }
    if (widget.initialPackageId != null) {
      setState(
        () => _selectedPackage = _pkgService.packages
            .where((p) => p.id == widget.initialPackageId && p.isActive)
            .firstOrNull,
      );
    }
  }

  String _formatCoins(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  String _formatVnd(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  String _formatRemaining(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  double get _finalPrice =>
      _serverOrder?.amount.toDouble() ??
      (_selectedPackage?.price ?? 0) * (1 - _promoDiscountPercent / 100);

  int get _totalCoins => _selectedPackage?.totalCoins ?? 0;

  Future<void> _applyPromoCode() async {
    if (_isCreatingOrder || _flowState == _DepositFlowState.verifyingPayment) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    try {
      if (_serverOrder != null) {
        final cancelled = await _verification.cancelOrder(
          _auth.currentUser,
          _serverOrder!.id,
        );
        if (cancelled.status == 'completed') {
          await _refreshPaymentStatus();
          return;
        }
      }
      _expiryTimer?.cancel();
      _verificationTimer?.cancel();
      await prefs.remove(_draftKey);
      await prefs.remove('${_draftKey}_request');
      if (!mounted) return;
      setState(() {
        _serverOrder = null;
        _requestKey = null;
      });
      await _createServerOrder();
    } catch (error) {
      if (mounted) _showSnack(error.toString(), false);
    }
  }

  void _continueFromPackage() {
    if (_selectedPackage?.isActive != true) return;
    setState(() => _flowState = _DepositFlowState.selectPaymentMethod);
  }

  Future<void> _continueFromMethod() async {
    if (_selectedMethod == null || _isCreatingOrder) return;
    await _createServerOrder();
  }

  Future<void> _createServerOrder() async {
    final package = _selectedPackage;
    if (package == null || _isCreatingOrder) return;
    setState(() {
      _isCreatingOrder = true;
      _paymentError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _requestKey ??= const Uuid().v4();
      await prefs.setString('${_draftKey}_request', _requestKey!);
      final order = await _verification.createOrder(
        user: _auth.currentUser,
        packageId: package.id,
        promoCode: _promoCode.trim().toUpperCase(),
        requestKey: _requestKey!,
      );
      await prefs.setString(_draftKey, order.id);
      await _wallet.syncServerPayment(_auth.currentUser, order.id);
      if (!mounted) return;
      setState(() {
        _adoptOrder(order);
        _flowState = order.status == 'pending'
            ? _DepositFlowState.awaitingPayment
            : order.status == 'completed'
            ? _DepositFlowState.paymentSuccess
            : _DepositFlowState.paymentFailed;
      });
      if (order.status == 'completed') {
        await _openSuccessScreen(_pendingTransaction!);
      } else if (order.status == 'pending') {
        _startTimers();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _paymentError = error.toString());
        _showSnack(error.toString(), false);
      }
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }

  Future<void> _goToPreviousStep() async {
    if (_isCreatingOrder ||
        _isCheckingStatus ||
        _flowState == _DepositFlowState.verifyingPayment) {
      return;
    }
    if (_currentStep == 1) {
      setState(() => _flowState = _DepositFlowState.selectPackage);
      return;
    }
    try {
      if (_serverOrder?.status == 'pending') {
        final cancelled = await _verification.cancelOrder(
          _auth.currentUser,
          _serverOrder!.id,
        );
        if (cancelled.status == 'completed') {
          await _refreshPaymentStatus();
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      await prefs.remove('${_draftKey}_request');
      _expiryTimer?.cancel();
      _verificationTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _serverOrder = null;
        _requestKey = null;
        _flowState = _DepositFlowState.selectPaymentMethod;
      });
    } catch (error) {
      if (mounted) _showSnack(error.toString(), false);
    }
  }

  Future<void> _submitPaymentForVerification() async {
    if (_serverOrder?.status != 'pending' || _isCheckingStatus) return;
    setState(() => _flowState = _DepositFlowState.verifyingPayment);
    await _refreshPaymentStatus();
  }

  Future<void> _retryPayment() async {
    if (_isCreatingOrder) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    await prefs.remove('${_draftKey}_request');
    if (!mounted) return;
    setState(() {
      _serverOrder = null;
      _requestKey = null;
      _flowState = _DepositFlowState.awaitingPayment;
    });
    await _createServerOrder();
  }

  Future<void> _refreshPaymentStatus({bool silent = false}) async {
    final order = _serverOrder;
    if (order == null || _isCheckingStatus || _isCreatingOrder) return;
    setState(() => _isCheckingStatus = true);
    try {
      final refreshed = await _verification.getOrder(
        _auth.currentUser,
        order.id,
      );
      final tx = await _wallet.syncServerPayment(_auth.currentUser, order.id);
      if (!mounted) return;
      setState(() {
        _adoptOrder(refreshed);
        _paymentError = null;
        if (tx.status == TransactionStatus.completed) {
          _flowState = _DepositFlowState.paymentSuccess;
        } else if (refreshed.status != 'pending') {
          _flowState = _DepositFlowState.paymentFailed;
        }
      });
      if (tx.status == TransactionStatus.completed) {
        _expiryTimer?.cancel();
        _verificationTimer?.cancel();
        await _openSuccessScreen(tx);
      } else if (refreshed.status != 'pending') {
        _expiryTimer?.cancel();
        _verificationTimer?.cancel();
        if (!silent) {
          _showSnack(
            'Giao dịch đã hết hạn. Không chuyển thêm tiền bằng QR cũ.',
            false,
          );
        }
      } else if (!silent) {
        _showSnack('Chưa nhận được xác nhận chuyển khoản từ ngân hàng.', false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _paymentError = error.toString());
        if (!silent) _showSnack(error.toString(), false);
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _openSuccessScreen(CoinTransaction transaction) async {
    final order = _serverOrder;
    if (!mounted ||
        order == null ||
        transaction.status != TransactionStatus.completed) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    await prefs.remove('${_draftKey}_request');
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(
          transaction: transaction,
          package: order.package,
          paidAmount: order.amount.toDouble(),
        ),
      ),
    );
  }

  Widget _buildPaymentInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(bool isDark) {
    final method = _selectedMethod!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D29) : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: method.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(method.icon, color: method.color),
              const SizedBox(width: 8),
              Text(
                method.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPaymentInfoRow('Số tiền', '${_formatVnd(_finalPrice)} đ'),
          Text(
            'Mã QR đã chứa thông tin tài khoản nhận tiền và số tiền giao dịch.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _dynamicQrUrl,
                width: 220,
                height: 286,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        width: 220,
                        height: 286,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 220,
                  height: 286,
                  alignment: Alignment.center,
                  color: Colors.grey.shade100,
                  child: const Text(
                    'Không tải được mã QR. Kiểm tra mạng và tải lại; không sử dụng QR cũ.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Quét QR bằng ứng dụng ngân hàng hoặc Sacombank',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Nội dung chuyển khoản: $_transferCode',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingStatus() {
    final tx = _pendingTransaction!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Đang xác minh thanh toán...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Chip(
                label: Text(tx.status.label),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.orange.withValues(alpha: 0.16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mã giao dịch: ${tx.id}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'Thời hạn giao dịch còn lại: ${_formatRemaining(_timeRemaining)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'Hệ thống chỉ cộng coin sau khi nhận được xác nhận từ cổng thanh toán.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isCheckingStatus ? null : _refreshPaymentStatus,
            icon: _isCheckingStatus
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              _isCheckingStatus ? 'Đang cập nhật...' : 'Cập nhật trạng thái',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Thanh toán thất bại hoặc chưa được xác nhận. Bạn có thể thử gửi lại yêu cầu xác minh sau khi kiểm tra thông tin chuyển khoản.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardActions({
    required String primaryLabel,
    required VoidCallback? onPrimary,
    bool showBack = true,
  }) {
    final primary = Expanded(
      child: ElevatedButton(
        onPressed: onPrimary,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          primaryLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
    if (!showBack) return Row(children: [primary]);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed:
                _isCheckingStatus ||
                    _isCreatingOrder ||
                    _flowState == _DepositFlowState.verifyingPayment
                ? null
                : _goToPreviousStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6C5CE7),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Quay lại'),
          ),
        ),
        const SizedBox(width: 10),
        primary,
      ],
    );
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
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 16,
                  color: Color(0xFF6C5CE7),
                ),
                const SizedBox(width: 6),
                Text(
                  'Số dư: ${_formatCoins(_wallet.balance)} coins',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C5CE7),
                  ),
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
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                      _buildStepProgress(),
                      const SizedBox(height: 24),
                      if (_currentStep == 0)
                        _buildPackageStep(packages)
                      else if (_currentStep == 1)
                        _buildMethodStep(isDark)
                      else
                        _buildConfirmationStep(isDark),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFF00B894),
                            size: 14,
                          ),
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

  Widget _buildStepProgress() {
    const labels = ['Chọn gói', 'Thanh toán', 'Xác nhận'];
    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          final completed = index ~/ 2 < _currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: completed
                  ? const Color(0xFF6C5CE7)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          );
        }

        final step = index ~/ 2;
        final isCurrent = step == _currentStep;
        final isCompleted = step < _currentStep;
        final color = isCurrent || isCompleted
            ? const Color(0xFF6C5CE7)
            : Colors.grey.shade500;
        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF6C5CE7) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF6C5CE7),
                        size: 19,
                      )
                    : Text(
                        '${step + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              labels[step],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPackageStep(List<CoinPackage> packages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWizardTitle(
          'Bước 1',
          'Chọn gói Coins',
          Icons.monetization_on_rounded,
        ),
        const SizedBox(height: 12),
        _buildPackagesGrid(packages),
        if (_selectedPackage != null) ...[
          const SizedBox(height: 14),
          _buildSelectedPackageDetails(),
        ],
        const SizedBox(height: 20),
        _buildWizardActions(
          primaryLabel: 'Tiếp tục',
          showBack: false,
          onPrimary: _selectedPackage?.isActive == true
              ? _continueFromPackage
              : null,
        ),
      ],
    );
  }

  Widget _buildMethodStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWizardTitle(
          'Bước 2',
          'Chọn phương thức thanh toán',
          Icons.payment_rounded,
        ),
        const SizedBox(height: 12),
        ..._paymentMethods.map(
          (method) => _buildPaymentMethodTile(method, isDark),
        ),
        const SizedBox(height: 14),
        _buildWizardActions(
          primaryLabel: _isCreatingOrder ? 'Đang tạo đơn...' : 'Tiếp tục',
          onPrimary: _selectedMethod == null || _isCreatingOrder
              ? null
              : _continueFromMethod,
        ),
      ],
    );
  }

  Widget _buildConfirmationStep(bool isDark) {
    final hasPending =
        _flowState == _DepositFlowState.verifyingPayment &&
        _serverOrder != null;
    final isFailed =
        _flowState == _DepositFlowState.paymentFailed ||
        _pendingTransaction?.status == TransactionStatus.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWizardTitle(
          'Bước 3',
          'Xác nhận và thanh toán',
          Icons.receipt_long_rounded,
        ),
        const SizedBox(height: 12),
        _buildPromoField(isDark),
        const SizedBox(height: 14),
        _buildSummaryCard(isDark),
        const SizedBox(height: 14),
        if (_serverOrder?.status == 'pending') _buildPaymentDetails(isDark),
        if (_serverOrder?.status == 'pending') ...[
          const SizedBox(height: 8),
          Text(
            'Giao dịch hết hạn sau: ${_formatRemaining(_timeRemaining)}',
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_paymentError != null) ...[
          const SizedBox(height: 8),
          Text(_paymentError!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 14),
        if (hasPending && !isFailed)
          _buildPendingStatus()
        else if (isFailed)
          _buildFailedStatus()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Sau khi chuyển khoản, gửi yêu cầu xác minh. Coin chỉ được cộng khi hệ thống nhận được xác nhận thanh toán.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        if (hasPending && !isFailed)
          _buildWizardActions(
            primaryLabel: _isCheckingStatus
                ? 'Đang cập nhật...'
                : 'Cập nhật trạng thái',
            onPrimary: _isCheckingStatus ? null : _refreshPaymentStatus,
          )
        else
          _buildWizardActions(
            primaryLabel: _isCreatingOrder
                ? 'Đang tạo đơn...'
                : isFailed || _serverOrder == null
                ? 'Tạo giao dịch mới'
                : 'Tôi đã chuyển khoản',
            onPrimary: _isCreatingOrder
                ? null
                : isFailed || _serverOrder == null
                ? _retryPayment
                : _submitPaymentForVerification,
          ),
      ],
    );
  }

  Widget _buildWizardTitle(String step, String title, IconData icon) {
    return Row(
      children: [
        const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Color(0xFF6C5CE7),
        ),
        const SizedBox(width: 6),
        Icon(icon, color: const Color(0xFF6C5CE7), size: 22),
        const SizedBox(width: 8),
        Text(
          step,
          style: const TextStyle(
            color: Color(0xFF6C5CE7),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPackageDetails() {
    final package = _selectedPackage!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            package.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Coins cơ bản',
            '${_formatCoins(package.coins)} coins',
          ),
          if (package.bonusCoins > 0)
            _buildSummaryRow(
              'Coins thưởng',
              '+${_formatCoins(package.bonusCoins)} coins',
              valueColor: Colors.green,
            ),
          _buildSummaryRow(
            'Tổng nhận',
            '${_formatCoins(package.totalCoins)} coins',
            isBold: true,
          ),
          _buildSummaryRow(
            'Giá tiền',
            '${_formatVnd(package.price)}đ',
            isBold: true,
            valueColor: const Color(0xFF6C5CE7),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesGrid(List<CoinPackage> packages) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: constraints.maxWidth >= 620 ? 3 : 2,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'HOT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF6C5CE7),
                          size: 18,
                        ),
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
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatVnd(p.price)}đ',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
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
            color: isSelected
                ? m.color.withValues(alpha: 0.08)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? m.color
                  : (isDark
                        ? const Color(0xFF2E3440)
                        : const Color(0xFFE2E5EE)),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.feeText,
                      style: TextStyle(
                        fontSize: 10,
                        color: m.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: m.color, size: 22)
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
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
            controller: _promoController,
            enabled:
                !_isCreatingOrder &&
                _flowState != _DepositFlowState.verifyingPayment,
            onChanged: (v) => _promoCode = v,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(20),
            ],
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Nhập mã (VD: MANGA10, WELCOME, VIP20)',
              prefixIcon: const Icon(
                Icons.confirmation_number_rounded,
                color: Color(0xFF6C5CE7),
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF161924)
                  : const Color(0xFFF1F3F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed:
              _isCreatingOrder ||
                  _flowState == _DepositFlowState.verifyingPayment
              ? null
              : _applyPromoCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Áp dụng',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow('Gói nạp', pkg.name),
          if (_selectedMethod != null)
            _buildSummaryRow('Phương thức', _selectedMethod!.name),
          _buildSummaryRow('Coins cơ bản', '${_formatCoins(pkg.coins)} coins'),
          if (pkg.bonusCoins > 0)
            _buildSummaryRow(
              'Coins thưởng',
              '+${_formatCoins(pkg.bonusCoins)} coins',
              valueColor: Colors.green,
            ),
          const Divider(height: 20),
          _buildSummaryRow(
            'Tổng coins nhận',
            '${_formatCoins(_totalCoins)} coins',
            isBold: true,
          ),
          const SizedBox(height: 6),
          _buildSummaryRow('Giá gốc', '${_formatVnd(pkg.price)}đ'),
          if (_promoDiscountPercent > 0)
            _buildSummaryRow('Mã khuyến mãi', _promoCode),
          if (_promoDiscountPercent > 0)
            _buildSummaryRow(
              'Giảm giá ($_promoDiscountPercent%)',
              '-${_formatVnd(pkg.price * _promoDiscountPercent / 100)}đ',
              valueColor: Colors.green,
            ),
          const Divider(height: 20),
          _buildSummaryRow(
            'Thành tiền',
            '${_formatVnd(_finalPrice)}đ',
            isBold: true,
            valueColor: const Color(0xFF6C5CE7),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
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

class PaymentSuccessScreen extends StatelessWidget {
  final CoinTransaction transaction;
  final CoinPackage package;
  final double paidAmount;

  const PaymentSuccessScreen({
    super.key,
    required this.transaction,
    required this.package,
    required this.paidAmount,
  });

  String _formatCoins(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _formatVnd(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  String _formatTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả thanh toán')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _buildCompletedProgress(),
                const SizedBox(height: 20),
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00B894),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Thanh toán thành công!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Giao dịch nạp Coins của bạn đã được xác nhận.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _buildResultRow('Mã giao dịch', transaction.id),
                        _buildResultRow(
                          'Số tiền đã thanh toán',
                          '${_formatVnd(paidAmount)} đ',
                        ),
                        _buildResultRow(
                          'Coins cơ bản',
                          '${_formatCoins(package.coins)} coins',
                        ),
                        _buildResultRow(
                          'Coins thưởng',
                          '+${_formatCoins(package.bonusCoins)} coins',
                        ),
                        _buildResultRow(
                          'Tổng Coins nhận',
                          '${_formatCoins(package.totalCoins)} coins',
                        ),
                        _buildResultRow(
                          'Thời gian',
                          _formatTime(transaction.createdAt),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Về trang chủ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TransactionHistoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Xem lịch sử giao dịch'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C5CE7),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedProgress() {
    const labels = ['Chọn gói', 'Thanh toán', 'Hoàn tất'];
    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          return Expanded(
            child: Container(height: 2, color: const Color(0xFF6C5CE7)),
          );
        }
        final step = index ~/ 2;
        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF6C5CE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              labels[step],
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6C5CE7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
