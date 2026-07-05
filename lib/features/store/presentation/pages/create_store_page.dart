import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/store_bloc.dart';
import '../bloc/store_event.dart';
import '../bloc/store_state.dart';

const _kWilayas = [
  'Adrar', 'Chlef', 'Laghouat', 'Oum El Bouaghi', 'Batna', 'Béjaïa',
  'Biskra', 'Béchar', 'Blida', 'Bouira', 'Tamanrasset', 'Tébessa',
  'Tlemcen', 'Tiaret', 'Tizi Ouzou', 'Alger', 'Djelfa', 'Jijel',
  'Sétif', 'Saïda', 'Skikda', 'Sidi Bel Abbès', 'Annaba', 'Guelma',
  'Constantine', 'Médéa', 'Mostaganem', 'M\'Sila', 'Mascara', 'Ouargla',
  'Oran', 'El Bayadh', 'Illizi', 'Bordj Bou Arréridj', 'Boumerdès',
  'El Tarf', 'Tindouf', 'Tissemsilt', 'El Oued', 'Khenchela', 'Souk Ahras',
  'Tipaza', 'Mila', 'Aïn Defla', 'Naâma', 'Aïn Témouchent', 'Ghardaïa',
  'Relizane',
];

class CreateStorePage extends StatefulWidget {
  const CreateStorePage({super.key});

  @override
  State<CreateStorePage> createState() => _CreateStorePageState();
}

class _CreateStorePageState extends State<CreateStorePage> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController(text: 'Vente en Gros et Détail');
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nifCtrl = TextEditingController();
  final _nisCtrl = TextEditingController();
  final _rcCtrl = TextEditingController();
  final _aiCtrl = TextEditingController();
  String? _selectedWilaya;
  bool _enableTimbre = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtitleCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _nifCtrl.dispose();
    _nisCtrl.dispose();
    _rcCtrl.dispose();
    _aiCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<StoreBloc>().add(CreateStore(
          name: _nameCtrl.text.trim(),
          subtitle: _subtitleCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          wilaya: _selectedWilaya ?? '',
          phone: _phoneCtrl.text.trim(),
          nif: _nifCtrl.text.trim(),
          nis: _nisCtrl.text.trim(),
          rc: _rcCtrl.text.trim(),
          ai: _aiCtrl.text.trim(),
          enableTimbre: _enableTimbre,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: BlocListener<StoreBloc, StoreState>(
        listener: (context, state) {
          if (state is StoreOperationSuccess) {
            // StoreSelectionPage will handle navigation via its own listener
            context.go('/store-select');
          } else if (state is StoreError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back
                    TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Color(0xFF94A3B8), size: 18),
                      label: const Text(
                        'Back to stores',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    const Text(
                      'Create a New Store',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set up the store identity. You can change these later in Store Settings.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    // Steps indicator
                    _StepIndicator(current: _step, labels: const ['Identity', 'Legal Info']),
                    const SizedBox(height: 32),
                    // Form card
                    Expanded(
                      child: _buildFormCard(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: _step == 0 ? _buildStep1() : _buildStep2(),
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step > 0)
                    _NavButton(
                      label: 'Back',
                      icon: Icons.arrow_back_rounded,
                      onTap: () => setState(() => _step--),
                      isPrimary: false,
                    )
                  else
                    const SizedBox(),
                  if (_step == 0)
                    _NavButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onTap: () {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _step++);
                        }
                      },
                      isPrimary: true,
                    )
                  else
                    BlocBuilder<StoreBloc, StoreState>(
                      builder: (context, state) {
                        final isLoading = state is StoreLoading;
                        return _NavButton(
                          label: isLoading ? 'Creating...' : 'Create Store',
                          icon: Icons.storefront_rounded,
                          onTap: isLoading ? null : _submit,
                          isPrimary: true,
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Store Identity'),
        const SizedBox(height: 20),
        _DarkField(
          controller: _nameCtrl,
          label: 'Store Name',
          hint: 'e.g. Tech Store Alger',
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _DarkField(
          controller: _subtitleCtrl,
          label: 'Subtitle / Specialty',
          hint: 'e.g. Vente en Gros et Détail',
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DarkField(
                controller: _addressCtrl,
                label: 'Address',
                hint: '123 Rue Principale',
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _WilayaDropdown(
              value: _selectedWilaya,
              onChanged: (v) => setState(() => _selectedWilaya = v),
            )),
          ],
        ),
        const SizedBox(height: 16),
        _DarkField(
          controller: _phoneCtrl,
          label: 'Phone Number',
          hint: '023 XX XX XX',
        ),
        const SizedBox(height: 20),
        _SectionTitle('POS Settings'),
        const SizedBox(height: 16),
        _ToggleTile(
          label: 'Enable Timbre Fiscal (1%)',
          subtitle: 'Automatically adds 1% fiscal stamp on all B2B invoices.',
          value: _enableTimbre,
          onChanged: (v) => setState(() => _enableTimbre = v),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Legal Information'),
        const Text(
          'These details will appear on all generated invoices and PDFs.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _DarkField(
                controller: _rcCtrl,
                label: 'Registre de Commerce (RC)',
                hint: '00/00-XXXXXXX',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DarkField(
                controller: _nifCtrl,
                label: 'NIF',
                hint: 'XXXXXXXXXXXXXXX',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DarkField(
                controller: _nisCtrl,
                label: 'NIS',
                hint: 'XXXXXXXXXXXXXXX',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DarkField(
                controller: _aiCtrl,
                label: 'Article d\'Imposition (AI)',
                hint: 'XXXXXXXX',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Summary preview
        _StoreSummary(name: _nameCtrl.text, wilaya: _selectedWilaya),
      ],
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;

  const _StepIndicator({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: i ~/ 2 < current
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF1E293B),
            ),
          );
        }
        final step = i ~/ 2;
        final isDone = step < current;
        final isActive = step == current;
        return _StepDot(
          label: labels[step],
          isDone: isDone,
          isActive: isActive,
          number: step + 1,
        );
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  final int number;

  const _StepDot({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone || isActive ? const Color(0xFF2563EB) : const Color(0xFF1E293B);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? const Color(0xFF60A5FA) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF475569),
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF374151), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF0D1B2A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}

class _WilayaDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _WilayaDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wilaya',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Select wilaya',
            hintStyle: const TextStyle(color: Color(0xFF374151)),
            filled: true,
            fillColor: const Color(0xFF0D1B2A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
          items: _kWilayas
              .map((w) => DropdownMenuItem(value: w, child: Text(w)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 12, height: 1.5)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}

class _StoreSummary extends StatelessWidget {
  final String name;
  final String? wilaya;

  const _StoreSummary({required this.name, this.wilaya});

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.12),
            const Color(0xFF7C3AED).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (wilaya != null)
                  Text(
                    wilaya!,
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      label: Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
    );
  }
}
