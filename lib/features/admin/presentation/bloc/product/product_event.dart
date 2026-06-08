import 'package:equatable/equatable.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductEvent {
  final String? search;
  final String? categoryId;

  const LoadProducts({this.search, this.categoryId});

  @override
  List<Object?> get props => [search, categoryId];
}

class CreateProduct extends ProductEvent {
  final String nameFr;
  final String? nameAr;
  final String? refCode;
  final String categoryName;
  final double purchasePrice;
  final double tva;
  final double wholesaleMargin;
  final double retailMultiplier;

  const CreateProduct({
    required this.nameFr,
    this.nameAr,
    this.refCode,
    required this.categoryName,
    required this.purchasePrice,
    required this.tva,
    required this.wholesaleMargin,
    required this.retailMultiplier,
  });

  @override
  List<Object?> get props => [
        nameFr,
        nameAr,
        refCode,
        categoryName,
        purchasePrice,
        tva,
        wholesaleMargin,
        retailMultiplier,
      ];
}

class DeleteProduct extends ProductEvent {
  final String id;

  const DeleteProduct(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateStock extends ProductEvent {
  final String productId;
  final double qtySuperGros;
  final double qtyGros;
  final double qtyDetail;
  final double alertThreshold;

  const UpdateStock({
    required this.productId,
    required this.qtySuperGros,
    required this.qtyGros,
    required this.qtyDetail,
    required this.alertThreshold,
  });

  @override
  List<Object?> get props => [
        productId,
        qtySuperGros,
        qtyGros,
        qtyDetail,
        alertThreshold,
      ];
}
