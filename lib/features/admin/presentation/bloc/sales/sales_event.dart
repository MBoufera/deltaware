import 'package:equatable/equatable.dart';

abstract class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

class LoadProducts extends SalesEvent {
  /// The store whose products should be loaded.
  final String storeId;
  const LoadProducts(this.storeId);

  @override
  List<Object?> get props => [storeId];
}

class SelectSaleType extends SalesEvent {
  final String saleType;

  const SelectSaleType(this.saleType);

  @override
  List<Object?> get props => [saleType];
}

class SearchProducts extends SalesEvent {
  final String query;

  const SearchProducts(this.query);

  @override
  List<Object?> get props => [query];
}

class AddItemToCart extends SalesEvent {
  final Map<String, dynamic> product;

  const AddItemToCart(this.product);

  @override
  List<Object?> get props => [product];
}

class RemoveItemFromCart extends SalesEvent {
  final String productId;

  const RemoveItemFromCart(this.productId);

  @override
  List<Object?> get props => [productId];
}

class UpdateItemQty extends SalesEvent {
  final String productId;
  final int delta;

  const UpdateItemQty(this.productId, this.delta);

  @override
  List<Object?> get props => [productId, delta];
}

class SetClient extends SalesEvent {
  final Map<String, dynamic>? client;

  const SetClient(this.client);

  @override
  List<Object?> get props => [client];
}

class ToggleTimbreFiscal extends SalesEvent {
  final bool isEnabled;

  const ToggleTimbreFiscal(this.isEnabled);

  @override
  List<Object?> get props => [isEnabled];
}

class SubmitSale extends SalesEvent {
  final double? amountPaid;

  const SubmitSale({this.amountPaid});

  @override
  List<Object?> get props => [amountPaid];
}

class ResetSale extends SalesEvent {
  final String storeId;
  const ResetSale(this.storeId);

  @override
  List<Object?> get props => [storeId];
}
