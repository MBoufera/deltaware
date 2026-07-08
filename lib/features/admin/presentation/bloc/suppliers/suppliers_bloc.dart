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
    on<CreatePurchaseInvoice>(_onCreatePurchaseInvoice);
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
    final storeId = event.data['store_id'] as String;
    emit(SuppliersLoading());
    try {
      await _supabase.from('suppliers').insert(event.data);
      emit(const SupplierOperationSuccess('Supplier created successfully'));
      add(LoadSuppliers(storeId));
    } catch (e) {
      emit(SuppliersError(e.toString()));
      // Removed automatic reload so the error is visible
    }
  }

  Future<void> _onUpdateSupplier(UpdateSupplier event, Emitter<SuppliersState> emit) async {
    final storeId = event.data['store_id'] as String;
    emit(SuppliersLoading());
    try {
      await _supabase.from('suppliers').update(event.data).eq('id', event.id);
      emit(const SupplierOperationSuccess('Supplier updated successfully'));
      add(LoadSuppliers(storeId));
    } catch (e) {
      emit(SuppliersError(e.toString()));
      add(LoadSuppliers(storeId));
    }
  }

  Future<void> _onToggleSupplierStatus(ToggleSupplierStatus event, Emitter<SuppliersState> emit) async {
    final s = state;
    final storeId = (s is SuppliersLoaded) ? s.storeId : null;
    emit(SuppliersLoading());
    try {
      await _supabase.from('suppliers').update({'is_active': event.isActive}).eq('id', event.id);
      add(LoadSuppliers(storeId));
    } catch (e) {
      emit(SuppliersError(e.toString()));
      add(LoadSuppliers(storeId));
    }
  }

  Future<void> _onAddSupplierPayment(AddSupplierPayment event, Emitter<SuppliersState> emit) async {
    emit(SuppliersLoading());
    try {
      await _supabase.from('supplier_payments').insert({
        'supplier_id': event.supplierId,
        'store_id': event.storeId,
        'amount': event.amount,
        'payment_method': event.paymentMethod ?? 'cash',
        'reference': event.reference,
        'notes': 'Manual Payment Entry',
      });
      emit(const SupplierOperationSuccess('Payment added successfully'));
      add(LoadSuppliers(event.storeId));
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }

  Future<void> _onCreatePurchaseInvoice(CreatePurchaseInvoice event, Emitter<SuppliersState> emit) async {
    final s = state;
    final storeId = (s is SuppliersLoaded) ? s.storeId : event.storeId;
    
    emit(SuppliersLoading());
    try {
      // 1. Insert Invoice
      final invoiceData = Map<String, dynamic>.from(event.invoiceData);
      // Ensure store_id is set
      invoiceData['store_id'] = event.storeId;
      
      final invoiceResult = await _supabase
          .from('purchase_invoices')
          .insert(invoiceData)
          .select()
          .single();
          
      final invoiceId = invoiceResult['id'];
      
      // 2. Insert Items
      final items = event.items.map((item) {
        return {
          ...item,
          'invoice_id': invoiceId,
        };
      }).toList();
      
      if (items.isNotEmpty) {
        await _supabase.from('purchase_invoice_items').insert(items);
      }
      
      emit(const SupplierOperationSuccess('Purchase invoice created successfully'));
      add(LoadSuppliers(storeId));
    } catch (e) {
      emit(SuppliersError(e.toString()));
      add(LoadSuppliers(storeId));
    }
  }
}
