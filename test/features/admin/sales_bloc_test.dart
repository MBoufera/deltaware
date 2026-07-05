import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/features/admin/presentation/bloc/sales/sales_bloc.dart';
import 'package:deltaware/features/admin/presentation/bloc/sales/sales_event.dart';
import 'package:deltaware/features/admin/presentation/bloc/sales/sales_state.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late SalesBloc salesBloc;

  final testProduct = {
    'id': '1',
    'name_fr': 'Test Product',
    'ref_code': 'P001',
    'product_pricing': {
      'prix_vente_gros_ht': 100.0,
      'prix_vente_detail_ht': 150.0,
      'tva_rate': 19.0,
    },
  };

  final initialStateWithProducts = SalesUpdated(
    products: [testProduct],
    filteredProducts: [testProduct],
    saleType: 'detail',
    cart: const {},
    selectedClient: null,
    timbreFiscalEnabled: false,
    storeId: 'test-store-id',
    totalHt: 0.0,
    tvaBreakdown: const {},
    totalTva: 0.0,
    subtotalTtc: 0.0,
    timbreFiscal: 0.0,
    grandTotalTtc: 0.0,
  );

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    salesBloc = SalesBloc(mockSupabaseClient);
  });

  tearDown(() {
    salesBloc.close();
  });

  group('SalesBloc - Cart Math & Logic', () {
    test('initial state is SalesInitial', () {
      expect(salesBloc.state, isA<SalesInitial>());
    });

    blocTest<SalesBloc, SalesState>(
      'AddItemToCart adds item and recalculates totals correctly (Detail)',
      build: () => salesBloc,
      seed: () => initialStateWithProducts,
      act: (bloc) => bloc.add(AddItemToCart(testProduct)),
      expect: () => [
        isA<SalesUpdated>()
            .having((s) => s.cart, 'cart', {'1': 1})
            .having((s) => s.totalHt, 'totalHt', 150.0) // Detail HT price
            .having((s) => s.totalTva, 'totalTva', 150.0 * 0.19)
            .having((s) => s.grandTotalTtc, 'grandTotalTtc', 150.0 * 1.19),
      ],
    );

    blocTest<SalesBloc, SalesState>(
      'UpdateItemQty increases quantity and recalculates (Detail)',
      build: () => salesBloc,
      seed: () => initialStateWithProducts.copyWith(cart: {'1': 1}),
      act: (bloc) => bloc.add(const UpdateItemQty('1', 1)), // +1
      expect: () => [
        isA<SalesUpdated>()
            .having((s) => s.cart, 'cart', {'1': 2})
            .having((s) => s.totalHt, 'totalHt', 300.0)
      ],
    );

    blocTest<SalesBloc, SalesState>(
      'UpdateItemQty to <= 0 removes the item from cart',
      build: () => salesBloc,
      seed: () => initialStateWithProducts.copyWith(cart: {'1': 1}),
      act: (bloc) => bloc.add(const UpdateItemQty('1', -1)),
      expect: () => [
        isA<SalesUpdated>()
            .having((s) => s.cart, 'cart', isEmpty)
            .having((s) => s.totalHt, 'totalHt', 0.0)
      ],
    );

    blocTest<SalesBloc, SalesState>(
      'SelectSaleType to Gros recalculates using Gros price',
      build: () => salesBloc,
      seed: () => initialStateWithProducts.copyWith(cart: {'1': 1}), // Currently detail: 150 HT
      act: (bloc) => bloc.add(const SelectSaleType('gros')),
      expect: () => [
        isA<SalesUpdated>()
            .having((s) => s.saleType, 'saleType', 'gros')
            .having((s) => s.totalHt, 'totalHt', 100.0) // Gros HT price
      ],
    );

    blocTest<SalesBloc, SalesState>(
      'ToggleTimbreFiscal adds 1% to grandTotalTtc',
      build: () => salesBloc,
      seed: () => initialStateWithProducts.copyWith(cart: {'1': 1}), // Detail: 150 HT, 178.5 TTC
      act: (bloc) => bloc.add(const ToggleTimbreFiscal(true)),
      expect: () => [
        isA<SalesUpdated>()
            .having((s) => s.timbreFiscalEnabled, 'timbreFiscalEnabled', true)
            .having((s) => s.timbreFiscal, 'timbreFiscal', (150.0 * 1.19) * 0.01)
            .having((s) => s.grandTotalTtc, 'grandTotalTtc', (150.0 * 1.19) * 1.01),
      ],
    );
  });
}
