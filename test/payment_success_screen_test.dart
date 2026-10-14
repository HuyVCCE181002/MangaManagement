import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/models/coin_package.dart';
import 'package:manga_management_app/models/coin_transaction.dart';
import 'package:manga_management_app/screens/deposit_screen.dart';

void main() {
  for (final size in [const Size(375, 812), const Size(1280, 900)]) {
    testWidgets('Verified receipt result fits ${size.width} width in dark theme', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final time = DateTime(2026, 10, 14, 3, 30);
      final package = CoinPackage(id: 'pkg_4', name: 'Gold Pack', coins: 2000,
        bonusCoins: 400, price: 160000, createdAt: time);
      final receipt = CoinTransaction(id: 'e4a31a72-a58a-47a6-b0b8-331f4523f963',
        userId: 'reader_1', walletId: 'wallet_reader_1', type: TransactionType.deposit,
        amount: 2400, coinsBefore: 0, coinsAfter: 2400, description: 'Verified',
        status: TransactionStatus.completed, createdAt: time);
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(),
        home: PaymentSuccessScreen(transaction: receipt, package: package, paidAmount: 160000)));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán thành công!'), findsOneWidget);
      expect(find.text('2,400 coins'), findsOneWidget);
      expect(find.text('Về trang chủ'), findsOneWidget);
      expect(find.text('Xem lịch sử giao dịch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
