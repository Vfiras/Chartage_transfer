import 'package:flutter/material.dart';

import '../../models/supplier_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/supplier_card.dart';

class AdminSuppliersScreen extends StatelessWidget {
  const AdminSuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final suppliers = SupplierModel.sampleData;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
        children: [
          const Text(
            'Suppliers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage transport suppliers as clean mobile cards.',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          for (final supplier in suppliers) ...[
            SupplierCard(
              supplier: supplier,
              onEdit: () {},
              onDelete: () {},
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
