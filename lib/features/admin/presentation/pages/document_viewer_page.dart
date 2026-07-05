import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import '../../../../core/services/pdf_generator_service.dart';

class DocumentViewerPage extends StatefulWidget {
  final String saleId;
  
  const DocumentViewerPage({super.key, required this.saleId});

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      // 1. Fetch Sale Data with Joins
      final data = await _supabase
          .from('sales')
          .select('*, clients(*), sale_items(*, products(name_fr, ref_code))')
          .eq('id', widget.saleId)
          .single();

      // 2. Fetch Store Settings dynamically based on sale's store_id
      final storeId = data['store_id'];
      Map<String, dynamic> settings;
      if (storeId != null) {
        settings = await _supabase
            .from('stores')
            .select()
            .eq('id', storeId)
            .single();
      } else {
        // Fallback for legacy sales: query first store
        final storesList = await _supabase.from('stores').select().order('created_at').limit(1);
        if (storesList.isNotEmpty) {
          settings = List<Map<String, dynamic>>.from(storesList).first;
        } else {
          settings = await _supabase.from('store_settings').select().eq('id', 1).single();
        }
      }

      // 3. Generate PDF Bytes
      final bytes = await PdfGeneratorService.generatePdf(data, settings);

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating document: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Viewer'),
        backgroundColor: const Color(0xFF1A2A32),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfBytes == null
              ? const Center(child: Text('Failed to generate document'))
              : PdfPreview(
                  build: (format) => _pdfBytes!,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                ),
    );
  }
}
