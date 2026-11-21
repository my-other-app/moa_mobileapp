import 'package:flutter/material.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/motion.dart';

/// One thing an actions sheet offers: an icon in a soft grey circle, then
/// what it does (and a quieter line under it).
class AppAction<T> {
  const AppAction({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
    this.selected = false,
    this.key,
  });

  /// What the sheet answers when this is chosen.
  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;

  /// Removes, blocks or deletes: drawn in red.
  final bool destructive;
  final bool enabled;

  /// The current choice, among choices (a sort): ticked.
  final bool selected;

  /// On the row, for tests.
  final Key? key;
}

/// The red of an action that removes something.
const appDestructive = Color(0xFFC62828);

/// The app's actions sheet, in place of a 3-dot [PopupMenuButton]'s menu:
/// from the bottom, with the drag handle, a title in Bebas Neue when given,
/// and one row a choice, each 56 high. Answers the chosen action's value;
/// null when closed without a choice.
Future<T?> showAppActions<T>(
  BuildContext context, {
  required List<AppAction<T>> actions,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => AppActionsSheet<T>(title: title, actions: actions),
  );
}

/// What [showAppActions] shows: public for tests and for a screen that
/// wants the rows inline.
class AppActionsSheet<T> extends StatelessWidget {
  const AppActionsSheet({super.key, required this.actions, this.title});

  final List<AppAction<T>> actions;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title!.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 22,
                          color: AppColors.ink),
                    ),
                  ),
                ),
              for (final action in actions) AppActionRow<T>(action: action),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the sheet: tapping it closes the sheet with its value.
class AppActionRow<T> extends StatelessWidget {
  const AppActionRow({super.key, required this.action});

  final AppAction<T> action;

  @override
  Widget build(BuildContext context) {
    final a = action;
    final color = a.destructive ? appDestructive : AppColors.ink;
    final row = Semantics(
      button: true,
      enabled: a.enabled,
      selected: a.selected,
      child: InkWell(
        key: a.key,
        onTap: a.enabled
            ? () {
                Haptics.selection();
                Navigator.of(context).pop<T>(a.value);
              }
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                if (a.icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: a.destructive
                          ? const Color(0xFFFDECEC)
                          : AppColors.softGrey,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              a.selected ? FontWeight.w700 : FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (a.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          a.subtitle!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (a.selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(Icons.check_rounded,
                        size: 22, color: AppColors.ink),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return a.enabled ? row : Opacity(opacity: 0.4, child: row);
  }
}

/// A button that opens [actions] in the app's actions sheet, in place of a
/// [PopupMenuButton]: the app's rounded "more" icon by default, or [child]
/// (a "Sort: Newest" pill). [onSelected] is told what was chosen.
class AppMenuButton<T> extends StatelessWidget {
  const AppMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    this.title,
    this.tooltip = 'More',
    this.icon,
    this.child,
    this.enabled = true,
    this.color,
  });

  /// Read when the button is tapped, so the rows follow the screen's state.
  final List<AppAction<T>> Function() actions;
  final ValueChanged<T> onSelected;
  final String? title;
  final String tooltip;

  /// In place of the "more" icon.
  final Widget? icon;

  /// In place of an icon button: the whole of what is tapped.
  final Widget? child;
  final bool enabled;

  /// The icon's colour; the app bar's own when null.
  final Color? color;

  Future<void> _open(BuildContext context) async {
    final chosen =
        await showAppActions<T>(context, title: title, actions: actions());
    if (chosen != null) onSelected(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final tappable = child;
    if (tappable != null) {
      return Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(60),
            onTap: enabled ? () => _open(context) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Center(widthFactor: 1, child: tappable),
            ),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: tooltip,
      color: color,
      icon: icon ?? const Icon(Icons.more_horiz_rounded),
      onPressed: enabled ? () => _open(context) : null,
    );
  }
}
