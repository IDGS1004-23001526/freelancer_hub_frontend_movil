import 'package:equatable/equatable.dart';
import '../../models/user_profile.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final String selectedRole;
  final UserProfile? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.selectedRole = 'CLIENT',
    this.user,
    this.errorMessage,
  });

  bool get isLoading => status == AuthStatus.loading;
  bool get isClientSelected => selectedRole.toUpperCase() == 'CLIENT';
  bool get isFreelancerSelected => selectedRole.toUpperCase() == 'FREELANCER';

  AuthState copyWith({
    AuthStatus? status,
    String? selectedRole,
    UserProfile? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      selectedRole: selectedRole ?? this.selectedRole,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, selectedRole, user, errorMessage];
}
