import 'package:flutter/material.dart';
import '../../data/home_data.dart';
import '../../theme/app_colors.dart';

class TrustElements extends StatelessWidget {
  const TrustElements({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122, // slightly lighter visual weight
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: HomeData.trustChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final chip = HomeData.trustChips[index];
          return Container(
            width: 96,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.softBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0x14FFB400),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconData(chip.iconCodePoint, fontFamily: 'MaterialIcons'),
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  chip.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  chip.value,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}