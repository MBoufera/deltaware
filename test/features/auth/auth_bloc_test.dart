import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:deltaware/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:deltaware/features/auth/presentation/bloc/auth_event.dart';
import 'package:deltaware/features/auth/presentation/bloc/auth_state.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockSession extends Mock implements Session {}
class MockAuthResponse extends Mock implements AuthResponse {}
class MockUser extends Mock implements User {}

void main() {
  group('AuthBloc', () {
    late AuthBloc authBloc;
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockGoTrueClient;
    late MockUser mockUser;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockGoTrueClient = MockGoTrueClient();
      mockUser = MockUser();
      when(() => mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
      
      authBloc = AuthBloc(supabase: mockSupabaseClient);
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when AppStarted is added and session exists as regular worker',
      build: () {
        when(() => mockGoTrueClient.currentSession).thenReturn(MockSession());
        when(() => mockGoTrueClient.currentUser).thenReturn(mockUser);
        when(() => mockUser.userMetadata).thenReturn({'is_super_admin': false});
        return authBloc;
      },
      act: (bloc) => bloc.add(AppStarted()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthSuperAdmin] when AppStarted is added and session exists as super admin',
      build: () {
        when(() => mockGoTrueClient.currentSession).thenReturn(MockSession());
        when(() => mockGoTrueClient.currentUser).thenReturn(mockUser);
        when(() => mockUser.userMetadata).thenReturn({'is_super_admin': true});
        return authBloc;
      },
      act: (bloc) => bloc.add(AppStarted()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthSuperAdmin>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when AppStarted is added and session is null',
      build: () {
        when(() => mockGoTrueClient.currentSession).thenReturn(null);
        return authBloc;
      },
      act: (bloc) => bloc.add(AppStarted()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthUnauthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when LoginRequested is successful',
      build: () {
        when(() => mockGoTrueClient.signInWithPassword(
              email: 'test@test.com',
              password: 'password123',
            )).thenAnswer((_) async => MockAuthResponse());
        when(() => mockGoTrueClient.currentUser).thenReturn(mockUser);
        when(() => mockUser.userMetadata).thenReturn({'is_super_admin': false});
        return authBloc;
      },
      act: (bloc) => bloc.add(LoginRequested('test@test.com', 'password123')),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when LoginRequested fails with AuthException',
      build: () {
        when(() => mockGoTrueClient.signInWithPassword(
              email: 'test@test.com',
              password: 'wrongpassword',
            )).thenThrow(const AuthException('Invalid login credentials'));
        return authBloc;
      },
      act: (bloc) => bloc.add(LoginRequested('test@test.com', 'wrongpassword')),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
    );
  });
}
