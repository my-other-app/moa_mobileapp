import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/discover/domain/discover_cities.dart';
import 'package:finnet/features/discover/domain/discover_days.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/providers/discover_place_provider.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_filter.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_filter_bar.dart';

const _ink = Color(0xFF1E1E1E);

// --- Where ----------------------------------------------------------------------

/// "Near Thiruvananthapuram", or "Near you" when the city is not known.
String nearLabel(DiscoverWhere where) {
  final city = where.city?.trim() ?? '';
  return city.isEmpty ? 'Near you' : 'Near $city';
}

/// "near Thiruvananthapuram", or "near you".
String nearPhrase(DiscoverWhere where) =>
    nearLabel(where).replaceFirst('Near', 'near');

/// "Near Thiruvananthapuram ▾" or "Everywhere ▾": what the list is about.
///
/// The app never asks for the phone's location (the owner's call): near is
/// the place the app keeps -- the connection's first guess, or a city the
/// person picks here. Picking a city, or asking the connection to guess
/// again, changes it for every list, and this one shows what is near it.
class WherePill extends ConsumerWidget {
  const WherePill({
    super.key,
    required this.where,
    required this.place,
    required this.onChanged,
  });

  final DiscoverWhere where;
  final DiscoverPlace place;
  final ValueChanged<DiscoverPlace> onChanged;

  String get _label =>
      place == DiscoverPlace.near ? nearLabel(where) : 'Everywhere';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Where: $_label. Change',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('discover-where'),
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final picked =
              await showWhereSheet(context, where: where, place: place);
          final places = ref.read(discoverPlaceProvider.notifier);
          switch (picked) {
            case null:
              return;
            case PlacePick(:final place):
              if (place != this.place) onChanged(place);
            case CityPick(:final city):
              places.pick(city);
              onChanged(DiscoverPlace.near);
            case GuessAgainPick():
              places.guessAgain();
              onChanged(DiscoverPlace.near);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                place == DiscoverPlace.near
                    ? Icons.near_me_outlined
                    : Icons.public,
                size: 16,
                color: _ink,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  _label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _ink),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18, color: _ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// What was chosen in the place sheet.
sealed class WherePick {
  const WherePick();
}

/// Near the place the lists are about, or everywhere.
class PlacePick extends WherePick {
  const PlacePick(this.place);
  final DiscoverPlace place;
}

/// A city, to be the place instead.
class CityPick extends WherePick {
  const CityPick(this.city);
  final DiscoverCity city;
}

/// Forget the place, for the connection to guess again.
class GuessAgainPick extends WherePick {
  const GuessAgainPick();
}

/// Near the place, or everywhere; or another place: a city, or the
/// connection's guess again.
Future<WherePick?> showWhereSheet(
  BuildContext context, {
  required DiscoverWhere where,
  required DiscoverPlace place,
}) {
  final picked = where.source == WhereSource.picked;
  return showModalBottomSheet<WherePick>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scroll) => SafeArea(
        child: ListView(
          key: const ValueKey('discover-where-sheet'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text('WHERE',
                style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
            const SizedBox(height: 4),
            Text(where.explanation,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            _PlaceOption(
              key: const ValueKey('discover-where-near'),
              icon: Icons.near_me_outlined,
              label: nearLabel(where),
              detail: 'Closest first when sorted by distance',
              selected: place == DiscoverPlace.near,
              onTap: () => Navigator.of(context)
                  .pop(const PlacePick(DiscoverPlace.near)),
            ),
            _PlaceOption(
              key: const ValueKey('discover-where-everywhere'),
              icon: Icons.public,
              label: 'Everywhere',
              detail: 'Every event and club, wherever it is',
              selected: place == DiscoverPlace.everywhere,
              onTap: () => Navigator.of(context)
                  .pop(const PlacePick(DiscoverPlace.everywhere)),
            ),
            _PlaceOption(
              key: const ValueKey('discover-where-guess'),
              icon: Icons.wifi_find_outlined,
              label: picked
                  ? "Use my connection's guess"
                  : 'Guess again from my connection',
              detail: picked
                  ? 'Instead of the city you picked'
                  : "If you've moved, or the guess is wrong",
              selected: false,
              onTap: () => Navigator.of(context).pop(const GuessAgainPick()),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 4),
              child: Text('OR PICK A CITY',
                  style: TextStyle(fontSize: 20, fontFamily: 'BebasNeue')),
            ),
            for (final city in discoverCities)
              _PlaceOption(
                key: ValueKey('discover-where-city-${city.slug}'),
                icon: Icons.location_city_outlined,
                label: city.name,
                detail: city.state,
                selected: picked && where.city == city.name,
                onTap: () => Navigator.of(context).pop(CityPick(city)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PlaceOption extends StatelessWidget {
  const _PlaceOption({
    super.key,
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _ink),
      title: Text(label),
      subtitle: Text(detail),
      trailing: selected ? const Icon(Icons.check, color: _ink) : null,
      selected: selected,
      selectedColor: _ink,
      onTap: onTap,
    );
  }
}

// --- Removable chips --------------------------------------------------------------

/// Names for what a filter holds: the topics directory and the list's own
/// facets.
class FilterNames {
  const FilterNames({this.topics = const [], this.categories = const []});

  final List<Topic> topics;
  final List<CategoryCount> categories;

  Topic? topic(String? slug) => topicNamed(slug, topics);

  Interest? interest(int? id) => id == null
      ? null
      : interestsOf(topics).where((i) => i.id == id).firstOrNull;

  String category(int? id) =>
      categories.where((c) => c.id == id).firstOrNull?.name ?? 'Event type';
}

/// The filters on, each a chip that takes itself off.
class EventFilterChips extends StatelessWidget {
  const EventFilterChips({
    super.key,
    required this.filters,
    required this.names,
    required this.onChanged,
  });

  final EventFilters filters;
  final FilterNames names;
  final ValueChanged<EventFilters> onChanged;

  String _label(EventFilterKey key) {
    final f = filters;
    switch (key) {
      case EventFilterKey.when:
        return f.when!.label;
      case EventFilterKey.dates:
        final d = f.days!;
        return rangeLabel(d.from, d.to);
      case EventFilterKey.format:
        return f.format!.label;
      case EventFilterKey.price:
        return f.price!.label;
      case EventFilterKey.category:
        return names.category(f.category);
      case EventFilterKey.topic:
        return names.topic(f.topic)?.label ?? f.topic!;
      case EventFilterKey.interest:
        return names.interest(f.interest)?.name ?? 'Interest';
      case EventFilterKey.radius:
        return 'Within ${f.radiusKm} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = filters.activeKeys;
    if (keys.isEmpty) return const SizedBox.shrink();
    return _ChipRow(
      chips: [
        for (final key in keys)
          _RemovableChip(
            key: ValueKey('filter-chip-${key.name}'),
            label: _label(key),
            onRemove: () => onChanged(filters.without(key)),
          ),
        if (keys.length > 1)
          _ClearChip(onTap: () => onChanged(filters.cleared())),
      ],
    );
  }
}

class ClubFilterChips extends StatelessWidget {
  const ClubFilterChips({
    super.key,
    required this.filters,
    required this.names,
    required this.onChanged,
  });

  final ClubFilters filters;
  final FilterNames names;
  final ValueChanged<ClubFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final keys = filters.activeKeys;
    if (keys.isEmpty) return const SizedBox.shrink();
    String label(ClubFilterKey key) => switch (key) {
          ClubFilterKey.topic =>
            names.topic(filters.topic)?.label ?? filters.topic!,
          ClubFilterKey.interest =>
            names.interest(filters.interest)?.name ?? 'Interest',
          ClubFilterKey.radius => 'Within ${filters.radiusKm} km',
        };
    return _ChipRow(
      chips: [
        for (final key in keys)
          _RemovableChip(
            key: ValueKey('filter-chip-${key.name}'),
            label: label(key),
            onRemove: () => onChanged(filters.without(key)),
          ),
        if (keys.length > 1)
          _ClearChip(onTap: () => onChanged(filters.cleared())),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        key: const ValueKey('active-filter-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip(
      {super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 13, color: _ink)),
      backgroundColor: AppColors.paleYellow,
      side: const BorderSide(color: AppColors.border, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      visualDensity: VisualDensity.compact,
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteButtonTooltipMessage: 'Remove $label',
      onDeleted: onRemove,
      onPressed: onRemove,
    );
  }
}

class _ClearChip extends StatelessWidget {
  const _ClearChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('filter-chip-clear'),
      onPressed: onTap,
      child: const Text('Clear all'),
    );
  }
}

// --- The sheet ------------------------------------------------------------------

String _keyOf(Object? option) => switch (option) {
      null => 'any',
      Enum e => e.name,
      _ => '$option',
    };

/// A row of single-choice chips with a title.
class _ChoiceSection<T> extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.keyPrefix,
  });

  final String title;
  final List<(T?, String)> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 20, fontFamily: 'BebasNeue')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (option, label) in options)
                ChoiceChip(
                  key: keyPrefix == null
                      ? null
                      : ValueKey('$keyPrefix-${_keyOf(option)}'),
                  label: Text(label),
                  selected: value == option,
                  selectedColor: AppColors.paleYellow,
                  side: const BorderSide(color: AppColors.border, width: 0.5),
                  onSelected: (_) => onChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The events' filters, edited as a draft: "Show results" applies them,
/// closing the sheet leaves them as they were.
Future<EventFilters?> showEventFilterSheet(
  BuildContext context, {
  required EventFilters filters,
  required FilterNames names,
  required DiscoverWhere where,
  bool calendar = false,
}) {
  return showModalBottomSheet<EventFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => _EventFilterSheet(
      initial: filters,
      names: names,
      where: where,
      calendar: calendar,
    ),
  );
}

class _EventFilterSheet extends StatefulWidget {
  const _EventFilterSheet({
    required this.initial,
    required this.names,
    required this.where,
    required this.calendar,
  });

  final EventFilters initial;
  final FilterNames names;
  final DiscoverWhere where;
  final bool calendar;

  @override
  State<_EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<_EventFilterSheet> {
  late EventFilters _draft = widget.initial;

  void _set(EventFilters next) => setState(() => _draft = next);

  Future<void> _pickDates() async {
    final today = dayAsDate(istDay());
    final days = _draft.days;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2, 12, 31),
      initialDateRange: days == null
          ? null
          : DateTimeRange(start: dayAsDate(days.from), end: dayAsDate(days.to)),
      helpText: 'Pick the days',
    );
    if (picked == null || !mounted) return;
    final from = dayFromDate(picked.start);
    var to = dayFromDate(picked.end);
    // The server takes at most a year.
    if (daysBetween(from, to) > 365) to = addDays(from, 365);
    _set(_draft.withDays(from, to));
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.names;
    final topics = names.topics;
    final days = _draft.days;
    final topicFilter = TopicFilter(
      topic: names.topic(_draft.topic),
      interest: names.interest(_draft.interest),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Text('FILTERS',
                    style: TextStyle(fontSize: 28, fontFamily: 'BebasNeue')),
                const SizedBox(height: 12),
                if (!widget.calendar) ...[
                  _ChoiceSection<EventWhen>(
                    title: 'When',
                    keyPrefix: 'sheet-when',
                    options: [
                      (null, 'Any day'),
                      for (final w in EventWhen.values) (w, w.label),
                    ],
                    value: days == null ? _draft.when : null,
                    onChanged: (w) => _set(_draft.withWhen(w)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          key: const ValueKey('sheet-pick-dates'),
                          avatar: const Icon(Icons.date_range, size: 18),
                          label: Text(days == null
                              ? 'Pick dates…'
                              : rangeLabel(days.from, days.to)),
                          backgroundColor:
                              days == null ? null : AppColors.paleYellow,
                          side: const BorderSide(
                              color: AppColors.border, width: 0.5),
                          onPressed: _pickDates,
                        ),
                      ],
                    ),
                  ),
                ],
                _ChoiceSection<EventPrice>(
                  title: 'Price',
                  keyPrefix: 'sheet-price',
                  options: [
                    (null, 'Any price'),
                    for (final p in EventPrice.values) (p, p.label),
                  ],
                  value: _draft.price,
                  onChanged: (p) => _set(_draft.copyWith(price: p)),
                ),
                _ChoiceSection<EventFormat>(
                  title: 'Online or in person',
                  keyPrefix: 'sheet-format',
                  options: [
                    (null, 'Either'),
                    for (final f in EventFormat.values) (f, f.label),
                  ],
                  value: _draft.format,
                  onChanged: (f) => _set(_draft.copyWith(format: f)),
                ),
                if (topics.isNotEmpty) ...[
                  Text(
                    topicsWorthShowing(topics) ? 'TOPIC' : 'INTEREST',
                    style:
                        const TextStyle(fontSize: 20, fontFamily: 'BebasNeue'),
                  ),
                  const SizedBox(height: 8),
                  // The explore screens' bar, edge to edge.
                  Transform.translate(
                    offset: const Offset(-16, 0),
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      child: TopicFilterBar(
                        topics: topics,
                        filter: topicFilter,
                        topicCount: (t) => t.upcomingEvents,
                        interestCount: (i) => i.upcomingEvents,
                        onChanged: (f) => _set(_draft.copyWith(
                          topic: f.topic?.slug,
                          interest: f.interest?.id,
                        )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (names.categories.isNotEmpty)
                  _ChoiceSection<int>(
                    title: 'Event type',
                    keyPrefix: 'sheet-category',
                    options: [
                      (null, 'Any type'),
                      for (final c in names.categories)
                        (
                          c.id,
                          c.upcoming == null
                              ? c.name
                              : '${c.name} · ${c.upcoming}'
                        ),
                    ],
                    value: _draft.category,
                    onChanged: (c) => _set(_draft.copyWith(category: c)),
                  ),
                if (_draft.isNear)
                  _ChoiceSection<int>(
                    title: 'Distance',
                    keyPrefix: 'sheet-radius',
                    options: [
                      (null, 'Any distance'),
                      for (final r in radiusOptions) (r, 'Within $r km'),
                    ],
                    value: _draft.radiusKm,
                    onChanged: (r) => _set(_draft.copyWith(radiusKm: r)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DISTANCE',
                            style: TextStyle(
                                fontSize: 20, fontFamily: 'BebasNeue')),
                        const SizedBox(height: 4),
                        Text(
                          'Showing events everywhere. To pick a distance, '
                          'show what is ${nearPhrase(widget.where)}.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                        TextButton(
                          key: const ValueKey('sheet-go-near'),
                          onPressed: () =>
                              _set(_draft.withPlace(DiscoverPlace.near)),
                          child:
                              Text('Show what is ${nearPhrase(widget.where)}'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('sheet-clear'),
                    onPressed: _draft.activeCount == 0
                        ? null
                        : () => _set(_draft.cleared()),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('sheet-apply'),
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('Show results'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The clubs' order, topic and distance, as a draft.
Future<ClubFilters?> showClubFilterSheet(
  BuildContext context, {
  required ClubFilters filters,
  required FilterNames names,
  required DiscoverWhere where,
}) {
  return showModalBottomSheet<ClubFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) =>
        _ClubFilterSheet(initial: filters, names: names, where: where),
  );
}

class _ClubFilterSheet extends StatefulWidget {
  const _ClubFilterSheet({
    required this.initial,
    required this.names,
    required this.where,
  });

  final ClubFilters initial;
  final FilterNames names;
  final DiscoverWhere where;

  @override
  State<_ClubFilterSheet> createState() => _ClubFilterSheetState();
}

class _ClubFilterSheetState extends State<_ClubFilterSheet> {
  late ClubFilters _draft = widget.initial;

  void _set(ClubFilters next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final names = widget.names;
    final topics = names.topics;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Text('SORT AND FILTER',
                    style: TextStyle(fontSize: 28, fontFamily: 'BebasNeue')),
                const SizedBox(height: 12),
                _ChoiceSection<ClubSort>(
                  title: 'Sort by',
                  keyPrefix: 'sheet-club-sort',
                  options: [
                    for (final s in ClubSort.values)
                      if (s != ClubSort.nearby || _draft.isNear)
                        (s == ClubSort.popular ? null : s, s.label),
                  ],
                  value: _draft.sort,
                  onChanged: (s) => _set(_draft.copyWith(sort: s)),
                ),
                if (topics.isNotEmpty) ...[
                  Text(
                    topicsWorthShowing(topics) ? 'TOPIC' : 'INTEREST',
                    style:
                        const TextStyle(fontSize: 20, fontFamily: 'BebasNeue'),
                  ),
                  const SizedBox(height: 8),
                  Transform.translate(
                    offset: const Offset(-16, 0),
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      child: TopicFilterBar(
                        topics: topics,
                        filter: TopicFilter(
                          topic: names.topic(_draft.topic),
                          interest: names.interest(_draft.interest),
                        ),
                        topicCount: (t) => t.clubs,
                        topicCountUnit: 'clubs',
                        onChanged: (f) => _set(_draft.copyWith(
                          topic: f.topic?.slug,
                          interest: f.interest?.id,
                        )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_draft.isNear)
                  _ChoiceSection<int>(
                    title: 'Distance',
                    keyPrefix: 'sheet-radius',
                    options: [
                      (null, 'Any distance'),
                      for (final r in radiusOptions) (r, 'Within $r km'),
                    ],
                    value: _draft.radiusKm,
                    onChanged: (r) => _set(_draft.copyWith(radiusKm: r)),
                  )
                else
                  TextButton(
                    key: const ValueKey('sheet-go-near'),
                    onPressed: () =>
                        _set(_draft.copyWith(place: DiscoverPlace.near)),
                    child: Text('Show clubs ${nearPhrase(widget.where)}, '
                        'to sort by distance'),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('sheet-clear'),
                    onPressed: _draft.activeCount == 0
                        ? null
                        : () => _set(_draft.cleared()),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('sheet-apply'),
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('Show clubs'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- The order --------------------------------------------------------------------

/// "Sort: Date ▾", offering what makes sense now.
class EventSortMenu extends StatelessWidget {
  const EventSortMenu(
      {super.key, required this.filters, required this.onChanged});

  final EventFilters filters;
  final ValueChanged<EventFilters> onChanged;

  EventSort get _current =>
      filters.sort ??
      (filters.q.isNotEmpty ? EventSort.relevance : EventSort.date);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<EventSort>(
      key: const ValueKey('discover-sort'),
      tooltip: 'Sort',
      initialValue: _current,
      onSelected: (s) => onChanged(filters.copyWith(sort: s)),
      itemBuilder: (_) => [
        for (final (sort, enabled) in eventSortChoices(filters))
          PopupMenuItem<EventSort>(
            key: ValueKey('discover-sort-${sort.param}'),
            value: sort,
            enabled: enabled,
            child: Text(enabled
                ? sort.label
                : '${sort.label} · show what is near you first'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18, color: _ink),
            const SizedBox(width: 4),
            Text('Sort: ${_current.label}',
                style: const TextStyle(fontSize: 13, color: _ink)),
          ],
        ),
      ),
    );
  }
}

/// "Filters (2)".
class FiltersButton extends StatelessWidget {
  const FiltersButton({
    super.key,
    required this.count,
    required this.onTap,
    this.label = 'Filters',
  });

  final int count;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = count > 0 ? '$label ($count)' : label;
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('discover-filters'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.paleYellow : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 16, color: _ink),
              const SizedBox(width: 4),
              Text(text, style: const TextStyle(fontSize: 13, color: _ink)),
            ],
          ),
        ),
      ),
    );
  }
}
