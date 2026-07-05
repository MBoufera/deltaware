import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseClient _supabase;

  AuthBloc({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  AuthState _resolveAuthState() {
    final user = _supabase.auth.currentUser;
    if (user == null) return AuthUnauthenticated();
    final metadata = user.userMetadata ?? {};
    final isSuperAdmin = metadata['is_super_admin'] == true;
    return isSuperAdmin ? AuthSuperAdmin() : AuthAuthenticated();
  }

  // ─── Handlers ────────────────────────────────────────────────────────────

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final session = _supabase.auth.currentSession;
    if (session != null) {
      emit(_resolveAuthState());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _supabase.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      emit(_resolveAuthState());
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('An unexpected error occurred.'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _supabase.auth.signOut();
    emit(AuthUnauthenticated());
  }
}
