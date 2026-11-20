import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:freelance_hub_movil/bloc/auth/auth_bloc.dart';
import 'package:freelance_hub_movil/bloc/auth/auth_event.dart';
import 'package:freelance_hub_movil/bloc/auth/auth_state.dart';
import 'package:freelance_hub_movil/config/api_constants.dart';
import 'package:freelance_hub_movil/models/user_profile.dart';
import 'package:freelance_hub_movil/screens/auth/login_screen.dart';
import 'package:freelance_hub_movil/screens/auth/register_screen.dart';
import 'package:freelance_hub_movil/services/auth_service.dart';
import 'package:freelance_hub_movil/widgets/google_sign_in_button.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GoogleSignInButton Widget', () {
    testWidgets('Renderiza icono de Google y texto personalizado correctamente',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              text: 'Continuar con Google',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.byType(GoogleLogoIcon), findsOneWidget);

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('Muestra indicador de progreso cuando isLoading es true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              text: 'Registrarse con Google',
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Registrarse con Google'), findsNothing);
    });
  });

  group('AuthService - Autenticación con Google (/auth/google)', () {
    test('googleAuthWithResult autentica correctamente y persiste sesión',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/google'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['idToken'], 'test_google_id_token_123');
        expect(body['role'], 'FREELANCER');

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Autenticación con Google exitosa.',
            'data': {
              'accessToken': 'jwt_google_access_token_abc',
              'refreshToken': 'jwt_google_refresh_token_xyz',
              'user': {
                'id': 'user-google-001',
                'fullName': 'Carlos Google Developer',
                'email': 'carlos.dev@gmail.com',
                'role': 'FREELANCER',
                'avatarUrl': 'https://lh3.googleusercontent.com/photo.jpg',
                'location': 'Guadalajara, México',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      FlutterSecureStorage.setMockInitialValues({});
      final authService = AuthService(
        httpClient: mockClient,
        storage: const FlutterSecureStorage(),
      );

      final result = await authService.googleAuthWithResult(
        role: 'FREELANCER',
        explicitIdToken: 'test_google_id_token_123',
      );

      expect(result.success, isTrue);
      expect(result.token, 'jwt_google_access_token_abc');
      expect(result.user?.fullName, 'Carlos Google Developer');
      expect(result.user?.email, 'carlos.dev@gmail.com');

      // Validar persistencia en storage
      final storedToken = await authService.getToken();
      final storedProfile = await authService.getCachedUserProfile();
      expect(storedToken, 'jwt_google_access_token_abc');
      expect(storedProfile?.fullName, 'Carlos Google Developer');
    });

    test('googleAuthWithResult maneja errores del backend adecuadamente',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'El token de Google proporcionado no es válido o ha expirado.',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      FlutterSecureStorage.setMockInitialValues({});
      final authService = AuthService(
        httpClient: mockClient,
        storage: const FlutterSecureStorage(),
      );

      final result = await authService.googleAuthWithResult(
        explicitIdToken: 'invalid_token',
      );

      expect(result.success, isFalse);
      expect(result.message,
          'El token de Google proporcionado no es válido o ha expirado.');
    });
  });

  group('AuthBloc - Flujo AuthGoogleSubmitted', () {
    test('AuthGoogleSubmitted pasa por loading y llega a authenticated',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'accessToken': 'token_bloc_test',
              'refreshToken': 'refresh_bloc_test',
              'user': {
                'id': 'google-bloc-user-99',
                'fullName': 'Ana Bloc Tester',
                'email': 'ana.tester@gmail.com',
                'role': 'CLIENT',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      FlutterSecureStorage.setMockInitialValues({});
      final authService = AuthService(httpClient: mockClient);
      final bloc = AuthBloc(authService: authService);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(const AuthGoogleSubmitted(
        role: 'CLIENT',
        explicitIdToken: 'token_valido_google',
      ));

      await Future.delayed(const Duration(milliseconds: 150));

      expect(states.any((s) => s.status == AuthStatus.loading), isTrue);
      expect(states.last.status, AuthStatus.authenticated);
      expect(states.last.user?.fullName, 'Ana Bloc Tester');

      await subscription.cancel();
      await bloc.close();
    });
  });

  group('LoginScreen y RegisterScreen - Botones de Google', () {
    testWidgets('LoginScreen muestra botón de continuar con Google',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => AuthBloc(),
            child: const LoginScreen(),
          ),
        ),
      );

      expect(find.byKey(const Key('login_google_button')), findsOneWidget);
      expect(find.text('Continuar con Google'), findsOneWidget);
    });

    testWidgets('RegisterScreen en Paso 0 muestra botón de registrarse con Google',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => AuthBloc(),
            child: const RegisterScreen(),
          ),
        ),
      );

      expect(find.byKey(const Key('register_google_button')), findsOneWidget);
      expect(find.text('Registrarse con Google'), findsOneWidget);
    });
  });
}
