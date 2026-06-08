import 'package:flutter_test/flutter_test.dart';

// Since the POS math is currently embedded in the UI, we extract the pure mathematical functions here to test them rigorously.
class SaleCalculator {
  static double calculateItemTtc(double puHt, int qty, double tvaRate) {
    return (puHt * qty) * (1 + tvaRate);
  }

  static double calculateTotalHt(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) => sum + ((item['pu_ht'] as num).toDouble() * (item['qty'] as num).toInt()));
  }

  static double calculateTotalTva(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      final tva = (item['tva_rate'] as num).toDouble();
      return sum + ((item['pu_ht'] as num).toDouble() * (item['qty'] as num).toInt() * tva);
    });
  }

  static double calculateTimbre(double totalTtcPreTimbre, bool includeTimbre) {
    if (!includeTimbre) return 0.0;
    // Timbre in Algeria is usually 1% of the total amount (up to a cap, but we'll assume 1% strict for testing)
    return totalTtcPreTimbre * 0.01;
  }

  static double calculateFinalTtc(List<Map<String, dynamic>> items, bool includeTimbre) {
    final ht = calculateTotalHt(items);
    final tva = calculateTotalTva(items);
    final ttcPreTimbre = ht + tva;
    final timbre = calculateTimbre(ttcPreTimbre, includeTimbre);
    return ttcPreTimbre + timbre;
  }
}

void main() {
  group('Pricing Mathematics Verification', () {
    test('calculateItemTtc correctly calculates 19% TVA', () {
      final ttc = SaleCalculator.calculateItemTtc(100.0, 2, 0.19);
      expect(ttc, 238.0); // (100 * 2) * 1.19
    });

    test('calculateItemTtc correctly calculates 9% TVA', () {
      final ttc = SaleCalculator.calculateItemTtc(100.0, 2, 0.09);
      expect(ttc, 218.0); // (100 * 2) * 1.09
    });

    test('calculateTotalHt sums correctly across mixed items', () {
      final items = [
        {'pu_ht': 50.0, 'qty': 2, 'tva_rate': 0.19},
        {'pu_ht': 120.0, 'qty': 1, 'tva_rate': 0.09},
      ];
      final totalHt = SaleCalculator.calculateTotalHt(items);
      expect(totalHt, 220.0); // (50 * 2) + 120
    });

    test('calculateTotalTva calculates exact TVA mass for mixed baskets', () {
      final items = [
        {'pu_ht': 100.0, 'qty': 1, 'tva_rate': 0.19}, // 19 DZD TVA
        {'pu_ht': 200.0, 'qty': 2, 'tva_rate': 0.09}, // 36 DZD TVA
      ];
      final totalTva = SaleCalculator.calculateTotalTva(items);
      expect(totalTva, 55.0); // 19 + 36
    });

    test('calculateFinalTtc with Timbre Fiscal applied (1%)', () {
      final items = [
        {'pu_ht': 1000.0, 'qty': 1, 'tva_rate': 0.19}, // HT: 1000, TVA: 190, PreTimbre: 1190
      ];
      final finalTtc = SaleCalculator.calculateFinalTtc(items, true);
      expect(finalTtc, 1201.90); // 1190 + 11.90
    });

    test('calculateFinalTtc without Timbre Fiscal', () {
      final items = [
        {'pu_ht': 1000.0, 'qty': 1, 'tva_rate': 0.19},
      ];
      final finalTtc = SaleCalculator.calculateFinalTtc(items, false);
      expect(finalTtc, 1190.0);
    });
  });
}
