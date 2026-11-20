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
import 'proposals/client_candidates_screen.dart';
import 'proposals/my_proposals_screen.dart';
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

      final List<Widget> screens = isClient
          ? const [
              ExplorarScreen(),
              ClientCandidatesScreen(),
              ContractsScreen(),
              ConversationsScreen(),
              ProfileScreen(),
            ]
          : const [
              ExplorarScreen(),
              MyProposalsScreen(),
              ContractsScreen(),
              ConversationsScreen(),
              ProfileScreen(),
            ];

      final List<BottomNavigationBarItem> navItems = isClient
          ? const [
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Proyectos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Candidatos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.work_outline),
                activeIcon: Icon(Icons.work),
                label: 'Mis Contratos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ]
          : const [
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Explorar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.work_outline),
                activeIcon: Icon(Icons.work),
                label: 'Postulaciones',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_outlined),
                activeIcon: Icon(Icons.assignment),
                label: 'Contratos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ];

      final safeIndex = _currentIndex < screens.length ? _currentIndex : 0;

      return Scaffold(
        body: IndexedStack(
          index: safeIndex,
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: navItems,
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
