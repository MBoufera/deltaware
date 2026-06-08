import 'package:equatable/equatable.dart';

abstract class AnalyticsState extends Equatable {
  const AnalyticsState();

  @override
  List<Object?> get props => [];
}

class AnalyticsInitial extends AnalyticsState {}

class AnalyticsLoading extends AnalyticsState {}

class AnalyticsLoaded extends AnalyticsState {
  final Map<String, dynamic> summary;
  final List<dynamic> timeline;
  final List<dynamic> topProducts;
  final List<dynamic> topWorkers;
  final List<dynamic> categoryBreakdown;
  final DateTime fromDate;
  final DateTime toDate;
  final String period;

  const AnalyticsLoaded({
    required this.summary,
    required this.timeline,
    required this.topProducts,
    required this.topWorkers,
    required this.categoryBreakdown,
    required this.fromDate,
    required this.toDate,
    required this.period,
  });

  @override
  List<Object?> get props => [
        summary,
        timeline,
        topProducts,
        topWorkers,
        categoryBreakdown,
        fromDate,
        toDate,
        period,
      ];
}

class AnalyticsError extends AnalyticsState {
  final String message;

  const AnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
