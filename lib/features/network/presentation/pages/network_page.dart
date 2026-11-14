import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/network/data/network_api.dart';
import 'package:finnet/features/network/data/network_files.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/providers/network_saver.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/toast.dart';

const _muted = Color(0xFF6B7280);

/// "28 Nov", or "28 Nov 2025" in another year.
String metDay(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final thisYear = (now ?? DateTime.now()).year == local.year;
  return DateFormat(thisYear ? 'd MMM' : 'd MMM yyyy').format(local);
}

/// Where and when someone was last met: "DevFest · 28 Nov", or "28 Nov".
String metLine(NetworkPerson person) {
  final last = person.encounters.isEmpty ? null : person.encounters.first;
  final at = last?.metAt ?? person.lastMetAt;
  final parts = [
    if (last?.event != null) last!.event!.name,
    if (at != null) metDay(at),
  ];
  return parts.isEmpty ? '' : 'Met ${parts.join(' · ')}';
}

/// The Network tab: everyone the person saved, newest first and grouped by
/// the event they were last met at, with search, the events and tags to
/// filter by, mutual only, and the sort. At one event (`?event=`, the
/// recap's link) it says how many were met there and nudges for notes.
///
/// Above the list: who saved them and hasn't been saved back, and the
/// saves still waiting for a signal.
class NetworkPage extends ConsumerStatefulWidget {
  const NetworkPage({super.key, this.eventId});

  /// The event to open at: the recap push's and email's link.
  final int? eventId;

  static const searchKey = ValueKey('network-search');
  static const mutualKey = ValueKey('network-mutual');
  static const emptyKey = ValueKey('network-empty');
  static const recapKey = ValueKey('network-recap');
  static const savedMeKey = ValueKey('network-saved-me');
  static const pendingKey = ValueKey('network-pending');
  static const scanKey = ValueKey('network-scan');
  static const exportKey = ValueKey('network-export');

  @override
  ConsumerState<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends ConsumerState<NetworkPage> {
  late NetworkQuery _query = NetworkQuery(eventId: widget.eventId);
  final _search = TextEditingController();
  Timer? _typing;

  /// Pages after the first, for the query on screen.
  final List<NetworkPerson> _more = [];
  int _page = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    // Anything saved with no signal goes now, if it can.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(networkSaverProvider.notifier).drain());
  }

  @override
  void didUpdateWidget(NetworkPage old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) {
      _setQuery(_query.copyWith(
          eventId: widget.eventId, clearEvent: widget.eventId == null));
    }
  }

  @override
  void dispose() {
    _typing?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setQuery(NetworkQuery query) {
    setState(() {
      _query = query;
      _more.clear();
      _page = 1;
    });
  }

  void _onTyping(String text) {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _setQuery(_query.copyWith(q: text));
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final next = _page + 1;
    try {
      final list = await ref.read(networkApiProvider).list(NetworkQuery(
            q: _query.q,
            eventId: _query.eventId,
            tag: _query.tag,
            mutualOnly: _query.mutualOnly,
            sort: _query.sort,
            page: next,
            pageSize: _query.pageSize,
          ));
      if (!mounted) return;
      setState(() {
        _more.addAll(list.items);
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

  Future<void> _export(NetworkExportFormat format) async {
    try {
      final text = await ref.read(networkApiProvider).export(format);
      await ref.read(textFileSharerProvider)(
        fileName: 'my-network.${format.name}',
        text: text,
        mimeType: format == NetworkExportFormat.vcf ? 'text/vcard' : 'text/csv',
        subject: 'My MyOtherApp network',
      );
    } catch (e) {
      if (!mounted) return;
      showToast(
          context,
          extractErrorMessage(e,
              defaultMessage: "Couldn't export your network. Try again."),
          icon: Icons.error_outline);
    }
  }

  Future<void> _refresh() async {
    unawaited(ref.read(networkSaverProvider.notifier).drain());
    setState(() {
      _more.clear();
      _page = 1;
    });
    ref.invalidate(savedMeProvider(null));
    try {
      final fresh = ref.refresh(networkListProvider(_query).future);
      await fresh;
    } catch (_) {
      // The page says why.
    }
  }

  @override
  Widget build(BuildContext context) {
    final answer = ref.watch(networkListProvider(_query));
    final list = answer.valueOrNull;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('NETWORK',
            style: TextStyle(fontSize: 28, fontFamily: 'BebasNeue')),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            key: NetworkPage.scanKey,
            tooltip: 'Scan to save a person',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () =>
                context.push(savePersonScanAt(ref.read(atEventIdProvider))),
          ),
          IconButton(
            tooltip: 'My QR',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => context.push(myQrLocation),
          ),
          PopupMenuButton<NetworkExportFormat>(
            key: NetworkPage.exportKey,
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            onSelected: _export,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: NetworkExportFormat.vcf,
                  child: Text('Export to contacts (vCard)')),
              PopupMenuItem(
                  value: NetworkExportFormat.csv,
                  child: Text('Export as a spreadsheet (CSV)')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.ink,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList.list(children: [
                const _PendingStrip(),
                const _SavedMeStrip(),
                _searchField(),
                const SizedBox(height: 10),
                _filters(list),
                if (_query.eventId != null && list != null) _recap(list),
              ]),
            ),
            ..._body(answer, list),
          ],
        ),
      ),
    );
  }

  Widget _searchField() => TextField(
        key: NetworkPage.searchKey,
        controller: _search,
        onChanged: _onTyping,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name, organisation or tag',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          filled: true,
          fillColor: AppColors.softGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    _setQuery(_query.copyWith(q: ''));
                  },
                ),
        ),
      );

  Widget _filters(NetworkList? list) {
    final events = list?.events ?? const <NetworkEventCount>[];
    final tags = list?.tags ?? const <NetworkTagCount>[];
    final chosenEvent = _query.eventId;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          PopupMenuButton<NetworkSort>(
            tooltip: 'Sort',
            onSelected: (sort) => _setQuery(_query.copyWith(sort: sort)),
            itemBuilder: (_) => [
              for (final sort in NetworkSort.values)
                CheckedPopupMenuItem(
                    value: sort,
                    checked: sort == _query.sort,
                    child: Text(sort.label)),
            ],
            child: Chip(
              avatar: const Icon(Icons.sort, size: 16),
              label: Text(_query.sort.label),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: NetworkPage.mutualKey,
            label: const Text('Mutual'),
            selected: _query.mutualOnly,
            visualDensity: VisualDensity.compact,
            onSelected: (on) => _setQuery(_query.copyWith(mutualOnly: on)),
          ),
          for (final e in events) ...[
            const SizedBox(width: 6),
            FilterChip(
              key: ValueKey('network-event-${e.event.id}'),
              label: Text('${e.event.name} · ${e.count}'),
              selected: chosenEvent == e.event.id,
              visualDensity: VisualDensity.compact,
              onSelected: (on) => _setQuery(on
                  ? _query.copyWith(eventId: e.event.id)
                  : _query.copyWith(clearEvent: true)),
            ),
          ],
          for (final t in tags) ...[
            const SizedBox(width: 6),
            FilterChip(
              key: ValueKey('network-tag-${t.tag}'),
              label: Text('#${t.tag}'),
              selected: _query.tag == t.tag,
              visualDensity: VisualDensity.compact,
              onSelected: (on) => _setQuery(on
                  ? _query.copyWith(tag: t.tag)
                  : _query.copyWith(clearTag: true)),
            ),
          ],
        ],
      ),
    );
  }

  /// At one event: "You met 12 people at DevFest", and the nudge.
  Widget _recap(NetworkList list) {
    final id = _query.eventId!;
    final counted = list.eventCount(id);
    final name = counted?.event.name ??
        (list.items.isNotEmpty
            ? list.items.first.events
                .where((e) => e.id == id)
                .map((e) => e.name)
                .firstOrNull
            : null);
    final count = counted?.count ?? list.total;
    if (name == null) return const SizedBox.shrink();
    final withoutNotes = list.items.where((p) => p.note == null).length;
    return Container(
      key: NetworkPage.recapKey,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.paleYellow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 1
                ? 'You met 1 person at $name'
                : 'You met $count people at $name',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (withoutNotes > 0) ...[
            const SizedBox(height: 2),
            const Text('Add notes while you still remember who was who.',
                style: TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  List<Widget> _body(AsyncValue<NetworkList> answer, NetworkList? list) {
    if (list == null) {
      if (answer.hasError) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              message: extractErrorMessage(answer.error,
                  defaultMessage: "Couldn't load your network."),
              onRetry: _refresh,
            ),
          ),
        ];
      }
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.ink)),
        ),
      ];
    }
    final people = [...list.items, ..._more];
    if (people.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _query.filtered ? const _NoMatches() : const _Empty(),
        ),
      ];
    }
    // Grouped by the event each was last met at, when the list is the
    // newest first and not one event's already.
    final grouped = _query.sort == NetworkSort.recent && _query.eventId == null;
    final rows = <Widget>[];
    String? lastGroup;
    for (final person in people) {
      if (grouped) {
        final last = person.encounters.isEmpty ? null : person.encounters.first;
        final group = last?.event?.name ?? 'Not at an event';
        if (group != lastGroup) {
          lastGroup = group;
          final count = last?.event == null
              ? null
              : list.eventCount(last!.event!.id)?.count;
          final day = last?.event?.startsAt;
          rows.add(_GroupHeading(
            [
              group,
              if (day != null) metDay(day),
              if (count != null) count == 1 ? '1 person' : '$count people',
            ].join(' · '),
          ));
        }
      }
      rows.add(NetworkPersonTile(person: person));
    }
    final hasMore = people.length < list.total;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverList.list(children: [
          ...rows,
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Loading…' : 'Show more'),
              ),
            ),
        ]),
      ),
    ];
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _muted)),
      );
}

/// One person in the network: who, where they were met, the owner's tags.
class NetworkPersonTile extends StatelessWidget {
  const NetworkPersonTile({super.key, required this.person});

  final NetworkPerson person;

  @override
  Widget build(BuildContext context) {
    final brief = person.person;
    final met = metLine(person);
    return InkWell(
      key: ValueKey('network-person-${person.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(networkPersonRoute(person.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonAvatar(picture: brief.picture, initials: brief.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(brief.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      if (person.mutual) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: "You've saved each other",
                          child: Icon(Icons.handshake_outlined,
                              size: 16, color: Color(0xFF15803D)),
                        ),
                      ],
                    ],
                  ),
                  if (brief.line != null)
                    Text(brief.line!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  if (met.isNotEmpty)
                    Text(met,
                        style: const TextStyle(fontSize: 12.5, color: _muted)),
                  if (person.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [for (final t in person.tags) TagPill(t)],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

/// Saves made with no signal, still to send.
class _PendingStrip extends ConsumerWidget {
  const _PendingStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(networkSaverProvider);
    if (pending.count == 0) return const SizedBox.shrink();
    return Container(
      key: NetworkPage.pendingKey,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.softGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pending.count == 1
                  ? '1 save is waiting for a signal'
                  : '${pending.count} saves are waiting for a signal',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: pending.syncing
                ? null
                : () => ref.read(networkSaverProvider.notifier).drain(),
            child: Text(pending.syncing ? 'Sending…' : 'Try now'),
          ),
        ],
      ),
    );
  }
}

/// "3 people saved you": to save back.
class _SavedMeStrip extends ConsumerWidget {
  const _SavedMeStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(savedMeProvider(null)).valueOrNull?.total ?? 0;
    if (total <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.paleYellow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: NetworkPage.savedMeKey,
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(savedMeLocation),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                const Text('👋', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    total == 1
                        ? '1 person saved you. Save them back?'
                        : '$total people saved you. Save them back?',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: NetworkPage.emptyKey,
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🤝', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Keep the people you meet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            "At an event, scan someone's QR to save them here, with where "
            'and when you met.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push(savePersonScanLocation),
            style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan a QR'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push(myQrLocation),
            child: const Text('Show my QR'),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Text('Nobody matches that.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: _muted)),
      );
}
