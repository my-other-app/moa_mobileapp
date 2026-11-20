/// The event's live room as the people in it see it: `GET
/// /events/{id}/live` (the `room` view; a stream snapshot is the same JSON).
///
/// Read leniently, field by field: a server that sends less (an older one)
/// or more (a newer one) still gives a room, never an exception. This
/// release's server (asked with `X-Live-Version: 2`) adds the poll kinds and
/// their settings (CONTRACT 7) and the room's theme (CONTRACT 9.1).
library;

import 'package:finnet/features/live/domain/live_theme.dart';

int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

/// An update the organiser pushed: a room change, a schedule change, news.
class LiveUpdate {
  const LiveUpdate({
    required this.id,
    required this.text,
    this.kind = 'general',
    this.sentAt,
  });

  final String id;
  final String text;

  /// `schedule`, `room` or `general`.
  final String kind;
  final DateTime? sentAt;

  /// What the website calls each kind.
  String get kindLabel => switch (kind) {
        'schedule' => 'Schedule change',
        'room' => 'Room change',
        _ => 'Update',
      };

  static LiveUpdate? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = _str(json['text']);
    if (text == null) return null;
    return LiveUpdate(
      id: _str(json['id']) ?? text,
      text: text,
      kind: _str(json['kind']) ?? 'general',
      sentAt: _date(json['sent_at']),
    );
  }
}

/// One answer of a multiple-choice poll, with its share so far. Also a bar
/// of a rating's histogram (its label the score).
class PollChoice {
  const PollChoice({required this.label, this.count = 0, this.pct = 0});
  final String label;
  final int count;

  /// 0 to 100. A multiple-choice poll's add up past 100: each is the share
  /// of the people who answered.
  final int pct;
}

/// A word of a word cloud, and how many said it.
class PollWord {
  const PollWord({required this.word, this.count = 0});
  final String word;
  final int count;
}

/// An option of a ranking poll, as the room ranked it: best first.
class PollRank {
  const PollRank({
    required this.label,
    this.average,
    this.points = 0,
    this.first = 0,
  });
  final String label;

  /// Its mean place, 1 the top; null before anyone ranked.
  final double? average;
  final int points;

  /// How many put it first.
  final int first;
}

/// An open-text answer the organiser let through.
class PollText {
  const PollText({required this.id, required this.text, this.name, this.at});
  final String id;
  final String text;

  /// Shown only when the poll is not anonymous.
  final String? name;
  final DateTime? at;
}

/// How a poll is answered and shown (CONTRACT 7.1). Defaults: today's.
class PollSettings {
  const PollSettings({
    this.maxChoices = 1,
    this.scale = 5,
    this.style = 'stars',
    this.results = 'live',
    this.show = 'both',
    this.chart = 'bar',
    this.hideResults = false,
    this.anonymous = true,
    this.changeVote = true,
    this.seconds,
    this.moderate = true,
  });

  /// More than 1: multiple choice, up to this many.
  final int maxChoices;

  /// A rating's top score: 5 or 10.
  final int scale;

  /// A rating drawn as `stars` or `numbers`.
  final String style;

  /// `live` (results while it runs) or `closed` (once it closes).
  final String results;

  /// `both`, `percent` or `count`.
  final String show;

  /// `bar`, `column`, `donut` or `cloud` (words only).
  final String chart;
  final bool hideResults;
  final bool anonymous;

  /// False: one answer, no changing it.
  final bool changeVote;

  /// The poll closes by itself this long after it opened.
  final int? seconds;

  /// Open-text answers wait for the organiser.
  final bool moderate;

  bool get showsPercent => show != 'count';
  bool get showsCount => show != 'percent';

  static PollSettings fromJson(String kind, Object? json) {
    final m = json is Map ? json : const {};
    final scale = m['scale'] == 10 ? 10 : 5;
    String oneOf(Object? v, List<String> allowed, String fallback) =>
        v is String && allowed.contains(v) ? v : fallback;
    final max = m['max_choices'];
    final seconds = m['seconds'];
    return PollSettings(
      maxChoices: max is num && max >= 1 ? max.toInt() : 1,
      scale: scale,
      style: oneOf(m['style'], const ['stars', 'numbers'],
          scale == 10 ? 'numbers' : 'stars'),
      results: oneOf(m['results'], const ['live', 'closed'], 'live'),
      show: oneOf(m['show'], const ['both', 'percent', 'count'], 'both'),
      chart: oneOf(m['chart'], const ['bar', 'column', 'donut', 'cloud'],
          kind == 'words' ? 'cloud' : 'bar'),
      hideResults: m['hide_results'] == true,
      anonymous: m['anonymous'] != false,
      changeVote: m['change_vote'] != false,
      seconds: seconds is num ? seconds.toInt() : null,
      moderate: m['moderate'] != false,
    );
  }
}

/// An answer to a poll, as it is sent (CONTRACT 7.3): a choice's label, a
/// word, a rating or a text in [value]; a multiple choice's labels in
/// [values]; a ranking's labels in [order]; a name on an open-text answer.
class PollAnswer {
  const PollAnswer({this.value, this.values, this.order, this.name});

  const PollAnswer.value(String this.value)
      : values = null,
        order = null,
        name = null;

  final String? value;
  final List<String>? values;
  final List<String>? order;
  final String? name;

  /// The labels the answer stands for.
  List<String> get labels => values ?? order ?? [if (value != null) value!];

  Map<String, dynamic> toJson() => {
        if (value != null) 'value': value,
        if (values != null) 'values': values,
        if (order != null) 'order': order,
        if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      };
}

/// The longest an open-text answer may be (CONTRACT 7.1).
const pollTextMax = 120;

/// The poll the organiser has up.
class LivePoll {
  const LivePoll({
    required this.id,
    required this.kind,
    required this.prompt,
    this.options = const [],
    this.status = 'live',
    this.responses = 0,
    this.choices = const [],
    this.words = const [],
    this.ratingAverage,
    this.myResponse,
    this.settings = const PollSettings(),
    this.closesAt,
    this.optionImages = const [],
    this.resultsHidden = false,
    this.myValues,
    this.histogram = const [],
    this.ranking = const [],
    this.texts = const [],
  });

  final String id;

  /// `choice`, `words`, `rating`; this release's server adds `ranking` and
  /// `text`. Any other is a newer kind: shown with a line asking to update.
  final String kind;
  final String prompt;
  final List<String> options;
  final String status;
  final int responses;
  final List<PollChoice> choices;

  /// The room's words, most said first (the server sends the top few).
  final List<PollWord> words;
  final double? ratingAverage;

  /// This phone's (or this account's) answer, when it has given one: a
  /// label, a word, a rating, a text; for multiple choice and ranking the
  /// options' places joined by commas (use [mine]).
  final String? myResponse;

  final PollSettings settings;

  /// When the poll's timer closes it.
  final DateTime? closesAt;

  /// A picture per option, or null, aligned with [options].
  final List<LiveMedia?> optionImages;

  /// The guests are not shown the results (now, or at all).
  final bool resultsHidden;

  /// The answer as labels: a multiple choice's picks, a ranking's order.
  final List<String>? myValues;

  /// A rating's scores, 1 up.
  final List<PollChoice> histogram;
  final List<PollRank> ranking;
  final List<PollText> texts;

  bool get isChoice => kind == 'choice';
  bool get isWords => kind == 'words';
  bool get isRating => kind == 'rating';
  bool get isRanking => kind == 'ranking';
  bool get isText => kind == 'text';
  bool get isMultiple => isChoice && settings.maxChoices > 1;

  /// A kind this app can answer.
  bool get isKnown => isChoice || isWords || isRating || isRanking || isText;
  bool get isOpen => status == 'live';
  bool get answered => myResponse != null || (myValues?.isNotEmpty ?? false);

  /// The answer as labels, whatever the kind.
  List<String> get mine =>
      myValues ?? [if (myResponse != null) myResponse!];

  int get scale => settings.scale;

  /// The choices to draw: the server's counts, or the options before any
  /// came in.
  List<PollChoice> get choicesToShow => choices.isNotEmpty
      ? choices
      : [for (final o in options) PollChoice(label: o)];

  /// The picture on option [i], if it has one.
  LiveMedia? imageOf(int i) =>
      i >= 0 && i < optionImages.length ? optionImages[i] : null;

  LivePoll withMine(String? value, [List<String>? values]) => LivePoll(
        id: id,
        kind: kind,
        prompt: prompt,
        options: options,
        status: status,
        responses: responses,
        choices: choices,
        words: words,
        ratingAverage: ratingAverage,
        myResponse: value,
        settings: settings,
        closesAt: closesAt,
        optionImages: optionImages,
        resultsHidden: resultsHidden,
        myValues: values,
        histogram: histogram,
        ranking: ranking,
        texts: texts,
      );

  LivePoll withMyResponse(String? value) => withMine(value, myValues);

  static LivePoll? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    final prompt = _str(json['prompt']);
    if (id == null || prompt == null) return null;
    final kind = _str(json['kind']) ?? 'choice';
    final results = json['results'] is Map ? json['results'] as Map : const {};
    final rating = results['rating'] is Map ? results['rating'] as Map : null;
    final average = rating?['average'];
    final settings = PollSettings.fromJson(kind, json['settings']);
    final values = json['my_values'];
    final images = json['option_images'];
    return LivePoll(
      id: id,
      kind: kind,
      prompt: prompt,
      options: json['options'] is List
          ? [
              for (final o in json['options'] as List)
                if (_str(o) != null) _str(o)!,
            ]
          : const [],
      status: _str(json['status']) ?? 'live',
      responses: _int(results['responses']),
      choices: [
        for (final c in _maps(results['choices']))
          if (_str(c['label']) != null)
            PollChoice(
              label: _str(c['label'])!,
              count: _int(c['count']),
              pct: _int(c['pct']).clamp(0, 100),
            ),
      ],
      words: [
        for (final w in _maps(results['words']))
          if (_str(w['word']) != null)
            PollWord(word: _str(w['word'])!, count: _int(w['count'])),
      ],
      ratingAverage: average is num ? average.toDouble() : null,
      myResponse: _str(json['my_response']),
      settings: settings,
      closesAt: _date(json['closes_at']),
      optionImages:
          images is List ? [for (final i in images) LiveMedia.fromJson(i)] : const [],
      resultsHidden: json['results_hidden'] == true,
      myValues: values is List
          ? [
              for (final v in values)
                if (_str(v) != null) _str(v)!,
            ]
          : null,
      histogram: [
        for (final h in _maps(rating?['histogram']))
          PollChoice(
            label: '${_int(h['value'])}',
            count: _int(h['count']),
            pct: _int(h['pct']).clamp(0, 100),
          ),
      ],
      ranking: [
        for (final r in _maps(results['ranking']))
          if (_str(r['label']) != null)
            PollRank(
              label: _str(r['label'])!,
              average: r['average'] is num
                  ? (r['average'] as num).toDouble()
                  : null,
              points: _int(r['points']),
              first: _int(r['first']),
            ),
      ],
      texts: [
        for (final t in _maps(results['texts']))
          if (_str(t['text']) != null)
            PollText(
              id: _str(t['id']) ?? _str(t['text'])!,
              text: _str(t['text'])!,
              name: _str(t['name']),
              at: _date(t['at']),
            ),
      ],
    );
  }
}

/// A question from the floor.
class LiveQuestion {
  const LiveQuestion({
    required this.id,
    required this.text,
    this.authorName,
    this.status = 'approved',
    this.pinned = false,
    this.votes = 0,
    this.createdAt,
    this.voted = false,
    this.mine = false,
  });

  final String id;
  final String text;
  final String? authorName;

  /// `pending` (waiting for the organiser), `approved`, `answered`.
  final String status;

  /// On the big screen now.
  final bool pinned;
  final int votes;
  final DateTime? createdAt;

  /// This phone (or account) voted it up.
  final bool voted;

  /// Asked from this phone (or account).
  final bool mine;

  bool get answered => status == 'answered';
  bool get pending => status == 'pending';

  LiveQuestion withVote({required int votes, required bool voted}) =>
      LiveQuestion(
        id: id,
        text: text,
        authorName: authorName,
        status: status,
        pinned: pinned,
        votes: votes < 0 ? 0 : votes,
        createdAt: createdAt,
        voted: voted,
        mine: mine,
      );

  static LiveQuestion? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    final text = _str(json['text']);
    if (id == null || text == null) return null;
    return LiveQuestion(
      id: id,
      text: text,
      authorName: _str(json['author_name']),
      status: _str(json['status']) ?? 'approved',
      pinned: json['pinned'] == true,
      votes: _int(json['votes']),
      createdAt: _date(json['created_at']),
      voted: json['voted'] == true,
      mine: json['mine'] == true,
    );
  }
}

/// The board's order: the one on the screen first, then the most voted,
/// then the oldest.
List<LiveQuestion> sortQuestions(Iterable<LiveQuestion> questions) {
  final list = questions.toList();
  final at = {for (var i = 0; i < list.length; i++) list[i].id: i};
  list.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    if (a.votes != b.votes) return b.votes.compareTo(a.votes);
    final ac = a.createdAt, bc = b.createdAt;
    if (ac != null && bc != null && ac != bc) return ac.compareTo(bc);
    return at[a.id]!.compareTo(at[b.id]!);
  });
  return list;
}

/// The room.
class LiveRoom {
  const LiveRoom({
    required this.eventId,
    this.eventName,
    this.eventStatus,
    this.banner,
    this.updates = const [],
    this.poll,
    this.questions = const [],
    this.qaOpen = false,
    this.approveFirst = false,
    this.quizLive = false,
    this.quizTitle,
    this.theme,
  });

  final int eventId;
  final String? eventName;

  /// `published`, `live`, `closed`, `archived`; null from a server that
  /// does not say.
  final String? eventStatus;

  /// The latest update, while it is fresh (the server's three hours).
  final LiveUpdate? banner;

  /// The latest updates, newest first (the banner among them).
  final List<LiveUpdate> updates;
  final LivePoll? poll;

  /// On the board: approved and answered, in the board's order.
  final List<LiveQuestion> questions;

  /// The floor takes questions: the event is not over, and the club's plan
  /// has Q&A (when it does not, the server says closed rather than refuse).
  final bool qaOpen;

  /// A question shows once the organiser lets it through.
  final bool approveFirst;
  final bool quizLive;
  final String? quizTitle;

  /// The room's look; null from a server from before themes (the room is
  /// then drawn as it always was, as it is for an event with none saved).
  final LiveThemeState? theme;

  /// The event is over: the room is read-only.
  bool get isClosed => eventStatus == 'closed' || eventStatus == 'archived';

  bool get isEventLive => eventStatus == 'live';

  /// Updates before the banner's: "Earlier tonight".
  List<LiveUpdate> get earlier =>
      updates.length > 1 ? updates.sublist(1) : const [];

  /// Nothing to show at all.
  bool get isEmpty =>
      banner == null &&
      updates.isEmpty &&
      poll == null &&
      questions.isEmpty &&
      !qaOpen &&
      !quizLive;

  LiveRoom copyWith({
    LivePoll? Function()? poll,
    List<LiveQuestion>? questions,
    bool? qaOpen,
  }) =>
      LiveRoom(
        eventId: eventId,
        eventName: eventName,
        eventStatus: eventStatus,
        banner: banner,
        updates: updates,
        poll: poll != null ? poll() : this.poll,
        questions: questions ?? this.questions,
        qaOpen: qaOpen ?? this.qaOpen,
        approveFirst: approveFirst,
        quizLive: quizLive,
        quizTitle: quizTitle,
        theme: theme,
      );

  static LiveRoom? tryParse(Object? json) {
    if (json is! Map) return null;
    final event = json['event'] is Map ? json['event'] as Map : const {};
    final qa = json['qa'] is Map ? json['qa'] as Map : const {};
    final quiz = json['quiz'] is Map ? json['quiz'] as Map : const {};
    final updates = [
      for (final u in (json['updates'] is List ? json['updates'] as List : []))
        if (LiveUpdate.fromJson(u) != null) LiveUpdate.fromJson(u)!,
    ];
    return LiveRoom(
      eventId: _int(event['id']),
      eventName: _str(event['name']),
      eventStatus: _str(event['status']),
      banner: LiveUpdate.fromJson(json['banner']),
      updates: updates,
      poll: LivePoll.fromJson(json['poll']),
      questions: sortQuestions([
        for (final q
            in (json['questions'] is List ? json['questions'] as List : []))
          if (LiveQuestion.fromJson(q) != null) LiveQuestion.fromJson(q)!,
      ]),
      qaOpen: qa['open'] == true,
      approveFirst: qa['approve_first'] == true,
      quizLive: quiz['live'] == true,
      quizTitle: _str(quiz['title']),
      theme: LiveThemeState.fromJson(json['theme']),
    );
  }
}
