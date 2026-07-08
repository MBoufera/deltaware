import 'package:equatable/equatable.dart';

abstract class SuppliersEvent extends Equatable {
  const SuppliersEvent();

  @override
  List<Object?> get props => [];
}

class LoadSuppliers extends SuppliersEvent {
  final String? storeId;
  const LoadSuppliers(this.storeId);

  @override
  List<Object?> get props => [storeId];
}

class AddSupplier extends SuppliersEvent {
  final Map<String, dynamic> data;
  const AddSupplier(this.data);

  @override
  List<Object> get props => [data];
}

class UpdateSupplier extends SuppliersEvent {
  final String id;
  final Map<String, dynamic> data;

  const UpdateSupplier(this.id, this.data);

  @override
  List<Object> get props => [id, data];
}

class ToggleSupplierStatus extends SuppliersEvent {
  final String id;
  final bool isActive;

  const ToggleSupplierStatus(this.id, this.isActive);

  @override
  List<Object> get props => [id, isActive];
}

class AddSupplierPayment extends SuppliersEvent {
  final String supplierId;
  final String storeId;
  final double amount;
  final String? paymentMethod;
  final String? reference;

  const AddSupplierPayment({
    required this.supplierId,
    required this.storeId,
    required this.amount,
    this.paymentMethod,
    this.reference,
  });

  @override
  List<Object?> get props => [supplierId, storeId, amount, paymentMethod, reference];
}

class CreatePurchaseInvoice extends SuppliersEvent {
  final Map<String, dynamic> invoiceData;
  final List<Map<String, dynamic>> items;
  final String storeId;

  const CreatePurchaseInvoice({
    required this.invoiceData,
    required this.items,
    required this.storeId,
  });

  @override
  List<Object> get props => [invoiceData, items, storeId];
}
