import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final SupabaseClient _supabase;

  ProductBloc({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(ProductInitial()) {
    
    on<LoadProducts>((event, emit) async {
      emit(ProductLoading());
      try {
        var query = _supabase.from('products').select('*, categories(name_fr), product_pricing(*), stock(*)');
        if (event.categoryId != null) {
          query = query.eq('category_id', event.categoryId!);
        }
        
        final data = await query.order('created_at', ascending: false);
        final productsList = List<Map<String, dynamic>>.from(data);
        
        if (event.search != null && event.search!.isNotEmpty) {
          final searchLower = event.search!.toLowerCase();
          final filtered = productsList.where((p) {
            final name = (p['name_fr'] ?? '').toString().toLowerCase();
            final ref = (p['ref_code'] ?? '').toString().toLowerCase();
            final cat = (p['categories']?['name_fr'] ?? '').toString().toLowerCase();
            return name.contains(searchLower) || ref.contains(searchLower) || cat.contains(searchLower);
          }).toList();
          emit(ProductsLoaded(filtered));
        } else {
          emit(ProductsLoaded(productsList));
        }
      } catch (e) {
        emit(ProductError('Failed to load products: $e'));
      }
    });

    on<CreateProduct>((event, emit) async {
      emit(ProductLoading());
      try {
        final categoryName = event.categoryName.isEmpty ? 'Uncategorized' : event.categoryName;
        
        // Find or create category
        var categoryResponse = await _supabase.from('categories').select('id').eq('name_fr', categoryName).maybeSingle();
        String categoryId;
        if (categoryResponse == null) {
          final newCat = await _supabase.from('categories').insert({'name_fr': categoryName}).select('id').single();
          categoryId = newCat['id'];
        } else {
          categoryId = categoryResponse['id'];
        }
        
        // Insert product
        final productResponse = await _supabase.from('products').insert({
          'name_fr': event.nameFr,
          'name_ar': event.nameAr,
          'ref_code': event.refCode?.isEmpty ?? true ? null : event.refCode,
          'category_id': categoryId,
          'contenance': event.contenance,
        }).select('id').single();
        final productId = productResponse['id'];
        
        // Calculate retail margin percent
        final margeDetail = (event.retailMultiplier - 1.0) * 100;
        
        // Insert product pricing
        await _supabase.from('product_pricing').insert({
          'product_id': productId,
          'prix_achat_super_gros': event.purchasePrice,
          'marge_gros_percent': event.wholesaleMargin,
          'marge_detail_percent': margeDetail,
          'tva_rate': event.tva,
        });
        
        // Insert stock entry
        await _supabase.from('stock').insert({
          'product_id': productId,
          'qty_super_gros': event.qtySuperGros,
          'qty_gros': event.qtyGros,
          'qty_detail': event.qtyDetail + (event.qtyGros * event.contenance),
          'alert_threshold': event.alertThreshold,
        });
        
        emit(ProductOperationSuccess());
      } catch (e) {
        emit(ProductError('Failed to create product: $e'));
      }
    });

    on<UpdateProduct>((event, emit) async {
      emit(ProductLoading());
      try {
        final categoryName = event.categoryName.isEmpty ? 'Uncategorized' : event.categoryName;
        
        // Find or create category
        var categoryResponse = await _supabase.from('categories').select('id').eq('name_fr', categoryName).maybeSingle();
        String categoryId;
        if (categoryResponse == null) {
          final newCat = await _supabase.from('categories').insert({'name_fr': categoryName}).select('id').single();
          categoryId = newCat['id'];
        } else {
          categoryId = categoryResponse['id'];
        }
        
        // Update product
        await _supabase.from('products').update({
          'name_fr': event.nameFr,
          'name_ar': event.nameAr,
          'ref_code': event.refCode?.isEmpty ?? true ? null : event.refCode,
          'category_id': categoryId,
          'contenance': event.contenance,
        }).eq('id', event.id);
        
        // Calculate retail margin percent
        final margeDetail = (event.retailMultiplier - 1.0) * 100;
        
        // Update product pricing
        await _supabase.from('product_pricing').update({
          'prix_achat_super_gros': event.purchasePrice,
          'marge_gros_percent': event.wholesaleMargin,
          'marge_detail_percent': margeDetail,
          'tva_rate': event.tva,
        }).eq('product_id', event.id);
        
        emit(ProductOperationSuccess());
      } catch (e) {
        emit(ProductError('Failed to update product: $e'));
      }
    });

    on<DeleteProduct>((event, emit) async {
      emit(ProductLoading());
      try {
        await _supabase.from('products').delete().eq('id', event.id);
        emit(ProductOperationSuccess());
      } catch (e) {
        emit(ProductError('Failed to delete product: $e'));
      }
    });

    on<UpdateStock>((event, emit) async {
      emit(ProductLoading());
      try {
        await _supabase.from('stock').upsert({
          'product_id': event.productId,
          'qty_super_gros': event.qtySuperGros,
          'qty_gros': event.qtyGros,
          'qty_detail': event.qtyDetail,
          'alert_threshold': event.alertThreshold,
        });
        emit(ProductOperationSuccess());
      } catch (e) {
        emit(ProductError('Failed to update stock: $e'));
      }
    });
  }
}
