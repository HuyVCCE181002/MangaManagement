import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/screens/admin_dashboard_screen.dart';
import 'package:manga_management_app/screens/transaction_history_screen.dart';
import 'package:manga_management_app/screens/wallet_screen.dart';
import 'package:manga_management_app/services/auth_service.dart';
import 'package:manga_management_app/services/wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    WalletService.instance.clearCache();
    await AuthService.instance.logout();
  });

  testWidgets('UC-44 Reader View Wallet & Coins: guest bi chan khoi vi coins', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await tester.pump();
    expect(find.text('Bạn cần đăng nhập để sử dụng Ví Coins'), findsOneWidget);
    expect(find.text('Đăng nhập ngay'), findsOneWidget);
  });

  testWidgets('UC-47 Reader View Transaction History: empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TransactionHistoryScreen()),
    );
    await tester.pump();
    expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
  });

  testWidgets('UC-43 Admin View Statistics Dashboard: tu choi non-admin', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
    await tester.pump();
    expect(
      find.text('Chỉ quản trị viên mới xem được dashboard.'),
      findsOneWidget,
    );
  });
}
