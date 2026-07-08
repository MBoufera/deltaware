import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/suppliers/suppliers_bloc.dart';
import '../bloc/suppliers/suppliers_event.dart';

class SupplierDialog extends StatefulWidget {
  final Map<String, dynamic>? supplier; // Null for Create, non-null for Edit
  final String storeId;

  const SupplierDialog({Key? key, this.supplier, required this.storeId}) : super(key: key);

  @override
  State<SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<SupplierDialog> {
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

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      final s = widget.supplier!;
      _nameController.text = s['name'] ?? '';
      _phoneController.text = s['phone'] ?? '';
      _emailController.text = s['email'] ?? '';
      _addressController.text = s['address'] ?? '';
      _rcController.text = s['rc'] ?? '';
      _nifController.text = s['nif'] ?? '';
      _nisController.text = s['nis'] ?? '';
      _aiController.text = s['ai'] ?? '';
      _type = s['type'] ?? 'entreprise';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplier != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEditing ? 'Edit Supplier' : 'Add New Supplier', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  decoration: const InputDecoration(labelText: 'Supplier Type', border: OutlineInputBorder()),
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
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203A43), foregroundColor: Colors.white),
          child: Text(isEditing ? 'Save Changes' : 'Create Supplier'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
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

      if (widget.supplier == null) {
        context.read<SuppliersBloc>().add(AddSupplier(data));
      } else {
        context.read<SuppliersBloc>().add(UpdateSupplier(widget.supplier!['id'], data));
      }
      Navigator.pop(context);
    }
  }
}
