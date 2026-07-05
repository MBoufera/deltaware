import '../../data/models/store_model.dart';

abstract class StoreState {}

class StoreInitial extends StoreState {}

class StoreLoading extends StoreState {}

/// Stores are loaded. [selectedStore] is null if the user hasn't picked one yet.
class StoresLoaded extends StoreState {
  final List<Store> stores;
  final Store? selectedStore;

  StoresLoaded({required this.stores, this.selectedStore});

  StoresLoaded copyWith({List<Store>? stores, Store? selectedStore}) {
    return StoresLoaded(
      stores: stores ?? this.stores,
      selectedStore: selectedStore ?? this.selectedStore,
    );
  }

  /// Returns true when the user must be prompted to pick a store.
  bool get needsStoreSelection => selectedStore == null && stores.length > 1;

  /// Returns true when the store has been automatically resolved (single store).
  bool get isSingleStore => stores.length == 1;
}

class StoreOperationSuccess extends StoreState {
  final String message;
  final List<Store> stores;
  final Store? selectedStore;

  StoreOperationSuccess({
    required this.message,
    required this.stores,
    this.selectedStore,
  });
}

class StoreError extends StoreState {
  final String message;
  StoreError(this.message);
}
