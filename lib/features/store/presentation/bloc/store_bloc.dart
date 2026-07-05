import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/store_model.dart';
import 'store_event.dart';
import 'store_state.dart';

class StoreBloc extends Bloc<StoreEvent, StoreState> {
  final SupabaseClient _supabase;

  StoreBloc({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(StoreInitial()) {
    on<LoadUserStores>(_onLoadUserStores);
    on<SelectStore>(_onSelectStore);
    on<ClearSelectedStore>(_onClearSelectedStore);
    on<CreateStore>(_onCreateStore);
    on<UpdateCurrentStore>(_onUpdateCurrentStore);
    on<ResetStore>((event, emit) => emit(StoreInitial()));
  }

  /// Returns the currently active store_id, or null.
  String? get currentStoreId {
    final s = state;
    if (s is StoresLoaded) return s.selectedStore?.id;
    if (s is StoreOperationSuccess) return s.selectedStore?.id;
    return null;
  }

  Store? get currentStore {
    final s = state;
    if (s is StoresLoaded) return s.selectedStore;
    if (s is StoreOperationSuccess) return s.selectedStore;
    return null;
  }

  // ─── Handlers ────────────────────────────────────────────────────────────

  Future<void> _onLoadUserStores(
    LoadUserStores event,
    Emitter<StoreState> emit,
  ) async {
    emit(StoreLoading());
    try {
      final response = await _supabase.rpc('get_stores');
      final rawList = response as List? ?? [];
      final stores = rawList
          .map((e) => Store.fromJson(e as Map<String, dynamic>))
          .toList();

      // Preserve selection across reloads
      Store? preserved;
      if (state is StoresLoaded) {
        final prevId = (state as StoresLoaded).selectedStore?.id;
        if (prevId != null) {
          try {
            preserved = stores.firstWhere((s) => s.id == prevId);
          } catch (_) {}
        }
      }

      emit(StoresLoaded(stores: stores, selectedStore: preserved));
    } catch (e) {
      emit(StoreError('Failed to load stores: $e'));
    }
  }

  void _onSelectStore(SelectStore event, Emitter<StoreState> emit) {
    final s = state;
    if (s is StoresLoaded) {
      emit(s.copyWith(selectedStore: event.store));
    } else {
      // If still in loading/error state, create a minimal loaded state
      emit(StoresLoaded(stores: [event.store], selectedStore: event.store));
    }
  }

  void _onClearSelectedStore(
    ClearSelectedStore event,
    Emitter<StoreState> emit,
  ) {
    final s = state;
    if (s is StoresLoaded) {
      emit(StoresLoaded(stores: s.stores, selectedStore: null));
    }
  }

  Future<void> _onCreateStore(
    CreateStore event,
    Emitter<StoreState> emit,
  ) async {
    final previousStores = state is StoresLoaded
        ? (state as StoresLoaded).stores
        : <Store>[];

    emit(StoreLoading());
    try {
      final result = await _supabase.rpc('create_store', params: {
        'p_name':          event.name,
        'p_subtitle':      event.subtitle,
        'p_address':       event.address,
        'p_wilaya':        event.wilaya,
        'p_phone':         event.phone,
        'p_nif':           event.nif,
        'p_nis':           event.nis,
        'p_rc':            event.rc,
        'p_ai':            event.ai,
        'p_enable_timbre': event.enableTimbre,
      });

      // Reload the full store list after creation
      final response = await _supabase.rpc('get_stores');
      final rawList = response as List? ?? [];
      final stores = rawList
          .map((e) => Store.fromJson(e as Map<String, dynamic>))
          .toList();

      final newStoreId = result['store_id'] as String?;
      Store? newStore;
      if (newStoreId != null) {
        try {
          newStore = stores.firstWhere((s) => s.id == newStoreId);
        } catch (_) {}
      }

      emit(StoreOperationSuccess(
        message: 'Store "${event.name}" created successfully.',
        stores: stores,
        selectedStore: newStore,
      ));
    } catch (e) {
      emit(StoreError('Failed to create store: $e'));
      // Restore previous state
      if (previousStores.isNotEmpty) {
        emit(StoresLoaded(stores: previousStores));
      }
    }
  }

  Future<void> _onUpdateCurrentStore(
    UpdateCurrentStore event,
    Emitter<StoreState> emit,
  ) async {
    final s = state;
    if (s is! StoresLoaded || s.selectedStore == null) return;
    final storeId = s.selectedStore!.id;

    try {
      await _supabase.rpc('update_store', params: {
        'p_store_id':      storeId,
        'p_name':          event.name,
        'p_subtitle':      event.subtitle,
        'p_address':       event.address,
        'p_wilaya':        event.wilaya,
        'p_phone':         event.phone,
        'p_nif':           event.nif,
        'p_nis':           event.nis,
        'p_rc':            event.rc,
        'p_ai':            event.ai,
        'p_enable_timbre': event.enableTimbre,
      });

      // Reload stores to reflect updated name / subtitle
      final response = await _supabase.rpc('get_stores');
      final rawList = response as List? ?? [];
      final stores = rawList
          .map((e) => Store.fromJson(e as Map<String, dynamic>))
          .toList();

      Store? updated;
      try {
        updated = stores.firstWhere((st) => st.id == storeId);
      } catch (_) {}

      emit(StoreOperationSuccess(
        message: 'Settings saved.',
        stores: stores,
        selectedStore: updated,
      ));
    } catch (e) {
      emit(StoreError('Failed to save settings: $e'));
    }
  }
}
