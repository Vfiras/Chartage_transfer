import 'package:flutter/material.dart';

const _gold = Color(0xFFC8A96B);
const _surface = Color(0xFF1C1C1F);

/// The AVA concierge portrait. Loads a network image and gracefully
/// degrades to a gold-sparkle emblem if the image is unavailable.
class AvaAvatar extends StatelessWidget {
  final double size;
  final double borderWidth;

  const AvaAvatar({
    super.key,
    this.size = 32,
    this.borderWidth = 1.5,
  });

  // Stitch-hosted concierge portrait (CDN). Falls back to the sparkle emblem.
  static const _portraitUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBg03rnVbyGZf5xlE0rDcxEULcOh0Ju8X1GiRfLyxCSZi4rcZEF5BtFvdjtFdHJEjgo4meKqnfZfwUx_Opqa9rNNnI44khrANeXF6Q9I3a-BJCw4WEfzUANC_0KKOU3XcXdUq_NHQNK8neVNwOlJxZqulzF7IJMMBimxCftFj_tO7usI80BJUuJ50zTrjk87dm_Z8XBN-cTKPZDnWRYmPVQe71rBvxXIDdEZZp70I9u61AgxliB85Vx39obSdxcLQrEt7aLoQIfAA';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _surface,
        border: Border.all(
            color: _gold.withValues(alpha: 0.35), width: borderWidth),
      ),
      child: ClipOval(
        child: Image.network(
          _portraitUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _Fallback(size: size);
          },
          errorBuilder: (_, __, ___) => _Fallback(size: size),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final double size;
  const _Fallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: _surface,
      alignment: Alignment.center,
      child: Icon(Icons.auto_awesome, color: _gold, size: size * 0.42),
    );
  }
}
