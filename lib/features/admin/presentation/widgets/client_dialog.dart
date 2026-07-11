import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientDialog extends StatefulWidget {
  final Map<String, dynamic>? client; // Null for Create, non-null for Edit
  final String storeId;

  const ClientDialog({Key? key, this.client, required this.storeId}) : super(key: key);

  @override
  State<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<ClientDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _rcController = TextEditingController();
  final _nifController = TextEditingController();
  final _nisController = TextEditingController();
  final _aiController = TextEditingController();
  
  String _type = 'entreprise'; // entreprise, particulier, gouvernement
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      final c = widget.client!;
      _nameController.text = c['name'] ?? '';
      _phoneController.text = c['phone'] ?? '';
      _emailController.text = c['email'] ?? '';
      _addressController.text = c['address'] ?? '';
      _rcController.text = c['rc'] ?? '';
      _nifController.text = c['nif'] ?? '';
      _nisController.text = c['nis'] ?? '';
      _aiController.text = c['ai'] ?? '';
      _type = c['type'] ?? 'entreprise';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.client != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEditing ? 'Edit Client' : 'Add New Client', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Client Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'entreprise', child: Text('Entreprise (Company)')),
                    DropdownMenuItem(value: 'particulier', child: Text('Particulier (Individual)')),
                    DropdownMenuItem(value: 'gouvernement', child: Text('Gouvernement (Government)')),
                  ],
                  onChanged: (val) => setState(() => _type = val!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                ),
                if (_type != 'particulier') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(alignment: Alignment.centerLeft, child: Text('Legal Info', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _rcController, decoration: const InputDecoration(labelText: 'RC (Registre Commerce)', border: OutlineInputBorder()))),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(controller: _nifController, decoration: const InputDecoration(labelText: 'NIF', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _nisController, decoration: const InputDecoration(labelText: 'NIS', border: OutlineInputBorder()))),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(controller: _aiController, decoration: const InputDecoration(labelText: 'AI (Article Imposition)', border: OutlineInputBorder()))),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203A43), foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isEditing ? 'Save Changes' : 'Create Client'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final data = {
        'store_id': widget.storeId,
        'name': _nameController.text.trim(),
        'type': _type,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'rc': _rcController.text.trim(),
        'nif': _nifController.text.trim(),
        'nis': _nisController.text.trim(),
        'ai': _aiController.text.trim(),
      };

      try {
        if (widget.client == null) {
          await _supabase.from('clients').insert(data);
        } else {
          await _supabase.from('clients').update(data).eq('id', widget.client!['id']);
        }
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
