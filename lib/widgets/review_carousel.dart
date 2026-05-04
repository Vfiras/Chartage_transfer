import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../models/review.dart';
import '../themes/app_theme.dart';
import 'review_card.dart';

class ReviewCarousel extends StatefulWidget {
  final List<Review> reviews;

  const ReviewCarousel({
    super.key,
    required this.reviews,
  });

  @override
  State<ReviewCarousel> createState() => _ReviewCarouselState();
}

class _ReviewCarouselState extends State<ReviewCarousel> {
  final CarouselSliderController _controller = CarouselSliderController();
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fraction = constraints.maxWidth >= 900
            ? 0.33
            : constraints.maxWidth >= 640
                ? 0.52
                : 1.05;

        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CarouselSlider.builder(
                carouselController: _controller,
                itemCount: widget.reviews.length,
                itemBuilder: (context, index, realIndex) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: ReviewCard(review: widget.reviews[index]),
                  );
                },
                options: CarouselOptions(
                  height: 235,
                  viewportFraction: fraction,
                  enableInfiniteScroll: widget.reviews.length > 2,
                  autoPlay: !_hovering,
                  autoPlayInterval: const Duration(seconds: 4),
                  autoPlayAnimationDuration: const Duration(milliseconds: 650),
                  pauseAutoPlayOnManualNavigate: true,
                  pauseAutoPlayOnTouch: true,
                ),
              ),
              Positioned(
                left: 2,
                child: _ArrowButton(
                  icon: Icons.chevron_left,
                  label: 'Previous review',
                  onTap: () => _controller.previousPage(),
                ),
              ),
              Positioned(
                right: 2,
                child: _ArrowButton(
                  icon: Icons.chevron_right,
                  label: 'Next review',
                  onTap: () => _controller.nextPage(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [AppTheme.cardShadow],
          ),
          child: Icon(icon, color: AppTheme.primaryText),
        ),
      ),
    );
  }
}
