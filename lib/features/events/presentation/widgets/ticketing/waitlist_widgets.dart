import 'package:flutter/material.dart';

import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/whatsapp_number.dart';
import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/events/domain/ticketing.dart';

const _ink = Color(0xFF2C333D);

/// Where the signed-in person stands on the event's waiting list: their
/// place in line, or the place held for them, and a way to leave.
class WaitlistPlacesCard extends StatelessWidget {
  const WaitlistPlacesCard({
    super.key,
    required this.places,
    this.onLeave,
    this.leaving = false,
  });

  final List<WaitlistEntry> places;
  final VoidCallback? onLeave;
  final bool leaving;

  static const cardKey = ValueKey('waitlist-places');
  static const leaveKey = ValueKey('waitlist-leave');

  @override
  Widget build(BuildContext context) {
    final offered = places.any((p) => p.isOffered);
    return Container(
      key: cardKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      decoration: BoxDecoration(
        color: offered ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                offered ? Icons.celebration_outlined : Icons.hourglass_top,
                size: 18,
                color: offered ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 6),
              Text(
                offered ? 'A place is yours to claim' : "You're on the waiting list",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          for (final place in places)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(place.summary,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ),
          if (onLeave != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: leaveKey,
                onPressed: leaving ? null : onLeave,
                style: TextButton.styleFrom(foregroundColor: _ink),
                child: Text(leaving ? 'Leaving…' : 'Leave the waiting list'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Asks before leaving: a place in line can't be taken back.
Future<bool> confirmLeaveWaitlist(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Leave the waiting list?'),
      content: const Text(
          "You'll lose your place in line. Joining again puts you at the back."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _ink),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return yes == true;
}

/// "Join the waiting list": who to tell, and for which ticket. Resolves to
/// the place in line, or null when closed without joining.
Future<WaitlistEntry?> showJoinWaitlistSheet(
  BuildContext context, {
  required Object event,
  required EventTicketing? ticketing,
  required TicketingApi api,
  String? name,
  String? email,
  String? phone,
  int? ticketTypeId,
}) {
  return showModalBottomSheet<WaitlistEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: JoinWaitlistForm(
        event: event,
        ticketing: ticketing,
        api: api,
        name: name,
        email: email,
        phone: phone,
        ticketTypeId: ticketTypeId,
        onJoined: (entry) => Navigator.of(context).pop(entry),
      ),
    ),
  );
}

/// The waiting list's form, in [showJoinWaitlistSheet].
class JoinWaitlistForm extends StatefulWidget {
  const JoinWaitlistForm({
    super.key,
    required this.event,
    required this.ticketing,
    required this.api,
    required this.onJoined,
    this.name,
    this.email,
    this.phone,
    this.ticketTypeId,
  });

  final Object event;
  final EventTicketing? ticketing;
  final TicketingApi api;
  final ValueChanged<WaitlistEntry> onJoined;
  final String? name;
  final String? email;
  final String? phone;
  final int? ticketTypeId;

  static const submitKey = ValueKey('waitlist-join-submit');
  static const errorKey = ValueKey('waitlist-join-error');

  @override
  State<JoinWaitlistForm> createState() => _JoinWaitlistFormState();
}

class _JoinWaitlistFormState extends State<JoinWaitlistForm> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _email = TextEditingController(text: widget.email ?? '');
  late final _phone = TextEditingController(text: widget.phone ?? '');
  bool _whatsapp = false;
  bool _sending = false;
  String? _problem;
  int? _type;

  /// The server said the club confirms each place here (409
  /// WAITLIST_OFF_ON_APPROVAL_EVENTS): there is no list to join, so no
  /// button to try again.
  bool _noList = false;

  /// The types whose list can be joined: those the server says, or -- an
  /// answer from before they sold out -- every sold-out one. None when the
  /// club confirms each place.
  List<TicketType> get _choices {
    final ticketing = widget.ticketing;
    if (ticketing == null || ticketing.requiresApproval) return const [];
    final open = ticketing.waitlistTypes;
    if (open.isNotEmpty) return open;
    return [
      for (final type in ticketing.types)
        if (type.status == TicketTypeStatus.soldOut) type,
    ];
  }

  @override
  void initState() {
    super.initState();
    final choices = _choices;
    final wanted = widget.ticketTypeId;
    if (wanted != null && choices.any((t) => t.id == wanted)) {
      _type = wanted;
    } else if (choices.length == 1) {
      _type = choices.single.id;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _needsType =>
      (widget.ticketing?.requiresChoice ?? false) && _choices.length > 1;

  Future<void> _join() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    String? problem;
    if (name.isEmpty) {
      problem = 'Enter your name.';
    } else if (email.isEmpty && phone.isEmpty) {
      problem = 'Add an email address or a phone number so we can tell you.';
    } else if (_needsType && _type == null) {
      problem = 'Choose which ticket to wait for.';
    } else if (_whatsapp && whatsappNumber(phone) == null) {
      problem = 'WhatsApp needs a mobile number. Or untick WhatsApp.';
    }
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    try {
      final entry = await widget.api.joinWaitlist(
        widget.event,
        ticketTypeId: _type,
        fullName: name,
        email: email,
        phone: phone,
        whatsappOptIn: _whatsapp && phone.isNotEmpty,
      );
      if (!mounted) return;
      widget.onJoined(entry);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _problem = waitlistJoinProblem(e);
        _noList = errorCodeOf(e) ==
            TicketingErrorCodes.waitlistOffOnApprovalEvents;
      });
    }
  }

  InputDecoration _box(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    final hours = widget.ticketing?.offerHours ?? 24;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Join the waiting list',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              "When a place opens up, we'll send you a link to claim it. It's "
              'held for you for $hours ${hours == 1 ? 'hour' : 'hours'}.',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 16),
            if (choices.length > 1) ...[
              const Text('Which ticket?',
                  style: TextStyle(fontSize: 12, color: _ink)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final type in choices)
                    ChoiceChip(
                      key: ValueKey('waitlist-type-${type.id}'),
                      label: Text(type.name),
                      selected: _type == type.id,
                      onSelected: (_) => setState(() => _type = type.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ] else if (choices.length == 1) ...[
              Text('For: ${choices.single.name}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('waitlist-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _box('Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('waitlist-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _box('Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('waitlist-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: _box('Phone (optional)'),
            ),
            if (_phone.text.trim().isNotEmpty)
              CheckboxListTile(
                key: const ValueKey('waitlist-whatsapp'),
                value: _whatsapp,
                onChanged: (on) => setState(() => _whatsapp = on ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: _ink,
                title: const Text('Tell me on WhatsApp too'),
              ),
            if (_problem != null) ...[
              const SizedBox(height: 8),
              Text(
                _problem!,
                key: JoinWaitlistForm.errorKey,
                style: const TextStyle(color: Color(0xFFCC0000), fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            if (!_noList)
              FilledButton(
                key: JoinWaitlistForm.submitKey,
                onPressed: _sending ? null : _join,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('JOIN THE WAITING LIST'),
              ),
          ],
        ),
      ),
    );
  }
}

/// What to say once someone is in line: their place, or that they were
/// already.
String joinedWaitlistMessage(WaitlistEntry entry) {
  final at = entry.position;
  final place = at == null ? '' : " You're #$at in line.";
  return entry.created
      ? "You're on the waiting list.$place We'll tell you when a place opens up."
      : "You're already on the waiting list.$place";
}
