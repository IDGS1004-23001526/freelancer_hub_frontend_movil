import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/auth_screen.dart'; // <-- Actualizado

void main() {
  runApp(
    const ProviderScope(
      child: FreelanceHubApp(),
    ),
  );
}

class FreelanceHubApp extends StatelessWidget {
  const FreelanceHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freelance Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthScreen(), // <-- Instancia la nueva pantalla combinada
    );
  }
}