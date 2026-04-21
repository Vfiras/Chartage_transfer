import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../common/fallback_network_image.dart';

class HeroSection extends StatelessWidget {
  final VoidCallback onBookNowTap;

  const HeroSection({
    super.key,
    required this.onBookNowTap,
  });

  static const _heroImage =
      'https://images.unsplash.com/photo-1633433491270-5c9c57a4ddb0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1400';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : 460.0;
        final compact = heroHeight < 320;
        final superCompact = heroHeight < 260;
        final topPadding = superCompact
            ? 10.0
            : compact
                ? 12.0
                : 16.0;
        final bottomPadding = superCompact
            ? 8.0
            : compact
                ? 14.0
                : 24.0;
        final interBlockSpacing = superCompact
            ? 10.0
            : compact
                ? 14.0
                : 18.0;
        final titleSize = superCompact
            ? 22.0
            : compact
                ? 24.0
                : 28.0;
        final subtitleSize = superCompact
            ? 11.0
            : compact
                ? 12.0
                : 13.0;
        final topBarGap = superCompact
            ? 6.0
            : compact
                ? 14.0
                : 32.0;

        return SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(34)),
                child: FallbackNetworkImage(
                  url: _heroImage,
                  fit: BoxFit.cover,
                ),
              ),

              // Improved readability layer
              Container(
                decoration: const BoxDecoration(
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(34)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x14000000),
                      Color(0x5C000000),
                      Color(0xCC000000),
                    ],
                  ),
                ),
              ),

              // Gold top shimmer
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.secondaryLight,
                        AppColors.secondary,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topBar(),
                      SizedBox(height: topBarGap),
                      const _VerifiedChip(),
                      SizedBox(height: compact ? 8 : 10),
                      Text(
                        'Book your private\ntransfer',
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          letterSpacing: -0.25,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 6),
                      Text(
                        'Comfortable · Punctual · Reliable',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xCCFFFFFF),
                          fontSize: subtitleSize,
                          letterSpacing: .25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      _ctaRow(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.secondaryLight, AppColors.secondary],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66E6A200),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.flight_rounded,
              color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'PREMIUM SERVICE',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 9,
                letterSpacing: 2.1,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'CARTHAGE TRANSFER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x38FFFFFF)),
          ),
          child: const Icon(Icons.notifications_none_rounded,
              color: Colors.white, size: 18),
        ),
      ],
    );
  }

  Widget _ctaRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: onBookNowTap,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 18 : 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [AppColors.secondaryLight, AppColors.secondary],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x80E6A200),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Book now',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded,
                        color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0x24FFFFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x38FFFFFF)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      color: AppColors.secondaryLight, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '4.9',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '· 2,400+ rides',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x40FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.verified_user_outlined,
              size: 14, color: AppColors.secondaryLight),
          SizedBox(width: 6),
          Text(
            'Verified · Licensed · Insured',
            style: TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
