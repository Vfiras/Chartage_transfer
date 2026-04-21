import 'package:flutter/material.dart';
import '../data/services_data.dart';
import '../theme/app_colors.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = ServicesData.items;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WHAT WE OFFER', style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8)),
              const SizedBox(height: 4),
              const Text('Our Services', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1)),
              const SizedBox(height: 4),
              const Text('Tailored transfer solutions for every need.', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
              const SizedBox(height: 16),
              ...items.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.softBorder),
                    boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 6))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.popular)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x26FFB400),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('POPULAR', style: TextStyle(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .8)),
                        ),
                      Text(item.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(item.desc, style: const TextStyle(color: Color(0xFF777777), fontSize: 12, height: 1.55)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: item.tags
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.chipGoldBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(tag, style: const TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.w700)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}