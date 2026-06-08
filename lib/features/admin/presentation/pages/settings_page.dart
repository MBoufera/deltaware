import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _supabase.from('store_settings').select().eq('id', 1).single();
      _nameCtrl.text = data['name'] ?? '';
      _subtitleCtrl.text = data['subtitle'] ?? '';
      _addressCtrl.text = data['address'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _rcCtrl.text = data['rc'] ?? '';
      _nifCtrl.text = data['nif'] ?? '';
      _nisCtrl.text = data['nis'] ?? '';
      _aiCtrl.text = data['ai'] ?? '';
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _supabase.from('store_settings').update({
        'name': _nameCtrl.text,
        'subtitle': _subtitleCtrl.text,
        'address': _addressCtrl.text,
        'phone': _phoneCtrl.text,
        'rc': _rcCtrl.text,
        'nif': _nifCtrl.text,
        'nis': _nisCtrl.text,
        'ai': _aiCtrl.text,
      }).eq('id', 1);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('Store Configuration'),
        backgroundColor: const Color(0xFF1A2A32),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Company Identity', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2A32))),
              const SizedBox(height: 8),
              const Text('These details will appear on all generated PDFs and Receipts', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom du Magasin', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Required' : null)),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _subtitleCtrl, decoration: const InputDecoration(labelText: 'Sous-titre / Spécialité', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Adresse Complète', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Required' : null)),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),
                      const Align(alignment: Alignment.centerLeft, child: Text('Informations Légales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _rcCtrl, decoration: const InputDecoration(labelText: 'Registre de Commerce (RC)', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _nifCtrl, decoration: const InputDecoration(labelText: 'NIF', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _nisCtrl, decoration: const InputDecoration(labelText: 'NIS', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _aiCtrl, decoration: const InputDecoration(labelText: 'Article d\'Imposition (AI)', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2A32)),
                          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Enregistrer les Paramètres', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
