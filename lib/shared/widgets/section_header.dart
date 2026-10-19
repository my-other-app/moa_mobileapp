import 'package:flutter/material.dart';

const _ink = Color(0xFF1E1E1E);
const _link = Color(0xFF2C333D);

/// A section's heading on the main tabs: the title in BebasNeue.
const sectionTitleStyle = TextStyle(
  fontFamily: 'BebasNeue',
  fontSize: 24,
  height: 1.1,
  letterSpacing: 0.3,
  color: _ink,
);

/// A section's title with "See all ›" beside it on the same baseline: the
/// one heading every list on the discover screens, Home and Clubs uses.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllKey,
    this.seeAllLabel = 'See all',
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  /// Written in capitals.
  final String title;
  final VoidCallback? onSeeAll;
  final Key? seeAllKey;
  final String seeAllLabel;

  /// Beside the title, before "See all": a count, say.
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: sectionTitleStyle,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (onSeeAll != null) ...[
            const SizedBox(width: 12),
            SeeAllLink(key: seeAllKey, onTap: onSeeAll!, label: seeAllLabel),
          ],
        ],
      ),
    );
  }
}

/// "See all ›": a small text button, no underline.
class SeeAllLink extends StatelessWidget {
  const SeeAllLink({super.key, required this.onTap, this.label = 'See all'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
          // The label's baseline is the row's, so it lines up with the
          // title beside it.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _link,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: _link),
            ],
          ),
        ),
      ),
    );
  }
}
