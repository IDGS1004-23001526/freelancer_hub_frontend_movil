import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/auth/auth_event.dart';
import 'bloc/auth/auth_state.dart';
import 'firebase_options.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/firebase_notification_service.dart';
import 'services/notification_socket_service.dart';
import 'theme/app_colors.dart';
import 'widgets/message_notification_overlay.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Hive para caché offline (HU-Offline / Rúbrica)
  await Hive.initFlutter();
  await Hive.openBox('convocatoriasBox');
  await Hive.openBox('offlineActionsBox');
  await Hive.openBox('notificationsBox');

  // Inicializar motor local y socket de notificaciones
  await NotificationSocketService.instance.initializeLocalNotifications();

  // Inicializar Firebase Messaging para notificaciones push oficiales
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseNotificationService.instance
        .initializeFirebaseMessaging(navKey: appNavigatorKey);
  } catch (e) {
    debugPrint('Aviso: Inicialización de Firebase omitida/error: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => AuthBloc()..add(const AuthSessionChecked()),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            NotificationSocketService.instance.connectIfAuthenticated();
            FirebaseNotificationService.instance.syncFcmTokenWithBackend();
          } else if (state.status == AuthStatus.unauthenticated) {
            NotificationSocketService.instance.disconnect();
          }
        },
        child: MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Freelancer Hub',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background,
          ),
          builder: (context, child) {
            return MessageNotificationOverlay(
              navigatorKey: appNavigatorKey,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Compuerta de autenticación inicial:
/// - Si hay token y sesión activa -> navega directo a [MainNavigationScreen]
/// - Si no hay sesión -> muestra [OnboardingScreen]
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          return const MainNavigationScreen();
        }
        return const OnboardingScreen();
      },
    );
  }
}
