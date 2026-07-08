import 'package:equatable/equatable.dart';

abstract class SuppliersState extends Equatable {
  const SuppliersState();

  @override
  List<Object?> get props => [];
}

class SuppliersInitial extends SuppliersState {}

class SuppliersLoading extends SuppliersState {}

class SuppliersLoaded extends SuppliersState {
  final List<Map<String, dynamic>> suppliers;
  final String? storeId;

  const SuppliersLoaded(this.suppliers, {this.storeId});

  @override
  List<Object?> get props => [suppliers, storeId];
}

class SuppliersError extends SuppliersState {
  final String message;

  const SuppliersError(this.message);

  @override
  List<Object> get props => [message];
}

class SupplierOperationSuccess extends SuppliersState {
  final String message;
  const SupplierOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}
