import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_event.dart';
import 'analytics_state.dart';

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final SupabaseClient _supabase;

  AnalyticsBloc(this._supabase) : super(AnalyticsInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<ChangeDateRange>(_onChangeDateRange);
  }

  Future<void> _onLoadDashboard(LoadDashboard event, Emitter<AnalyticsState> emit) async {
    emit(AnalyticsLoading());
    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      switch (event.period) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        case 'month':
        default:
          startDate = DateTime(now.year, now.month, 1);
          break;
      }

      await _fetchAndEmit(startDate, endDate, event.period, emit);
    } catch (e) {
      emit(AnalyticsError(e.toString()));
    }
  }

  Future<void> _onChangeDateRange(ChangeDateRange event, Emitter<AnalyticsState> emit) async {
    emit(AnalyticsLoading());
    try {
      await _fetchAndEmit(event.from, event.to, 'custom', emit);
    } catch (e) {
      emit(AnalyticsError(e.toString()));
    }
  }

  Future<void> _fetchAndEmit(DateTime start, DateTime end, String period, Emitter<AnalyticsState> emit) async {
    final data = await _supabase.rpc('get_deep_analytics', params: {
      'start_date': start.toUtc().toIso8601String(),
      'end_date': end.toUtc().toIso8601String(),
    });

    emit(AnalyticsLoaded(
      summary: data['kpi'] ?? {},
      timeline: List<dynamic>.from(data['timeline'] ?? []),
      topWorkers: List<dynamic>.from(data['top_workers'] ?? []),
      topProducts: List<dynamic>.from(data['top_products'] ?? []),
      categoryBreakdown: List<dynamic>.from(data['category_breakdown'] ?? []),
      fromDate: start,
      toDate: end,
      period: period,
    ));
  }
}
