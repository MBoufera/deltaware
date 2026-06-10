import 'package:flutter/material.dart';
import '../../data/models/role_model.dart';

class RoleCreationDialog extends StatefulWidget {
  final Map<String, List<AppPermission>> permissions;
  final Function(String name, String? description, List<String> permissionKeys) onCreate;

  const RoleCreationDialog({
    super.key,
    required this.permissions,
    required this.onCreate,
  });

  @override
  State<RoleCreationDialog> createState() => _RoleCreationDialogState();
}

class _RoleCreationDialogState extends State<RoleCreationDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedPermissions = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Create New Role'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Role Name',
                hintText: 'e.g., Content Manager',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Describe the purpose of this role',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Select Permissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.permissions.isEmpty)
              const Text('No permissions available')
            else
              ...widget.permissions.entries.map((entry) {
                final category = entry.key;
                final perms = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        category.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...perms.map((perm) {
                      return CheckboxListTile(
                        title: Text(perm.name, style: const TextStyle(fontSize: 13)),
                        subtitle: perm.description != null
                            ? Text(perm.description!, style: const TextStyle(fontSize: 11))
                            : null,
                        value: _selectedPermissions.contains(perm.key),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedPermissions.add(perm.key);
                            } else {
                              _selectedPermissions.remove(perm.key);
                            }
                          });
                        },
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createRole,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C5364),
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Role'),
        ),
      ],
    );
  }

  void _createRole() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a role name')),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    widget.onCreate(name, description.isNotEmpty ? description : null, _selectedPermissions.toList());
    Navigator.pop(context);
  }
}
