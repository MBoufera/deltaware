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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF203A43), width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF203A43).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.badge_outlined, color: Color(0xFF203A43), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Edit Role: ${widget.role.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Role Name',
                hintText: 'Enter role name',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                hintText: 'Describe the purpose of this role',
                icon: Icons.description_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              const Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
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
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF203A43),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...perms.map((perm) {
                        return CheckboxListTile(
                          title: Text(
                            perm.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          subtitle: perm.description != null
                              ? Text(perm.description!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
                              : null,
                          value: _selectedPermissions.contains(perm.key),
                          activeColor: const Color(0xFF203A43),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _updateRole,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF203A43),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Update Role',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _updateRole() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a role name'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    widget.onUpdate(name, description.isNotEmpty ? description : null, _selectedPermissions.toList());
    Navigator.pop(context);
  }
}
