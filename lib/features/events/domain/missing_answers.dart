import 'package:intl/intl.dart';

import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/utils/json_read.dart';

// "Missing answers" (feature-register `missing-answers-contract.md`): a club
// that changes its sign-up questions after people signed up can ask exactly
// those people for exactly the answers they are missing, with a personal
// link. The app opens that link (`/answers/{event}/{ref}?k=`), shows a
// "details needed" note wherever a ticket or a registration is, and lets a
// door volunteer fill a missing answer at check-in. Read without trusting any
// field to be there: a server without the feature sends none of it, and
// every screen does what it did before.

String? _text(Object? value) {
  final s = jsonString(value)?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// "Sat 14 Nov, 6:00 PM".
String answersMoment(DateTime at) =>
    DateFormat('EEE d MMM, h:mm a').format(at.toLocal());

/// `answers_needed` on a ticket, a registration in My events, or a
/// registration under review (§2.4): the club asked this person for
/// [count] more details, and [url] is their personal link to add them.
/// Only there while the ask is open.
class AnswersNeeded {
  const AnswersNeeded({required this.url, this.count, this.deadline});

  /// How many details are asked for; null when the server didn't say.
  final int? count;

  /// The personal link: `https://myotherapp.in/answers/{event}/{ref}?k=…`.
  final String url;

  /// When the club wants them by.
  final DateTime? deadline;

  /// The note, or null: none sent (an older server, or nothing asked), no
  /// link to add them with, or a count of none.
  static AnswersNeeded? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    final url = _text(json['url']);
    final count = jsonInt(json['count']);
    if (url == null || (count != null && count <= 0)) return null;
    return AnswersNeeded(
      url: url,
      count: count,
      deadline: jsonDate(json['deadline']),
    );
  }

  /// "2 details needed", "1 detail needed", or "Details needed".
  String get title => switch (count) {
        null => 'Details needed',
        1 => '1 detail needed',
        final n => '$n details needed',
      };

  /// "Add them", or "Add it" for one.
  String get action => count == 1 ? 'Add it' : 'Add them';

  /// "2 details needed · Add them".
  String get line => '$title · $action';

  /// "By Sat 14 Nov, 6:00 PM", or null without a deadline.
  String? get byLine {
    final by = deadline;
    return by == null ? null : 'By ${answersMoment(by)}';
  }
}

/// Where a person's asked-for details stand (`status`).
enum AnswersStatus {
  /// Something is asked, and there is still time.
  open,

  /// Nothing is missing any more.
  done,

  /// The deadline passed, or the event ended.
  closed,

  /// The person no longer counts (cancelled, declined...).
  nothing,

  /// A word this build doesn't know.
  unknown,
}

AnswersStatus answersStatusFrom(Object? value) =>
    switch (jsonString(value)?.trim().toLowerCase()) {
      'open' => AnswersStatus.open,
      'done' => AnswersStatus.done,
      'closed' => AnswersStatus.closed,
      'nothing' => AnswersStatus.nothing,
      _ => AnswersStatus.unknown,
    };

/// The event the details are for (`event`).
class AnswersEvent {
  const AnswersEvent({
    required this.id,
    this.name = '',
    this.startsAt,
    this.orgName = '',
    this.poster,
    this.slug = '',
  });

  final int id;
  final String name;
  final DateTime? startsAt;
  final String orgName;

  /// The poster's URL, or null.
  final String? poster;
  final String slug;

  /// The app's route to the event.
  String get route =>
      '/events/${slug.isNotEmpty ? Uri.encodeComponent(slug) : id}';

  static AnswersEvent fromJson(Object? value, {int fallbackId = 0}) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    final poster = json['poster'];
    return AnswersEvent(
      id: jsonInt(json['id']) ?? fallbackId,
      name: _text(json['name']) ?? '',
      startsAt: jsonDate(json['starts_at']),
      orgName: _text(json['org_name']) ?? '',
      // The contract sends a URL; a poster map is read too.
      poster: poster is Map
          ? (_text(poster['medium']) ??
              _text(poster['thumbnail']) ??
              _text(poster['original']))
          : _text(poster),
      slug: _text(json['slug']) ?? '',
    );
  }
}

/// `GET` (and `POST`) `/events/{event_id}/answers/{ref}` (§2.3): the
/// person's asked-for details, with the whole form and what they answered,
/// for the conditions and to fill in what they have.
class AnswersForm {
  const AnswersForm({
    required this.status,
    required this.event,
    this.firstName,
    this.kind = 'registration',
    this.deadline,
    this.message,
    this.questions = const [],
    this.asked = const [],
    this.answers = const {},
    this.ticketUrl,
    this.requestUrl,
  });

  final AnswersStatus status;
  final AnswersEvent event;

  /// The person's first name, when the server said it.
  final String? firstName;

  /// `registration` (a ticket) or `request` (a registration under review).
  final String kind;
  final DateTime? deadline;

  /// The club's message with the ask.
  final String? message;

  /// The whole current form, as every read endpoint sends it.
  final List<AdditionalDetail> questions;

  /// The keys asked for, in the form's order.
  final List<String> asked;

  /// What the person has answered, by key, for the current form.
  final Map<String, Object?> answers;

  /// Their ticket on the website, when they hold one.
  final String? ticketUrl;

  /// A registration under review's own page on the website
  /// (`https://myotherapp.in/requests/{token}`); null for a ticket.
  final String? requestUrl;

  bool get isRequest => kind == 'request';

  /// The organiser's name, or "The club": for the start of a sentence.
  String get clubName => event.orgName.isEmpty ? 'The club' : event.orgName;

  /// The organiser's name, or "the club": for the middle of one.
  String get clubMidSentence =>
      event.orgName.isEmpty ? 'the club' : event.orgName;

  /// [asked], and every question that follows from one of them: the
  /// questions this screen can show.
  Set<String> get editable => askedWithFollowUps(questions, asked);

  static AnswersForm fromJson(Object? value, {int fallbackEventId = 0}) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    final person = jsonObject(json['person']) ?? const <String, dynamic>{};
    final questions = [
      for (final q in jsonObjects(json['questions']))
        if (_text(q['key']) != null) AdditionalDetail.fromJson(q),
    ];
    final known = {for (final q in questions) q.key};
    final rawAsked = json['asked'];
    final asked = <String>[
      if (rawAsked is List)
        for (final key in rawAsked)
          if (key != null && known.contains('$key')) '$key',
    ];
    // In the form's order, once each.
    final askedSet = asked.toSet();
    final answers = jsonObject(json['answers']);
    return AnswersForm(
      status: answersStatusFrom(json['status']),
      event: AnswersEvent.fromJson(json['event'], fallbackId: fallbackEventId),
      firstName: _text(person['first_name']),
      kind: _text(person['kind'])?.toLowerCase() ?? 'registration',
      deadline: jsonDate(json['deadline']),
      message: _text(json['message']),
      questions: questions,
      asked: [
        for (final q in questions)
          if (askedSet.contains(q.key)) q.key,
      ],
      answers: answers == null ? const {} : Map<String, Object?>.of(answers),
      ticketUrl: _text(json['ticket_url']),
      requestUrl: _text(json['request_url']),
    );
  }
}

/// The keys in [asked], and of every question that follows from one of
/// them -- a child, a grandchild -- in [questions]. A parent comes before
/// its children (rule R1), so one pass in list order finds them all.
Set<String> askedWithFollowUps(
  List<AdditionalDetail> questions,
  Iterable<String> asked,
) {
  final found = asked.toSet();
  for (final question in questions) {
    final parent = question.showIf?.key;
    if (parent != null && found.contains(parent)) found.add(question.key);
  }
  return found;
}

/// The `error_code` an answer refused after the deadline comes with (409).
abstract final class AnswersErrorCodes {
  static const closed = 'CLOSED';
}

/// The app's route for a personal link to add missing details
/// (`https://myotherapp.in/answers/{eventId}/{ref}?k=…`, a push's `url`):
/// `/answers/{eventId}/{ref}?k=…`. Null for any other link.
String? answersRouteFrom(String? link) {
  final uri = Uri.tryParse(link?.trim() ?? '');
  if (uri == null) return null;
  if (uri.hasScheme && !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }
  final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  if (parts.length != 3 || parts.first.toLowerCase() != 'answers') return null;
  final eventId = int.tryParse(parts[1]);
  final ref = parts[2];
  if (eventId == null || eventId <= 0 || ref.isEmpty) return null;
  final key = uri.queryParameters['k'] ?? '';
  return answersRoute(eventId, ref, key: key);
}

/// The app's route to add a person's missing details.
String answersRoute(int eventId, String ref, {String key = ''}) => Uri(
      path: '/answers/$eventId/${Uri.encodeComponent(ref)}',
      queryParameters: key.isEmpty ? null : {'k': key},
    ).toString();
