import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'login.dart';

void main() {
  runApp(const SmartHomeGuardianApp());
}

class SmartHomeGuardianApp extends StatelessWidget {
  const SmartHomeGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home Guardian',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFe6d4cb),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFFe6d4cb),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
