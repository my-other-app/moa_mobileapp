/// The door console's words, as the server says them
/// (`moa_backend app/api/checkins/schemas.py`, `merch/schemas.py`,
/// `store/schemas.py`). The club dashboard's door console reads the same
/// (moa_web `apps/clubs/src/features/gate`). Each is read field by field:
/// one odd value must not lose the answer at the door.
library;

import 'package:finnet/core/utils/json_read.dart';

/// What this person may do at the door: from the club (everything), or the
/// switches the club set on them as a volunteer.
class GatePermissions {
  const GatePermissions({
    this.checkIn = false,
    this.walkup = false,
    this.merch = false,
    this.full = false,
  });

  factory GatePermissions.fromJson(Object? json) {
    final o = jsonObject(json) ?? const {};
    final full = jsonBool(o['full']) ?? false;
    return GatePermissions(
      checkIn: (jsonBool(o['check_in']) ?? false) || full,
      walkup: (jsonBool(o['walkup']) ?? false) || full,
      merch: (jsonBool(o['merch']) ?? false) || full,
      full: full,
    );
  }

  final bool checkIn;
  final bool walkup;
  final bool merch;

  /// The club or an admin: above the switches.
  final bool full;
}

/// `GET /events/{id}/gate/context`: everything the console needs on open.
class GateContext {
  const GateContext({
    required this.eventId,
    required this.eventName,
    this.orgName = '',
    this.doorOpen = true,
    this.permissions = const GatePermissions(),
    this.checkedIn,
    this.registered,
    this.doors = const [],
    this.expectedDoorId,
    this.hasMerch = false,
    this.hasStore = false,
  });

  factory GateContext.fromJson(Map<String, dynamic> json) {
    final event = jsonObject(json['event']) ?? const {};
    final counters = jsonObject(json['counters']) ?? const {};
    return GateContext(
      eventId: jsonInt(event['id']) ?? 0,
      eventName: jsonText(event['name']),
      orgName: jsonText(event['org_name']),
      doorOpen: jsonBool(event['door_open']) ?? true,
      permissions: GatePermissions.fromJson(json['permissions']),
      checkedIn: jsonInt(counters['checked_in']),
      registered: jsonInt(counters['registered']),
      doors: [
        for (final d in jsonObjects(json['doors']))
          (id: jsonText(d['id']), name: jsonText(d['name'])),
      ],
      expectedDoorId: jsonString(json['expected_door_id']),
      hasMerch: jsonBool(json['has_merch']) ?? false,
      hasStore: jsonBool(json['has_store']) ?? false,
    );
  }

  final int eventId;
  final String eventName;
  final String orgName;

  /// Whether the event's door admits anyone now (the organiser opens it).
  final bool doorOpen;
  final GatePermissions permissions;
  final int? checkedIn;
  final int? registered;
  final List<({String id, String name})> doors;

  /// The door this volunteer was put on, if any.
  final String? expectedDoorId;

  /// Whether there is anything to hand out: swag, or orders from the shelf.
  final bool hasMerch;
  final bool hasStore;

  /// The door's name every admission here is recorded at, or null for the
  /// event's default door.
  String? get doorName {
    final id = expectedDoorId;
    if (id == null) return null;
    for (final d in doors) {
      if (d.id == id && d.name.trim().isNotEmpty) return d.name;
    }
    return null;
  }

  /// Whether the Merch tab is offered: the switch, and something to hand
  /// out.
  bool get handsOut => permissions.merch && (hasMerch || hasStore);

  /// The same, with [checkedIn] guests in: one more after an admission,
  /// before the server's count is read again.
  GateContext withCheckedIn(int checkedIn) => GateContext(
        eventId: eventId,
        eventName: eventName,
        orgName: orgName,
        doorOpen: doorOpen,
        permissions: permissions,
        checkedIn: checkedIn,
        registered: registered,
        doors: doors,
        expectedDoorId: expectedDoorId,
        hasMerch: hasMerch,
        hasStore: hasStore,
      );
}

/// A guest, as a scan, a search or a check-in answers with them.
class GateAttendee {
  const GateAttendee({
    required this.id,
    required this.name,
    required this.ticketId,
    this.role = 'attendee',
    this.email,
    this.phone,
    this.isPaid = true,
    this.checkedInAt,
    this.admissionNo,
  });

  static GateAttendee? fromJson(Object? json) {
    final o = jsonObject(json);
    if (o == null) return null;
    final id = jsonText(o['id']);
    if (id.isEmpty) return null;
    return GateAttendee(
      id: id,
      name: jsonText(o['name']),
      ticketId: jsonText(o['ticket_id']),
      role: jsonText(o['role'], 'attendee'),
      email: jsonString(o['email']),
      phone: jsonString(o['phone']),
      isPaid: jsonBool(o['is_paid']) ?? true,
      checkedInAt: jsonDate(o['checked_in_at']),
      admissionNo: jsonString(o['admission_no']),
    );
  }

  /// The registration's id.
  final String id;
  final String name;
  final String ticketId;
  final String role;
  final String? email;
  final String? phone;
  final bool isPaid;
  final DateTime? checkedInAt;
  final String? admissionNo;

  bool get checkedIn => checkedInAt != null;
}

/// The seven answers to a scan, all 200.
enum ScanOutcome {
  checkedIn('CHECKED_IN'),
  alreadyCheckedIn('ALREADY_CHECKED_IN'),
  wrongEvent('WRONG_EVENT'),
  revoked('REVOKED'),
  unpaid('UNPAID'),
  invalid('INVALID'),
  eventNotOpen('EVENT_NOT_OPEN');

  const ScanOutcome(this.value);
  final String value;

  static ScanOutcome parse(Object? value) =>
      ScanOutcome.values.firstWhere((o) => o.value == '$value',
          orElse: () => ScanOutcome.invalid);
}

/// The hint on an INVALID scan of an admission number (the number printed
/// under the QR): not a ticket, so nobody was let in, but [GateScanResult
/// .attendee] is who holds it, for the volunteer to check in by hand.
const admissionNumberHint = 'ADMISSION_NUMBER';

/// `POST /gate/scan` (and each answer of `/gate/scan-batch`,
/// `/gate/check-in/{id}`).
class GateScanResult {
  const GateScanResult({
    required this.outcome,
    this.attendee,
    this.checkedInAt,
    this.checkedInByName,
    this.checkedInAtDoor,
    this.otherEventName,
    this.revokedAt,
    this.replayed = false,
    this.hint,
    this.error,
  });

  factory GateScanResult.fromJson(Map<String, dynamic> json) {
    final by = jsonObject(json['checked_in_by']);
    final other = jsonObject(json['other_event']);
    return GateScanResult(
      outcome: ScanOutcome.parse(json['outcome']),
      attendee: GateAttendee.fromJson(json['attendee']),
      checkedInAt: jsonDate(json['checked_in_at']),
      checkedInByName: by == null ? null : jsonString(by['name']),
      checkedInAtDoor: by == null ? null : jsonString(by['door']),
      otherEventName: other == null ? null : jsonString(other['name']),
      revokedAt: jsonDate(json['revoked_at']),
      replayed: jsonBool(json['replayed']) ?? false,
      hint: jsonString(json['hint']),
      error: jsonString(json['error']),
    );
  }

  final ScanOutcome outcome;
  final GateAttendee? attendee;
  final DateTime? checkedInAt;
  final String? checkedInByName;
  final String? checkedInAtDoor;
  final String? otherEventName;
  final DateTime? revokedAt;

  /// This very scan was admitted before (a retry): still an admission.
  final bool replayed;
  final String? hint;

  /// A scan of the offline queue the server could not take at all.
  final String? error;

  bool get admitted => outcome == ScanOutcome.checkedIn;

  /// An admission number, not a ticket: who holds it, to check in by hand.
  bool get needsHandCheckIn =>
      outcome == ScanOutcome.invalid &&
      hint == admissionNumberHint &&
      attendee != null;
}

/// A scan kept on the phone while it could not reach the server, replayed
/// through `/gate/scan-batch` when it can. [clientRef] is the scan's own:
/// the server admits a guest once however many times it is sent.
class QueuedScan {
  const QueuedScan({
    required this.eventId,
    required this.code,
    required this.clientRef,
    required this.scannedAt,
    this.door,
  });

  static QueuedScan? fromJson(Object? json) {
    final o = jsonObject(json);
    if (o == null) return null;
    final code = jsonText(o['code']);
    final ref = jsonText(o['client_ref']);
    final at = jsonDate(o['scanned_at']);
    if (code.isEmpty || ref.isEmpty || at == null) return null;
    return QueuedScan(
      eventId: jsonInt(o['event_id']) ?? 0,
      code: code,
      clientRef: ref,
      scannedAt: at,
      door: jsonString(o['door']),
    );
  }

  final int eventId;
  final String code;
  final String clientRef;
  final DateTime scannedAt;
  final String? door;

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        ...toBody(),
      };

  /// What `/gate/scan` and `/gate/scan-batch` take (`ScanBody`).
  Map<String, dynamic> toBody() => {
        'code': code,
        'client_ref': clientRef,
        'scanned_at': scannedAt.toUtc().toIso8601String(),
        if (door != null) 'door': door,
      };
}

/// One answer of `/gate/scan-batch`, with the scan as it was saved.
class ReplayedScan {
  const ReplayedScan(
      {required this.clientRef, required this.result, this.scan});

  final String clientRef;
  final GateScanResult result;
  final QueuedScan? scan;
}

/// What one guest is owed of one item (`MerchStatusRow`).
class MerchOwed {
  const MerchOwed({
    required this.itemId,
    required this.name,
    required this.status,
    this.photoUrl,
    this.variantLabel,
    this.remaining,
    this.onFile,
    this.choices = const [],
  });

  static MerchOwed? fromJson(Object? json) {
    final o = jsonObject(json);
    if (o == null) return null;
    final id = jsonText(o['item_id']);
    if (id.isEmpty) return null;
    return MerchOwed(
      itemId: id,
      name: jsonText(o['name']),
      status: jsonText(o['status']),
      photoUrl: jsonString(o['photo_url']),
      variantLabel: jsonString(o['variant_label']),
      remaining: jsonInt(o['remaining']),
      onFile: jsonString(o['on_file']),
      choices: [
        for (final c in jsonObjects(o['choices']))
          (
            label: jsonText(c['label']),
            remaining: jsonInt(c['remaining']) ?? 0
          ),
      ],
    );
  }

  final String itemId;
  final String name;

  /// COLLECTABLE, ALREADY_COLLECTED, NOT_ELIGIBLE, NO_VARIANT_VALUE,
  /// NO_MATCHING_VARIANT or OUT_OF_STOCK.
  final String status;
  final String? photoUrl;
  final String? variantLabel;
  final int? remaining;
  final String? onFile;

  /// The sizes to pick from, when their record has none that fits.
  final List<({String label, int remaining})> choices;

  bool get collectable => status == 'COLLECTABLE';
  bool get collected => status == 'ALREADY_COLLECTED';

  /// No size on file, or not one of the options: pick one, then hand over.
  bool get needsSize =>
      status == 'NO_VARIANT_VALUE' || status == 'NO_MATCHING_VARIANT';
}

/// `GET /gate/merch/{registration_id}`: what this guest is owed.
class AttendeeMerch {
  const AttendeeMerch({required this.items});

  factory AttendeeMerch.fromJson(Map<String, dynamic> json) => AttendeeMerch(
        items: jsonObjects(json['items'])
            .map(MerchOwed.fromJson)
            .whereType<MerchOwed>()
            .toList(),
      );

  final List<MerchOwed> items;
}

/// `POST /gate/merch/{item_id}/collect`.
class CollectResult {
  const CollectResult({
    required this.status,
    required this.collected,
    this.variantLabel,
  });

  factory CollectResult.fromJson(Map<String, dynamic> json) => CollectResult(
        status: jsonText(json['status']),
        collected: jsonBool(json['collected']) ?? false,
        variantLabel: jsonString(json['variant_label']),
      );

  final String status;
  final bool collected;
  final String? variantLabel;
}

/// One order from the event's shelf (`OrderOut`).
class StoreOrder {
  const StoreOrder({
    required this.id,
    required this.status,
    required this.summary,
    this.total = 0,
    this.lines = const [],
    this.paidAt,
    this.handedOverAt,
  });

  static StoreOrder? fromJson(Object? json) {
    final o = jsonObject(json);
    if (o == null) return null;
    final id = jsonText(o['id']);
    if (id.isEmpty) return null;
    return StoreOrder(
      id: id,
      status: jsonText(o['status']),
      summary: jsonText(o['summary']),
      total: jsonDouble(o['total']) ?? 0,
      lines: [
        for (final l in jsonObjects(o['lines']))
          (
            name: jsonText(l['item_name']),
            variant: jsonString(l['variant_label']),
            qty: jsonInt(l['qty']) ?? 1,
          ),
      ],
      paidAt: jsonString(o['paid_at']),
      handedOverAt: jsonString(o['handed_over_at']),
    );
  }

  final String id;
  final String status;
  final String summary;
  final double total;
  final List<({String name, String? variant, int qty})> lines;
  final String? paidAt;
  final String? handedOverAt;

  bool get handedOver => handedOverAt != null && handedOverAt!.isNotEmpty;

  /// Not handed over yet. The door is only ever shown paid orders.
  bool get toHandOver => !handedOver;
}
