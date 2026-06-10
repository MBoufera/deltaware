import 'package:flutter/material.dart';
import '../../data/models/role_model.dart';

class RoleAssignmentDialog extends StatefulWidget {
  final String userName;
  final List<Role> availableRoles;
  final List<Role> assignedRoles;
  final Function(String roleId) onAssignRole;
  final Function(String roleId) onRemoveRole;

  const RoleAssignmentDialog({
    super.key,
    required this.userName,
    required this.availableRoles,
    required this.assignedRoles,
    required this.onAssignRole,
    required this.onRemoveRole,
  });

  @override
  State<RoleAssignmentDialog> createState() => _RoleAssignmentDialogState();
}

class _RoleAssignmentDialogState extends State<RoleAssignmentDialog> {
  late List<String> _assignedRoleIds;

  @override
  void initState() {
    super.initState();
    _assignedRoleIds = widget.assignedRoles.map((r) => r.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Assign Roles to ${widget.userName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Roles',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.availableRoles.isEmpty)
              const Text('No roles available')
            else
              ...widget.availableRoles.map((role) {
                final isAssigned = _assignedRoleIds.contains(role.id);
                return CheckboxListTile(
                  title: Text(role.name),
                  subtitle: role.description != null
                      ? Text(role.description!, style: const TextStyle(fontSize: 11))
                      : null,
                  value: isAssigned,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _assignedRoleIds.add(role.id);
                      } else {
                        _assignedRoleIds.remove(role.id);
                      }
                    });
                  },
                  dense: true,
                );
              }).toList(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned Roles (${_assignedRoleIds.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_assignedRoleIds.isEmpty)
                    const Text('No roles assigned', style: TextStyle(fontSize: 12))
                  else
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _assignedRoleIds.map((roleId) {
                        final role = widget.availableRoles
                            .firstWhere((r) => r.id == roleId);
                        return Chip(
                          label: Text(role.name, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.blue.shade300),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _updateRoles,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C5364),
            foregroundColor: Colors.white,
          ),
          child: const Text('Update Roles'),
        ),
      ],
    );
  }

  void _updateRoles() {
    // Determine which roles to add and remove
    final originalIds = widget.assignedRoles.map((r) => r.id).toList();
    
    // Find roles to add
    for (var roleId in _assignedRoleIds) {
      if (!originalIds.contains(roleId)) {
        widget.onAssignRole(roleId);
      }
    }
    
    // Find roles to remove
    for (var roleId in originalIds) {
      if (!_assignedRoleIds.contains(roleId)) {
        widget.onRemoveRole(roleId);
      }
    }
    
    Navigator.pop(context);
  }
}
