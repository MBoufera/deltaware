import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import 'package:deltaware/core/widgets/permission_guard.dart';
import '../../../../features/store/presentation/bloc/store_bloc.dart';
import '../../../../features/store/presentation/bloc/store_state.dart';
import '../../data/services/audit_service.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final _auditService = AuditService();
  late Future<List<AuditLog>> _auditLogsFuture;
  
  // Filters
  String? _selectedAction;
  String? _selectedStatus;
  String? _selectedResourceType;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  static const int _logsPerPage = 25;

  final List<String> _availableActions = [
    'assign_role', 'remove_role', 'create_role', 'update_role', 'delete_role',
    'edit_permissions', 'create_user', 'update_user', 'delete_user',
    'create_setting', 'update_setting', 'delete_setting',
    'permission_denied', 'privilege_escalation_attempt'
  ];

  final List<String> _availableStatuses = ['success', 'failed', 'denied'];
  
  final List<String> _availableResourceTypes = [
    'user', 'role', 'permission', 'setting', 'user_role', 'role_permission'
  ];

  static const _headerStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 14,
    color: Color(0xFF1A2A32),
  );

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  void _loadAuditLogs() {
    String? storeId;
    try {
      final storeState = context.read<StoreBloc>().state;
      if (storeState is StoresLoaded) {
        storeId = storeState.selectedStore?.id;
      }
    } catch (_) {}

    setState(() {
      _auditLogsFuture = _auditService.getAuditLogs(
        offset: _currentPage * _logsPerPage,
        limit: _logsPerPage,
        action: _selectedAction,
        resourceType: _selectedResourceType,
        status: _selectedStatus,
        startDate: _startDate,
        endDate: _endDate,
        storeId: storeId,
      );
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF203A43),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A2A32),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
        _currentPage = 0;
      });
      _loadAuditLogs();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedAction = null;
      _selectedStatus = null;
      _selectedResourceType = null;
      _startDate = null;
      _endDate = null;
      _currentPage = 0;
    });
    _loadAuditLogs();
  }

  String _getActionDisplay(String action) {
    return action
        .replaceAllMapped(RegExp(r'_'), (m) => ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('${label}_${value ?? 'null'}'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.grey.shade50,
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
          borderSide: const BorderSide(color: Color(0xFF203A43)),
        ),
      ),
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: Colors.white,
      initialValue: value,
      onChanged: onChanged,
      items: items,
    );
  }

  Widget _buildDatePickerButton() {
    final hasRange = _startDate != null && _endDate != null;
    final text = hasRange
        ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
        : 'Dates de sélection';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: _selectDateRange,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: hasRange ? const Color(0xFF203A43) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasRange ? Colors.transparent : Colors.grey.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: hasRange ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: hasRange ? Colors.white : Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('Date & Heure', style: _headerStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('Administrateur', style: _headerStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('Action', style: _headerStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('Ressource', style: _headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('Statut', style: _headerStyle),
          ),
          Expanded(
            flex: 1,
            child: Text('Détails', style: _headerStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case 'success':
        bgColor = const Color(0xFFECFDF5);
        textColor = const Color(0xFF10B981);
        text = 'Succès';
        break;
      case 'failed':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        text = 'Échoué';
        break;
      case 'denied':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFEF4444);
        text = 'Refusé';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bgColor;
    Color textColor;

    if (action == 'permission_denied' || action == 'privilege_escalation_attempt') {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
    } else if (action.startsWith('delete_')) {
      bgColor = const Color(0xFFFFF1F2);
      textColor = const Color(0xFFE11D48);
    } else if (action.startsWith('create_') || action.startsWith('assign_')) {
      bgColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF2563EB);
    } else if (action.startsWith('update_') || action.startsWith('edit_')) {
      bgColor = const Color(0xFFF0FDF4);
      textColor = const Color(0xFF16A34A);
    } else {
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _getActionDisplay(action),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page ${_currentPage + 1}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2A32),
            ),
          ),
          Row(
            children: [
              _buildPaginationButton(
                icon: Icons.chevron_left_rounded,
                onPressed: _currentPage > 0
                    ? () {
                        setState(() => _currentPage--);
                        _loadAuditLogs();
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              _buildPaginationButton(
                icon: Icons.chevron_right_rounded,
                onPressed: () {
                  setState(() => _currentPage++);
                  _loadAuditLogs();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;
    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDisabled ? Colors.transparent : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDisabled ? Colors.transparent : Colors.grey.shade200,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDisabled ? Colors.grey.shade300 : const Color(0xFF203A43),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _selectedAction != null ||
        _selectedStatus != null ||
        _selectedResourceType != null ||
        _startDate != null ||
        _endDate != null;

    return PermissionGuard(
      requiredPermission: AppPermission.canViewAuditLogs.key,
      child: BlocListener<StoreBloc, StoreState>(
        listenWhen: (prev, curr) {
          final prevId = prev is StoresLoaded ? prev.selectedStore?.id : null;
          final currId = curr is StoresLoaded ? curr.selectedStore?.id : null;
          return prevId != currId;
        },
        listener: (context, state) {
          setState(() {
            _currentPage = 0;
          });
          _loadAuditLogs();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Inline Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Journal d'Audit",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A2A32),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Inspectez les actions de sécurité et les modifications de ressources.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Filters Bar Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Filtres de recherche',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2A32),
                              ),
                            ),
                            if (hasActiveFilters)
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: TextButton.icon(
                                  onPressed: _clearFilters,
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  label: const Text('Réinitialiser'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    backgroundColor: Colors.red.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 900;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildFilterDropdown(
                                          label: 'Action',
                                          value: _selectedAction,
                                          items: [
                                            const DropdownMenuItem(
                                              value: null,
                                              child: Text('Toutes les actions'),
                                            ),
                                            ..._availableActions.map(
                                              (action) => DropdownMenuItem(
                                                value: action,
                                                child: Text(_getActionDisplay(action)),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedAction = value;
                                              _currentPage = 0;
                                            });
                                            _loadAuditLogs();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildFilterDropdown(
                                          label: 'Statut',
                                          value: _selectedStatus,
                                          items: [
                                            const DropdownMenuItem(
                                              value: null,
                                              child: Text('Tous les statuts'),
                                            ),
                                            ..._availableStatuses.map(
                                              (status) => DropdownMenuItem(
                                                value: status,
                                                child: Text(
                                                  status[0].toUpperCase() + status.substring(1),
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedStatus = value;
                                              _currentPage = 0;
                                            });
                                            _loadAuditLogs();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildFilterDropdown(
                                          label: 'Type de Ressource',
                                          value: _selectedResourceType,
                                          items: [
                                            const DropdownMenuItem(
                                              value: null,
                                              child: Text('Toutes les ressources'),
                                            ),
                                            ..._availableResourceTypes.map(
                                              (type) => DropdownMenuItem(
                                                value: type,
                                                child: Text(
                                                  type[0].toUpperCase() + type.substring(1),
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedResourceType = value;
                                              _currentPage = 0;
                                            });
                                            _loadAuditLogs();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildDatePickerButton(),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            } else {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildFilterDropdown(
                                      label: 'Action',
                                      value: _selectedAction,
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('Toutes les actions'),
                                        ),
                                        ..._availableActions.map(
                                          (action) => DropdownMenuItem(
                                            value: action,
                                            child: Text(_getActionDisplay(action)),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedAction = value;
                                          _currentPage = 0;
                                        });
                                        _loadAuditLogs();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildFilterDropdown(
                                      label: 'Statut',
                                      value: _selectedStatus,
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('Tous les statuts'),
                                        ),
                                        ..._availableStatuses.map(
                                          (status) => DropdownMenuItem(
                                            value: status,
                                            child: Text(
                                              status[0].toUpperCase() + status.substring(1),
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStatus = value;
                                          _currentPage = 0;
                                        });
                                        _loadAuditLogs();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildFilterDropdown(
                                      label: 'Type de Ressource',
                                      value: _selectedResourceType,
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('Toutes les ressources'),
                                        ),
                                        ..._availableResourceTypes.map(
                                          (type) => DropdownMenuItem(
                                            value: type,
                                            child: Text(
                                              type[0].toUpperCase() + type.substring(1),
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedResourceType = value;
                                          _currentPage = 0;
                                        });
                                        _loadAuditLogs();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _buildDatePickerButton(),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Table View
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: FutureBuilder<List<AuditLog>>(
                          future: _auditLogsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF203A43),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 48,
                                      color: Colors.red.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Erreur lors du chargement des logs: ${snapshot.error}',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final logs = snapshot.data ?? [];

                            if (logs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history_toggle_off_rounded,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Aucun log d\'audit trouvé',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final tableWidth = constraints.maxWidth > 950
                                    ? constraints.maxWidth
                                    : 950.0;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      children: [
                                        _buildTableHeader(),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: logs.length,
                                            itemBuilder: (context, index) {
                                              final log = logs[index];
                                              return _AuditRow(
                                                log: log,
                                                onTapDetails: () =>
                                                    _showLogDetails(context, log),
                                                getActionDisplay: _getActionDisplay,
                                                getStatusBadge: _buildStatusBadge,
                                                getActionBadge: _buildActionBadge,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pagination footer
                  _buildPagination(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogDetails(BuildContext context, AuditLog log) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Détails du Log d'Audit",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2A32),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFE2E8F0)),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStatusBadge(log.status),
                          const SizedBox(width: 8),
                          _buildActionBadge(log.action),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildMetaDetailGrid(log),
                      const SizedBox(height: 16),
                      if (log.ipAddress != null)
                        _buildDetailItem('Adresse IP', log.ipAddress!),
                      if (log.reason != null)
                        _buildDetailItem('Raison', log.reason!),
                      if (log.errorMessage != null)
                        _buildDetailItem(
                          "Message d'erreur",
                          log.errorMessage!,
                          isError: true,
                        ),
                      if (log.oldValue != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Ancienne valeur',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCodeBlock(log.oldValue!),
                      ],
                      if (log.newValue != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Nouvelle valeur',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCodeBlock(log.newValue!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF203A43),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaDetailGrid(AuditLog log) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          _buildGridRow(
            'Date & Heure',
            DateFormat('dd MMM yyyy, HH:mm:ss').format(log.timestamp),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildGridRow(
            'Administrateur',
            '${log.adminName ?? 'Inconnu'} (${log.adminEmail ?? '-'})',
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildGridRow('Type de Ressource', log.resourceType),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildGridRow('Ressource', log.resourceName ?? log.resourceId ?? '-'),
        ],
      ),
    );
  }

  Widget _buildGridRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isError = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? Colors.red.shade100 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isError ? Colors.red.shade700 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isError ? Colors.red.shade800 : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(Map<String, dynamic> data) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          prettyJson,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF38BDF8),
          ),
        ),
      ),
    );
  }
}

class _AuditRow extends StatefulWidget {
  final AuditLog log;
  final VoidCallback onTapDetails;
  final String Function(String) getActionDisplay;
  final Widget Function(String) getStatusBadge;
  final Widget Function(String) getActionBadge;

  const _AuditRow({
    required this.log,
    required this.onTapDetails,
    required this.getActionDisplay,
    required this.getStatusBadge,
    required this.getActionBadge,
  });

  @override
  State<_AuditRow> createState() => _AuditRowState();
}

class _AuditRowState extends State<_AuditRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('dd MMM, HH:mm').format(widget.log.timestamp),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.log.adminName ?? 'Inconnu',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.log.adminEmail ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.getActionBadge(widget.log.action),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.log.resourceName ?? widget.log.resourceId ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.log.resourceType,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.getStatusBadge(widget.log.status),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  color: const Color(0xFF203A43),
                  onPressed: widget.onTapDetails,
                  tooltip: 'Afficher les détails',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
