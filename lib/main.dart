import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF12141D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181A24),
          elevation: 0,
          centerTitle: false,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          surface: Color(0xFF1E212D),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
