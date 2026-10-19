import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/entities/competition.dart';

// Reading `MyState` (moa_backend `app/api/competitions/schemas.py`) without
// trusting any field: a row without an id or a name is skipped, anything
// else missing takes its default.

String? _text(Object? v) {
  final s = jsonString(v)?.trim();
  return s == null || s.isEmpty ? null : s;
}

int _count(Object? v) {
  final n = jsonInt(v) ?? 0;
  return n < 0 ? 0 : n;
}

CompetitionTrack? _track(Map<String, dynamic> j) {
  final id = jsonInt(j['id']);
  final name = _text(j['name']);
  if (id == null || name == null) return null;
  return CompetitionTrack(
    id: id,
    name: name,
    description: _text(j['description']),
    sponsor: _text(j['sponsor']),
    prize: _text(j['prize']),
    teams: _count(j['teams']),
  );
}

CompetitionRequirement? _requirement(Map<String, dynamic> j) {
  final key = _text(j['key']);
  if (key == null) return null;
  return CompetitionRequirement(
    key: key,
    label: _text(j['label']) ?? key,
    required: jsonBool(j['required']) ?? true,
  );
}

CompetitionSubmission _submission(Object? value) {
  final j = jsonObject(value) ?? const <String, dynamic>{};
  final fields = jsonObject(j['fields']) ?? const <String, dynamic>{};
  return CompetitionSubmission(
    fields: {
      for (final e in fields.entries)
        if (jsonString(e.value) case final v?) e.key: v,
    },
    status: switch (jsonString(j['status'])) {
      'complete' => SubmissionStatus.complete,
      'in_progress' => SubmissionStatus.inProgress,
      _ => SubmissionStatus.nothing,
    },
    missing: [
      if (j['missing'] is List)
        for (final k in j['missing'] as List)
          if (jsonString(k) case final key?) key,
    ],
    updatedAt: jsonDate(j['updated_at']),
  );
}

CompetitionTeam? _team(Object? value) {
  final j = jsonObject(value);
  if (j == null) return null;
  final id = jsonInt(j['id']);
  if (id == null) return null;
  return CompetitionTeam(
    id: id,
    name: _text(j['name']) ?? 'Your team',
    trackId: jsonInt(j['track_id']),
    track: _text(j['track']),
    stage: switch (jsonString(j['stage'])) {
      'shortlisted' => TeamStage.shortlisted,
      'finalist' => TeamStage.finalist,
      _ => TeamStage.entered,
    },
    members: [
      for (final m in jsonObjects(j['members']))
        if (_text(m['name']) case final name?)
          CompetitionMember(
            registrationId: jsonText(m['registration_id']),
            name: name,
          ),
    ],
    openSpots: _count(j['open_spots']),
    submission: _submission(j['submission']),
  );
}

TeamSeeker? _seeker(Object? value) {
  final j = jsonObject(value);
  if (j == null) return null;
  final name = _text(j['name']);
  if (name == null) return null;
  return TeamSeeker(
    registrationId: jsonText(j['registration_id']),
    name: name,
    skills: [
      if (j['skills'] is List)
        for (final s in j['skills'] as List)
          if (_text(s) case final skill?) skill,
    ],
    note: _text(j['note']),
  );
}

Mentor? _mentor(Map<String, dynamic> j) {
  final id = jsonInt(j['id']);
  final name = _text(j['name']);
  if (id == null || name == null) return null;
  return Mentor(
    id: id,
    name: name,
    topic: _text(j['topic']),
    slots: [
      for (final s in jsonObjects(j['slots']))
        if ((jsonInt(s['id']), jsonDate(s['starts_at']))
            case (final int slotId, final DateTime at))
          MentorSlot(
            id: slotId,
            startsAt: at.toLocal(),
            minutes: _count(s['minutes']),
            teamId: jsonInt(s['team_id']),
            team: _text(s['team']),
          ),
    ],
  );
}

BoardRow? _row(Map<String, dynamic> j) {
  final id = jsonInt(j['team_id']);
  if (id == null) return null;
  return BoardRow(
    rank: jsonInt(j['rank']),
    teamId: id,
    name: _text(j['name']) ?? 'A team',
    track: _text(j['track']),
    score: jsonDouble(j['score']),
  );
}

/// [data], a `MyState`; null when it isn't one.
MyCompetition? myCompetitionFromJson(Object? data) {
  final j = jsonObject(data);
  if (j == null) return null;
  final eventId = jsonInt(j['event_id']);
  if (eventId == null) return null;
  final teamMax = jsonInt(j['team_max']);
  final teamMin = jsonInt(j['team_min']);
  return MyCompetition(
    eventId: eventId,
    enabled: jsonBool(j['enabled']) ?? true,
    registrationId: jsonText(j['registration_id']),
    name: jsonText(j['name']),
    teamMin: teamMin != null && teamMin > 0 ? teamMin : 1,
    teamMax: teamMax != null && teamMax > 0 ? teamMax : (teamMin ?? 1),
    teamsLocked: jsonBool(j['teams_locked']) ?? false,
    tracks: [
      for (final t in jsonObjects(j['tracks']))
        if (_track(t) case final track?) track,
    ],
    requirements: [
      for (final r in jsonObjects(j['requirements']))
        if (_requirement(r) case final req?) req,
    ],
    submissionsOpen: jsonBool(j['submissions_open']) ?? false,
    submissionsCloseAt: jsonDate(j['submissions_close_at'])?.toLocal(),
    team: _team(j['team']),
    openTeams: [
      for (final t in jsonObjects(j['open_teams']))
        if ((jsonInt(t['id']), _text(t['name']))
            case (final int id, final String name))
          OpenTeam(
            id: id,
            name: name,
            track: _text(t['track']),
            members: _count(t['members']),
            openSpots: _count(t['open_spots']),
          ),
    ],
    seeking: _seeker(j['seeking']),
    seekers: [
      for (final s in jsonObjects(j['seekers']))
        if (_seeker(s) case final seeker?) seeker,
    ],
    mentors: [
      for (final m in jsonObjects(j['mentors']))
        if (_mentor(m) case final mentor?) mentor,
    ],
    board: j['board'] is List
        ? [
            for (final r in jsonObjects(j['board']))
              if (_row(r) case final row?) row,
          ]
        : null,
  );
}
