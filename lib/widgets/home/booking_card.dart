import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../common/primary_button.dart';

class BookingCard extends StatefulWidget {
  final VoidCallback onSearch;

  const BookingCard({super.key, required this.onSearch});

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  final TextEditingController _pickup = TextEditingController();
  final TextEditingController _destination = TextEditingController();
  String _tripType = 'one-way';

  @override
  void dispose() {
    _pickup.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Premium floating surface
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x14FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 36,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              children: [
                _routeFields(),
                const SizedBox(height: 16),
                _datePassengerRow(),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Search & Book',
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                  onPressed: widget.onSearch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0A000000))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUICK BOOKING',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Where are you going?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _tripTypeBtn('one-way', 'One Way'),
                _tripTypeBtn('round-trip', 'Round Trip'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripTypeBtn(String value, String label) {
    final active = _tripType == value;
    return GestureDetector(
      onTap: () => setState(() => _tripType = value),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF888888),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _routeFields() {
    return Stack(
      children: [
        Positioned(
          left: 17,
          top: 44,
          bottom: 44,
          child: Container(
            width: 1.5,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, Color(0x66E6A200), AppColors.secondary],
              ),
            ),
          ),
        ),
        Column(
          children: [
            _routeField(
              icon: Icons.place_rounded,
              title: 'PICKUP',
              controller: _pickup,
              placeholder: 'Hotel, address, terminal…',
              iconBg: AppColors.primary,
              bg: const Color(0xFFF8F8F8),
              titleColor: AppColors.textHint,
            ),
            const SizedBox(height: 10),
            _routeField(
              icon: Icons.navigation_rounded,
              title: 'DESTINATION',
              controller: _destination,
              placeholder: 'Airport or destination…',
              iconBg: AppColors.secondary,
              bg: AppColors.chipGoldBg,
              titleColor: const Color(0xFFC8960A),
              borderColor: const Color(0x2EE6A200),
            ),
          ],
        ),
        Positioned(
          right: 2,
          top: 60,
          child: GestureDetector(
            onTap: () {
              final tmp = _pickup.text;
              _pickup.text = _destination.text;
              _destination.text = tmp;
              setState(() {});
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x16000000), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF888888)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeField({
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required String placeholder,
    required Color iconBg,
    required Color bg,
    required Color titleColor,
    Color borderColor = Colors.transparent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
                TextField(
                  controller: controller,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 3),
                    border: InputBorder.none,
                    hintText: placeholder,
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 26),
        ],
      ),
    );
  }

  Widget _datePassengerRow() {
    return Row(
      children: [
        Expanded(
          child: _smallInfo(
            icon: Icons.calendar_month_rounded,
            title: 'DATE',
            value: 'Select date',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _smallInfo(
            icon: Icons.groups_rounded,
            title: 'PASSENGERS',
            value: '1 person',
          ),
        ),
      ],
    );
  }

  Widget _smallInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}