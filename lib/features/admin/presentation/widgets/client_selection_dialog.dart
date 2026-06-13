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
      _filteredClients = _clients
          .where((c) => (c['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _createNewClient() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required'), backgroundColor: Color(0xFFB91C1C)),
      );
      return;
    }

    // Validate strict fields based on type
    if (['entreprise', 'gouvernement'].contains(_clientType) &&
        ['bon_livraison', 'bon_commande', 'gouvernement'].contains(widget.saleType)) {
      if (_nifController.text.trim().isEmpty || _rcController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NIF and RC are required for official documents'),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating client: $e'), backgroundColor: const Color(0xFFB91C1C)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      child: Container(
        width: 600,
        height: 620,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Client',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                  hoverColor: const Color(0xFFF1F5F9),
                  splashRadius: 20,
                )
              ],
            ),
            const SizedBox(height: 12),
            // Custom Tab Pill Switcher
            _buildTabSwitcher(),
            const SizedBox(height: 20),
            // Main Content Area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isCreatingNew ? _buildCreateForm() : _buildSearchList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              isActive: !_isCreatingNew,
              label: 'Search Existing',
              icon: Icons.search_rounded,
              onTap: () => setState(() => _isCreatingNew = false),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              isActive: _isCreatingNew,
              label: 'Create New',
              icon: Icons.person_add_rounded,
              onTap: () => setState(() => _isCreatingNew = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required bool isActive,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? const Color(0xFF203A43) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive ? const Color(0xFF203A43) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchList() {
    return Column(
      key: const ValueKey('search_list_key'),
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search clients by name...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
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
          onChanged: _filterClients,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF203A43),
                  ),
                )
              : _filteredClients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_search_rounded,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No clients available'
                                : 'No clients found matching "${_searchController.text}"',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isCreatingNew = true;
                                  _nameController.text = _searchController.text.trim();
                                });
                              },
                              icon: const Icon(Icons.person_add_rounded, size: 16),
                              label: const Text('Create New Client'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF203A43),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = _filteredClients[index];
                        return _ClientCard(
                          client: client,
                          onTap: () => Navigator.of(context).pop(client),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      key: const ValueKey('create_form_key'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClientTypeSelector(),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nameController,
            labelText: 'Name / Company Name',
            hintText: 'Enter name or enterprise title',
            prefixIcon: Icons.badge_outlined,
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _addressController,
            labelText: 'Address',
            hintText: 'Enter physical location or billing address',
            prefixIcon: Icons.location_on_outlined,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _clientType == 'particulier'
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _nifController,
                                labelText: 'NIF (Identifiant Fiscal)',
                                hintText: '15-digit code',
                                required: ['bon_livraison', 'bon_commande', 'gouvernement'].contains(widget.saleType),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _nisController,
                                labelText: 'NIS',
                                hintText: 'Identification code',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _rcController,
                                labelText: 'Registre Commerce (RC)',
                                hintText: 'Commercial record',
                                required: ['bon_livraison', 'bon_commande', 'gouvernement'].contains(widget.saleType),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _aiController,
                                labelText: 'Article Imposition (AI)',
                                hintText: 'Tax article number',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createNewClient,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203A43),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'SAVE & SELECT CLIENT',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildClientTypeSelector() {
    final types = [
      {'key': 'particulier', 'label': 'Particulier', 'icon': Icons.person_rounded},
      {'key': 'entreprise', 'label': 'Entreprise', 'icon': Icons.business_rounded},
      {'key': 'gouvernement', 'label': 'Gouvernement', 'icon': Icons.account_balance_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Client Type',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: types.map((t) {
              final isSelected = _clientType == t['key'];
              return Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _clientType = t['key'] as String;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            t['icon'] as IconData,
                            size: 14,
                            color: isSelected ? const Color(0xFF203A43) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF203A43) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              labelText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade400, size: 18) : null,
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
}

class _ClientCard extends StatefulWidget {
  final Map<String, dynamic> client;
  final VoidCallback onTap;

  const _ClientCard({required this.client, required this.onTap});

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.client['type'] ?? 'particulier';
    final name = widget.client['name'] ?? '';
    final nif = widget.client['nif'];
    final rc = widget.client['rc'];
    final address = widget.client['address'];

    IconData iconData;
    Color iconColor;
    Color iconBg;
    String typeLabel;

    if (type == 'entreprise') {
      iconData = Icons.business_rounded;
      iconColor = const Color(0xFF7C3AED); // Purple
      iconBg = const Color(0xFFF3E8FF);
      typeLabel = 'Entreprise';
    } else if (type == 'gouvernement') {
      iconData = Icons.account_balance_rounded;
      iconColor = const Color(0xFFD97706); // Amber
      iconBg = const Color(0xFFFEF3C7);
      typeLabel = 'Gov';
    } else {
      iconData = Icons.person_rounded;
      iconColor = const Color(0xFF0EA5E9); // Sky
      iconBg = const Color(0xFFE0F2FE);
      typeLabel = 'Particulier';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? const Color(0xFF203A43).withValues(alpha: 0.2) : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.04 : 0.01),
              blurRadius: _isHovered ? 8 : 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: ListTile(
          onTap: widget.onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address != null && address.toString().trim().isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Row(
                  children: [
                    if (nif != null && nif.toString().trim().isNotEmpty) ...[
                      Text(
                        'NIF: $nif',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                      ),
                      if (rc != null && rc.toString().trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '|',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade300),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                    if (rc != null && rc.toString().trim().isNotEmpty) ...[
                      Text(
                        'RC: $rc',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: _isHovered ? const Color(0xFF203A43) : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
