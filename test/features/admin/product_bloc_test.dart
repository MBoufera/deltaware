import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/features/admin/presentation/bloc/product/product_bloc.dart';
import 'package:deltaware/features/admin/presentation/bloc/product/product_event.dart';
import 'package:deltaware/features/admin/presentation/bloc/product/product_state.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakePostgrestFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final FutureOr<T> Function() _valueFn;

  FakePostgrestFilterBuilder(T value) : _valueFn = (() => value);
  FakePostgrestFilterBuilder.error(Object error) : _valueFn = (() => throw error);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> order(String column, {bool? ascending, bool? nullsFirst, String? referencedTable}) => this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) async {
    try {
      final val = await _valueFn();
      final result = onValue(val);
      if (result is Future<R>) {
        return await result;
      }
      return result;
    } catch (e, stackTrace) {
      if (onError != null) {
        final errResult = onError(e, stackTrace);
        if (errResult is Future<R>) {
          return await errResult;
        }
        return errResult as R;
      }
      rethrow;
    }
  }
}

void main() {
  group('ProductBloc', () {
    late ProductBloc productBloc;
    late MockSupabaseClient mockSupabaseClient;
    late MockSupabaseQueryBuilder mockProductsQuery;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockProductsQuery = MockSupabaseQueryBuilder();

      when(() => mockSupabaseClient.from('products')).thenAnswer((_) => mockProductsQuery);
    });

    tearDown(() {
      productBloc.close();
    });

    test('initial state is ProductInitial', () {
      productBloc = ProductBloc(supabase: mockSupabaseClient);
      expect(productBloc.state, isA<ProductInitial>());
    });

    blocTest<ProductBloc, ProductState>(
      'emits [ProductLoading, ProductsLoaded] when LoadProducts is successful',
      build: () {
        productBloc = ProductBloc(supabase: mockSupabaseClient);
        final dummyProducts = [
          {
            'id': '1',
            'name_fr': 'Laptop',
            'categories': {'name_fr': 'Informatique'},
            'product_pricing': {'prix_achat_super_gros': 100.0, 'prix_vente_gros_ht': 110.0, 'prix_vente_detail_ht': 130.0, 'tva_rate': 19.0},
            'stock': {'qty_detail': 10.0, 'alert_threshold': 5.0}
          }
        ];
        
        when(() => mockProductsQuery.select('*, categories(name_fr), product_pricing(*), stock(*)')).thenAnswer(
          (_) => FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(dummyProducts),
        );
        return productBloc;
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
        productBloc = ProductBloc(supabase: mockSupabaseClient);
        when(() => mockProductsQuery.select('*, categories(name_fr), product_pricing(*), stock(*)')).thenAnswer(
          (_) => FakePostgrestFilterBuilder<List<Map<String, dynamic>>>.error(Exception('Database error')),
        );
        return productBloc;
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
        productBloc = ProductBloc(supabase: mockSupabaseClient);
        when(() => mockProductsQuery.delete()).thenAnswer(
          (_) => FakePostgrestFilterBuilder<dynamic>([]),
        );
        return productBloc;
      },
      act: (bloc) => bloc.add(const DeleteProduct('1')),
      expect: () => [
        isA<ProductLoading>(),
        isA<ProductOperationSuccess>(),
      ],
    );
  });
}
