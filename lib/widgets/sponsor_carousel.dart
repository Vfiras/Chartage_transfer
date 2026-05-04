import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

import '../models/sponsor.dart';

class SponsorCarousel extends StatelessWidget {
  final List<Sponsor> sponsors;

  const SponsorCarousel({
    super.key,
    required this.sponsors,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trusted sponsors carousel',
      child: CarouselSlider.builder(
        itemCount: sponsors.length,
        itemBuilder: (context, index, realIndex) {
          final sponsor = sponsors[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: sponsor.logoUrl.toLowerCase().endsWith('.svg')
                  ? SvgPicture.network(
                      sponsor.logoUrl,
                      height: 36,
                      semanticsLabel: sponsor.name,
                    )
                  : CachedNetworkImage(
                      imageUrl: sponsor.logoUrl,
                      height: 42,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => _LogoPlaceholder(),
                      errorWidget: (_, __, ___) => Text(
                        sponsor.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          );
        },
        options: CarouselOptions(
          height: 70,
          autoPlay: true,
          viewportFraction: 0.32,
          enlargeCenterPage: false,
          pauseAutoPlayOnTouch: true,
        ),
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEDEDED),
      highlightColor: Colors.white,
      child: Container(
        width: 96,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
