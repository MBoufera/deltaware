import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:deltaware/core/constants/permissions_constants.dart';
import 'package:deltaware/core/widgets/permission_guard.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  void _loadAuditLogs() {
    setState(() {
      _auditLogsFuture = _auditService.getAuditLogs(
        offset: _currentPage * _logsPerPage,
        limit: _logsPerPage,
        action: _selectedAction,
        resourceType: _selectedResourceType,
        status: _selectedStatus,
        startDate: _startDate,
        endDate: _endDate,
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.orange;
      case 'denied':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requiredPermission: AppPermission.canViewAuditLogs.key,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        appBar: AppBar(
          title: const Text('Audit Logs'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF203A43),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Filters section
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Filters'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filter row 1
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Action',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              initialValue: _selectedAction,
                              onChanged: (value) {
                                setState(() {
                                  _selectedAction = value;
                                  _currentPage = 0;
                                });
                                _loadAuditLogs();
                              },
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Actions')),
                                ..._availableActions.map(
                                  (action) => DropdownMenuItem(
                                    value: action,
                                    child: Text(_getActionDisplay(action)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              initialValue: _selectedStatus,
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value;
                                  _currentPage = 0;
                                });
                                _loadAuditLogs();
                              },
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Statuses')),
                                ..._availableStatuses.map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status[0].toUpperCase() + status.substring(1)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Resource Type',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              initialValue: _selectedResourceType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedResourceType = value;
                                  _currentPage = 0;
                                });
                                _loadAuditLogs();
                              },
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Types')),
                                ..._availableResourceTypes.map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type[0].toUpperCase() + type.substring(1)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _startDate != null && _endDate != null
                              ? 'Date Range: ${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                              : 'Select Date Range',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Audit logs table
              Expanded(
                child: FutureBuilder<List<AuditLog>>(
                  future: _auditLogsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text('Error loading audit logs: ${snapshot.error}'),
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
                            Icon(Icons.history_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('No audit logs found'),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Timestamp')),
                            DataColumn(label: Text('Admin')),
                            DataColumn(label: Text('Action')),
                            DataColumn(label: Text('Resource')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Details')),
                          ],
                          rows: logs.map((log) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(DateFormat('MMM dd, HH:mm').format(log.timestamp)),
                                  showEditIcon: false,
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.adminName ?? 'Unknown',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          log.adminEmail ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(_getActionDisplay(log.action)),
                                    backgroundColor: Colors.blue.shade100,
                                    labelStyle: TextStyle(color: Colors.blue.shade900),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.resourceName ?? log.resourceId ?? '-',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          log.resourceType,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      log.status[0].toUpperCase() + log.status.substring(1),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: _getStatusColor(log.status),
                                  ),
                                ),
                                DataCell(
                                  GestureDetector(
                                    onTap: () => _showLogDetails(context, log),
                                    child: const Icon(Icons.info_outline, size: 20),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Pagination
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() => _currentPage--);
                            _loadAuditLogs();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  const SizedBox(width: 16),
                  Text('Page ${_currentPage + 1}'),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _currentPage++);
                      _loadAuditLogs();
                    },
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetails(BuildContext context, AuditLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audit Log Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Timestamp', DateFormat('MMM dd, yyyy HH:mm:ss').format(log.timestamp)),
              _DetailRow('Admin', log.adminName ?? 'Unknown'),
              _DetailRow('Email', log.adminEmail ?? '-'),
              _DetailRow('Action', _getActionDisplay(log.action)),
              _DetailRow('Resource Type', log.resourceType),
              _DetailRow('Resource Name', log.resourceName ?? '-'),
              _DetailRow('Status', log.status),
              if (log.reason != null) _DetailRow('Reason', log.reason!),
              if (log.errorMessage != null) _DetailRow('Error', log.errorMessage!),
              if (log.ipAddress != null) _DetailRow('IP Address', log.ipAddress!),
              if (log.oldValue != null) ...[
                const SizedBox(height: 12),
                const Text('Previous Value:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(log.oldValue.toString(), style: const TextStyle(fontSize: 12)),
              ],
              if (log.newValue != null) ...[
                const SizedBox(height: 12),
                const Text('New Value:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(log.newValue.toString(), style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
