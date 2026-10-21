import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/discover/domain/discover_days.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/providers/discover_place_provider.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_calendar.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'package:finnet/features/discover/presentation/widgets/filter_widgets.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/entrance.dart';
import 'package:finnet/shared/widgets/fade_switch.dart';

const _ink = Color(0xFF1E1E1E);

/// Find events: search, the filters (when, price, online or in person,
/// topic and interest, type, distance) and the order, as a list or a
/// month's calendar -- the website's `/events`, natively.
///
/// The filters are the screen's address (`/discover/events?when=today`);
/// changing one shows a new list, and the screen keeps them while an event
/// is open on top of it.
class FindEventsPage extends ConsumerStatefulWidget {
  const FindEventsPage({
    super.key,
    this.initialFilters = EventFilters.none,
    this.calendar = false,
    this.month,
    this.focusSearch = false,
    this.today,
  });

  /// From the route's parameters.
  factory FindEventsPage.fromParams(Map<String, String> params, {Key? key}) =>
      FindEventsPage(
        key: key,
        initialFilters: EventFilters.fromParams(params),
        calendar: params['view'] == 'calendar',
        month: isMonth(params['month']) ? params['month'] : null,
        focusSearch: params['focus'] == 'search',
      );

  final EventFilters initialFilters;
  final bool calendar;
  final String? month;
  final bool focusSearch;

  /// For tests; India's today otherwise.
  final String? today;

  @override
  ConsumerState<FindEventsPage> createState() => _FindEventsPageState();
}

class _FindEventsPageState extends ConsumerState<FindEventsPage> {
  late EventFilters _filters = widget.initialFilters.normalized();
  late bool _calendar = widget.calendar;
  late String _month =
      widget.month ?? monthOf(_filters.days?.from ?? widget.today ?? istDay());
  String? _day;
  late final TextEditingController _search =
      TextEditingController(text: _filters.q);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply(EventFilters next) {
    final normalized = next.normalized();
    if (normalized == _filters) return;
    setState(() => _filters = normalized);
    if (_search.text != normalized.q) _search.text = normalized.q;
  }

  Future<void> _openSheet(FilterNames names, DiscoverWhere where) async {
    final picked = await showEventFilterSheet(
      context,
      filters: _filters,
      names: names,
      where: where,
      calendar: _calendar,
    );
    if (picked != null && mounted) _apply(picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventSearchProvider(_filters));
    final topics = ref.watch(topicDirectoryProvider).valueOrNull ?? const [];
    final meta = state.meta;
    // The place the answer is about; while it is on its way, the place the
    // app keeps, which it is being asked about.
    final where = meta?.where ??
        ref.watch(discoverPlaceProvider).place ??
        DiscoverWhere.unknown;
    final names =
        FilterNames(topics: topics, categories: meta?.categories ?? const []);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'FIND EVENTS',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        actions: [
          IconButton(
            key: const ValueKey('discover-view-toggle'),
            tooltip: _calendar ? 'Show as a list' : 'Show as a calendar',
            icon: Icon(_calendar
                ? Icons.view_agenda_outlined
                : Icons.calendar_month_outlined),
            onPressed: () => setState(() => _calendar = !_calendar),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchField(
            controller: _search,
            autofocus: widget.focusSearch,
            onSubmit: (q) => _apply(_filters.copyWith(q: q)),
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
                  onChanged: (p) => _apply(_filters.withPlace(p)),
                ),
                const SizedBox(width: 8),
                FiltersButton(
                  count: _filters.activeCount,
                  onTap: () => _openSheet(names, where),
                ),
              ],
            ),
          ),
          EventFilterChips(filters: _filters, names: names, onChanged: _apply),
          _InterestChips(
            topic: names.topic(_filters.topic),
            interest: _filters.interest,
            onChanged: (id) => _apply(_filters.copyWith(interest: id)),
          ),
          _CategoryChips(
            categories: names.categories,
            selected: _filters.category,
            onChanged: (id) => _apply(_filters.copyWith(category: id)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _calendar
                ? DiscoverCalendarView(
                    filters: _filters,
                    month: _month,
                    selectedDay: _day,
                    today: widget.today,
                    onMonth: (m) => setState(() {
                      _month = m;
                      _day = null;
                    }),
                    onDay: (d) => setState(() => _day = d),
                  )
                : _Results(
                    filters: _filters,
                    state: state,
                    onChanged: _apply,
                    onClear: () => _apply(EventFilters(place: _filters.place)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmit,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final bool autofocus;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: TextField(
        key: const ValueKey('discover-search'),
        controller: widget.controller,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        maxLength: maxSearchLength,
        onSubmitted: widget.onSubmit,
        decoration: InputDecoration(
          hintText: 'Search events or topics',
          counterText: '',
          isDense: true,
          prefixIcon: const Icon(Icons.search, color: Color(0xFF979797)),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onSubmit('');
                  },
                ),
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
    );
  }
}

/// A picked topic's interests: "All Development", then each with how many
/// are coming up.
class _InterestChips extends StatelessWidget {
  const _InterestChips({
    required this.topic,
    required this.interest,
    required this.onChanged,
  });

  final Topic? topic;
  final int? interest;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = topic;
    if (t == null || t.interests.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        key: const ValueKey('discover-interest-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          InterestChip(
            key: const ValueKey('interest-chip-all'),
            label: 'All ${t.label}',
            compact: true,
            selected: interest == null,
            onTap: () => onChanged(null),
          ),
          for (final i in t.interests) ...[
            const SizedBox(width: 8),
            InterestChip(
              key: ValueKey('interest-chip-${i.id}'),
              label: i.name,
              glyph: i.emoji,
              compact: true,
              count: i.upcomingEvents,
              topicLabel: t.label,
              selected: interest == i.id,
              onTap: () => onChanged(interest == i.id ? null : i.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// The event types with how many are coming up, as the website's chips.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<CategoryCount> categories;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
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
        key: const ValueKey('discover-category-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          chip(null, 'All types', key: const ValueKey('category-chip-all')),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            chip(
              c.id,
              c.upcoming == null
                  ? c.name
                  : '${c.name} ${formatCount(c.upcoming!)}',
              key: ValueKey('category-chip-${c.id}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.filters,
    required this.state,
    required this.onChanged,
    required this.onClear,
  });

  final EventFilters filters;
  final EventSearchState state;
  final ValueChanged<EventFilters> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The skeleton gives way to the results with a cross-fade.
    return FadeSwitch(
      phase: state.isLoading && state.items.isEmpty
          ? ScreenPhase.loading
          : state.error != null && state.items.isEmpty
              ? ScreenPhase.error
              : state.items.isEmpty
                  ? ScreenPhase.empty
                  : ScreenPhase.content,
      child: _results(context, ref),
    );
  }

  Widget _results(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(eventSearchProvider(filters).notifier);
    if (state.isLoading && state.items.isEmpty) return const ListSkeleton();
    if (state.error != null && state.items.isEmpty) {
      return ErrorView(message: state.error, onRetry: notifier.load);
    }
    final narrowed = filters.activeCount > 0 || filters.q.isNotEmpty;
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            DiscoverEmpty(
              key: const ValueKey('discover-events-empty'),
              title: 'No events match',
              message: narrowed
                  ? 'Try another day, a wider distance or fewer filters.'
                  : 'Nothing is listed here yet. Clubs add new events all the time.',
              actionLabel:
                  narrowed ? 'Clear search and filters' : 'Browse clubs',
              onAction: narrowed
                  ? onClear
                  : () => context.push(clubsDirectoryLocation()),
            ),
          ],
        ),
      );
    }

    final where = state.meta?.where;
    final scope = [
      if (filters.radiusKm != null) 'within ${filters.radiusKm} km',
      if (filters.isNear && filters.radiusKm == null && where != null)
        nearPhrase(where),
    ].join(' ');

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: EntranceScope(
          child: ListView.builder(
        key: const ValueKey('discover-events-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: state.items.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            // The count, and the order beside it (as the website's
            // result line has them).
            return Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: formatTotal(state.total, capped: state.capped),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                          text: state.total == 1 && !state.capped
                              ? ' event'
                              : ' events'),
                      if (scope.isNotEmpty) TextSpan(text: ' $scope'),
                    ]),
                    key: const ValueKey('discover-events-count'),
                    style: const TextStyle(fontSize: 13, color: _ink),
                  ),
                ),
                EventSortMenu(filters: filters, onChanged: onChanged),
              ],
            );
          }
          if (i == state.items.length + 1) {
            return PagedFooter(state: state, onLoadMore: notifier.loadMore);
          }
          return Entrance(
            index: i - 1,
            child: DiscoverEventTile(event: state.items[i - 1]),
          );
        },
      )),
    );
  }
}
