import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/supplier_model.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/supplier_service.dart';
import '../../../shared/widgets/admin/admin_top_bar.dart';
import '../../../shared/widgets/admin/supplier_card.dart';

class AdminSuppliersScreen extends StatefulWidget {
  const AdminSuppliersScreen({super.key});

  @override
  State<AdminSuppliersScreen> createState() => _AdminSuppliersScreenState();
}

class _AdminSuppliersScreenState extends State<AdminSuppliersScreen> {
  final _service = const SupplierService();
  late Future<List<SupplierModel>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listSuppliers();
  }

  void _reload() {
    setState(() {
      _future = _service.listSuppliers();
    });
  }

  Future<void> _setStatus(SupplierModel supplier, String status) async {
    if (_busy || supplier.id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.updateStatus(supplier.id, status);
      if (!mounted) return;
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSupplier(SupplierModel supplier) async {
    if (_busy || supplier.id.isEmpty) return;
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupplierEditSheet(supplier: supplier),
    );
    if (payload == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.updateSupplier(supplier.id, payload);
      if (!mounted) return;
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AdminTopBar(
            title: LanguageService.instance.t('admin_qa_suppliers'),
            showBack: true,
          ),
          Expanded(
            child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                Text(
                  'Edit, suspend, or reactivate supplier partners from MongoDB.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<SupplierModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final suppliers = snapshot.data ?? SupplierModel.sampleData;
                    return Column(
                      children: [
                        for (final supplier in suppliers) ...[
                          SupplierCard(
                            supplier: supplier,
                            onEdit: () => _editSupplier(supplier),
                            onSuspend: () => _setStatus(supplier, 'suspended'),
                            onReactivate: () => _setStatus(supplier, 'active'),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(child: CircularProgressIndicator()),
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

class _SupplierEditSheet extends StatefulWidget {
  final SupplierModel supplier;

  const _SupplierEditSheet({required this.supplier});

  @override
  State<_SupplierEditSheet> createState() => _SupplierEditSheetState();
}

class _SupplierEditSheetState extends State<_SupplierEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _handleController;
  late String _status;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier.name);
    _phoneController = TextEditingController(text: widget.supplier.phone);
    _emailController = TextEditingController(text: widget.supplier.email);
    _handleController = TextEditingController(text: widget.supplier.handle);
    _status = widget.supplier.status.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'handle': _handleController.text.trim(),
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8CCB5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Edit Supplier',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _EditField(label: 'Name', controller: _nameController),
            _EditField(label: 'Phone', controller: _phoneController),
            _EditField(label: 'Email', controller: _emailController),
            _EditField(label: 'Handle', controller: _handleController),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: _inputDecoration('Status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _EditField({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: _inputDecoration(label),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surfaceElevated,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.border),
    ),
  );
}
