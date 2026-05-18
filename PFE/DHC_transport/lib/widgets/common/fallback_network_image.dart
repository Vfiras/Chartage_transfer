import 'package:flutter/material.dart';

class FallbackNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;

  const FallbackNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
      );
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFECECEC),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          width: width,
          height: height,
          color: const Color(0xFF2F2F2F),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_rounded,
            color: Colors.white54,
            size: 32,
          ),
        );
      },
    );
  }
}
