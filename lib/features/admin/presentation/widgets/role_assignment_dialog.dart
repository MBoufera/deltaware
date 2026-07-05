import 'package:flutter/material.dart';
import '../../data/models/role_model.dart';

class RoleAssignmentDialog extends StatefulWidget {
  final String userName;
  final List<Role> availableRoles;
  final List<Role> assignedRoles;
  /// Called once with the full diff when the user confirms. Receives
  /// [rolesToAdd] and [rolesToRemove] so a single atomic BLoC event can handle it.
  final void Function(List<String> rolesToAdd, List<String> rolesToRemove) onSyncRoles;

  const RoleAssignmentDialog({
    super.key,
    required this.userName,
    required this.availableRoles,
    required this.assignedRoles,
    required this.onSyncRoles,
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
  void didUpdateWidget(covariant RoleAssignmentDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.assignedRoles.map((r) => r.id).toSet();
    final newIds = widget.assignedRoles.map((r) => r.id).toSet();
    if (oldIds.length != newIds.length || !oldIds.containsAll(newIds)) {
      _assignedRoleIds = widget.assignedRoles.map((r) => r.id).toList();
    }
  }

  // ─── Redundancy Helpers ──────────────────────────────────────────────────

  /// Returns the union of all permission keys for a given set of role IDs.
  Set<String> _permissionsOf(Iterable<String> roleIds) {
    final result = <String>{};
    for (final id in roleIds) {
      final role = widget.availableRoles.firstWhere(
        (r) => r.id == id,
        orElse: () => widget.assignedRoles.firstWhere((r) => r.id == id),
      );
      result.addAll(role.getPermissionKeys());
    }
    return result;
  }

  /// Returns true if [role]'s permissions are fully covered by the union of
  /// all OTHER currently-assigned roles — meaning this role adds nothing new.
  bool _isRoleRedundant(Role role) {
    if (!_assignedRoleIds.contains(role.id)) return false;
    final ownKeys = role.getPermissionKeys().toSet();
    if (ownKeys.isEmpty) return false;
    final otherIds = _assignedRoleIds.where((id) => id != role.id);
    final otherKeys = _permissionsOf(otherIds);
    return otherKeys.containsAll(ownKeys);
  }

  /// If we were to ADD [role], which currently-assigned roles would become
  /// redundant (their permissions fully covered by the new union)?
  List<Role> _redundanciesIfAdding(Role role) {
    final hypotheticalIds = [..._assignedRoleIds, role.id];
    return _assignedRoleIds
        .map((id) => widget.availableRoles.firstWhere((r) => r.id == id))
        .where((assigned) {
          final keys = assigned.getPermissionKeys().toSet();
          if (keys.isEmpty) return false;
          final others = hypotheticalIds.where((id) => id != assigned.id);
          return _permissionsOf(others).containsAll(keys);
        })
        .toList();
  }

  /// If role is NOT yet assigned, returns any already-assigned roles that
  /// already fully cover it — so adding it would be pointless.
  Role? _coveredBy(Role role) {
    if (_assignedRoleIds.contains(role.id)) return null;
    final ownKeys = role.getPermissionKeys().toSet();
    if (ownKeys.isEmpty) return null;
    final currentKeys = _permissionsOf(_assignedRoleIds);
    if (!currentKeys.containsAll(ownKeys)) return null;
    // Find the single most-responsible covering role to name in the label
    for (final id in _assignedRoleIds) {
      final r = widget.availableRoles.firstWhere((x) => x.id == id);
      if (r.getPermissionKeys().toSet().containsAll(ownKeys)) return r;
    }
    return widget.availableRoles.firstWhere(
      (r) => _assignedRoleIds.contains(r.id),
      orElse: () => widget.availableRoles.first,
    );
  }

  /// All currently redundant roles in the selection.
  List<Role> get _currentRedundancies => _assignedRoleIds
      .map((id) => widget.availableRoles.firstWhere((r) => r.id == id))
      .where(_isRoleRedundant)
      .toList();

  void _toggle(Role role, bool add) {
    setState(() {
      if (add) {
        _assignedRoleIds.add(role.id);
      } else {
        _assignedRoleIds.remove(role.id);
      }
    });
  }

  void _removeRedundant(List<Role> redundant) {
    setState(() {
      for (final r in redundant) {
        _assignedRoleIds.remove(r.id);
      }
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final redundancies = _currentRedundancies;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Assign Roles to ${widget.userName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Redundancy Warning Banner ──────────────────────────────
              if (redundancies.isNotEmpty) ...[
                _RedundancyBanner(
                  redundantRoles: redundancies,
                  onRemove: () => _removeRedundant(redundancies),
                ),
                const SizedBox(height: 12),
              ],

              // ── Role List ──────────────────────────────────────────────
              Text(
                'Available Roles',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (widget.availableRoles.isEmpty)
                const Text('No roles available')
              else
                ...widget.availableRoles.map((role) {
                  final isAssigned = _assignedRoleIds.contains(role.id);
                  final coveredByRole = _coveredBy(role);
                  final wouldMakeRedundant =
                      !isAssigned ? _redundanciesIfAdding(role) : <Role>[];
                  final isSelfRedundant = isAssigned && _isRoleRedundant(role);

                  return _RoleTile(
                    role: role,
                    isAssigned: isAssigned,
                    isSelfRedundant: isSelfRedundant,
                    coveredByRole: coveredByRole,
                    wouldMakeRedundant: wouldMakeRedundant,
                    onChanged: (value) {
                      if (value == true) {
                        _toggle(role, true);
                      } else {
                        _toggle(role, false);
                      }
                    },
                  );
                }),

              const SizedBox(height: 12),

              // ── Assigned Summary ──────────────────────────────────────
              _AssignedSummary(
                assignedRoleIds: _assignedRoleIds,
                availableRoles: widget.availableRoles,
              ),
            ],
          ),
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
    final originalIds = widget.assignedRoles.map((r) => r.id).toSet();
    final newIds = _assignedRoleIds.toSet();

    final toAdd = newIds.difference(originalIds).toList();
    final toRemove = originalIds.difference(newIds).toList();

    if (toAdd.isNotEmpty || toRemove.isNotEmpty) {
      widget.onSyncRoles(toAdd, toRemove);
    }
    Navigator.pop(context);
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _RedundancyBanner extends StatelessWidget {
  final List<Role> redundantRoles;
  final VoidCallback onRemove;

  const _RedundancyBanner({
    required this.redundantRoles,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final names = redundantRoles.map((r) => '"${r.name}"').join(', ');
    final plural = redundantRoles.length > 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Redundant ${plural ? "roles" : "role"} detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plural ? "Roles" : "Role"} $names ${plural ? "add" : "adds"} no new permissions — ${plural ? "they are" : "it is"} fully covered by other assigned roles.',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onRemove,
                  child: Text(
                    'Remove redundant ${plural ? "roles" : "role"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final Role role;
  final bool isAssigned;
  final bool isSelfRedundant;
  final Role? coveredByRole;
  final List<Role> wouldMakeRedundant;
  final ValueChanged<bool?> onChanged;

  const _RoleTile({
    required this.role,
    required this.isAssigned,
    required this.isSelfRedundant,
    required this.coveredByRole,
    required this.wouldMakeRedundant,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCoveredByOther = coveredByRole != null;

    // Build subtitle string
    String? subtitleText = role.description;
    Color subtitleColor = Colors.grey.shade600;

    Widget? extraHint;

    if (isSelfRedundant) {
      // This role IS assigned but adds nothing new
      extraHint = _HintChip(
        icon: Icons.info_outline,
        label: 'Adds no new permissions',
        color: Colors.orange,
      );
    } else if (isCoveredByOther) {
      // Not assigned — would be redundant to add
      extraHint = _HintChip(
        icon: Icons.lock_outline,
        label: 'Already covered by ${coveredByRole!.name}',
        color: Colors.blue,
      );
    } else if (wouldMakeRedundant.isNotEmpty) {
      // Adding this would make existing roles redundant
      final names = wouldMakeRedundant.map((r) => r.name).join(', ');
      extraHint = _HintChip(
        icon: Icons.merge_type,
        label: 'Would make $names redundant',
        color: Colors.amber.shade800,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  role.name,
                  style: TextStyle(
                    color: (isCoveredByOther && !isAssigned)
                        ? Colors.grey.shade400
                        : null,
                  ),
                ),
              ),
              if (role.isSystem)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'System',
                    style: TextStyle(fontSize: 9, color: Colors.blue.shade700),
                  ),
                ),
            ],
          ),
          subtitle: subtitleText != null
              ? Text(
                  subtitleText,
                  style: TextStyle(fontSize: 11, color: subtitleColor),
                )
              : null,
          value: isAssigned,
          onChanged: onChanged,
          dense: true,
          activeColor: isSelfRedundant ? Colors.orange : const Color(0xFF2C5364),
        ),
        if (extraHint != null)
          Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 4),
            child: extraHint,
          ),
      ],
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HintChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AssignedSummary extends StatelessWidget {
  final List<String> assignedRoleIds;
  final List<Role> availableRoles;

  const _AssignedSummary({
    required this.assignedRoleIds,
    required this.availableRoles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assigned Roles (${assignedRoleIds.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (assignedRoleIds.isEmpty)
            Text(
              'No roles assigned — this user will have no access.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade400,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: assignedRoleIds.map((roleId) {
                final role = availableRoles.firstWhere(
                  (r) => r.id == roleId,
                  orElse: () => availableRoles.first,
                );
                return Chip(
                  label: Text(role.name, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: const Color(0xFF2C5364).withValues(alpha: 0.4)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
