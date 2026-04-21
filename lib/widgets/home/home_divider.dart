import 'package:flutter/material.dart';

class HomeDivider extends StatelessWidget {
  const HomeDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Color(0x1A000000),
            Color(0x1A000000),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}