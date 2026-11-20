import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'chat/conversations_screen.dart';
import 'contracts/contracts_screen.dart';
import 'convocatorias/explorar_screen.dart';
import 'profile/profile_screen.dart';
import 'wallet/wallet_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  String _resolvedRole = 'FREELANCER';

  final List<Widget> _screens = const [
    ExplorarScreen(),
    ContractsScreen(),
    WalletScreen(),
    ConversationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadEffectiveRole();
  }

  Future<void> _loadEffectiveRole() async {
    final blocRole = context.read<AuthBloc?>()?.state.user?.role;
    if (blocRole != null && blocRole.isNotEmpty) {
      setState(() => _resolvedRole = AuthService.normalizeRole(blocRole));
      return;
    }
    final savedRole = await AuthService().getSavedRole();
    if (savedRole != null && mounted) {
      setState(() => _resolvedRole = savedRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc?>();

    Widget buildScaffold(String role) {
      final isClient = AuthService.normalizeRole(role) == 'CLIENT';

      return Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.explore_outlined),
              activeIcon: const Icon(Icons.explore),
              label: isClient ? 'Proyectos' : 'Explorar',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.work_outline),
              activeIcon: const Icon(Icons.work),
              label: isClient ? 'Mis Contratos' : 'Contratos',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet),
              label: isClient ? 'Escrow' : 'Billetera',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      );
    }

    if (authBloc != null) {
      return BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final role = state.user?.role ?? _resolvedRole;
          return buildScaffold(role);
        },
      );
    }

    return buildScaffold(_resolvedRole);
  }
}