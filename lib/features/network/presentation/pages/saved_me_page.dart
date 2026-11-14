import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/time_ago.dart';
import 'package:finnet/features/network/data/network_api.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/providers/network_saver.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// `/network/saved-me`: who saved the person and hasn't been saved back
/// -- what the batched "saved your profile" push opens -- each with Save
/// back. At one event with `?event=`.
class SavedMePage extends ConsumerStatefulWidget {
  const SavedMePage({super.key, this.eventId});

  final int? eventId;

  static const emptyKey = ValueKey('saved-me-empty');
  static const moreKey = ValueKey('saved-me-more');

  @override
  ConsumerState<SavedMePage> createState() => _SavedMePageState();
}

class _SavedMePageState extends ConsumerState<SavedMePage> {
  /// Saved back here, by handle: shown as done until the list is read again.
  final Set<String> _savedBack = {};
  final Set<String> _saving = {};

  /// Pages after the first.
  final List<SavedMeEntry> _more = [];
  int _page = 1;
  bool _loadingMore = false;

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final firstPage = ref.read(savedMeProvider(widget.eventId)).valueOrNull;
    final next = _page + 1;
    try {
      final more = await ref
          .read(networkApiProvider)
          .savedMe(eventId: widget.eventId, page: next);
      if (!mounted) return;
      // Page 1 read again meanwhile: these were at the old offsets.
      if (!identical(
          ref.read(savedMeProvider(widget.eventId)).valueOrNull, firstPage)) {
        return;
      }
      setState(() {
        _more.addAll(more.items);
        _page = next;
      });
    } catch (e) {
      if (mounted) {
        showToast(context, extractErrorMessage(e), icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _saveBack(SavedMeEntry entry) async {
    final handle = entry.person.handle;
    if (handle == null || _saving.contains(handle)) return;
    setState(() => _saving.add(handle));
    final attempt = await ref.read(networkSaverProvider.notifier).save(
          handle: handle,
          method: MetHow.link,
          eventId: entry.event?.id,
        );
    if (!mounted) return;
    setState(() => _saving.remove(handle));
    switch (attempt) {
      case Saved():
      case SavedLater():
        setState(() => _savedBack.add(handle));
        showToast(
            context,
            attempt is Saved
                ? "You've saved each other."
                : "Saved. It'll sync when you're back online.");
      case SaveRefused(:final message):
        showToast(context, message, icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(savedMeProvider(widget.eventId), (before, now) {
      if (before?.valueOrNull != null &&
          now.valueOrNull != null &&
          !identical(before!.valueOrNull, now.valueOrNull) &&
          (_more.isNotEmpty || _page != 1)) {
        setState(() {
          _more.clear();
          _page = 1;
        });
      }
    });
    final answer = ref.watch(savedMeProvider(widget.eventId));
    final page = answer.valueOrNull;
    // Each person once, however the pages overlapped.
    final seen = <String>{};
    final items = page == null
        ? const <SavedMeEntry>[]
        : [
            for (final e in [...page.items, ..._more])
              if (seen.add('${e.person.userId ?? e.person.handle}')) e,
          ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SAVED YOU',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
      ),
      body: page == null
          ? answer.hasError
              ? ErrorView(
                  message: extractErrorMessage(answer.error,
                      defaultMessage: "Couldn't load who saved you."),
                  onRetry: () =>
                      ref.invalidate(savedMeProvider(widget.eventId)),
                )
              : const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.ink))
          : RefreshIndicator(
              color: AppColors.ink,
              onRefresh: () async {
                setState(_savedBack.clear);
                final fresh =
                    ref.refresh(savedMeProvider(widget.eventId).future);
                await fresh;
              },
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          key: SavedMePage.emptyKey,
                          padding: EdgeInsets.fromLTRB(32, 64, 32, 32),
                          child: Text(
                            'No one new. When someone saves you, they show up '
                            'here to save back.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        for (final entry in items) _row(entry),
                        if (_page * savedMePageSize < page.total)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton(
                              key: SavedMePage.moreKey,
                              onPressed: _loadingMore ? null : _loadMore,
                              child:
                                  Text(_loadingMore ? 'Loading…' : 'Show more'),
                            ),
                          ),
                      ],
                    ),
            ),
    );
  }

  Widget _row(SavedMeEntry entry) {
    final brief = entry.person;
    final handle = brief.handle;
    final done = handle != null && _savedBack.contains(handle);
    final busy = handle != null && _saving.contains(handle);
    final when = [
      if (entry.event != null)
        'Saved you at ${entry.event!.name}'
      else
        'Saved you',
      if (entry.savedAt != null) timeAgo(entry.savedAt!),
    ].join(' · ');
    return InkWell(
      key: ValueKey('saved-me-${handle ?? brief.fullName}'),
      onTap: brief.route == null ? null : () => context.push(brief.route!),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            PersonAvatar(picture: brief.picture, initials: brief.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brief.fullName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  if (brief.line != null)
                    Text(brief.line!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  Text(when,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (handle != null)
              done
                  ? const Chip(
                      avatar: Icon(Icons.check, size: 16),
                      label: Text('Saved'),
                      visualDensity: VisualDensity.compact,
                    )
                  : FilledButton(
                      key: ValueKey('save-back-$handle'),
                      onPressed: busy ? null : () => _saveBack(entry),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          visualDensity: VisualDensity.compact),
                      child: const Text('Save back'),
                    ),
          ],
        ),
      ),
    );
  }
}
