import 'package:flutter/material.dart';

/// A reusable empty state widget for scenarios with no data.
///
/// This widget provides a consistent "no data" UI across the app with:
/// - An icon or illustration
/// - A title message
/// - An optional subtitle
/// - An optional action button
class EmptyStateView extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// The main title text
  final String title;

  /// Optional subtitle/description
  final String? subtitle;

  /// Optional action button label
  final String? actionLabel;

  /// Optional action callback
  final VoidCallback? onAction;

  /// Icon color (defaults to grey)
  final Color? iconColor;

  /// Icon size
  final double iconSize;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize = 80,
  });

  /// Factory for "no clubs" state
  factory EmptyStateView.noClubs({VoidCallback? onExplore}) {
    return EmptyStateView(
      icon: Icons.groups_outlined,
      title: 'No Clubs Yet',
      subtitle: 'Start following clubs to see them here',
      actionLabel: 'Explore Clubs',
      onAction: onExplore,
      iconColor: Colors.purple,
    );
  }

  /// Factory for "no events" state
  factory EmptyStateView.noEvents({VoidCallback? onExplore}) {
    return EmptyStateView(
      icon: Icons.event_outlined,
      title: 'No Events',
      subtitle: 'Check back later for upcoming events',
      actionLabel: 'Refresh',
      onAction: onExplore,
      iconColor: Colors.blue,
    );
  }

  /// Factory for "no notifications" state
  factory EmptyStateView.noNotifications() {
    return const EmptyStateView(
      icon: Icons.notifications_none_outlined,
      title: 'No Notifications',
      subtitle: 'You\'re all caught up!',
      iconColor: Colors.teal,
    );
  }

  /// Factory for "no search results" state
  factory EmptyStateView.noSearchResults({String? query}) {
    return EmptyStateView(
      icon: Icons.search_off_outlined,
      title: 'No Results Found',
      subtitle: query != null
          ? 'No results for "$query"'
          : 'Try a different search term',
      iconColor: Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? Colors.grey;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
