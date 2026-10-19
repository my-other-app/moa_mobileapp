import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_club_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'package:finnet/features/discover/presentation/widgets/filter_widgets.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/shared/widgets/error_view.dart';

const _ink = Color(0xFF1E1E1E);

/// Find clubs: by name, topic or interest, most followed, nearest or
/// newest -- the website's `/clubs`.
class ClubsDirectoryPage extends ConsumerStatefulWidget {
  const ClubsDirectoryPage({super.key, this.initialFilters = ClubFilters.none});

  factory ClubsDirectoryPage.fromParams(Map<String, String> params,
          {Key? key}) =>
      ClubsDirectoryPage(
          key: key, initialFilters: ClubFilters.fromParams(params));

  final ClubFilters initialFilters;

  @override
  ConsumerState<ClubsDirectoryPage> createState() => _ClubsDirectoryPageState();
}

class _ClubsDirectoryPageState extends ConsumerState<ClubsDirectoryPage> {
  late ClubFilters _filters = widget.initialFilters.normalized();
  late final TextEditingController _search =
      TextEditingController(text: _filters.q);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply(ClubFilters next) {
    final normalized = next.normalized();
    if (normalized == _filters) return;
    setState(() => _filters = normalized);
    if (_search.text != normalized.q) _search.text = normalized.q;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubSearchProvider(_filters));
    final notifier = ref.read(clubSearchProvider(_filters).notifier);
    final topics = ref.watch(topicDirectoryProvider).valueOrNull ?? const [];
    final where = state.meta?.where ?? DiscoverWhere.unknown;
    final names = FilterNames(topics: topics);
    final sortLabel = (_filters.sort ?? ClubSort.popular).label;

    Widget body;
    if (state.isLoading && state.items.isEmpty) {
      body = const ListSkeleton(rowHeight: 64);
    } else if (state.error != null && state.items.isEmpty) {
      body = ErrorView(message: state.error, onRetry: notifier.load);
    } else if (state.items.isEmpty) {
      final narrowed = _filters.activeCount > 0 || _filters.q.isNotEmpty;
      body = ListView(
        children: [
          DiscoverEmpty(
            key: const ValueKey('discover-clubs-empty'),
            icon: Icons.groups_outlined,
            title: 'No clubs match',
            message: narrowed
                ? 'Try another interest, a wider distance or a shorter search.'
                : 'No clubs are listed here yet.',
            actionLabel:
                narrowed ? 'Clear search and filters' : 'Browse events',
            onAction: narrowed
                ? () => _apply(ClubFilters(place: _filters.place))
                : () => context.push(findEventsLocation(EventFilters.none)),
          ),
        ],
      );
    } else {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView.separated(
          key: const ValueKey('discover-clubs-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: state.items.length + 2,
          separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 4 : 12),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: formatTotal(state.total, capped: state.capped),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                      text: state.total == 1 && !state.capped
                          ? ' club'
                          : ' clubs'),
                ]),
                key: const ValueKey('discover-clubs-count'),
                style: const TextStyle(fontSize: 13, color: _ink),
              );
            }
            if (i == state.items.length + 1) {
              return PagedFooter(
                  state: state, onLoadMore: notifier.loadMore, noun: 'clubs');
            }
            return DiscoverClubCard(club: state.items[i - 1]);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'FIND CLUBS',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              key: const ValueKey('discover-club-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              maxLength: maxSearchLength,
              onSubmitted: (q) => _apply(_filters.copyWith(q: q)),
              decoration: InputDecoration(
                hintText: 'Search clubs by name',
                counterText: '',
                isDense: true,
                prefixIcon: const Icon(Icons.search, color: Color(0xFF979797)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _ink, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _ink, width: 0.5),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                WherePill(
                  where: where,
                  place: _filters.place,
                  onChanged: (p) => _apply(_filters.copyWith(place: p)),
                ),
                const SizedBox(width: 8),
                FiltersButton(
                  label: 'Sort: $sortLabel',
                  count: _filters.activeCount,
                  onTap: () async {
                    final picked = await showClubFilterSheet(
                      context,
                      filters: _filters,
                      names: names,
                      where: where,
                    );
                    if (picked != null && mounted) _apply(picked);
                  },
                ),
              ],
            ),
          ),
          ClubFilterChips(filters: _filters, names: names, onChanged: _apply),
          _InterestChips(
            interests: state.meta?.interests ?? const [],
            topicInterests: names
                    .topic(_filters.topic)
                    ?.interests
                    .map((i) => (i.id, i.name))
                    .toList() ??
                const [],
            selected: _filters.interest,
            onChanged: (id) => _apply(_filters.copyWith(interest: id)),
          ),
          const SizedBox(height: 4),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// The interests to narrow by, with how many clubs pick each: the picked
/// topic's own, else the list's.
class _InterestChips extends StatelessWidget {
  const _InterestChips({
    required this.interests,
    required this.topicInterests,
    required this.selected,
    required this.onChanged,
  });

  final List<InterestCount> interests;
  final List<(int, String)> topicInterests;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final pool = topicInterests.isNotEmpty
        ? [
            for (final (id, name) in topicInterests)
              InterestCount(
                id: id,
                name: name,
                clubs: interests.where((x) => x.id == id).firstOrNull?.clubs,
              ),
          ]
        : interests;
    if (pool.isEmpty) return const SizedBox.shrink();
    Widget chip(int? id, String label, {Key? key}) => ChoiceChip(
          key: key,
          label: Text(label, style: const TextStyle(fontSize: 13)),
          selected: selected == id,
          selectedColor: AppColors.paleYellow,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: AppColors.border, width: 0.5),
          onSelected: (_) => onChanged(selected == id ? null : id),
        );
    return SizedBox(
      height: 44,
      child: ListView(
        key: const ValueKey('discover-club-interest-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          chip(null, 'All', key: const ValueKey('club-interest-all')),
          for (final i in pool) ...[
            const SizedBox(width: 8),
            chip(
              i.id,
              i.clubs == null ? i.name : '${i.name} ${formatCount(i.clubs!)}',
              key: ValueKey('club-interest-${i.id}'),
            ),
          ],
        ],
      ),
    );
  }
}
