import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/features/admin/presentation/bloc/analytics/analytics_bloc.dart';
import 'package:deltaware/features/admin/presentation/bloc/analytics/analytics_event.dart';
import 'package:deltaware/features/admin/presentation/bloc/analytics/analytics_state.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late AnalyticsBloc analyticsBloc;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    analyticsBloc = AnalyticsBloc(mockSupabaseClient);
  });

  tearDown(() {
    analyticsBloc.close();
  });

  group('AnalyticsBloc', () {
    test('initial state is AnalyticsInitial', () {
      expect(analyticsBloc.state, isA<AnalyticsInitial>());
    });

    blocTest<AnalyticsBloc, AnalyticsState>(
      'LoadDashboard emits [AnalyticsLoading, AnalyticsLoaded] when RPC is successful',
      build: () {
        when(() => mockSupabaseClient.rpc('get_deep_analytics', params: any(named: 'params')))
            .thenAnswer((_) async => {
                  'kpi': {'total_revenue_ht': 1000},
                  'timeline': [],
                  'top_workers': [],
                  'top_products': [],
                  'category_breakdown': []
                });
        return analyticsBloc;
      },
      act: (bloc) => bloc.add(const LoadDashboard(period: 'month')),
      expect: () => [
        isA<AnalyticsLoading>(),
        isA<AnalyticsLoaded>()
            .having((s) => s.period, 'period', 'month')
            .having((s) => s.summary['total_revenue_ht'], 'total_revenue_ht', 1000),
      ],
      verify: (_) {
        verify(() => mockSupabaseClient.rpc('get_deep_analytics', params: any(named: 'params'))).called(1);
      },
    );

    blocTest<AnalyticsBloc, AnalyticsState>(
      'ChangeDateRange emits [AnalyticsLoading, AnalyticsLoaded] with custom period',
      build: () {
        when(() => mockSupabaseClient.rpc('get_deep_analytics', params: any(named: 'params')))
            .thenAnswer((_) async => {});
        return analyticsBloc;
      },
      act: (bloc) => bloc.add(ChangeDateRange(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      )),
      expect: () => [
        isA<AnalyticsLoading>(),
        isA<AnalyticsLoaded>().having((s) => s.period, 'period', 'custom'),
      ],
    );

    blocTest<AnalyticsBloc, AnalyticsState>(
      'LoadDashboard emits [AnalyticsLoading, AnalyticsError] when RPC fails',
      build: () {
        when(() => mockSupabaseClient.rpc('get_deep_analytics', params: any(named: 'params')))
            .thenThrow(Exception('RPC Failed'));
        return analyticsBloc;
      },
      act: (bloc) => bloc.add(const LoadDashboard()),
      expect: () => [
        isA<AnalyticsLoading>(),
        isA<AnalyticsError>().having((e) => e.message, 'message', contains('RPC Failed')),
      ],
    );
  });
}
