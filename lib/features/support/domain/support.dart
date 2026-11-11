/// Help and support: what the app reads from the support desk
/// (feature-register `support-leads-contract.md`, "Public / signed-in").
///
/// Every reader is forgiving: a field that is missing or of the wrong kind
/// gets a fallback, and a row without what it needs is skipped, so one odd
/// answer never empties a list.
library;

import 'package:finnet/core/utils/json_read.dart';

/// The longest message the desk takes (`message (≤5000)`).
const maxSupportMessageLength = 5000;

/// Screenshots on one request or reply.
const maxSupportAttachments = 3;

/// The largest file the desk takes (`≤5 MB`).
const maxSupportFileBytes = 5 * 1024 * 1024;

/// The kinds of file the desk takes from the app: the picture formats a
/// phone's photo picker hands back (the desk also takes PDF, which the
/// app does not offer).
const supportFileTypes = {'png', 'jpg', 'jpeg', 'webp'};

/// The push the desk sends when the team replies (`support_reply`, data
/// `{case_id, number}`).
const supportReplyType = 'support_reply';

/// The app's screen for a request.
String supportRequestRoute(String caseId) =>
    '/profile/help/requests/${Uri.encodeComponent(caseId)}';

/// Where a `support_reply` push (or its inbox line) opens: the request, by
/// its `case_id`; My requests without one.
String supportReplyRoute(Map<String, dynamic> data) {
  final id = jsonString(data['case_id'])?.trim();
  return id == null || id.isEmpty
      ? '/profile/help/requests'
      : supportRequestRoute(id);
}

String? _text(Object? value) {
  final s = jsonString(value)?.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  return s == null || s.isEmpty ? null : s;
}

/// One of the desk's published answers (`GET /support/help`).
class HelpAnswer {
  const HelpAnswer({
    required this.id,
    required this.question,
    required this.answer,
    this.topic,
  });

  final String id;
  final String? topic;
  final String question;
  final String answer;

  static HelpAnswer? fromJson(Map<String, dynamic> json) {
    final question = _text(json['question']);
    final answer = _text(json['answer']);
    if (question == null || answer == null) return null;
    return HelpAnswer(
      id: jsonText(json['id'], question),
      topic: _text(json['topic']),
      question: question,
      answer: answer,
    );
  }

  /// Every answer in [value] -- a list, or `{items: [...]}` -- in order.
  static List<HelpAnswer> listFrom(Object? value) => [
        for (final json in jsonObjects(_items(value)))
          if (fromJson(json) case final answer?) answer,
      ];
}

/// What a request is about (`GET /support/topics`).
class SupportTopic {
  const SupportTopic(this.key, this.label);

  final String key;
  final String label;

  /// The topics the desk's migration seeds, for when the list cannot be
  /// read: the form still works.
  static const defaults = [
    SupportTopic('account', 'My account'),
    SupportTopic('tickets', 'Tickets and registrations'),
    SupportTopic('payments', 'Payments and refunds'),
    SupportTopic('report', 'Report something'),
    SupportTopic('bug', 'Something is not working'),
    SupportTopic('other', 'Something else'),
  ];

  /// The dashboard's topic: for club teams, not for the app.
  static const dashboard = 'dashboard';

  static List<SupportTopic> listFrom(Object? value) => [
        for (final json in jsonObjects(_items(value)))
          if (_text(json['key']) case final key?)
            if (key != dashboard) SupportTopic(key, _text(json['label']) ?? key),
      ];

  /// The words for [key] among [topics], else among [defaults], else the
  /// key itself ("tickets" -> "Tickets").
  static String labelFor(String? key, [List<SupportTopic> topics = const []]) {
    if (key == null || key.isEmpty) return 'Request';
    for (final topic in [...topics, ...defaults]) {
      if (topic.key == key) return topic.label;
    }
    return key[0].toUpperCase() + key.substring(1).replaceAll('_', ' ');
  }
}

/// Where a request stands.
enum SupportStatus { newCase, open, waiting, resolved, closed }

SupportStatus supportStatusFrom(Object? value) => switch (jsonString(value)) {
      'new' => SupportStatus.newCase,
      'waiting' => SupportStatus.waiting,
      'resolved' => SupportStatus.resolved,
      'closed' => SupportStatus.closed,
      _ => SupportStatus.open,
    };

extension SupportStatusWords on SupportStatus {
  /// The chip's words, from the asker's side: `waiting` is the team
  /// waiting on them.
  String get label => switch (this) {
        SupportStatus.newCase => 'Sent',
        SupportStatus.open => 'Open',
        SupportStatus.waiting => 'Waiting for you',
        SupportStatus.resolved => 'Solved',
        SupportStatus.closed => 'Closed',
      };

  bool get isDone =>
      this == SupportStatus.resolved || this == SupportStatus.closed;
}

/// One of the person's requests in My requests (`GET /support/requests`).
class SupportRequestSummary {
  const SupportRequestSummary({
    required this.id,
    required this.status,
    this.number,
    this.subject,
    this.topic,
    this.updatedAt,
    this.unread = false,
  });

  final String id;
  final int? number;
  final String? subject;
  final String? topic;
  final SupportStatus status;
  final DateTime? updatedAt;

  /// The team replied since the person last looked.
  final bool unread;

  static SupportRequestSummary? fromJson(Map<String, dynamic> json) {
    final id = _text(json['id']);
    if (id == null) return null;
    return SupportRequestSummary(
      id: id,
      number: jsonInt(json['number']),
      subject: _text(json['subject']),
      topic: _text(json['topic']),
      status: supportStatusFrom(json['status']),
      updatedAt: jsonDate(json['updated_at']) ?? jsonDate(json['created_at']),
      unread: jsonBool(json['unread']) == true,
    );
  }

  static List<SupportRequestSummary> listFrom(Object? value) => [
        for (final json in jsonObjects(_items(value)))
          if (fromJson(json) case final row?) row,
      ];
}

/// "#1042", or nothing without a number.
String supportNumber(int? number) => number == null ? '' : '#$number';

/// A file on a message.
class SupportAttachment {
  const SupportAttachment({
    required this.name,
    this.id,
    this.url,
    this.apiPath,
    this.contentType,
  });

  final String? id;
  final String name;

  /// A web address anyone with it can open.
  final Uri? url;

  /// The desk's own address for it (`/api/v1/support/requests/{id}/
  /// attachments/{file}`), relative to the app's API base: read with the
  /// session, so only the person who asked can.
  final String? apiPath;
  final String? contentType;

  bool get canOpen => url != null || apiPath != null;

  /// A name safe to keep the file under on the phone.
  String get fileName {
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final prefix = id == null ? '' : '$id-';
    return '$prefix${safe.isEmpty ? 'attachment' : safe}';
  }

  static SupportAttachment? fromJson(Map<String, dynamic> json) {
    final raw = jsonText(json['url']).trim();
    final url = Uri.tryParse(raw);
    final web = url != null && (url.isScheme('https') || url.isScheme('http'));
    // Only the desk's own files: a path under /api/v1/support/ (or the
    // same without the prefix), never one that climbs out of it.
    String? apiPath;
    if (!web && raw.startsWith('/') && !raw.contains('..')) {
      final path = raw.startsWith('/api/v1/') ? raw.substring(7) : raw;
      if (path.startsWith('/support/')) apiPath = path;
    }
    final name =
        _text(json['name']) ?? (web || apiPath != null ? 'Attachment' : null);
    if (name == null) return null;
    return SupportAttachment(
      id: _text(json['id']),
      name: name,
      url: web ? url : null,
      apiPath: apiPath,
      contentType: _text(json['content_type']),
    );
  }
}

/// One message in a request's thread. Notes never reach the app.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.fromUs,
    required this.body,
    this.authorName,
    this.createdAt,
    this.attachments = const [],
  });

  final String id;

  /// From the MyOtherApp team (`reply_out`), not the person (`reply_in`).
  final bool fromUs;
  final String body;
  final String? authorName;
  final DateTime? createdAt;
  final List<SupportAttachment> attachments;

  static SupportMessage? fromJson(Map<String, dynamic> json) {
    final kind = jsonString(json['kind']);
    // An internal note is never meant for the person, should one slip in;
    // a system line ("Reopened") reads as the team's.
    if (kind == 'note') return null;
    final attachments = [
      for (final a in jsonObjects(json['attachments']))
        if (SupportAttachment.fromJson(a) case final file?) file,
    ];
    final body = _text(json['body_text']) ?? _text(json['body']) ?? '';
    if (body.isEmpty && attachments.isEmpty) return null;
    return SupportMessage(
      id: jsonText(json['id'], '${json.hashCode}'),
      fromUs: kind != 'reply_in',
      body: body,
      authorName: _text(json['author_name']),
      createdAt: jsonDate(json['created_at']),
      attachments: attachments,
    );
  }
}

/// A request with its thread (`GET /support/requests/{id}`).
class SupportRequestDetail {
  const SupportRequestDetail({
    required this.id,
    required this.status,
    this.number,
    this.subject,
    this.topic,
    this.createdAt,
    this.messages = const [],
    this.canReply = true,
    this.surveyAnswered = false,
    this.canSurvey = false,
  });

  final String id;
  final int? number;
  final String? subject;
  final String? topic;
  final SupportStatus status;
  final DateTime? createdAt;
  final List<SupportMessage> messages;
  final bool canReply;

  /// "Did we solve it?" has its answer.
  final bool surveyAnswered;

  /// "Did we solve it?" may be asked: the server's `can_survey`, else a
  /// solved request without an answer.
  final bool canSurvey;

  static SupportRequestDetail fromJson(Object? value, {required String id}) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    final status = supportStatusFrom(json['status']);
    final answered = jsonObject(json['survey']) != null;
    return SupportRequestDetail(
      id: _text(json['id']) ?? id,
      number: jsonInt(json['number']),
      subject: _text(json['subject']),
      topic: _text(json['topic']),
      status: status,
      createdAt: jsonDate(json['created_at']),
      messages: [
        for (final m in jsonObjects(json['messages']))
          if (SupportMessage.fromJson(m) case final message?) message,
      ],
      canReply: jsonBool(json['can_reply']) ?? status != SupportStatus.closed,
      surveyAnswered: answered,
      canSurvey: jsonBool(json['can_survey']) ??
          (status == SupportStatus.resolved && !answered),
    );
  }

  SupportRequestDetail copyWith({bool? surveyAnswered}) => SupportRequestDetail(
        id: id,
        number: number,
        subject: subject,
        topic: topic,
        status: status,
        createdAt: createdAt,
        messages: messages,
        canReply: canReply,
        surveyAnswered: surveyAnswered ?? this.surveyAnswered,
        canSurvey: canSurvey,
      );
}

/// A file the desk has taken (`POST /support/uploads`): its key goes with
/// the request or reply.
class SupportUpload {
  const SupportUpload({required this.key, required this.name, this.size});

  final String key;
  final String name;
  final int? size;

  /// The upload in [value]: an object, or the first of a list.
  static SupportUpload? fromJson(Object? value) {
    final direct = jsonObject(value);
    final json = direct != null && direct['key'] != null
        ? direct
        : jsonObjects(_items(value)).firstOrNull ??
            jsonObject(direct?['file']);
    if (json == null) return null;
    final key = _text(json['key']);
    if (key == null) return null;
    return SupportUpload(
      key: key,
      name: _text(json['name']) ?? key,
      size: jsonInt(json['size']),
    );
  }
}

/// A request just sent (`POST /support/requests`).
class SupportRequestSent {
  const SupportRequestSent({required this.id, this.number});

  final String id;
  final int? number;

  static SupportRequestSent fromJson(Object? value) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    return SupportRequestSent(
      id: _text(json['id']) ?? '',
      number: jsonInt(json['number']),
    );
  }
}

/// A reply just sent (`POST /support/requests/{id}/replies`): the request
/// it went to -- a new one ([newCase]) when the old one was closed, or
/// solved more than a week ago.
class SupportReplySent {
  const SupportReplySent({
    required this.caseId,
    this.number,
    this.newCase = false,
  });

  final String caseId;
  final int? number;
  final bool newCase;

  static SupportReplySent fromJson(Object? value, {required String caseId}) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    return SupportReplySent(
      caseId: _text(json['case_id']) ?? caseId,
      number: jsonInt(json['number']),
      newCase: jsonBool(json['new_case']) == true,
    );
  }
}

/// What a request is about, beyond its words: the app, its version, and
/// one of the person's events when they picked one.
class SupportContext {
  const SupportContext({this.appVersion, this.eventId});

  final String? appVersion;
  final int? eventId;

  Map<String, dynamic> toJson() => {
        'platform': 'app',
        if (appVersion != null && appVersion!.isNotEmpty)
          'app_version': appVersion,
        if (eventId != null) 'event_id': eventId,
      };
}

/// One of the person's events, to say a request is about it.
class SupportEventChoice {
  const SupportEventChoice({
    required this.eventId,
    required this.name,
    this.when,
  });

  final int eventId;
  final String name;
  final DateTime? when;
}

/// A bare list, or the list under `items` (or `data`).
Object? _items(Object? value) {
  if (value is List) return value;
  final json = jsonObject(value);
  if (json == null) return null;
  return json['items'] ?? json['data'] ?? json['files'];
}
