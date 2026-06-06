import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthBloc() : super(AuthInitial()) {
    on<AppStarted>((event, emit) async {
      emit(AuthLoading());
      final session = _supabase.auth.currentSession;
      if (session != null) {
        emit(AuthAuthenticated());
      } else {
        emit(AuthUnauthenticated());
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await _supabase.auth.signInWithPassword(
          email: event.email,
          password: event.password,
        );
        emit(AuthAuthenticated());
      } on AuthException catch (e) {
        emit(AuthError(e.message));
      } catch (e) {
        emit(AuthError('An unexpected error occurred.'));
      }
    });

    on<LogoutRequested>((event, emit) async {
      emit(AuthLoading());
      await _supabase.auth.signOut();
      emit(AuthUnauthenticated());
    });
  }
}
