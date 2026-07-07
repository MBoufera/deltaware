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

  // ─── Handlers ────────────────────────────────────────────────────────────

  Future<void> _onLoadProducts(LoadProducts event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      final data = await _supabase
          .from('products')
          .select(
            'id, name_fr, ref_code, reference, '
            'stock(qty_super_gros, qty_gros, qty_detail), '
            'product_pricing(prix_vente_gros_ht, prix_vente_detail_ht, tva_rate), '
            'categories(name_fr)',
          )
          .eq('is_active', true)
          .eq('store_id', event.storeId);

      emit(_calculateTotals(
        products: data,
        filteredProducts: List.from(data),
        saleType: 'detail',
        cart: {},
        selectedClient: null,
        timbreFiscalEnabled: false,
        storeId: event.storeId,
      ));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  void _onSelectSaleType(SelectSaleType event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final s = state as SalesUpdated;
      emit(_calculateTotals(
        products: s.products,
        filteredProducts: s.filteredProducts,
        saleType: event.saleType,
        cart: s.cart,
        selectedClient: s.selectedClient,
        timbreFiscalEnabled: s.timbreFiscalEnabled,
        storeId: s.storeId,
      ));
    }
  }

  void _onSearchProducts(SearchProducts event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final s = state as SalesUpdated;
      final query = event.query.toLowerCase();
      final filtered = s.products.where((p) {
        final name = (p['name_fr'] ?? '').toLowerCase();
        final ref = (p['ref_code'] ?? '').toLowerCase();
        final reference = (p['reference'] ?? '').toLowerCase();
        return name.contains(query) || ref.contains(query) || reference.contains(query);
      }).toList();
      emit(s.copyWith(filteredProducts: filtered));
    }
  }

  void _onAddItemToCart(AddItemToCart event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final s = state as SalesUpdated;
      final id = event.product['id'] as String;
      final newCart = Map<String, int>.from(s.cart);
      
      final contenance = event.product['contenance'] as int? ?? 1;
      final delta = s.saleType == 'gros' ? contenance : 1;
      
      newCart[id] = (newCart[id] ?? 0) + delta;
      emit(_calculateTotals(
        products: s.products,
        filteredProducts: s.filteredProducts,
        saleType: s.saleType,
        cart: newCart,
        selectedClient: s.selectedClient,
        timbreFiscalEnabled: s.timbreFiscalEnabled,
        storeId: s.storeId,
      ));
    }
  }

  void _onRemoveItemFromCart(RemoveItemFromCart event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final s = state as SalesUpdated;
      final newCart = Map<String, int>.from(s.cart)..remove(event.productId);
      emit(_calculateTotals(
        products: s.products,
        filteredProducts: s.filteredProducts,
        saleType: s.saleType,
        cart: newCart,
        selectedClient: s.selectedClient,
        timbreFiscalEnabled: s.timbreFiscalEnabled,
        storeId: s.storeId,
      ));
    }
  }

  void _onUpdateItemQty(UpdateItemQty event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final s = state as SalesUpdated;
      final newCart = Map<String, int>.from(s.cart);
      final newQty = (newCart[event.productId] ?? 0) + event.delta;
      if (newQty <= 0) {
        newCart.remove(event.productId);
      } else {
        newCart[event.productId] = newQty;
      }
      emit(_calculateTotals(
        products: s.products,
        filteredProducts: s.filteredProducts,
        saleType: s.saleType,
        cart: newCart,
        selectedClient: s.selectedClient,
        timbreFiscalEnabled: s.timbreFiscalEnabled,
        storeId: s.storeId,
      ));
    }
  }

  void _onSetClient(SetClient event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      emit((state as SalesUpdated).copyWith(selectedClient: event.client));
    }
  }

  void _onToggleTimbreFiscal(ToggleTimbreFiscal event, Emitter<SalesState> emit) {
    if (state is SalesUpdated) {
      final s = state as SalesUpdated;
      emit(_calculateTotals(
        products: s.products,
        filteredProducts: s.filteredProducts,
        saleType: s.saleType,
        cart: s.cart,
        selectedClient: s.selectedClient,
        timbreFiscalEnabled: event.isEnabled,
        storeId: s.storeId,
      ));
    }
  }

  Future<void> _onSubmitSale(SubmitSale event, Emitter<SalesState> emit) async {
    if (state is! SalesUpdated) return;
    final s = state as SalesUpdated;

    if (['bon_livraison', 'bon_commande', 'gros', 'gouvernement'].contains(s.saleType) &&
        s.selectedClient == null) {
      emit(SalesError('Client is required for this sale type'));
      emit(s);
      return;
    }

    if (s.cart.isEmpty) {
      emit(SalesError('Cart is empty'));
      emit(s);
      return;
    }

    emit(SalesSubmitting(
      products: s.products,
      filteredProducts: s.filteredProducts,
      saleType: s.saleType,
      cart: s.cart,
      selectedClient: s.selectedClient,
      timbreFiscalEnabled: s.timbreFiscalEnabled,
      storeId: s.storeId,
      totalHt: s.totalHt,
      tvaBreakdown: s.tvaBreakdown,
      totalTva: s.totalTva,
      subtotalTtc: s.subtotalTtc,
      timbreFiscal: s.timbreFiscal,
      grandTotalTtc: s.grandTotalTtc,
    ));

    try {
      final user = _supabase.auth.currentUser;

      List<Map<String, dynamic>> items = [];
      s.cart.forEach((id, qty) {
        final p = s.products.firstWhere((p) => p['id'] == id);
        final priceHt = _getPriceForType(p, s.saleType);
        final tvaRate = _getTvaRate(p);
        final itemTva = priceHt * (tvaRate / 100);
        final priceTtc = priceHt + itemTva;
        items.add({
          'product_id':    id,
          'quantity':      qty,
          'unit_price_ht': priceHt,
          'tva_rate':      tvaRate,
          'unit_price_ttc': priceTtc,
          'total_ht':      priceHt * qty,
          'total_ttc':     priceTtc * qty,
          'discount_percent': 0,
        });
      });

      final payload = {
        'sale': {
          'sale_type':    s.saleType,
          'worker_id':    user?.id,
          'client_id':    s.selectedClient?['id'],
          'store_id':     s.storeId,          // ← store isolation
          'total_ht':     s.totalHt,
          'tva_amount':   s.totalTva,
          'timbre_fiscal': s.timbreFiscal,
          'total_ttc':    s.grandTotalTtc,
          'notes':        'POS Sale',
        },
        'items': items,
      };

      final response = await _supabase.rpc('process_pos_sale', params: {'payload': payload});
      
      final String saleId = response is Map ? response['sale_id'] as String : response.toString();
      
      if (event.amountPaid != null && event.amountPaid! > 0 && s.selectedClient != null) {
        await _supabase.from('client_payments').insert({
          'client_id': s.selectedClient!['id'],
          'store_id': s.storeId,
          'sale_id': saleId,
          'amount': event.amountPaid,
          'payment_method': 'cash',
          'notes': 'POS Checkout Payment',
        });
        
        await _supabase.from('sales').update({'amount_paid': event.amountPaid}).eq('id', saleId);
      }

      emit(SalesSuccess(saleId, s.grandTotalTtc));
    } catch (e) {
      emit(SalesError(e.toString()));
      emit(s);
    }
  }

  void _onResetSale(ResetSale event, Emitter<SalesState> emit) {
    emit(SalesInitial());
    add(LoadProducts(event.storeId));
  }

  // ─── Math Helpers ─────────────────────────────────────────────────────────

  double _getPriceForType(Map<String, dynamic> product, String saleType) {
    final pricing = product['product_pricing'];
    if (pricing == null) return 0.0;
    final double rawPrice = saleType == 'detail'
        ? (pricing['prix_vente_detail_ht'] as num?)?.toDouble() ?? 0.0
        : (pricing['prix_vente_gros_ht'] as num?)?.toDouble() ?? 0.0;
    return (rawPrice / 5).roundToDouble() * 5;
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
    required String storeId,
  }) {
    double totalHt = 0;
    Map<double, double> tvaBreakdown = {};

    cart.forEach((id, qty) {
      final p = products.firstWhere((p) => p['id'] == id);
      final priceHt = _getPriceForType(p, saleType);
      final rate = _getTvaRate(p);
      final itemHt = priceHt * qty;
      final itemTva = itemHt * (rate / 100);
      totalHt += itemHt;
      tvaBreakdown[rate] = (tvaBreakdown[rate] ?? 0) + itemTva;
    });

    final totalTva = tvaBreakdown.values.fold(0.0, (a, b) => a + b);
    final subtotalTtc = totalHt + totalTva;
    final timbreFiscal = timbreFiscalEnabled ? subtotalTtc * 0.01 : 0.0;
    final grandTotalTtc = subtotalTtc + timbreFiscal;

    return SalesUpdated(
      products: products,
      filteredProducts: filteredProducts,
      saleType: saleType,
      cart: cart,
      selectedClient: selectedClient,
      timbreFiscalEnabled: timbreFiscalEnabled,
      storeId: storeId,
      totalHt: totalHt,
      tvaBreakdown: tvaBreakdown,
      totalTva: totalTva,
      subtotalTtc: subtotalTtc,
      timbreFiscal: timbreFiscal,
      grandTotalTtc: grandTotalTtc,
    );
  }
}
