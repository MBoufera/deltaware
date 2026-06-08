import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfGeneratorService {
  static Future<Uint8List> generatePdf(Map<String, dynamic> saleData, Map<String, dynamic> storeSettings) async {
    final pdf = pw.Document();

    final saleType = saleData['sale_type'] ?? 'detail';
    String documentTitle = 'FACTURE';
    if (saleType == 'bon_livraison') documentTitle = 'BON DE LIVRAISON';
    if (saleType == 'bon_commande') documentTitle = 'BON DE COMMANDE';

    final client = saleData['clients'];
    final items = List<dynamic>.from(saleData['sale_items'] ?? []);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return _buildHeader(documentTitle, saleData['sale_number'], saleData['created_at'], storeSettings);
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Document généré par Deltaware POS', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                  pw.Text('Page ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                ]
              )
            ]
          );
        },
        build: (pw.Context context) => [
          _buildClientSection(client),
          pw.SizedBox(height: 24),
          _buildItemsTable(items, saleType),
          pw.SizedBox(height: 16),
          _buildTotalsSection(saleData),
          pw.SizedBox(height: 48),
          _buildSignatures(),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(String title, String? number, String? dateStr, Map<String, dynamic> settings) {
    final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Company Info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(settings['name']?.toString() ?? 'DELTAWARE STATIONARY', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text(settings['subtitle']?.toString() ?? 'Vente en Gros et Détail', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Text('Adresse: ${settings['address'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Tél: ${settings['phone'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Text('RC: ${settings['rc'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('NIF: ${settings['nif'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('AI: ${settings['ai'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('NIS: ${settings['nis'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            // Document Info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.SizedBox(height: 8),
                  pw.Text('N°: ${number ?? "-"}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ${formatter.format(date)}', style: const pw.TextStyle(fontSize: 12)),
                ]
              )
            )
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Divider(color: PdfColors.blue900, thickness: 2),
        pw.SizedBox(height: 16),
      ]
    );
  }

  static pw.Widget _buildClientSection(Map<String, dynamic>? client) {
    if (client == null) {
      return pw.Text('Client: Comptoir (Client Passager)', style: const pw.TextStyle(fontSize: 12));
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Doit à:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(client['name'] ?? '', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Adresse: ${client['address'] ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
            ]
          ),
          if (client['type'] != 'particulier') pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('RC: ${client['rc'] ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('NIF: ${client['nif'] ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('NIS: ${client['nis'] ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('AI: ${client['ai'] ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
            ]
          )
        ]
      )
    );
  }

  static pw.Widget _buildItemsTable(List<dynamic> items, String saleType) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.all(6),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      headers: ['Réf', 'Désignation', 'Qté', 'PU HT', 'TVA', 'Montant TTC'],
      data: items.map((item) {
        final product = item['products'] ?? {};
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final puHt = (item['unit_price_ht'] as num?)?.toDouble() ?? 0;
        final tvaRate = (item['tva_rate'] as num?)?.toDouble() ?? 0;
        final ttc = (item['total_ttc'] as num?)?.toDouble() ?? 0;
        
        return [
          product['ref_code'] ?? '-',
          product['name_fr'] ?? 'Article inconnu',
          qty.toStringAsFixed(0),
          puHt.toStringAsFixed(2),
          '$tvaRate%',
          ttc.toStringAsFixed(2),
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildTotalsSection(Map<String, dynamic> saleData) {
    final ht = (saleData['total_ht'] as num?)?.toDouble() ?? 0;
    final tva = (saleData['tva_amount'] as num?)?.toDouble() ?? 0;
    final timbre = (saleData['timbre_fiscal'] as num?)?.toDouble() ?? 0;
    final ttc = (saleData['total_ttc'] as num?)?.toDouble() ?? 0;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          child: pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
            },
            data: [
              ['Total HT', ht.toStringAsFixed(2)],
              ['TVA', tva.toStringAsFixed(2)],
              if (timbre > 0) ['Timbre Fiscal', timbre.toStringAsFixed(2)],
              ['Total TTC en DZD', ttc.toStringAsFixed(2)],
            ],
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))
            ),
          ),
        ),
      ]
    );
  }

  static pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Signature Client', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 50),
          ]
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Cachet et Signature', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 50),
          ]
        ),
      ]
    );
  }
}
