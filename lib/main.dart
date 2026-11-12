import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/auth/auth_state.dart';
import 'screens/auth/onboarding_screen.dart';
import 'services/notification_socket_service.dart';
import 'widgets/message_notification_overlay.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationSocketService.instance.initializeLocalNotifications();
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
      create: (_) => AuthBloc(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            NotificationSocketService.instance.connectIfAuthenticated();
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
          ),
          builder: (context, child) {
            return MessageNotificationOverlay(
              navigatorKey: appNavigatorKey,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const OnboardingScreen(),
        ),
      ),
    );
  }
}
