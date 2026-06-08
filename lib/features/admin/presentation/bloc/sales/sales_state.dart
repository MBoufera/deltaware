import 'package:equatable/equatable.dart';

abstract class SalesState extends Equatable {
  const SalesState();

  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {}

class SalesLoading extends SalesState {}

class SalesUpdated extends SalesState {
  final List<dynamic> products;
  final List<dynamic> filteredProducts;
  final String saleType;
  final Map<String, int> cart;
  final Map<String, dynamic>? selectedClient;
  final bool timbreFiscalEnabled;
  
  // Computed totals
  final double totalHt;
  final Map<double, double> tvaBreakdown;
  final double totalTva;
  final double subtotalTtc;
  final double timbreFiscal;
  final double grandTotalTtc;

  const SalesUpdated({
    required this.products,
    required this.filteredProducts,
    required this.saleType,
    required this.cart,
    this.selectedClient,
    required this.timbreFiscalEnabled,
    required this.totalHt,
    required this.tvaBreakdown,
    required this.totalTva,
    required this.subtotalTtc,
    required this.timbreFiscal,
    required this.grandTotalTtc,
  });

  SalesUpdated copyWith({
    List<dynamic>? products,
    List<dynamic>? filteredProducts,
    String? saleType,
    Map<String, int>? cart,
    Map<String, dynamic>? selectedClient,
    bool? timbreFiscalEnabled,
    double? totalHt,
    Map<double, double>? tvaBreakdown,
    double? totalTva,
    double? subtotalTtc,
    double? timbreFiscal,
    double? grandTotalTtc,
  }) {
    return SalesUpdated(
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      saleType: saleType ?? this.saleType,
      cart: cart ?? this.cart,
      selectedClient: selectedClient ?? this.selectedClient,
      timbreFiscalEnabled: timbreFiscalEnabled ?? this.timbreFiscalEnabled,
      totalHt: totalHt ?? this.totalHt,
      tvaBreakdown: tvaBreakdown ?? this.tvaBreakdown,
      totalTva: totalTva ?? this.totalTva,
      subtotalTtc: subtotalTtc ?? this.subtotalTtc,
      timbreFiscal: timbreFiscal ?? this.timbreFiscal,
      grandTotalTtc: grandTotalTtc ?? this.grandTotalTtc,
    );
  }

  @override
  List<Object?> get props => [
        products,
        filteredProducts,
        saleType,
        cart,
        selectedClient,
        timbreFiscalEnabled,
        totalHt,
        tvaBreakdown,
        totalTva,
        subtotalTtc,
        timbreFiscal,
        grandTotalTtc,
      ];
}

class SalesSubmitting extends SalesUpdated {
  const SalesSubmitting({
    required super.products,
    required super.filteredProducts,
    required super.saleType,
    required super.cart,
    super.selectedClient,
    required super.timbreFiscalEnabled,
    required super.totalHt,
    required super.tvaBreakdown,
    required super.totalTva,
    required super.subtotalTtc,
    required super.timbreFiscal,
    required super.grandTotalTtc,
  });
}

class SalesSuccess extends SalesState {
  final Map<String, dynamic> response;
  final double totalTtc;

  const SalesSuccess(this.response, this.totalTtc);

  @override
  List<Object?> get props => [response, totalTtc];
}

class SalesError extends SalesState {
  final String message;

  const SalesError(this.message);

  @override
  List<Object?> get props => [message];
}
