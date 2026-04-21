import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SupportScreen extends StatelessWidget {
  final VoidCallback? onOpenAbout;

  const SupportScreen({super.key, this.onOpenAbout});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      ['How do I book a transfer?', 'Use the Book tab to select route, date, and vehicle.'],
      ['Are prices fixed?', 'Yes. All prices are fixed and transparent.'],
      ['What if my flight is delayed?', 'We track flights in real-time and adjust pickup.'],
      ['Can I cancel?', 'Free cancellation up to 24h before pickup.'],
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            const Text('Support', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Available 24/7. Reach us however you prefer.', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            const SizedBox(height: 14),
            Row(
              children: [
                _contactBox(Icons.phone_outlined, 'Call', '+216 71 000 000'),
                const SizedBox(width: 8),
                _contactBox(Icons.chat_bubble_outline_rounded, 'WhatsApp', 'Instant reply'),
                const SizedBox(width: 8),
                _contactBox(Icons.mail_outline_rounded, 'Email', '24h response'),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Frequently Asked', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...faqs.map((e) => _FaqTile(q: e[0], a: e[1])),
            const SizedBox(height: 12),
            if (onOpenAbout != null)
              OutlinedButton.icon(
                onPressed: onOpenAbout,
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('About Carthage Transfer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.softBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contactBox(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.secondary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: open ? const Color(0x40FFB400) : AppColors.softBorder),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(widget.q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.a, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.55)),
            ),
          )
        ],
        onExpansionChanged: (v) => setState(() => open = v),
      ),
    );
  }
}