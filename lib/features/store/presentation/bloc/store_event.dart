import '../../data/models/store_model.dart';

abstract class StoreEvent {}

/// Reset store state on logout.
class ResetStore extends StoreEvent {}

/// Load all stores accessible to the current user.
class LoadUserStores extends StoreEvent {}

/// Set the active working store context.
class SelectStore extends StoreEvent {
  final Store store;
  SelectStore(this.store);
}

/// Clear the selected store (go back to store picker).
class ClearSelectedStore extends StoreEvent {}

/// Create a new store (super admin only).
class CreateStore extends StoreEvent {
  final String name;
  final String subtitle;
  final String address;
  final String wilaya;
  final String phone;
  final String nif;
  final String nis;
  final String rc;
  final String ai;
  final bool enableTimbre;

  CreateStore({
    required this.name,
    this.subtitle = 'Vente en Gros et Détail',
    this.address = '',
    this.wilaya = '',
    this.phone = '',
    this.nif = '',
    this.nis = '',
    this.rc = '',
    this.ai = '',
    this.enableTimbre = false,
  });
}

/// Update the settings of the currently selected store.
class UpdateCurrentStore extends StoreEvent {
  final String name;
  final String subtitle;
  final String address;
  final String wilaya;
  final String phone;
  final String nif;
  final String nis;
  final String rc;
  final String ai;
  final bool enableTimbre;

  UpdateCurrentStore({
    required this.name,
    this.subtitle = '',
    this.address = '',
    this.wilaya = '',
    this.phone = '',
    this.nif = '',
    this.nis = '',
    this.rc = '',
    this.ai = '',
    this.enableTimbre = false,
  });
}
