import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';

// Provide AuthService instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Stream of Firebase User auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Provide current Firebase user
final firebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authServiceProvider).currentUser;
});

// Fetch Firestore UserModel details for active authenticated user
final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final firebaseUser = ref.watch(authStateProvider).value;
  if (firebaseUser == null) {
    return Stream.value(null);
  }
  return DatabaseService().getUserStream(firebaseUser.uid);
});

// State class for Auth UI operations (Login/Signup loading or error handling)
class AuthState {
  final bool isLoading;
  final String? errorMessage;

  AuthState({this.isLoading = false, this.errorMessage});

  AuthState copyWith({bool? isLoading, String? errorMessage}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Controller to manage login/signup flows using modern Riverpod Notifier
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState();
  }

  AuthService get _authService => ref.read(authServiceProvider);

  Future<bool> login(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      await _authService.signInWithEmail(email, password);
      state = AuthState(isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    String? photoUrl,
  }) async {
    state = AuthState(isLoading: true);
    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      state = AuthState(isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = AuthState(isLoading: true);
    try {
      final credential = await _authService.signInWithGoogle();
      state = AuthState(isLoading: false);
      return credential != null;
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState(isLoading: true);
    try {
      await _authService.signOut();
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// Provide AuthController
final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
