import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/repositories/competition_repository.dart';
import 'package:finnet/features/events/domain/entities/competition.dart';
import 'package:finnet/features/events/presentation/providers/competition_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_sign_in.dart';

/// "Your team": a registered guest's side of an event's competition, as the
/// website's `/events/{slug}/compete` has it. Pick a track and make a team
/// or join an open one; say you are looking for teammates; hand in the
/// links before the close; book a mentor's slot; and see the board once
/// the organisers make it public.
class CompetitionPage extends ConsumerStatefulWidget {
  /// The event's slug or id.
  final String eventRef;
  final String? eventName;

  /// How often the screen asks the server again while it is open (teams
  /// fill up, slots get booked): the website's twenty seconds, plus a bit.
  final Duration refreshEvery;

  const CompetitionPage({
    super.key,
    required this.eventRef,
    this.eventName,
    this.refreshEvery = const Duration(seconds: 30),
  });

  @override
  ConsumerState<CompetitionPage> createState() => _CompetitionPageState();
}

class _CompetitionPageState extends ConsumerState<CompetitionPage>
    with WidgetsBindingObserver {
  Timer? _timer;

  CompetitionNotifier get _notifier =>
      ref.read(competitionProvider(widget.eventRef).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.refreshEvery, (_) {
      if (mounted && ref.read(isAuthenticatedProvider)) {
        _notifier.load(quietly: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(isAuthenticatedProvider)) {
      _notifier.load(quietly: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isAuthenticatedProvider);
    // Signed out, nothing is asked for: the competition is the person's own.
    if (signedIn) {
      ref.listen<CompetitionState>(competitionProvider(widget.eventRef),
          (_, next) {
        final notice = next.notice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice)));
          _notifier.noticeShown();
        }
      });
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Your team',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
      ),
      body: signedIn ? _body() : _signInFirst(),
    );
  }

  Widget _signInFirst() => _Problem(
        icon: Icons.lock_outline,
        message: 'Sign in to see your team.',
        action: 'Sign in',
        onAction: () => ensureSignedInFor(context, ref,
            reason: 'Sign in to see your team and submission.'),
      );

  Widget _body() {
    final state = ref.watch(competitionProvider(widget.eventRef));
    final data = state.data;
    if (data == null) {
      if (state.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      final failure = state.failure;
      return _Problem(
        icon: switch (failure?.problem) {
          CompetitionProblem.none => Icons.emoji_events_outlined,
          CompetitionProblem.notRegistered =>
            Icons.confirmation_number_outlined,
          _ => Icons.cloud_off_outlined,
        },
        message: failure?.message ?? "We couldn't load your team.",
        action: failure?.problem == CompetitionProblem.signIn
            ? 'Sign in'
            : failure?.problem == CompetitionProblem.other
                ? 'Try again'
                : null,
        onAction: failure?.problem == CompetitionProblem.signIn
            ? () => ensureSignedInFor(context, ref,
                reason: 'Sign in to see your team and submission.')
            : () => _notifier.load(),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _notifier.load(quietly: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.eventName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(widget.eventName!,
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
            ),
          if (state.busy) const LinearProgressIndicator(minHeight: 2),
          if (data.tracks.isNotEmpty) _Tracks(tracks: data.tracks),
          if (data.team != null)
            ..._myTeam(data, data.team!, state.busy)
          else
            _TeamUp(
              me: data,
              busy: state.busy,
              onMake: (name, trackId) =>
                  _notifier.makeTeam(name, trackId: trackId),
              onJoin: (team) => _notifier.joinTeam(team.id),
              onSeeking: (on, skills) =>
                  _notifier.seeking(on: on, skills: skills),
            ),
          if (data.board != null && data.board!.isNotEmpty)
            _Board(rows: data.board!, mine: data.team?.id),
        ],
      ),
    );
  }

  List<Widget> _myTeam(MyCompetition me, CompetitionTeam team, bool busy) => [
        _Card(
          key: const ValueKey('competition-my-team'),
          title: team.name,
          subtitle: [
            team.track ?? 'No track yet',
            '${team.members.length} of ${me.teamMax}',
            if (team.stage == TeamStage.finalist) 'Finalist',
            if (team.stage == TeamStage.shortlisted) 'Shortlisted',
          ].join(' · '),
          children: [
            for (final m in team.members)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(m.name),
              ),
            if (me.tracks.isNotEmpty)
              DropdownButtonFormField<int?>(
                // Keyed by the track, so the server's answer shows.
                key: ValueKey('competition-track-${team.trackId}'),
                initialValue: team.trackId,
                decoration: const InputDecoration(labelText: 'Track'),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('No track')),
                  for (final t in me.tracks)
                    DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
                ],
                onChanged: busy || me.teamsLocked
                    ? null
                    : (id) => _notifier.setTrack(id),
              ),
            if (team.openSpots > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${team.openSpots} more can join — tell them to open '
                  'this screen and pick your team.',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                ),
              ),
            if (me.teamsLocked)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Teams are locked. Ask the organisers to move you.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF92400E))),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: busy ? null : _confirmLeave,
                  child: const Text('Leave the team'),
                ),
              ),
          ],
        ),
        _Submission(
          me: me,
          team: team,
          busy: busy,
          onSave: (fields) => _notifier.submit(fields),
        ),
        if (me.mentors.isNotEmpty)
          _OfficeHours(
            mentors: me.mentors,
            teamId: team.id,
            busy: busy,
            onTap: (slot, ours) => _notifier.toggleSlot(slot, ours: ours),
          ),
      ];

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Leave your team?'),
        content: const Text(
            'Your teammates keep the team. A team left empty is dissolved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Stay')),
          FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true) await _notifier.leaveTeam();
  }
}

// ------------------------------------------------------------------ parts

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _Card(
      {super.key, required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Tracks extends StatelessWidget {
  final List<CompetitionTrack> tracks;

  const _Tracks({required this.tracks});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Tracks',
      subtitle: 'Pick one for your team.',
      children: [
        for (final t in tracks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (t.description != null)
                  Text(t.description!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF4B5563))),
                Text(t.line,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
      ],
    );
  }
}

class _TeamUp extends StatefulWidget {
  final MyCompetition me;
  final bool busy;
  final Future<bool> Function(String name, int? trackId) onMake;
  final ValueChanged<OpenTeam> onJoin;
  final void Function(bool on, List<String> skills) onSeeking;

  const _TeamUp({
    required this.me,
    required this.busy,
    required this.onMake,
    required this.onJoin,
    required this.onSeeking,
  });

  @override
  State<_TeamUp> createState() => _TeamUpState();
}

class _TeamUpState extends State<_TeamUp> {
  final _name = TextEditingController();
  late final _skills =
      TextEditingController(text: widget.me.seeking?.skills.join(', ') ?? '');
  int? _track;

  @override
  void dispose() {
    _name.dispose();
    _skills.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final locked = me.teamsLocked;
    final off = widget.busy || locked;
    return _Card(
      key: const ValueKey('competition-team-up'),
      title: 'Find your team',
      subtitle: '${me.teamSizeLine} Make one, or join one with a spot.',
      children: [
        if (locked)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Teams are locked. Ask the organisers to move you.',
                style: TextStyle(fontSize: 13, color: Color(0xFF92400E))),
          ),
        TextField(
          key: const ValueKey('competition-team-name'),
          controller: _name,
          enabled: !off,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Team name'),
          onChanged: (_) => setState(() {}),
        ),
        if (me.tracks.isNotEmpty)
          DropdownButtonFormField<int?>(
            initialValue: _track,
            decoration: const InputDecoration(labelText: 'Track'),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Pick a track later')),
              for (final t in me.tracks)
                DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
            ],
            onChanged: off ? null : (id) => setState(() => _track = id),
          ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: off || _name.text.trim().isEmpty
              ? null
              : () async {
                  if (await widget.onMake(_name.text.trim(), _track)) {
                    _name.clear();
                  }
                },
          child: const Text('Make a team'),
        ),
        const SizedBox(height: 16),
        const Text('Open teams',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        if (me.openTeams.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('No open teams yet.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          )
        else
          for (final t in me.openTeams)
            ListTile(
              key: ValueKey('open-team-${t.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(t.name),
              subtitle: Text(
                  '${t.track ?? 'No track'} · ${t.members} of ${me.teamMax}'),
              trailing: OutlinedButton(
                onPressed: off ? null : () => widget.onJoin(t),
                child: const Text('Join'),
              ),
            ),
        const Divider(height: 24),
        SwitchListTile(
          key: const ValueKey('competition-seeking'),
          contentPadding: EdgeInsets.zero,
          value: me.seeking != null,
          onChanged: off
              ? null
              : (on) => widget.onSeeking(on, skillsFrom(_skills.text)),
          title: const Text('Find me teammates'),
          subtitle: const Text('List me as looking for a team'),
        ),
        if (me.seeking != null)
          TextField(
            controller: _skills,
            enabled: !off,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: 'What you bring',
              hintText: 'ML, PCB, pitching',
              suffixIcon: IconButton(
                tooltip: 'Save',
                icon: const Icon(Icons.check),
                onPressed: off
                    ? null
                    : () => widget.onSeeking(true, skillsFrom(_skills.text)),
              ),
            ),
          ),
        if (me.seekers.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Also looking',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          for (final s in me.seekers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.name),
              subtitle: Text(s.skills.isEmpty ? '—' : s.skills.join(' · ')),
            ),
          const Text('Make a team and they can join it from here.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
        ],
      ],
    );
  }
}

class _Submission extends StatefulWidget {
  final MyCompetition me;
  final CompetitionTeam team;
  final bool busy;
  final Future<bool> Function(Map<String, String> fields) onSave;

  const _Submission({
    required this.me,
    required this.team,
    required this.busy,
    required this.onSave,
  });

  @override
  State<_Submission> createState() => _SubmissionState();
}

class _SubmissionState extends State<_Submission> {
  final Map<String, TextEditingController> _fields = {};

  TextEditingController _field(String key) => _fields.putIfAbsent(
      key,
      () => TextEditingController(
          text: widget.team.submission.fields[key] ?? ''));

  @override
  void didUpdateWidget(_Submission old) {
    super.didUpdateWidget(old);
    // What the server now has, unless it is being typed over.
    for (final e in widget.team.submission.fields.entries) {
      final c = _fields[e.key];
      if (c != null && old.team.submission.fields[e.key] == c.text) {
        c.text = e.value;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final submission = widget.team.submission;
    final open = me.submissionsOpen;
    final close = me.submissionsCloseAt;
    final status = switch (submission.status) {
      SubmissionStatus.complete => 'Everything required is in.',
      SubmissionStatus.inProgress =>
        'Still missing: ${submission.missing.map(me.requirementLabel).join(', ')}',
      SubmissionStatus.nothing => 'Nothing handed in yet.',
    };
    return _Card(
      key: const ValueKey('competition-submission'),
      title: 'Your submission',
      subtitle: open
          ? (close != null
              ? 'Closes ${DateFormat("d MMM, h:mm a").format(close)}.'
              : 'Open until the organisers close it.')
          : 'Submissions are closed.',
      children: [
        Text(status,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: submission.status == SubmissionStatus.complete
                  ? const Color(0xFF047857)
                  : const Color(0xFF92400E),
            )),
        if (me.requirements.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('The organisers have not asked for anything yet.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ),
        for (final r in me.requirements)
          TextField(
            key: ValueKey('submission-${r.key}'),
            controller: _field(r.key),
            enabled: open && !widget.busy,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '${r.label} (${r.required ? 'required' : 'optional'})',
              hintText: 'https://…',
            ),
          ),
        if (me.requirements.isNotEmpty) ...[
          const SizedBox(height: 10),
          FilledButton(
            onPressed: !open || widget.busy
                ? null
                : () => widget.onSave({
                      for (final r in me.requirements)
                        r.key: _field(r.key).text.trim(),
                    }),
            child: const Text('Save submission'),
          ),
        ],
      ],
    );
  }
}

class _OfficeHours extends StatelessWidget {
  final List<Mentor> mentors;
  final int teamId;
  final bool busy;
  final void Function(MentorSlot slot, bool ours) onTap;

  const _OfficeHours({
    required this.mentors,
    required this.teamId,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('EEE h:mm a');
    return _Card(
      key: const ValueKey('competition-office-hours'),
      title: 'Mentor office hours',
      subtitle: 'Tap a free slot to book it for your team; tap yours to free '
          'it. One slot per mentor.',
      children: [
        for (final m in mentors)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (m.topic != null)
                  Text(m.topic!,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                if (m.slots.isEmpty)
                  const Text('No slots opened yet.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in m.slots) _slot(s, time),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _slot(MentorSlot s, DateFormat time) {
    final ours = s.teamId == teamId;
    final taken = s.teamId != null && !ours;
    return ChoiceChip(
      key: ValueKey('slot-${s.id}'),
      selected: ours,
      label: Text(
          '${time.format(s.startsAt)} · ${ours ? 'Yours' : taken ? 'Taken' : 'Free'}'),
      onSelected: busy || taken ? null : (_) => onTap(s, ours),
    );
  }
}

class _Board extends StatelessWidget {
  final List<BoardRow> rows;
  final int? mine;

  const _Board({required this.rows, this.mine});

  @override
  Widget build(BuildContext context) {
    return _Card(
      key: const ValueKey('competition-board'),
      title: 'Leaderboard',
      children: [
        for (final r in rows)
          Container(
            color: r.teamId == mine ? const Color(0xFFF5F3FF) : null,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Text(r.rank?.toString() ?? '–',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              title: Text(r.name),
              subtitle: r.track == null ? null : Text(r.track!),
              trailing: Text(
                  r.score == null ? '—' : r.score!.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const _Problem({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            if (action != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
