import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/convocatoria_service.dart';
import 'services/offline_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Hive
  await Hive.initFlutter();

  // Abrir cajas para caché y cola de acciones
  await Hive.openBox('convocatoriasBox');
  await Hive.openBox('offlineActionsBox');

  // Inicializar servicios de conectividad y cola offline
  ConnectivityService().initialize();
  OfflineQueueService().initialize();
  await ConvocatoriaService().initCacheIfNeeded();

  // Si el usuario ya había iniciado sesión previamente, se mantiene y accede directo
  // incluso sin conexión a internet
  final token = await AuthService().getToken();
  final bool hasActiveSession = token != null && token.isNotEmpty;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(MyApp(hasActiveSession: hasActiveSession));
}

class MyApp extends StatelessWidget {
  final bool hasActiveSession;
  const MyApp({super.key, this.hasActiveSession = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freelance Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: hasActiveSession
          ? const MainNavigationScreen()
          : const OnboardingScreen(),
    );
  }
}
