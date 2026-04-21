import 'package:flutter/material.dart';
import '../../data/home_data.dart';
import '../../theme/app_colors.dart';

class PartnersStrip extends StatelessWidget {
  const PartnersStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.softBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'TRUSTED PARTNERS',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  ...List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(Icons.star_rounded, size: 12, color: AppColors.secondaryLight),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '4.9',
                    style: TextStyle(color: Color(0xFF555555), fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    '· 2,400+ rides',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: HomeData.partners.map((p) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: p == HomeData.partners.last ? 0 : 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFC8C8C8),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}