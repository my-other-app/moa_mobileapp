/// What the door console says, in the club dashboard console's words
/// (moa_web `gate/lib/outcome-copy.ts`, `gate/lib/replay.ts`): plain, and
/// it says what to do next.
library;

import 'package:intl/intl.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';

/// How an answer reads at a glance: let in, look again, turned away, or
/// saved on the phone unchecked (no signal: the volunteer checks the person
/// themselves).
enum GateTone { admit, caution, refuse, unverified }

/// The card a scan answers with.
class OutcomeCard {
  const OutcomeCard({
    required this.tone,
    required this.tag,
    required this.title,
    this.sub,
    this.attribution,
    this.note,
  });

  final GateTone tone;
  final String tag;
  final String title;
  final String? sub;
  final String? attribution;
  final String? note;
}

const _roles = {
  'attendee': 'Attendee',
  'speaker': 'Speaker',
  'staff': 'Staff',
  'volunteer': 'Volunteer',
  'guest': 'Guest',
};

String _role(String role) => _roles[role] ?? role;

String _ago(DateTime at, DateTime now) {
  final m = now.difference(at).inMinutes;
  if (m < 1) return 'moments ago';
  if (m == 1) return '1 minute ago';
  if (m < 60) return '$m minutes ago';
  return '${m ~/ 60}h ${m % 60}m ago';
}

String _day(DateTime at) => DateFormat('d MMM').format(at.toLocal());

String _clock(DateTime at) => DateFormat('HH:mm').format(at.toLocal());

/// The card for a scan's answer at [door] ("Main door", or the event's).
OutcomeCard outcomeCard(GateScanResult r,
    {String door = 'Door', DateTime? now}) {
  final a = r.attendee;
  final who = a == null || a.name.trim().isEmpty ? 'This guest' : a.name;
  final sub = a == null
      ? null
      : [a.ticketId, _role(a.role).toUpperCase(), door.toUpperCase()]
          .where((s) => s.isNotEmpty)
          .join(' · ');
  switch (r.outcome) {
    case ScanOutcome.checkedIn:
      return OutcomeCard(
        tone: GateTone.admit,
        tag: r.replayed ? 'Already recorded' : 'Welcome in',
        title: '$who — welcome in.',
        sub: sub,
      );
    case ScanOutcome.alreadyCheckedIn:
      final by = r.checkedInByName;
      final at = r.checkedInAt;
      return OutcomeCard(
        tone: GateTone.caution,
        tag: 'Already in',
        title: '$who already checked in.',
        sub: sub,
        attribution: by != null && at != null
            ? '$by at ${r.checkedInAtDoor ?? 'a door'}, '
                '${_ago(at, now ?? DateTime.now())}.'
            : null,
        note: 'A second scan is normal — nothing went wrong. Wave them '
            'through.',
      );
    case ScanOutcome.wrongEvent:
      return OutcomeCard(
        tone: GateTone.refuse,
        tag: 'Wrong event',
        title: 'That ticket is for another event.',
        sub: r.otherEventName == null
            ? 'VALID TICKET · ANOTHER EVENT'
            : 'VALID TICKET · ${r.otherEventName!.toUpperCase()}',
        note: 'Point them at the right event rather than turning them away.',
      );
    case ScanOutcome.revoked:
      return OutcomeCard(
        tone: GateTone.refuse,
        tag: 'Revoked',
        title: 'This ticket was revoked.',
        sub: a == null
            ? null
            : '${a.ticketId}${r.revokedAt == null ? '' : ' · REVOKED ${_day(r.revokedAt!).toUpperCase()}'}',
        note: 'The organiser cancelled it, usually because it was lost or '
            'passed on. A replacement may have been issued in their name.',
      );
    case ScanOutcome.unpaid:
      return OutcomeCard(
        tone: GateTone.refuse,
        tag: 'Not paid',
        title: '$who has not paid for this ticket.',
        sub: sub,
        note: 'Take the payment at the desk and record it on their '
            'registration, then scan again.',
      );
    case ScanOutcome.eventNotOpen:
      return const OutcomeCard(
        tone: GateTone.caution,
        tag: 'Door shut',
        title: "This event's door is closed.",
        note: 'The organiser opens it from the club dashboard. Nothing is '
            'wrong with the ticket.',
      );
    case ScanOutcome.invalid:
      if (r.needsHandCheckIn) {
        return OutcomeCard(
          tone: GateTone.caution,
          tag: 'Admission number',
          title:
              '${a!.name}, admission no. ${a.admissionNo ?? 'on their ticket'}: '
              'check in by hand?',
          sub: sub == null ? 'NOT A TICKET CODE' : 'NOT A TICKET CODE · $sub',
          note: 'An admission number does not let anyone in by itself. If '
              'this is them, check them in by hand; otherwise ask for the '
              'ticket code under the QR.',
        );
      }
      return const OutcomeCard(
        tone: GateTone.refuse,
        tag: 'Not recognised',
        title: 'Not a recognised ticket code.',
        sub: 'NO TICKET MATCHES THIS CODE',
        note: 'Type the ticket code printed under the QR (MOA-XXXXX-XXXXX), '
            'or try the scan again.',
      );
  }
}

/// A ticket code saved on the phone with no signal: nothing has checked it
/// yet, so the volunteer looks at the person before letting them in. The
/// server decides when the phone is back online.
const unverifiedCard = OutcomeCard(
  tone: GateTone.unverified,
  tag: 'Unverified',
  title: "No signal — this ticket can't be checked right now.",
  sub: 'NOT CHECKED · SAVED ON THIS PHONE · WILL SYNC',
  note: 'Check their name or ID before letting them in. The scan is sent '
      'when the signal is back; anything the server refuses is listed here '
      'by name.',
);

/// No signal, and what was scanned or typed is not a ticket code: refused
/// on the phone, as the server would, and not saved.
const offlineNotATicketCard = OutcomeCard(
  tone: GateTone.refuse,
  tag: 'Not recognised',
  title: "That isn't a ticket code.",
  sub: 'NOT A TICKET CODE · NOT SAVED',
  note: 'Type the ticket code printed under the QR (MOA-XXXXX-XXXXX), '
      'or try the scan again.',
);

/// Someone showed their personal QR (Feature 4's `/p/` link) instead of
/// their ticket: refused on the phone, without asking the server.
const personalCodeCard = OutcomeCard(
  tone: GateTone.refuse,
  tag: 'Personal QR',
  title: "That's a personal QR, not a ticket.",
  sub: 'NOT A TICKET · NOT CHECKED IN',
  note: 'Ask for the ticket in their app or email, or find them by name '
      'under Guests.',
);

/// No signal, and an admission number: it never lets anyone in, and
/// finding whose it is needs the server.
const offlineAdmissionNumberCard = OutcomeCard(
  tone: GateTone.refuse,
  tag: 'Admission number',
  title: "That's an admission number, not a ticket code.",
  sub: 'NOT A TICKET CODE · NOT SAVED',
  note: 'An admission number does not let anyone in by itself, and finding '
      'whose it is needs the signal. Ask for the ticket code under the QR '
      '(MOA-XXXXX-XXXXX).',
);

/// No signal, and this phone has had the ticket already: saved here at
/// [at] and not yet sent, or seen through this phone to be checked in at
/// [at] ([checkedIn]). Refused, and not saved again.
OutcomeCard offlineRepeatCard(DateTime at, {bool checkedIn = false}) =>
    OutcomeCard(
      tone: GateTone.refuse,
      tag: checkedIn ? 'Already in' : 'Already scanned',
      title: checkedIn
          ? 'Already checked in at ${_clock(at)}.'
          : 'Already scanned on this phone at ${_clock(at)}.',
      sub: 'NO SIGNAL · NOT SAVED AGAIN',
      note: 'A ticket lets one person in. Unless this is the person who came '
          "through at ${_clock(at)}, don't let them in on it.",
    );

/// A saved scan the server did not admit: who or which ticket, and why.
class ReplayProblem {
  const ReplayProblem({
    required this.clientRef,
    required this.ticket,
    required this.tag,
    required this.reason,
    required this.tone,
    this.name,
    this.door,
    this.scannedAt,
  });

  final String clientRef;

  /// The guest's name, when the server knows whose the ticket is.
  final String? name;

  /// The ticket as printed, else the code as it was scanned.
  final String ticket;
  final String tag;
  final String reason;
  final GateTone tone;
  final String? door;
  final DateTime? scannedAt;
}

/// What became of the scans saved while the phone had no signal. The guests
/// behind them may have been let in at the time, so the ones the server did
/// not admit are listed by name, each with why, until the volunteer has read
/// them; the admissions are only counted.
class ReplayReport {
  const ReplayReport({
    this.synced = 0,
    this.admitted = 0,
    this.problems = const [],
  });

  /// Saved scans the server has answered, since the report was last read.
  final int synced;

  /// Of those, the ones it admitted (or had admitted from this phone).
  final int admitted;
  final List<ReplayProblem> problems;
}

({String tag, String reason, GateTone tone}) _why(GateScanResult r) {
  switch (r.outcome) {
    case ScanOutcome.alreadyCheckedIn:
      final by = r.checkedInByName == null
          ? ''
          : ' by ${r.checkedInByName} at ${r.checkedInAtDoor ?? 'a door'}';
      return (
        tone: GateTone.caution,
        tag: 'Already used',
        reason: 'This ticket was already checked in$by. Check it was the '
            'same person.',
      );
    case ScanOutcome.wrongEvent:
      return (
        tone: GateTone.refuse,
        tag: 'Wrong event',
        reason: 'The ticket is for ${r.otherEventName ?? 'another event'}, '
            'not this one.',
      );
    case ScanOutcome.revoked:
      return (
        tone: GateTone.refuse,
        tag: 'Revoked',
        reason: 'The ticket was revoked'
            '${r.revokedAt == null ? '' : ' on ${_day(r.revokedAt!)}'}: '
            'cancelled or refunded.',
      );
    case ScanOutcome.unpaid:
      return (
        tone: GateTone.refuse,
        tag: 'Not paid',
        reason: 'The ticket has not been paid for. Take the payment at the '
            'desk.',
      );
    case ScanOutcome.eventNotOpen:
      return (
        tone: GateTone.caution,
        tag: 'Door shut',
        reason: 'The door was shut when this synced, so nobody was checked '
            'in. Scan it again once it is open.',
      );
    case ScanOutcome.invalid:
    case ScanOutcome.checkedIn:
      if (r.hint == admissionNumberHint) {
        return (
          tone: GateTone.caution,
          tag: 'Admission number',
          reason: 'An admission number, not a ticket: nobody was checked '
              'in. If it was them, check them in by hand under Find.',
        );
      }
      return (
        tone: GateTone.refuse,
        tag: 'Not found',
        reason: 'No ticket matches this code.',
      );
  }
}

/// The problem a replayed scan is, or null when the server admitted it.
ReplayProblem? replayProblem(ReplayedScan s) {
  final r = s.result;
  // Admitted now, or this very scan was admitted on an earlier try.
  if (r.admitted) return null;
  final why = _why(r);
  final name = r.attendee?.name.trim();
  final ticket = r.attendee?.ticketId.trim();
  return ReplayProblem(
    clientRef: s.clientRef,
    name: name == null || name.isEmpty ? null : name,
    ticket: ticket != null && ticket.isNotEmpty
        ? ticket
        : (s.scan?.code ?? s.clientRef),
    door: s.scan?.door,
    scannedAt: s.scan?.scannedAt,
    tag: why.tag,
    reason: why.reason,
    tone: why.tone,
  );
}

/// [report] (or none yet) with one more batch of answers in it.
ReplayReport withReplayed(ReplayReport? report, List<ReplayedScan> results) {
  final before = report ?? const ReplayReport();
  final problems =
      results.map(replayProblem).whereType<ReplayProblem>().toList();
  final known = {for (final p in before.problems) p.clientRef};
  return ReplayReport(
    synced: before.synced + results.length,
    admitted: before.admitted + results.length - problems.length,
    problems: [
      ...before.problems,
      ...problems.where((p) => !known.contains(p.clientRef)),
    ],
  );
}

/// What a guest's merch line says, by its status.
String merchStatusNote(String status, {String? size, String? onFile}) {
  switch (status) {
    case 'COLLECTABLE':
      return size == null ? 'Ready to hand over' : 'Size $size';
    case 'ALREADY_COLLECTED':
      return 'Already collected';
    case 'NOT_ELIGIBLE':
      return 'Not eligible for this item';
    case 'NO_VARIANT_VALUE':
      return 'No size on file — ask them, and tap it.';
    case 'NO_MATCHING_VARIANT':
      return "Their size${onFile == null ? '' : ' ($onFile)'} isn't one of "
          'the options — pick what they take.';
    case 'OUT_OF_STOCK':
      return 'Out of stock in their size';
  }
  return status;
}

/// [merchStatusNote] for one line of what a guest is owed.
String merchNote(MerchOwed m) =>
    merchStatusNote(m.status, size: m.variantLabel, onFile: m.onFile);
