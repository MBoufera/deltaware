import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';
import '../../../../features/store/presentation/bloc/store_event.dart';
import '../../../../features/store/presentation/bloc/store_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _rcCtrl = TextEditingController();
  final _nifCtrl = TextEditingController();
  final _nisCtrl = TextEditingController();
  final _aiCtrl = TextEditingController();
  bool _enableTimbre = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtitleCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _rcCtrl.dispose();
    _nifCtrl.dispose();
    _nisCtrl.dispose();
    _aiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Prefer store from StoreBloc (multi-store) — fall back to store_settings id=1 (legacy)
    final storeState = context.read<StoreBloc>().state;
    String? storeId;
    if (storeState is StoresLoaded) storeId = storeState.selectedStore?.id;

    try {
      Map<String, dynamic>? data;

      if (storeId != null) {
        data = await _supabase
            .from('stores')
            .select()
            .eq('id', storeId)
            .single();
      } else {
        // Legacy fallback
        data = await _supabase
            .from('store_settings')
            .select()
            .eq('id', 1)
            .single();
      }

      _nameCtrl.text     = data['name'] ?? '';
      _subtitleCtrl.text = data['subtitle'] ?? '';
      _addressCtrl.text  = data['address'] ?? '';
      _phoneCtrl.text    = data['phone'] ?? '';
      _rcCtrl.text       = data['rc'] ?? '';
      _nifCtrl.text      = data['nif'] ?? '';
      _nisCtrl.text      = data['nis'] ?? '';
      _aiCtrl.text       = data['ai'] ?? '';
      _enableTimbre      = (data['enable_timbre'] as bool?) ?? false;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final storeState = context.read<StoreBloc>().state;
      String? storeId;
      if (storeState is StoresLoaded) storeId = storeState.selectedStore?.id;

      if (storeId != null) {
        // Use the multi-store RPC to ensure proper permissions check
        context.read<StoreBloc>().add(UpdateCurrentStore(
              name:         _nameCtrl.text,
              subtitle:     _subtitleCtrl.text,
              address:      _addressCtrl.text,
              phone:        _phoneCtrl.text,
              nif:          _nifCtrl.text,
              nis:          _nisCtrl.text,
              rc:           _rcCtrl.text,
              ai:           _aiCtrl.text,
              enableTimbre: _enableTimbre,
            ));
      } else {
        // Legacy fallback
        await _supabase.from('store_settings').update({
          'name':     _nameCtrl.text,
          'subtitle': _subtitleCtrl.text,
          'address':  _addressCtrl.text,
          'phone':    _phoneCtrl.text,
          'rc':       _rcCtrl.text,
          'nif':      _nifCtrl.text,
          'nis':      _nisCtrl.text,
          'ai':       _aiCtrl.text,
        }).eq('id', 1);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: BlocBuilder<StoreBloc, StoreState>(
          builder: (context, storeState) {
            final storeName = storeState is StoresLoaded
                ? storeState.selectedStore?.name
                : null;
            return Text(
              storeName != null ? 'Settings — $storeName' : 'Store Configuration',
            );
          },
        ),
        backgroundColor: const Color(0xFF1A2A32),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Company Identity',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2A32),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'These details will appear on all generated PDFs and Receipts',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nom du Magasin',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _subtitleCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Sous-titre / Spécialité',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _addressCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Adresse Complète',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Timbre Fiscal toggle
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Timbre Fiscal (1%)',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Text(
                                  'Ajoute automatiquement 1% sur les factures B2B.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _enableTimbre,
                            onChanged: (v) => setState(() => _enableTimbre = v),
                            activeThumbColor: const Color(0xFF1A2A32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Informations Légales',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rcCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Registre de Commerce (RC)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _nifCtrl,
                              decoration: const InputDecoration(
                                labelText: 'NIF',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nisCtrl,
                              decoration: const InputDecoration(
                                labelText: 'NIS',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _aiCtrl,
                              decoration: const InputDecoration(
                                labelText: "Article d'Imposition (AI)",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2A32),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Enregistrer les Paramètres',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
