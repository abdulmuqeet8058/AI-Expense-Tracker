import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import 'api_provider.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final bool busy;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final AuthStorage _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    loadSession();
  }

  // Called from the splash screen on launch: if we have a token, validate it
  // by loading the profile. Sets status to authenticated / unauthenticated.
  Future<void> loadSession() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _api.getMe();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      await _storage.clear();
      state = state.copyWith(
          status: AuthStatus.unauthenticated, clearUser: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await _api.login(email: email, password: password);
      await _storage.saveToken(res.accessToken, refresh: res.refreshToken);
      state = state.copyWith(
          status: AuthStatus.authenticated, user: res.user, busy: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String currency = 'PKR',
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await _api.register(
        email: email,
        password: password,
        fullName: fullName,
        currency: currency,
      );
      await _storage.saveToken(res.accessToken, refresh: res.refreshToken);
      state = state.copyWith(
          status: AuthStatus.authenticated, user: res.user, busy: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _storage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiClientProvider),
    ref.watch(authStorageProvider),
  );
});
