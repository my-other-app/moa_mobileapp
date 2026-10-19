import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/json_read.dart';

final feedbackSurveyDataSourceProvider =
    Provider<FeedbackSurveyDataSource>((ref) {
  return FeedbackSurveyDataSource(ref.watch(dioProvider));
});

/// One question of the organisers' survey.
enum SurveyKind { rating, nps, text }

class SurveyQuestion {
  final String key;
  final SurveyKind kind;
  final String label;

  const SurveyQuestion(
      {required this.key, required this.kind, required this.label});
}

/// The survey a guest's link opens (`PublicSurvey`).
class FeedbackSurvey {
  final String eventName;
  final String clubName;
  final String firstName;
  final List<SurveyQuestion> questions;

  /// They answered it already.
  final bool submitted;

  const FeedbackSurvey({
    this.eventName = '',
    this.clubName = '',
    this.firstName = '',
    this.questions = const [],
    this.submitted = false,
  });

  factory FeedbackSurvey.fromJson(Map<String, dynamic> json) => FeedbackSurvey(
        eventName: jsonText(json['event_name']),
        clubName: jsonText(json['club_name']),
        firstName: jsonText(json['first_name']),
        submitted: jsonBool(json['submitted']) ?? false,
        questions: [
          for (final q in jsonObjects(json['questions']))
            if ((
              jsonString(q['key']),
              switch (jsonString(q['kind'])) {
                'rating' => SurveyKind.rating,
                'nps' => SurveyKind.nps,
                'text' => SurveyKind.text,
                _ => null,
              },
            )
                case (final String key, final SurveyKind kind))
              SurveyQuestion(
                key: key,
                kind: kind,
                label: jsonText(q['label'], key),
              ),
        ],
      );
}

/// The feedback survey, for the guest its link was sent to (moa_backend
/// `app/api/live/router.py`): `GET` and `POST
/// /events/{id}/feedback/{registration_id}?k=…`. The key in the link is the
/// proof; no account is needed, so no token is sent.
class FeedbackSurveyDataSource {
  FeedbackSurveyDataSource(this._dio);

  final Dio _dio;

  static String _path(int eventId, String registrationId) =>
      '/events/$eventId/feedback/${Uri.encodeComponent(registrationId)}';

  static Options get _anonymous => Options(extra: {'skipAuth': true});

  Future<FeedbackSurvey> fetch(
      int eventId, String registrationId, String key) async {
    final response = await _dio.get<dynamic>(
      _path(eventId, registrationId),
      queryParameters: {'k': key},
      options: _anonymous,
    );
    return FeedbackSurvey.fromJson(
        jsonObject(response.data) ?? const <String, dynamic>{});
  }

  Future<void> submit(int eventId, String registrationId, String key,
      Map<String, Object> answers) async {
    await _dio.post<dynamic>(
      _path(eventId, registrationId),
      queryParameters: {'k': key},
      data: {'answers': answers},
      options: _anonymous,
    );
  }
}
