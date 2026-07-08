import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'suppliers_event.dart';
import 'suppliers_state.dart';

class SuppliersBloc extends Bloc<SuppliersEvent, SuppliersState> {
  final _supabase = Supabase.instance.client;

  SuppliersBloc() : super(SuppliersInitial()) {
    on<LoadSuppliers>(_onLoadSuppliers);
    on<AddSupplier>(_onAddSupplier);
    on<UpdateSupplier>(_onUpdateSupplier);
    on<ToggleSupplierStatus>(_onToggleSupplierStatus);
    on<AddSupplierPayment>(_onAddSupplierPayment);
  }

  Future<void> _onLoadSuppliers(LoadSuppliers event, Emitter<SuppliersState> emit) async {
    emit(SuppliersLoading());
    try {
      var query = _supabase.from('supplier_debts_view').select('*');
      
      if (event.storeId != null) {
        query = query.eq('store_id', event.storeId!);
      }

      final data = await query.order('name');
      emit(SuppliersLoaded(List<Map<String, dynamic>>.from(data), storeId: event.storeId));
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }

  Future<void> _onAddSupplier(AddSupplier event, Emitter<SuppliersState> emit) async {
    if (state is SuppliersLoaded) {
      final currentState = state as SuppliersLoaded;
      try {
        await _supabase.from('suppliers').insert(event.data);
        add(LoadSuppliers(currentState.storeId));
      } catch (e) {
        emit(SuppliersError(e.toString()));
        add(LoadSuppliers(currentState.storeId)); // Re-load to clear error state eventually
      }
    }
  }

  Future<void> _onUpdateSupplier(UpdateSupplier event, Emitter<SuppliersState> emit) async {
    if (state is SuppliersLoaded) {
      final currentState = state as SuppliersLoaded;
      try {
        await _supabase.from('suppliers').update(event.data).eq('id', event.id);
        add(LoadSuppliers(currentState.storeId));
      } catch (e) {
        emit(SuppliersError(e.toString()));
        add(LoadSuppliers(currentState.storeId));
      }
    }
  }

  Future<void> _onToggleSupplierStatus(ToggleSupplierStatus event, Emitter<SuppliersState> emit) async {
    if (state is SuppliersLoaded) {
      final currentState = state as SuppliersLoaded;
      try {
        await _supabase.from('suppliers').update({'is_active': event.isActive}).eq('id', event.id);
        add(LoadSuppliers(currentState.storeId));
      } catch (e) {
        emit(SuppliersError(e.toString()));
        add(LoadSuppliers(currentState.storeId));
      }
    }
  }

  Future<void> _onAddSupplierPayment(AddSupplierPayment event, Emitter<SuppliersState> emit) async {
    if (state is SuppliersLoaded) {
      final currentState = state as SuppliersLoaded;
      try {
        await _supabase.from('supplier_payments').insert({
          'supplier_id': event.supplierId,
          'store_id': event.storeId,
          'amount': event.amount,
          'payment_method': event.paymentMethod ?? 'cash',
          'reference': event.reference,
          'notes': 'Manual Payment Entry',
        });
        add(LoadSuppliers(currentState.storeId));
      } catch (e) {
        emit(SuppliersError(e.toString()));
        add(LoadSuppliers(currentState.storeId));
      }
    }
  }
}
