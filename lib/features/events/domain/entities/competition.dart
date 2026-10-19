/// A registered guest's side of an event's competition
/// (`GET /events/{id}/competition/me`, the server's `MyState`): the tracks,
/// their team or the open ones, what to hand in, the mentors' office hours,
/// and the board once the organisers make it public.
library;

class CompetitionTrack {
  final int id;
  final String name;
  final String? description;
  final String? sponsor;
  final String? prize;

  /// How many teams are on it.
  final int teams;

  const CompetitionTrack({
    required this.id,
    required this.name,
    this.description,
    this.sponsor,
    this.prize,
    this.teams = 0,
  });

  /// "Sponsored by Acme · ₹50,000 · 4 teams".
  String get line => [
        if (sponsor != null) 'Sponsored by $sponsor',
        if (prize != null) prize!,
        '$teams ${teams == 1 ? 'team' : 'teams'}',
      ].join(' · ');
}

/// One link a team hands in.
class CompetitionRequirement {
  final String key;
  final String label;
  final bool required;

  const CompetitionRequirement({
    required this.key,
    required this.label,
    this.required = true,
  });
}

class CompetitionMember {
  final String registrationId;
  final String name;

  const CompetitionMember({required this.registrationId, required this.name});
}

enum SubmissionStatus { nothing, inProgress, complete }

enum TeamStage { entered, shortlisted, finalist }

class CompetitionSubmission {
  final Map<String, String> fields;
  final SubmissionStatus status;

  /// The keys of required links still missing.
  final List<String> missing;
  final DateTime? updatedAt;

  const CompetitionSubmission({
    this.fields = const {},
    this.status = SubmissionStatus.nothing,
    this.missing = const [],
    this.updatedAt,
  });
}

class CompetitionTeam {
  final int id;
  final String name;
  final int? trackId;
  final String? track;
  final TeamStage stage;
  final List<CompetitionMember> members;
  final int openSpots;
  final CompetitionSubmission submission;

  const CompetitionTeam({
    required this.id,
    required this.name,
    this.trackId,
    this.track,
    this.stage = TeamStage.entered,
    this.members = const [],
    this.openSpots = 0,
    this.submission = const CompetitionSubmission(),
  });
}

/// A team with room for more.
class OpenTeam {
  final int id;
  final String name;
  final String? track;
  final int members;
  final int openSpots;

  const OpenTeam({
    required this.id,
    required this.name,
    this.track,
    this.members = 0,
    this.openSpots = 0,
  });
}

/// Someone looking for a team, and what they bring.
class TeamSeeker {
  final String registrationId;
  final String name;
  final List<String> skills;
  final String? note;

  const TeamSeeker({
    required this.registrationId,
    required this.name,
    this.skills = const [],
    this.note,
  });
}

class MentorSlot {
  final int id;
  final DateTime startsAt;
  final int minutes;

  /// The team that booked it; null while it is free.
  final int? teamId;
  final String? team;

  const MentorSlot({
    required this.id,
    required this.startsAt,
    this.minutes = 0,
    this.teamId,
    this.team,
  });
}

class Mentor {
  final int id;
  final String name;
  final String? topic;
  final List<MentorSlot> slots;

  const Mentor({
    required this.id,
    required this.name,
    this.topic,
    this.slots = const [],
  });
}

class BoardRow {
  final int? rank;
  final int teamId;
  final String name;
  final String? track;
  final double? score;

  const BoardRow({
    this.rank,
    required this.teamId,
    required this.name,
    this.track,
    this.score,
  });
}

class MyCompetition {
  final int eventId;
  final bool enabled;
  final String registrationId;

  /// The person's name, as registered.
  final String name;
  final int teamMin;
  final int teamMax;
  final bool teamsLocked;
  final List<CompetitionTrack> tracks;
  final List<CompetitionRequirement> requirements;
  final bool submissionsOpen;
  final DateTime? submissionsCloseAt;

  /// Their team; null while they have none.
  final CompetitionTeam? team;
  final List<OpenTeam> openTeams;

  /// Their own "looking for a team" entry, when they made one.
  final TeamSeeker? seeking;

  /// Everyone else looking.
  final List<TeamSeeker> seekers;
  final List<Mentor> mentors;

  /// The leaderboard, once the organisers make it public.
  final List<BoardRow>? board;

  const MyCompetition({
    required this.eventId,
    this.enabled = true,
    this.registrationId = '',
    this.name = '',
    this.teamMin = 1,
    this.teamMax = 1,
    this.teamsLocked = false,
    this.tracks = const [],
    this.requirements = const [],
    this.submissionsOpen = false,
    this.submissionsCloseAt,
    this.team,
    this.openTeams = const [],
    this.seeking,
    this.seekers = const [],
    this.mentors = const [],
    this.board,
  });

  /// "Teams are 2 to 4 people." / "Teams are 3 people."
  String get teamSizeLine => teamMin == teamMax
      ? 'Teams are $teamMax ${teamMax == 1 ? 'person' : 'people'}.'
      : 'Teams are $teamMin to $teamMax people.';

  /// A requirement's label by its key; the key when it is not one.
  String requirementLabel(String key) {
    for (final r in requirements) {
      if (r.key == key) return r.label;
    }
    return key;
  }
}
