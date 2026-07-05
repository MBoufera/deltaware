import 'package:equatable/equatable.dart';

abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboard extends AnalyticsEvent {
  final String period; // 'today', 'week', 'month', 'year'
  final String? storeId; // null = all stores (super admin overview)

  const LoadDashboard({this.period = 'month', this.storeId});

  @override
  List<Object?> get props => [period, storeId];
}

class ChangeDateRange extends AnalyticsEvent {
  final DateTime from;
  final DateTime to;
  final String? storeId;

  const ChangeDateRange({required this.from, required this.to, this.storeId});

  @override
  List<Object?> get props => [from, to, storeId];
}
