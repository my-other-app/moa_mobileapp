import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:finnet/features/discover/domain/discover_days.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'package:finnet/shared/widgets/error_view.dart';

const _ink = Color(0xFF1E1E1E);
const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', //
];

/// The day a month opens on: today in this month; otherwise its first day
/// with something on; otherwise none.
String? defaultDayFor(String month, CalendarMonth? counts, {String? today}) {
  final now = today ?? istDay();
  if (monthOf(now) == month) return now;
  return counts?.busyDays.firstOrNull;
}

/// Find events as a calendar: the month with a dot on each day that has
/// something on (from `/discover/calendar`, with the list's filters), and
/// the chosen day's events under it.
class DiscoverCalendarView extends ConsumerWidget {
  const DiscoverCalendarView({
    super.key,
    required this.filters,
    required this.month,
    required this.selectedDay,
    required this.onMonth,
    required this.onDay,
    this.today,
  });

  final EventFilters filters;
  final String month;

  /// Null: [defaultDayFor].
  final String? selectedDay;
  final ValueChanged<String> onMonth;
  final ValueChanged<String> onDay;

  /// For tests; India's today otherwise.
  final String? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (filters: filters.normalized(), month: month);
    final counts = ref.watch(calendarMonthProvider(key));
    final now = today ?? istDay();
    final data = counts.valueOrNull;
    final day = selectedDay != null && monthOf(selectedDay!) == month
        ? selectedDay
        : defaultDayFor(month, data, today: now);

    Widget grid;
    if (data == null && counts.isLoading) {
      grid = const _GridSkeleton();
    } else if (data == null) {
      grid = ErrorView(
        compact: true,
        message: "We couldn't load this month right now.",
        onRetry: () => ref.invalidate(calendarMonthProvider(key)),
      );
    } else {
      grid = _MonthGrid(
        month: month,
        counts: data,
        today: now,
        selected: day,
        onDay: onDay,
      );
    }

    final empty = data != null && data.days.isEmpty;
    return CustomScrollView(
      key: const ValueKey('discover-calendar'),
      slivers: [
        SliverToBoxAdapter(
          child: _MonthNav(month: month, today: now, onMonth: onMonth),
        ),
        SliverToBoxAdapter(child: grid),
        if (empty)
          SliverToBoxAdapter(
            child: DiscoverEmpty(
              title: 'Nothing on in ${monthWord(month)}',
              message: 'Try the next month, or fewer filters.',
              actionLabel: '${monthWord(addMonths(month, 1))} →',
              onAction: () => onMonth(addMonths(month, 1)),
            ),
          )
        else if (day != null)
          _DayEvents(filters: filters, day: day, count: data?.countOn(day)),
      ],
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.month,
    required this.today,
    required this.onMonth,
  });

  final String month;
  final String today;
  final ValueChanged<String> onMonth;

  @override
  Widget build(BuildContext context) {
    final thisMonth = monthOf(today);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('calendar-previous'),
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onMonth(addMonths(month, -1)),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                monthLabel(month).toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('calendar-next'),
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onMonth(addMonths(month, 1)),
          ),
          if (month != thisMonth)
            TextButton(
              key: const ValueKey('calendar-this-month'),
              onPressed: () => onMonth(thisMonth),
              child: const Text('This month'),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.counts,
    required this.today,
    required this.selected,
    required this.onDay,
  });

  final String month;
  final CalendarMonth counts;
  final String today;
  final String? selected;
  final ValueChanged<String> onDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Semantics(
                    label: _weekdayNames[i],
                    excludeSemantics: true,
                    child: Text(
                      _weekdays[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final week in monthWeeks(month))
            Row(
              children: [
                for (final day in week)
                  Expanded(
                    child: day == null
                        ? const SizedBox(height: 52)
                        : _DayCell(
                            day: day,
                            count: counts.countOn(day),
                            isToday: day == today,
                            isPast: day.compareTo(today) < 0,
                            isSelected: day == selected,
                            onTap: () => onDay(day),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isPast,
    required this.isSelected,
    required this.onTap,
  });

  final String day;
  final int count;
  final bool isToday;
  final bool isPast;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final number = int.parse(day.substring(8, 10));
    final ink = isSelected
        ? Colors.white
        : (isPast ? Colors.grey.shade500 : _ink);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${dayShort(day)}${isToday ? ', today' : ''}: '
          '${count > 0 ? plural(count, 'event') : 'nothing on'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: ValueKey('calendar-day-$day'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _ink : null,
                  border: isToday && !isSelected
                      ? Border.all(color: _ink, width: 1.5)
                      : null,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        count > 0 || isToday ? FontWeight.w700 : FontWeight.w400,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 8,
                child: count > 0
                    ? Row(
                        key: ValueKey('calendar-dot-$day'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < (count > 3 ? 3 : count); i++)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPast
                                    ? Colors.grey.shade400
                                    : const Color(0xFFB4232C),
                              ),
                            ),
                        ],
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      key: const ValueKey('calendar-loading'),
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (var w = 0; w < 5; w++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var d = 0; d < 7; d++)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The chosen day's events: the list's search, for that day.
class _DayEvents extends ConsumerWidget {
  const _DayEvents({required this.filters, required this.day, this.count});

  final EventFilters filters;
  final String day;
  final int? count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayFilters = filters.forDay(day);
    final state = ref.watch(eventSearchProvider(dayFilters));
    final notifier = ref.read(eventSearchProvider(dayFilters).notifier);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dayShort(day).toUpperCase(),
              key: const ValueKey('calendar-day-heading'),
              style: const TextStyle(fontSize: 22, fontFamily: 'BebasNeue'),
            ),
          ),
          if (count != null && count! > 0)
            Text(plural(count!, 'event'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ],
      ),
    );

    if (state.isLoading && state.items.isEmpty) {
      return SliverList.list(children: [header, const ListSkeleton(rows: 2)]);
    }
    if (state.error != null && state.items.isEmpty) {
      return SliverList.list(children: [
        header,
        ErrorView(compact: true, message: state.error, onRetry: notifier.load),
      ]);
    }
    if (state.items.isEmpty) {
      return SliverList.list(children: [
        header,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nothing on this day. Pick another one with a dot.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ]);
    }
    return SliverList.builder(
      itemCount: state.items.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        if (i == state.items.length + 1) {
          return PagedFooter(state: state, onLoadMore: notifier.loadMore);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DiscoverEventTile(event: state.items[i - 1]),
        );
      },
    );
  }
}
