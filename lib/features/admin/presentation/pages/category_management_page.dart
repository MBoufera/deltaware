import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _categories = [];

  final _nameFrController = TextEditingController();
  final _nameArController = TextEditingController();
  final _tvaRateController = TextEditingController(text: '19.00');

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('categories').select('*').order('name_fr');
      if (mounted) {
        setState(() {
          _categories = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? category]) {
    if (category != null) {
      _nameFrController.text = category['name_fr'] ?? '';
      _nameArController.text = category['name_ar'] ?? '';
      _tvaRateController.text = category['tva_rate']?.toString() ?? '19.00';
    } else {
      _nameFrController.clear();
      _nameArController.clear();
      _tvaRateController.text = '19.00';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameFrController,
              decoration: const InputDecoration(labelText: 'Name (FR)'),
            ),
            TextField(
              controller: _nameArController,
              decoration: const InputDecoration(labelText: 'Name (AR)'),
            ),
            TextField(
              controller: _tvaRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'TVA Rate (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _saveCategory(category?['id']);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCategory(String? id) async {
    try {
      final data = {
        'name_fr': _nameFrController.text,
        'name_ar': _nameArController.text,
        'tva_rate': double.tryParse(_tvaRateController.text) ?? 19.00,
      };

      if (id == null) {
        await _supabase.from('categories').insert(data);
      } else {
        await _supabase.from('categories').update(data).eq('id', id);
      }
      _fetchCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving category: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCategory(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text('This will fail if products are linked to this category.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('categories').delete().eq('id', id);
        _fetchCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e. You cannot delete categories in use.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF203A43),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF203A43),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return ListTile(
                  title: Text(cat['name_fr']),
                  subtitle: Text('TVA: ${cat['tva_rate']}%'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddEditDialog(cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(cat['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
