import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart'
    show posterAspectRatio;

/// A generic shimmer box for creating loading placeholders.
class ShimmerBox extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey[300],
      ),
    );
  }
}

/// Shimmer loading skeleton for event cards.
class ShimmerEventCard extends StatelessWidget {
  const ShimmerEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with avatar and text
          Row(
            children: [
              const ShimmerBox(height: 48, width: 48, borderRadius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(height: 16, width: 180),
                    SizedBox(height: 8),
                    ShimmerBox(height: 12, width: 120),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Image placeholder
          const ShimmerBox(height: 180),
          const SizedBox(height: 12),
          // Tags row
          Row(
            children: const [
              ShimmerBox(height: 24, width: 60, borderRadius: 12),
              SizedBox(width: 8),
              ShimmerBox(height: 24, width: 50, borderRadius: 12),
              SizedBox(width: 8),
              ShimmerBox(height: 24, width: 40, borderRadius: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading skeleton for club tiles.
class ShimmerClubTile extends StatelessWidget {
  const ShimmerClubTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(height: 52, width: 52, borderRadius: 26),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(height: 18, width: 200),
                      SizedBox(height: 8),
                      ShimmerBox(height: 14, width: 120),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerBox(height: 14),
            const SizedBox(height: 6),
            const ShimmerBox(height: 14),
            const SizedBox(height: 6),
            const ShimmerBox(height: 14, width: 200),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading skeleton for a club's post (a Threads card).
class ShimmerThreadCard extends StatelessWidget {
  const ShimmerThreadCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(height: 44, width: 44, borderRadius: 6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(height: 16, width: 160),
                      SizedBox(height: 8),
                      ShimmerBox(height: 12, width: 80),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerBox(height: 14),
            const SizedBox(height: 6),
            const ShimmerBox(height: 14),
            const SizedBox(height: 6),
            const ShimmerBox(height: 14, width: 220),
            const SizedBox(height: 16),
            const ShimmerBox(height: 20, width: 120),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading skeleton for profile page.
class ShimmerProfileCard extends StatelessWidget {
  const ShimmerProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Avatar and name section
            Row(
              children: [
                const ShimmerBox(height: 60, width: 60, borderRadius: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(height: 28, width: 180),
                      SizedBox(height: 8),
                      ShimmerBox(height: 16, width: 120),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Tags
            Row(
              children: const [
                ShimmerBox(height: 28, width: 80, borderRadius: 14),
                SizedBox(width: 8),
                ShimmerBox(height: 28, width: 70, borderRadius: 14),
                SizedBox(width: 8),
                ShimmerBox(height: 28, width: 90, borderRadius: 14),
              ],
            ),
            const SizedBox(height: 40),
            // Menu items
            ...List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: const [
                    ShimmerBox(height: 48, width: 48, borderRadius: 24),
                    SizedBox(width: 16),
                    ShimmerBox(height: 16, width: 140),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shimmer list builder for creating multiple shimmer items.
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final double separatorHeight;

  const ShimmerList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.separatorHeight = 24,
  });

  /// Creates a shimmer list of event cards.
  factory ShimmerList.events({int count = 3}) {
    return ShimmerList(
      itemCount: count,
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, __) => const ShimmerEventCard(),
    );
  }

  /// Creates a shimmer list of club tiles.
  factory ShimmerList.clubs({int count = 5}) {
    return ShimmerList(
      itemCount: count,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      separatorHeight: 16,
      itemBuilder: (_, __) => const ShimmerClubTile(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: separatorHeight),
      itemBuilder: itemBuilder,
    );
  }
}

/// Shimmer loading skeleton for event detail page.
class ShimmerEventDetail extends StatelessWidget {
  const ShimmerEventDetail({super.key, this.poster});

  /// The event's poster, when the way in already had it (a card's poster
  /// flying in): drawn as itself, above the rest still shimmering.
  final Widget? poster;

  @override
  Widget build(BuildContext context) {
    Widget shimmer(Widget child) => Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: child,
        );
    final rest = <Widget>[
      // Event title
      const ShimmerBox(height: 28, width: 280),
      const SizedBox(height: 12),
      // Organizer
      Row(
        children: const [
          ShimmerBox(height: 40, width: 40, borderRadius: 20),
          SizedBox(width: 12),
          ShimmerBox(height: 16, width: 150),
        ],
      ),
      const SizedBox(height: 24),
      // Tags
      Row(
        children: const [
          ShimmerBox(height: 28, width: 70, borderRadius: 14),
          SizedBox(width: 8),
          ShimmerBox(height: 28, width: 60, borderRadius: 14),
          SizedBox(width: 8),
          ShimmerBox(height: 28, width: 50, borderRadius: 14),
        ],
      ),
      const SizedBox(height: 24),
      // Date/time info
      const ShimmerBox(height: 60, borderRadius: 8),
      const SizedBox(height: 16),
      // Location
      const ShimmerBox(height: 60, borderRadius: 8),
      const SizedBox(height: 24),
      // Description
      const ShimmerBox(height: 16),
      const SizedBox(height: 8),
      const ShimmerBox(height: 16),
      const SizedBox(height: 8),
      const ShimmerBox(height: 16, width: 250),
      const SizedBox(height: 32),
      // Register button
      const ShimmerBox(height: 50, borderRadius: 25),
    ];
    final poster = this.poster;
    if (poster == null) {
      return shimmer(SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event poster: 4:5, as the page draws it.
            LayoutBuilder(
              builder: (context, box) => ShimmerBox(
                height: box.maxWidth / posterAspectRatio,
                borderRadius: 12,
              ),
            ),
            const SizedBox(height: 20),
            ...rest,
          ],
        ),
      ));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          poster,
          const SizedBox(height: 20),
          shimmer(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rest,
          )),
        ],
      ),
    );
  }
}

/// The club page while it loads, in its shape: the logo on the left, the
/// name, numbers, tagline and interests beside it, FOLLOW, then what it is
/// about.
class ShimmerClubDetail extends StatelessWidget {
  const ShimmerClubDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                ShimmerBox(height: 68, width: 68, borderRadius: 10),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name, numbers, tagline
                      ShimmerBox(height: 24, width: 170),
                      SizedBox(height: 8),
                      ShimmerBox(height: 14, width: 210),
                      SizedBox(height: 10),
                      ShimmerBox(height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(height: 14, width: 150),
                      SizedBox(height: 12),
                      // Interests
                      Row(
                        children: [
                          ShimmerBox(height: 26, width: 70),
                          SizedBox(width: 6),
                          ShimmerBox(height: 26, width: 64),
                          SizedBox(width: 6),
                          ShimmerBox(height: 26, width: 80),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            // Follow
            ShimmerBox(height: 56),
            SizedBox(height: 28),
            // About
            ShimmerBox(height: 16),
            SizedBox(height: 8),
            ShimmerBox(height: 16),
            SizedBox(height: 8),
            ShimmerBox(height: 16, width: 200),
          ],
        ),
      ),
    );
  }
}
