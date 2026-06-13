import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/features/admin/presentation/bloc/product/product_bloc.dart';
import 'package:deltaware/features/admin/presentation/bloc/product/product_event.dart';
import 'package:deltaware/features/admin/presentation/bloc/product/product_state.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

void main() {
  group('ProductBloc', () {
    ProductBloc? productBloc;
    late MockSupabaseClient mockSupabaseClient;
    late MockSupabaseQueryBuilder mockProductsQuery;
    late MockPostgrestFilterBuilder mockFilterBuilder;
    late MockPostgrestTransformBuilder mockTransformBuilder;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockProductsQuery = MockSupabaseQueryBuilder();
      mockFilterBuilder = MockPostgrestFilterBuilder();
      mockTransformBuilder = MockPostgrestTransformBuilder();

      when(() => mockSupabaseClient.from('products')).thenAnswer((_) => mockProductsQuery);
      when(() => mockProductsQuery.select(any())).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.order('created_at', ascending: false)).thenAnswer((_) => mockTransformBuilder);
    });

    tearDown(() {
      productBloc?.close();
    });

    test('initial state is ProductInitial', () {
      productBloc = ProductBloc(supabase: mockSupabaseClient);
      expect(productBloc!.state, isA<ProductInitial>());
    });

    blocTest<ProductBloc, ProductState>(
      'emits [ProductLoading, ProductsLoaded] when LoadProducts is successful',
      build: () {
        final dummyProducts = [
          {
            'id': '1',
            'name_fr': 'Laptop',
            'categories': {'name_fr': 'Informatique'},
            'product_pricing': {'prix_achat_super_gros': 100.0, 'prix_vente_gros_ht': 110.0, 'prix_vente_detail_ht': 130.0, 'tva_rate': 19.0},
            'stock': {'qty_detail': 10.0, 'alert_threshold': 5.0}
          }
        ];
        when(() => mockTransformBuilder.then(any())).thenAnswer((invocation) {
          final callback = invocation.positionalArguments[0] as Function;
          return Future.value(callback(dummyProducts));
        });
        return ProductBloc(supabase: mockSupabaseClient);
      },
      act: (bloc) => bloc.add(const LoadProducts()),
      expect: () => [
        isA<ProductLoading>(),
        isA<ProductsLoaded>(),
      ],
    );

    blocTest<ProductBloc, ProductState>(
      'emits [ProductLoading, ProductError] when LoadProducts fails',
      build: () {
        when(() => mockTransformBuilder.then(any())).thenAnswer(
          (_) => Future.error(Exception('Database error')),
        );
        return ProductBloc(supabase: mockSupabaseClient);
      },
      act: (bloc) => bloc.add(const LoadProducts()),
      expect: () => [
        isA<ProductLoading>(),
        isA<ProductError>(),
      ],
    );

    blocTest<ProductBloc, ProductState>(
      'emits [ProductLoading, ProductOperationSuccess] when DeleteProduct is successful',
      build: () {
        when(() => mockProductsQuery.delete()).thenAnswer((_) => mockFilterBuilder);
        when(() => mockFilterBuilder.eq(any(), any())).thenAnswer((_) => mockFilterBuilder);
        when(() => mockFilterBuilder.then(any())).thenAnswer((invocation) {
          final callback = invocation.positionalArguments[0] as Function;
          return Future.value(callback([]));
        });
        return ProductBloc(supabase: mockSupabaseClient);
      },
      act: (bloc) => bloc.add(const DeleteProduct('1')),
      expect: () => [
        isA<ProductLoading>(),
        isA<ProductOperationSuccess>(),
      ],
    );
  });
}
