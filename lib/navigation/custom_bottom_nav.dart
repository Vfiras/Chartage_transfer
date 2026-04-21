import 'package:flutter/material.dart';
import '../../navigation/app_tab.dart';
import '../../theme/app_colors.dart';

class CustomBottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onChanged;

  const CustomBottomNav({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isBookActive = current == AppTab.book;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? 8 : 12),
          child: SizedBox(
            height: 88,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Solid white pill bar
                Positioned.fill(
                  top: 14,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFE5E5E5),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: Icons.home_rounded,
                              label: 'Home',
                              active: current == AppTab.home,
                              onTap: () => onChanged(AppTab.home),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.directions_car_rounded,
                              label: 'Fleet',
                              active: current == AppTab.vehicles,
                              onTap: () => onChanged(AppTab.vehicles),
                            ),
                          ),
                          const SizedBox(width: 74),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.grid_view_rounded,
                              label: 'Services',
                              active: current == AppTab.services,
                              onTap: () => onChanged(AppTab.services),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.headset_mic_rounded,
                              label: 'Help',
                              active: current == AppTab.support,
                              onTap: () => onChanged(AppTab.support),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Center floating action button
                Positioned(
                  top: -2,
                  child: GestureDetector(
                    onTap: () => onChanged(AppTab.book),
                    child: Column(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isBookActive
                                  ? [
                                      AppColors.secondary,
                                      AppColors.secondaryDark
                                    ]
                                  : [
                                      AppColors.secondaryLight,
                                      AppColors.secondary
                                    ],
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: (isBookActive
                                        ? const Color(0x66CC8C00)
                                        : const Color(0x66E6A200))
                                    .withValues(alpha: 0.8),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Book',
                          style: TextStyle(
                            color: isBookActive
                                ? AppColors.secondary
                                : const Color(0xFF8A8A8A),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.secondary : const Color(0xFFAFAFAF);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
