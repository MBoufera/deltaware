import 'package:flutter/material.dart';
import '../../data/models/role_model.dart';

class RoleEditDialog extends StatefulWidget {
  final Role role;
  final Map<String, List<AppPermission>> permissions;
  final Function(String name, String? description, List<String> permissionKeys) onUpdate;

  const RoleEditDialog({
    super.key,
    required this.role,
    required this.permissions,
    required this.onUpdate,
  });

  @override
  State<RoleEditDialog> createState() => _RoleEditDialogState();
}

class _RoleEditDialogState extends State<RoleEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final Set<String> _selectedPermissions;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.role.name);
    _descriptionController = TextEditingController(text: widget.role.description ?? '');
    _selectedPermissions = Set<String>.from(widget.role.getPermissionKeys());
  }

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
      title: Text('Edit Role: ${widget.role.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Role Name',
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Permissions',
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
          onPressed: _updateRole,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C5364),
            foregroundColor: Colors.white,
          ),
          child: const Text('Update Role'),
        ),
      ],
    );
  }

  void _updateRole() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a role name')),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    widget.onUpdate(name, description.isNotEmpty ? description : null, _selectedPermissions.toList());
    Navigator.pop(context);
  }
}
