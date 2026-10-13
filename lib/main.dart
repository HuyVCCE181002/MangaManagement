import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/database_helper.dart';
import 'services/theme_service.dart';
import 'services/wallet_service.dart';
import 'services/daily_check_in_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo Database SQLite trước
  await DatabaseHelper.instance.database;

  // Khởi tạo AuthService và ThemeService
  await Future.wait([
    AuthService.instance.init(),
    ThemeService.instance.init(),
  ]);

  // Nếu đã đăng nhập, load ví và dữ liệu điểm danh ngay
  if (AuthService.instance.isLoggedIn) {
    await Future.wait([
      WalletService.instance.loadWallet(AuthService.instance.currentUser.id),
      DailyCheckInService.instance.loadForUser(AuthService.instance.currentUser.id),
    ]);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final theme = ThemeService.instance;

    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return MaterialApp(
          title: 'Manga Vault',
          debugShowCheckedModeBanner: false,
          themeMode: theme.themeMode,
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          // Nếu đã có tài khoản đăng nhập từ trước -> vào thẳng HomeScreen
          // Nếu chưa đăng nhập -> mở LoginScreen (có hỗ trợ duyệt Khách / Guest)
          home: auth.isLoggedIn ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}
