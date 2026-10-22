import 'package:equatable/equatable.dart';
import 'package:finnet/features/discover/domain/discover_days.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';

// The find-events and find-clubs filters: what the website keeps in its
// address (`/events?when=this_week&price=free`), here as values that read
// from and write back to the same parameters. Anything unknown is dropped,
// so a hand-made or stale link can never make the server answer 422.

const _keep = Object();

/// The longest search the server takes (`q`, max_length 100).
const maxSearchLength = 100;

/// The distances offered, in km.
const radiusOptions = [10, 25, 50, 100];

final _slug = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

/// A topic's slug as the API takes it (`?topic=`), lower case; null for
/// anything else.
String? topicParam(Object? value) {
  final s = '${value ?? ''}'.trim().toLowerCase();
  return _slug.hasMatch(s) ? s : null;
}

int? _id(Object? value) {
  final n = int.tryParse('${value ?? ''}'.trim());
  return n != null && n > 0 && n < 2147483648 ? n : null;
}

String _text(Object? value) {
  final s = value is String ? value.trim() : '';
  return s.length > maxSearchLength ? s.substring(0, maxSearchLength) : s;
}

int? _radius(Object? value) {
  final n = int.tryParse('${value ?? ''}'.trim());
  return radiusOptions.contains(n) ? n : null;
}

T? _pick<T extends Enum>(
    List<T> values, String? Function(T) param, Object? raw) {
  for (final v in values) {
    if (param(v) == raw) return v;
  }
  return null;
}

/// "When" presets.
enum EventWhen {
  today('today', 'Today'),
  tomorrow('tomorrow', 'Tomorrow'),
  thisWeek('this_week', 'This week'),
  thisWeekend('this_weekend', 'This weekend'),
  nextWeek('next_week', 'Next week'),
  thisMonth('this_month', 'This month');

  const EventWhen(this.param, this.label);
  final String param;
  final String label;

  static EventWhen? parse(Object? raw) =>
      _pick(EventWhen.values, (v) => v.param, raw);
}

/// In person or online (the API's `type`).
enum EventFormat {
  inPerson('in_person', 'In person'),
  online('online', 'Online');

  const EventFormat(this.param, this.label);
  final String param;
  final String label;

  static EventFormat? parse(Object? raw) =>
      _pick(EventFormat.values, (v) => v.param, raw);
}

enum EventPrice {
  free('free', 'Free'),
  paid('paid', 'Paid');

  const EventPrice(this.param, this.label);
  final String param;
  final String label;

  static EventPrice? parse(Object? raw) =>
      _pick(EventPrice.values, (v) => v.param, raw);
}

/// The orders a list of events can take. None picked is the server's own:
/// relevance with search words, else date.
enum EventSort {
  relevance('relevance', 'Relevance'),
  date('date', 'Date'),
  distance('distance', 'Distance'),
  popular('popular', 'Popular');

  const EventSort(this.param, this.label);
  final String param;
  final String label;

  static EventSort? parse(Object? raw) =>
      _pick(EventSort.values, (v) => v.param, raw);
}

/// What a removable chip under the search stands for.
enum EventFilterKey {
  when,
  dates,
  format,
  price,
  category,
  topic,
  interest,
  radius
}

/// What a list is about: everywhere, or near the person.
///
/// Near is the place the app keeps (no location permission, the owner's
/// call: the connection's first guess, or a city picked), sent with each
/// list as its point. Everywhere sends `radius_km=0`, the API's
/// "anywhere".
enum DiscoverPlace { everywhere, near }

/// The find-events filters.
class EventFilters extends Equatable {
  const EventFilters({
    this.q = '',
    this.when,
    this.from,
    this.to,
    this.format,
    this.price,
    this.category,
    this.topic,
    this.interest,
    this.sort,
    this.radiusKm,
    this.place = DiscoverPlace.everywhere,
  });

  static const none = EventFilters();

  final String q;
  final EventWhen? when;

  /// Picked days (`YYYY-MM-DD`), which replace [when].
  final String? from;
  final String? to;
  final EventFormat? format;
  final EventPrice? price;

  /// An event category's id ("Workshop").
  final int? category;

  /// A topic's slug, and within it an interest's id.
  final String? topic;
  final int? interest;
  final EventSort? sort;
  final int? radiusKm;
  final DiscoverPlace place;

  bool get isNear => place == DiscoverPlace.near;

  /// The picked days, when there are any.
  ({String from, String to})? get days => dayRange(from, to);

  /// The filters as the rules allow them: words trimmed; picked days in
  /// order, replacing "when"; an order by relevance only with words; a
  /// distance and an order by distance only near the person.
  EventFilters normalized() {
    final text = _text(q);
    final range = days;
    final s = sort == EventSort.relevance && text.isEmpty
        ? null
        : (sort == EventSort.distance && !isNear ? null : sort);
    return EventFilters(
      q: text,
      when: range == null ? when : null,
      from: range?.from,
      to: range?.to,
      format: format,
      price: price,
      category: category != null && category! > 0 ? category : null,
      topic: topicParam(topic),
      interest: interest != null && interest! > 0 ? interest : null,
      sort: s,
      radiusKm: isNear && radiusOptions.contains(radiusKm) ? radiusKm : null,
      place: place,
    );
  }

  EventFilters copyWith({
    String? q,
    Object? when = _keep,
    Object? from = _keep,
    Object? to = _keep,
    Object? format = _keep,
    Object? price = _keep,
    Object? category = _keep,
    Object? topic = _keep,
    Object? interest = _keep,
    Object? sort = _keep,
    Object? radiusKm = _keep,
    DiscoverPlace? place,
  }) {
    return EventFilters(
      q: q ?? this.q,
      when: identical(when, _keep) ? this.when : when as EventWhen?,
      from: identical(from, _keep) ? this.from : from as String?,
      to: identical(to, _keep) ? this.to : to as String?,
      format: identical(format, _keep) ? this.format : format as EventFormat?,
      price: identical(price, _keep) ? this.price : price as EventPrice?,
      category: identical(category, _keep) ? this.category : category as int?,
      topic: identical(topic, _keep) ? this.topic : topic as String?,
      interest: identical(interest, _keep) ? this.interest : interest as int?,
      sort: identical(sort, _keep) ? this.sort : sort as EventSort?,
      radiusKm: identical(radiusKm, _keep) ? this.radiusKm : radiusKm as int?,
      place: place ?? this.place,
    ).normalized();
  }

  /// A "when" preset, which takes the picked days off.
  EventFilters withWhen(EventWhen? value) =>
      copyWith(when: value, from: null, to: null);

  /// Picked days, which take the preset off.
  EventFilters withDays(String from, String to) =>
      copyWith(when: null, from: from, to: to);

  /// A topic starts over on its interests.
  EventFilters withTopic(String? slug) => copyWith(topic: slug, interest: null);

  /// Everywhere drops the distance and an order by it.
  EventFilters withPlace(DiscoverPlace value) => copyWith(place: value);

  /// The same search, just for [day]: what a calendar day opens.
  EventFilters forDay(String day) =>
      copyWith(when: null, from: day, to: day, sort: null);

  /// The removable chips, in the order the filter sheet has them.
  List<EventFilterKey> get activeKeys {
    final f = normalized();
    return [
      if (f.when != null) EventFilterKey.when,
      if (f.days != null) EventFilterKey.dates,
      if (f.format != null) EventFilterKey.format,
      if (f.price != null) EventFilterKey.price,
      if (f.category != null) EventFilterKey.category,
      if (f.topic != null) EventFilterKey.topic,
      if (f.interest != null) EventFilterKey.interest,
      if (f.radiusKm != null) EventFilterKey.radius,
    ];
  }

  /// How many filters are on ("Filters (2)"); the words and the order are
  /// not filters.
  int get activeCount => activeKeys.length;

  /// Without the filter a chip stands for. A topic takes its interest with
  /// it.
  EventFilters without(EventFilterKey key) {
    switch (key) {
      case EventFilterKey.when:
        return copyWith(when: null);
      case EventFilterKey.dates:
        return copyWith(from: null, to: null);
      case EventFilterKey.format:
        return copyWith(format: null);
      case EventFilterKey.price:
        return copyWith(price: null);
      case EventFilterKey.category:
        return copyWith(category: null);
      case EventFilterKey.topic:
        return copyWith(topic: null, interest: null);
      case EventFilterKey.interest:
        return copyWith(interest: null);
      case EventFilterKey.radius:
        return copyWith(radiusKm: null);
    }
  }

  /// Every filter off; the words, the order and the place stay.
  EventFilters cleared() =>
      EventFilters(q: q, sort: sort, place: place).normalized();

  /// The query for `GET /discover/events`.
  Map<String, dynamic> eventsQuery(
      [PageRequest paging = const PageRequest.first()]) {
    final f = normalized();
    final range = f.days;
    return {
      ..._shared(f),
      if (range != null) ...{
        'from': range.from,
        'to': range.to
      } else if (f.when != null)
        'when': f.when!.param,
      if (f.sort != null) 'sort': f.sort!.param,
      ...paging.query,
    };
  }

  /// The query for `GET /discover/calendar`: the list's filters for
  /// [month], without "when" and the order.
  Map<String, dynamic> calendarQuery(String month) {
    final f = normalized();
    return {'month': month, ..._shared(f)};
  }

  static Map<String, dynamic> _shared(EventFilters f) => {
        if (f.q.isNotEmpty) 'q': f.q,
        if (f.category != null) 'category': f.category,
        if (f.topic != null) 'topic': f.topic,
        if (f.interest != null) 'interest': f.interest,
        // Near asks for in-person events: the server lets every online one
        // through a radius, so they padded "near you" from anywhere.
        // Online stays a tap away, and a format picked is kept.
        if (f.format != null)
          'type': f.format!.param
        else if (f.isNear)
          'type': EventFormat.inPerson.param,
        if (f.price != null) 'price': f.price!.param,
        // Everywhere is radius 0. Near sends none of its own unless one was
        // picked: the server's 50 km around the place.
        if (!f.isNear)
          'radius_km': 0
        else if (f.radiusKm != null)
          'radius_km': f.radiusKm,
      };

  /// The filters as the screen's address carries them: only what is set,
  /// in a fixed order. `near=1` for near the person.
  Map<String, String> toParams() {
    final f = normalized();
    final range = f.days;
    return {
      if (f.q.isNotEmpty) 'q': f.q,
      if (f.when != null) 'when': f.when!.param,
      if (range != null) ...{'from': range.from, 'to': range.to},
      if (f.format != null) 'type': f.format!.param,
      if (f.price != null) 'price': f.price!.param,
      if (f.category != null) 'category': '${f.category}',
      if (f.topic != null) 'topic': f.topic!,
      if (f.interest != null) 'interest': '${f.interest}',
      if (f.sort != null) 'sort': f.sort!.param,
      if (f.radiusKm != null) 'radius_km': '${f.radiusKm}',
      if (f.isNear) 'near': '1',
    };
  }

  /// The filters a screen's address names; anything unknown is dropped.
  ///
  /// `near` is "1" (or the website's `lat,lng`, read as "near the person":
  /// near the place the app keeps). An order by distance asks for near too,
  /// as the website's "Events near you" link does.
  static EventFilters fromParams(Map<String, String> params) {
    final near = (params['near'] ?? '').trim().isNotEmpty ||
        params['sort'] == EventSort.distance.param;
    return EventFilters(
      q: _text(params['q']),
      when: EventWhen.parse(params['when']),
      from: params['from'],
      to: params['to'],
      format: EventFormat.parse(params['type']),
      price: EventPrice.parse(params['price']),
      category: _id(params['category']),
      topic: topicParam(params['topic']),
      interest: _id(params['interest']),
      sort: EventSort.parse(params['sort']),
      radiusKm: _radius(params['radius_km']),
      place: near ? DiscoverPlace.near : DiscoverPlace.everywhere,
    ).normalized();
  }

  @override
  List<Object?> get props => [
        q,
        when,
        from,
        to,
        format,
        price,
        category,
        topic,
        interest,
        sort,
        radiusKm,
        place,
      ];
}

/// The orders worth offering: relevance only with words, distance only
/// near the person (offered but switched off otherwise, with why).
List<(EventSort, bool enabled)> eventSortChoices(EventFilters filters) => [
      if (filters.q.isNotEmpty) (EventSort.relevance, true),
      (EventSort.date, true),
      (EventSort.distance, filters.isNear),
      (EventSort.popular, true),
    ];

/// The clubs list's orders. None picked is popular, the server's default.
enum ClubSort {
  popular('popular', 'Popular'),
  nearby('nearby', 'Nearby'),
  newest('newest', 'Newest');

  const ClubSort(this.param, this.label);
  final String param;
  final String label;

  static ClubSort? parse(Object? raw) =>
      _pick(ClubSort.values, (v) => v.param, raw);
}

enum ClubFilterKey { topic, interest, radius }

/// The find-clubs filters.
class ClubFilters extends Equatable {
  const ClubFilters({
    this.q = '',
    this.topic,
    this.interest,
    this.sort,
    this.radiusKm,
    this.place = DiscoverPlace.everywhere,
  });

  static const none = ClubFilters();

  final String q;
  final String? topic;
  final int? interest;
  final ClubSort? sort;
  final int? radiusKm;
  final DiscoverPlace place;

  bool get isNear => place == DiscoverPlace.near;

  ClubFilters normalized() => ClubFilters(
        q: _text(q),
        topic: topicParam(topic),
        interest: interest != null && interest! > 0 ? interest : null,
        sort: sort == ClubSort.popular || (sort == ClubSort.nearby && !isNear)
            ? null
            : sort,
        radiusKm: isNear && radiusOptions.contains(radiusKm) ? radiusKm : null,
        place: place,
      );

  ClubFilters copyWith({
    String? q,
    Object? topic = _keep,
    Object? interest = _keep,
    Object? sort = _keep,
    Object? radiusKm = _keep,
    DiscoverPlace? place,
  }) =>
      ClubFilters(
        q: q ?? this.q,
        topic: identical(topic, _keep) ? this.topic : topic as String?,
        interest: identical(interest, _keep) ? this.interest : interest as int?,
        sort: identical(sort, _keep) ? this.sort : sort as ClubSort?,
        radiusKm: identical(radiusKm, _keep) ? this.radiusKm : radiusKm as int?,
        place: place ?? this.place,
      ).normalized();

  ClubFilters withTopic(String? slug) => copyWith(topic: slug, interest: null);

  List<ClubFilterKey> get activeKeys {
    final f = normalized();
    return [
      if (f.topic != null) ClubFilterKey.topic,
      if (f.interest != null) ClubFilterKey.interest,
      if (f.radiusKm != null) ClubFilterKey.radius,
    ];
  }

  int get activeCount => activeKeys.length;

  ClubFilters without(ClubFilterKey key) {
    switch (key) {
      case ClubFilterKey.topic:
        return copyWith(topic: null, interest: null);
      case ClubFilterKey.interest:
        return copyWith(interest: null);
      case ClubFilterKey.radius:
        return copyWith(radiusKm: null);
    }
  }

  ClubFilters cleared() =>
      ClubFilters(q: q, sort: sort, place: place).normalized();

  /// The query for `GET /discover/clubs`.
  Map<String, dynamic> clubsQuery(
      [PageRequest paging = const PageRequest.first()]) {
    final f = normalized();
    return {
      if (f.q.isNotEmpty) 'q': f.q,
      if (f.topic != null) 'topic': f.topic,
      if (f.interest != null) 'interest': f.interest,
      if (!f.isNear)
        'radius_km': 0
      else if (f.radiusKm != null)
        'radius_km': f.radiusKm,
      if (f.sort != null) 'sort': f.sort!.param,
      ...paging.query,
    };
  }

  Map<String, String> toParams() {
    final f = normalized();
    return {
      if (f.q.isNotEmpty) 'q': f.q,
      if (f.topic != null) 'topic': f.topic!,
      if (f.interest != null) 'interest': '${f.interest}',
      if (f.sort != null) 'sort': f.sort!.param,
      if (f.radiusKm != null) 'radius_km': '${f.radiusKm}',
      if (f.isNear) 'near': '1',
    };
  }

  static ClubFilters fromParams(Map<String, String> params) {
    final near = (params['near'] ?? '').trim().isNotEmpty ||
        params['sort'] == ClubSort.nearby.param;
    return ClubFilters(
      q: _text(params['q']),
      topic: topicParam(params['topic']),
      interest: _id(params['interest']),
      sort: ClubSort.parse(params['sort']),
      radiusKm: _radius(params['radius_km']),
      place: near ? DiscoverPlace.near : DiscoverPlace.everywhere,
    ).normalized();
  }

  @override
  List<Object?> get props => [q, topic, interest, sort, radiusKm, place];
}

/// The address of a list screen with [params]: `/discover/events?when=today`.
String locationWith(String path, Map<String, String> params) =>
    params.isEmpty ? path : Uri(path: path, queryParameters: params).toString();
