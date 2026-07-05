import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/features/auth/presentation/bloc/permissions_bloc.dart';
import 'package:deltaware/features/auth/presentation/bloc/permissions_event.dart';
import 'package:deltaware/features/auth/presentation/bloc/permissions_state.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

class FakePostgrestFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;

  FakePostgrestFilterBuilder(this._value);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) {
    final result = onValue(_value);
    if (result is Future<R>) {
      return result;
    }
    return Future.value(result);
  }
}

void main() {
  group('PermissionsBloc', () {
    late PermissionsBloc permissionsBloc;
    late MockSupabaseClient mockSupabaseClient;
    late MockSupabaseQueryBuilder mockQueryBuilder;
    late MockGoTrueClient mockGoTrueClient;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockQueryBuilder = MockSupabaseQueryBuilder();
      mockGoTrueClient = MockGoTrueClient();

      when(() => mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
      when(() => mockGoTrueClient.currentUser).thenReturn(null);
      when(() => mockSupabaseClient.from('user_roles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('roles(name)')).thenAnswer(
        (_) => FakePostgrestFilterBuilder<List<Map<String, dynamic>>>([]),
      );
    });

    tearDown(() {
      permissionsBloc.close();
    });

    test('initial state is correct', () {
      permissionsBloc = PermissionsBloc(supabase: mockSupabaseClient);
      expect(permissionsBloc.state.isLoading, isTrue);
      expect(permissionsBloc.state.isAdmin, isFalse);
      expect(permissionsBloc.state.permissions, isEmpty);
    });

    blocTest<PermissionsBloc, PermissionsState>(
      'emits isAdmin=true when metadata role is admin (bypasses DB check)',
      build: () {
        permissionsBloc = PermissionsBloc(supabase: mockSupabaseClient);
        return permissionsBloc;
      },
      act: (bloc) => bloc.add(LoadPermissions('user-123', 'admin')),
      expect: () => [
        isA<PermissionsState>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.userId, 'userId', 'user-123'),
        isA<PermissionsState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.isAdmin, 'isAdmin', isTrue)
            .having((s) => s.userId, 'userId', 'user-123'),
      ],
    );

    blocTest<PermissionsBloc, PermissionsState>(
      'emits isAdmin=true when metadata role is worker but user has Admin role in DB',
      build: () {
        permissionsBloc = PermissionsBloc(supabase: mockSupabaseClient);
        
        final dummyRoles = [
          {
            'roles': {'name': 'Admin'}
          }
        ];
        when(() => mockQueryBuilder.select('roles(name)')).thenAnswer(
          (_) => FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(dummyRoles),
        );

        return permissionsBloc;
      },
      act: (bloc) => bloc.add(LoadPermissions('user-123', 'worker')),
      expect: () => [
        isA<PermissionsState>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.userId, 'userId', 'user-123'),
        isA<PermissionsState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.isAdmin, 'isAdmin', isTrue)
            .having((s) => s.userId, 'userId', 'user-123'),
      ],
    );

    blocTest<PermissionsBloc, PermissionsState>(
      'emits isAdmin=false and permissions map when metadata role is worker and has custom permissions in DB',
      build: () {
        permissionsBloc = PermissionsBloc(supabase: mockSupabaseClient);
        
        final dummyRoles = [
          {
            'roles': {'name': 'Staff'}
          }
        ];
        
        when(() => mockQueryBuilder.select('roles(name)')).thenAnswer(
          (_) => FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(dummyRoles),
        );

        // Stub the get_user_permissions RPC call using FakePostgrestFilterBuilder
        when(() => mockSupabaseClient.rpc(
              'get_user_permissions',
              params: {'p_user_id': 'user-123'},
            )).thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(['can_manage_products', 'can_view_reports']));
        
        return permissionsBloc;
      },
      act: (bloc) => bloc.add(LoadPermissions('user-123', 'worker')),
      expect: () => [
        isA<PermissionsState>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.userId, 'userId', 'user-123'),
        isA<PermissionsState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.isAdmin, 'isAdmin', isFalse)
            .having((s) => s.permissions, 'permissions', {
              'can_manage_products': true,
              'can_view_reports': true,
            })
            .having((s) => s.userId, 'userId', 'user-123'),
      ],
    );
  });
}
