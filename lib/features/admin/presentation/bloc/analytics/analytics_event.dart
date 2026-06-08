import 'package:equatable/equatable.dart';

abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboard extends AnalyticsEvent {
  final String period; // 'today', 'week', 'month', 'year'

  const LoadDashboard({this.period = 'month'});

  @override
  List<Object?> get props => [period];
}

class ChangeDateRange extends AnalyticsEvent {
  final DateTime from;
  final DateTime to;

  const ChangeDateRange({required this.from, required this.to});

  @override
  List<Object?> get props => [from, to];
}
