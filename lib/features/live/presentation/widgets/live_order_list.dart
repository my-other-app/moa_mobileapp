import 'package:finnet/features/live/presentation/widgets/live_look.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// One row of a [LiveOrderList].
class LiveOrderItem {
  const LiveOrderItem({required this.id, required this.label, this.image});
  final String id;
  final String label;

  /// A small picture beside the label.
  final String? image;
}

/// Put things in order: a row each, dragged by its handle, or moved a place
/// at a time with the arrows beside it (for a thumb that will not drag, and
/// for a screen reader, which also gets "Move up" and "Move down" actions).
///
/// [order] is the rows' ids as they stand; [onChanged] hears every move.
/// [marks] puts a tick or a cross on a row once the right order is shown.
class LiveOrderList extends StatelessWidget {
  const LiveOrderList({
    super.key,
    required this.items,
    required this.order,
    required this.onChanged,
    this.enabled = true,
    this.marks = const {},
    this.keyPrefix = 'order',
  });

  final List<LiveOrderItem> items;
  final List<String> order;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  /// Row id to right (true) or wrong (false) place.
  final Map<String, bool> marks;

  /// Keys the rows as `<prefix>-<id>`, their arrows `<prefix>-up-<id>`.
  final String keyPrefix;

  void _move(int from, int to) {
    if (to < 0 || to >= order.length || from == to) return;
    final next = [...order];
    final id = next.removeAt(from);
    next.insert(to, id);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final i in items) i.id: i};
    final rows = [
      for (final id in order)
        if (byId[id] != null) byId[id]!,
    ];
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: rows.length,
      onReorderItem: (from, to) {
        if (enabled) _move(from, to);
      },
      itemBuilder: (context, i) => _Row(
        key: ValueKey('$keyPrefix-${rows[i].id}'),
        item: rows[i],
        place: i,
        count: rows.length,
        enabled: enabled,
        mark: marks[rows[i].id],
        keyPrefix: keyPrefix,
        onUp: () => _move(i, i - 1),
        onDown: () => _move(i, i + 1),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.item,
    required this.place,
    required this.count,
    required this.enabled,
    required this.onUp,
    required this.onDown,
    required this.keyPrefix,
    this.mark,
  });

  final LiveOrderItem item;
  final int place;
  final int count;
  final bool enabled;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final String keyPrefix;
  final bool? mark;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final first = place == 0, last = place == count - 1;
    final edge = mark == null
        ? LiveColors.line
        : mark!
            ? LiveColors.right
            : LiveColors.wrong;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        label: '${place + 1} of $count: ${item.label}'
            '${mark == null ? '' : mark! ? ', in the right place' : ', not in the right place'}',
        customSemanticsActions: enabled
            ? {
                if (!first)
                  const CustomSemanticsAction(label: 'Move up'): onUp,
                if (!last)
                  const CustomSemanticsAction(label: 'Move down'): onDown,
              }
            : null,
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: edge, width: mark == null ? 1 : 2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                if (enabled)
                  ReorderableDragStartListener(
                    index: place,
                    child: const SizedBox(
                      width: liveTapTarget,
                      height: 56,
                      child: Icon(Icons.drag_indicator_rounded,
                          color: LiveColors.muted),
                    ),
                  )
                else
                  const SizedBox(width: 12),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: look.liveCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: look.liveEdge),
                  ),
                  child: Text('${place + 1}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: look.accent)),
                ),
                if (item.image != null) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppNetworkImage(
                        url: item.image, width: 40, height: 40),
                  ),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(item.label,
                        style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: LiveColors.ink)),
                  ),
                ),
                if (mark != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                        mark! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: edge),
                  ),
                if (enabled) ...[
                  IconButton(
                    key: ValueKey('$keyPrefix-up-${item.id}'),
                    tooltip: 'Move up',
                    onPressed: first ? null : onUp,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    constraints: const BoxConstraints(
                        minWidth: liveTapTarget, minHeight: liveTapTarget),
                  ),
                  IconButton(
                    key: ValueKey('$keyPrefix-down-${item.id}'),
                    tooltip: 'Move down',
                    onPressed: last ? null : onDown,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    constraints: const BoxConstraints(
                        minWidth: liveTapTarget, minHeight: liveTapTarget),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
