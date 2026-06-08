import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SupabaseClient _supabase;

  SalesBloc(this._supabase) : super(SalesInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<SelectSaleType>(_onSelectSaleType);
    on<SearchProducts>(_onSearchProducts);
    on<AddItemToCart>(_onAddItemToCart);
    on<RemoveItemFromCart>(_onRemoveItemFromCart);
    on<UpdateItemQty>(_onUpdateItemQty);
    on<SetClient>(_onSetClient);
    on<ToggleTimbreFiscal>(_onToggleTimbreFiscal);
    on<SubmitSale>(_onSubmitSale);
    on<ResetSale>(_onResetSale);
  }

  Future<void> _onLoadProducts(LoadProducts event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      final data = await _supabase
          .from('products')
          .select('id, name_fr, ref_code, stock(qty_super_gros, qty_gros, qty_detail), product_pricing(prix_vente_gros_ht, prix_vente_detail_ht, tva_rate), categories(name_fr)')
          .eq('is_active', true);
      
      emit(_calculateTotals(
        products: data,
        filteredProducts: List.from(data),
        saleType: 'detail',
        cart: {},
        selectedClient: null,
        timbreFiscalEnabled: false,
      ));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  void _onSelectSaleType(SelectSaleType event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final currentState = state as SalesUpdated;
      emit(_calculateTotals(
        products: currentState.products,
        filteredProducts: currentState.filteredProducts,
        saleType: event.saleType,
        cart: currentState.cart,
        selectedClient: currentState.selectedClient,
        timbreFiscalEnabled: currentState.timbreFiscalEnabled,
      ));
    }
  }

  void _onSearchProducts(SearchProducts event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final currentState = state as SalesUpdated;
      final query = event.query.toLowerCase();
      
      final filtered = currentState.products.where((p) {
        final name = (p['name_fr'] ?? '').toLowerCase();
        final ref = (p['ref_code'] ?? '').toLowerCase();
        return name.contains(query) || ref.contains(query);
      }).toList();

      emit(currentState.copyWith(filteredProducts: filtered));
    }
  }

  void _onAddItemToCart(AddItemToCart event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final currentState = state as SalesUpdated;
      final id = event.product['id'] as String;
      
      final newCart = Map<String, int>.from(currentState.cart);
      newCart[id] = (newCart[id] ?? 0) + 1;

      emit(_calculateTotals(
        products: currentState.products,
        filteredProducts: currentState.filteredProducts,
        saleType: currentState.saleType,
        cart: newCart,
        selectedClient: currentState.selectedClient,
        timbreFiscalEnabled: currentState.timbreFiscalEnabled,
      ));
    }
  }

  void _onRemoveItemFromCart(RemoveItemFromCart event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final currentState = state as SalesUpdated;
      
      final newCart = Map<String, int>.from(currentState.cart);
      newCart.remove(event.productId);

      emit(_calculateTotals(
        products: currentState.products,
        filteredProducts: currentState.filteredProducts,
        saleType: currentState.saleType,
        cart: newCart,
        selectedClient: currentState.selectedClient,
        timbreFiscalEnabled: currentState.timbreFiscalEnabled,
      ));
    }
  }

  void _onUpdateItemQty(UpdateItemQty event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final currentState = state as SalesUpdated;
      
      final newCart = Map<String, int>.from(currentState.cart);
      int newQty = (newCart[event.productId] ?? 0) + event.delta;
      
      if (newQty <= 0) {
        newCart.remove(event.productId);
      } else {
        newCart[event.productId] = newQty;
      }

      emit(_calculateTotals(
        products: currentState.products,
        filteredProducts: currentState.filteredProducts,
        saleType: currentState.saleType,
        cart: newCart,
        selectedClient: currentState.selectedClient,
        timbreFiscalEnabled: currentState.timbreFiscalEnabled,
      ));
    }
  }

  void _onSetClient(SetClient event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final currentState = state as SalesUpdated;
      emit(currentState.copyWith(selectedClient: event.client));
    }
  }

  void _onToggleTimbreFiscal(ToggleTimbreFiscal event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final currentState = state as SalesUpdated;
      emit(_calculateTotals(
        products: currentState.products,
        filteredProducts: currentState.filteredProducts,
        saleType: currentState.saleType,
        cart: currentState.cart,
        selectedClient: currentState.selectedClient,
        timbreFiscalEnabled: event.isEnabled,
      ));
    }
  }

  Future<void> _onSubmitSale(SubmitSale event, Emitter<SalesState> emit) async {
    if (state is! SalesUpdated) return;
    
    final currentState = state as SalesUpdated;
    
    if (['bon_livraison', 'bon_commande', 'gros', 'gouvernement'].contains(currentState.saleType) && currentState.selectedClient == null) {
      emit(SalesError('Client is required for this sale type'));
      emit(currentState); // Re-emit current state to clear error
      return;
    }

    if (currentState.cart.isEmpty) {
      emit(SalesError('Cart is empty'));
      emit(currentState);
      return;
    }

    emit(SalesSubmitting(
      products: currentState.products,
      filteredProducts: currentState.filteredProducts,
      saleType: currentState.saleType,
      cart: currentState.cart,
      selectedClient: currentState.selectedClient,
      timbreFiscalEnabled: currentState.timbreFiscalEnabled,
      totalHt: currentState.totalHt,
      tvaBreakdown: currentState.tvaBreakdown,
      totalTva: currentState.totalTva,
      subtotalTtc: currentState.subtotalTtc,
      timbreFiscal: currentState.timbreFiscal,
      grandTotalTtc: currentState.grandTotalTtc,
    ));

    try {
      final user = _supabase.auth.currentUser;
      
      List<Map<String, dynamic>> items = [];
      currentState.cart.forEach((id, qty) {
        final p = currentState.products.firstWhere((p) => p['id'] == id);
        final priceHt = _getPriceForType(p, currentState.saleType);
        final tvaRate = _getTvaRate(p);
        final itemTva = priceHt * (tvaRate / 100);
        final priceTtc = priceHt + itemTva;
        
        items.add({
          'product_id': id,
          'quantity': qty,
          'unit_price_ht': priceHt,
          'tva_rate': tvaRate,
          'unit_price_ttc': priceTtc,
          'total_ht': priceHt * qty,
          'total_ttc': priceTtc * qty,
          'discount_percent': 0,
        });
      });

      final payload = {
        'sale': {
          'sale_type': currentState.saleType,
          'worker_id': user?.id,
          'client_id': currentState.selectedClient?['id'],
          'total_ht': currentState.totalHt,
          'tva_amount': currentState.totalTva,
          'timbre_fiscal': currentState.timbreFiscal,
          'total_ttc': currentState.grandTotalTtc,
          'notes': 'POS Sale'
        },
        'items': items
      };

      final response = await _supabase.rpc('process_pos_sale', params: {'payload': payload});

      emit(SalesSuccess(response, currentState.grandTotalTtc));
      
      // We automatically reload products after success in ResetSale or LoadProducts
    } catch (e) {
      emit(SalesError(e.toString()));
      emit(currentState); // Fallback to cart state
    }
  }

  void _onResetSale(ResetSale event, Emitter<SalesState> emit) {
    if (state is SalesSuccess || state is SalesUpdated || state is SalesError) {
      // Reload products to refresh stock
      add(LoadProducts());
    }
  }

  // --- Helper Methods for Math ---
  
  double _getPriceForType(Map<String, dynamic> product, String saleType) {
    final pricing = product['product_pricing'];
    if (pricing == null) return 0.0;
    
    if (saleType == 'detail') {
      return (pricing['prix_vente_detail_ht'] as num?)?.toDouble() ?? 0.0;
    } else {
      return (pricing['prix_vente_gros_ht'] as num?)?.toDouble() ?? 0.0;
    }
  }

  double _getTvaRate(Map<String, dynamic> product) {
    final pricing = product['product_pricing'];
    return (pricing?['tva_rate'] as num?)?.toDouble() ?? 19.0;
  }

  SalesUpdated _calculateTotals({
    required List<dynamic> products,
    required List<dynamic> filteredProducts,
    required String saleType,
    required Map<String, int> cart,
    required Map<String, dynamic>? selectedClient,
    required bool timbreFiscalEnabled,
  }) {
    double totalHt = 0;
    Map<double, double> tvaBreakdown = {};

    cart.forEach((id, qty) {
      final p = products.firstWhere((p) => p['id'] == id);
      double priceHt = _getPriceForType(p, saleType);
      double rate = _getTvaRate(p);
      
      double itemHt = priceHt * qty;
      double itemTva = itemHt * (rate / 100);
      
      totalHt += itemHt;
      tvaBreakdown[rate] = (tvaBreakdown[rate] ?? 0) + itemTva;
    });

    double totalTva = tvaBreakdown.values.fold(0.0, (a, b) => a + b);
    double subtotalTtc = totalHt + totalTva;
    double timbreFiscal = timbreFiscalEnabled ? (subtotalTtc * 0.01) : 0.0;
    double grandTotalTtc = subtotalTtc + timbreFiscal;

    return SalesUpdated(
      products: products,
      filteredProducts: filteredProducts,
      saleType: saleType,
      cart: cart,
      selectedClient: selectedClient,
      timbreFiscalEnabled: timbreFiscalEnabled,
      totalHt: totalHt,
      tvaBreakdown: tvaBreakdown,
      totalTva: totalTva,
      subtotalTtc: subtotalTtc,
      timbreFiscal: timbreFiscal,
      grandTotalTtc: grandTotalTtc,
    );
  }
}
