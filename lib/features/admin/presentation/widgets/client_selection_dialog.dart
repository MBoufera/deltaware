import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientSelectionDialog extends StatefulWidget {
  final String saleType;
  const ClientSelectionDialog({super.key, required this.saleType});

  @override
  State<ClientSelectionDialog> createState() => _ClientSelectionDialogState();
}

class _ClientSelectionDialogState extends State<ClientSelectionDialog> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _clients = [];
  List<dynamic> _filteredClients = [];

  final _searchController = TextEditingController();

  // Form Controllers
  bool _isCreatingNew = false;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _nifController = TextEditingController();
  final _nisController = TextEditingController();
  final _rcController = TextEditingController();
  final _aiController = TextEditingController();
  String _clientType = 'entreprise'; // particulier, entreprise, gouvernement

  @override
  void initState() {
    super.initState();
    if (widget.saleType == 'gouvernement') {
      _clientType = 'gouvernement';
    } else if (widget.saleType == 'detail') {
      _clientType = 'particulier';
    }
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final data = await _supabase.from('clients').select('*').eq('is_active', true).order('name');
      if (mounted) {
        setState(() {
          _clients = data;
          _filteredClients = List.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _filterClients(String query) {
    setState(() {
      _filteredClients = _clients.where((c) => (c['name'] ?? '').toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  Future<void> _createNewClient() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    
    // Validate strict fields based on type
    if (['entreprise', 'gouvernement'].contains(_clientType) && 
        ['bon_livraison', 'bon_commande', 'gouvernement'].contains(widget.saleType)) {
      if (_nifController.text.trim().isEmpty || _rcController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NIF and RC are required for official documents')));
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'type': _clientType,
        'address': _addressController.text.trim(),
        'nif': _nifController.text.trim(),
        'nis': _nisController.text.trim(),
        'rc': _rcController.text.trim(),
        'ai': _aiController.text.trim(),
      };
      
      final result = await _supabase.from('clients').insert(data).select().single();
      
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating client: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Client', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() => _isCreatingNew = !_isCreatingNew),
                  child: Text(_isCreatingNew ? 'Search Existing' : 'Create New'),
                )
              ],
            ),
            const Divider(),
            Expanded(
              child: _isCreatingNew ? _buildCreateForm() : _buildSearchList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchList() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search clients by name...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: _filterClients,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _filteredClients.length,
                itemBuilder: (context, index) {
                  final client = _filteredClients[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.business)),
                      title: Text(client['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Type: ${client['type']} | NIF: ${client['nif'] ?? 'N/A'}'),
                      onTap: () => Navigator.of(context).pop(client),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _clientType,
            decoration: const InputDecoration(labelText: 'Client Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'particulier', child: Text('Particulier')),
              DropdownMenuItem(value: 'entreprise', child: Text('Entreprise')),
              DropdownMenuItem(value: 'gouvernement', child: Text('Gouvernement')),
            ],
            onChanged: (v) => setState(() => _clientType = v!),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name / Company Name', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          
          if (_clientType != 'particulier') ...[
            Row(
              children: [
                Expanded(child: TextField(controller: _nifController, decoration: const InputDecoration(labelText: 'NIF', border: OutlineInputBorder()))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _nisController, decoration: const InputDecoration(labelText: 'NIS', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _rcController, decoration: const InputDecoration(labelText: 'RC', border: OutlineInputBorder()))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _aiController, decoration: const InputDecoration(labelText: 'Article Imposition', border: OutlineInputBorder()))),
              ],
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createNewClient,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save & Select Client'),
            ),
          )
        ],
      ),
    );
  }
}
