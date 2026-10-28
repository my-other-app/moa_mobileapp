import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart'
    show findEventsPath;
import 'package:finnet/features/events/data/registration_requests_api.dart';
import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart'
    show ticketRoute;
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';

const _ink = Color(0xFF2C333D);
const _muted = Color(0xFF4B5563);
const _blue = Color(0xFF1D4ED8);
const _green = Color(0xFF16A34A);
const _deepGreen = Color(0xFF047857);
const _amber = Color(0xFFB45309);

/// `/requests/{token}`: where a registration stands, at an event whose club
/// reviews every registration (the API calls it a request; feature-register
/// `approvals-contract.md`, worded as `review-wording-contract.md` §1.3 and
/// §1.4 say). The link in the registration's emails (`https://
/// myotherapp.in/requests/{token}`), the pushes, My events' "Under review",
/// and the form once someone registers (`/events/request-sent`,
/// [justSent]) all open it. The token is the only credential, so it opens
/// signed out too.
///
/// - **pending:** "Your registration is under review", and "Cancel my
///   registration" (asked first). Just registered: "You're registered!".
/// - **confirmed, with its ticket:** straight on to the ticket.
/// - **confirmed, to pay:** "Pay ₹X by {time}", which opens the claim
///   screen (`/claim/{claim_token}`) that pays; [openPay] (the "confirmed,
///   pay" push) goes there at once.
/// - **declined, withdrawn, lapsed, closed:** each says what happened; a
///   closed one by its `closed_reason`.
class RegistrationRequestPage extends ConsumerStatefulWidget {
  const RegistrationRequestPage({
    super.key,
    required this.token,
    this.initial,
    this.justSent = false,
    this.openPay = false,
    this.askWithdraw = false,
    this.sentTo,
  });

  final String token;

  /// What the opener knows already (the form's answer, a row of My events):
  /// shown at once, then read again.
  final RegistrationRequest? initial;

  /// Opened by the form, the moment the person registered.
  final bool justSent;

  /// Go on to the claim screen as soon as the registration says what to pay
  /// (the `request_approved_pay` push, or `?next=pay`).
  final bool openPay;

  /// Ask at once whether to cancel it (`?withdraw=1`: "Cancel my
  /// registration" in its emails).
  final bool askWithdraw;

  /// The address the form was sent with ([justSent]): where the
  /// registration's link was emailed.
  final String? sentTo;

  static const statusKey = ValueKey('request-status');
  static const chipKey = ValueKey('request-status-chip');
  static const titleKey = ValueKey('request-title');
  static const withdrawKey = ValueKey('request-withdraw');
  static const payKey = ValueKey('request-pay');
  static const ticketKey = ValueKey('request-ticket');
  static const eventKey = ValueKey('request-event');
  static const seeKey = ValueKey('request-see');
  static const findEventsKey = ValueKey('request-find-events');
  static const myTicketsKey = ValueKey('request-my-tickets');
  static const registerAgainKey = ValueKey('request-register-again');
  static const retryKey = ValueKey('request-retry');
  static const problemKey = ValueKey('request-problem');
  static const noticeKey = ValueKey('request-notice');
  static const noteKey = ValueKey('request-decline-note');
  static const emailedKey = ValueKey('request-link-emailed');

  /// Cancelling refused because the registration moved on meanwhile
  /// (decided, paid, closed): said over the registration as it stands now.
  static const changedMeanwhile = 'Your registration changed meanwhile, so '
      "it wasn't cancelled. Here's where it stands now.";

  @override
  ConsumerState<RegistrationRequestPage> createState() =>
      _RegistrationRequestPageState();
}

enum _Stage { loading, notFound, failed, ready }

const _tooManyTries = 'Too many tries. Wait a minute, then try again.';

class _RegistrationRequestPageState
    extends ConsumerState<RegistrationRequestPage> {
  _Stage _stage = _Stage.loading;
  RegistrationRequest? _request;

  /// Why it didn't load ([_Stage.failed]).
  String? _loadProblem;

  /// Cancelling failed: said under its title, "We couldn't cancel your
  /// registration".
  String? _problem;

  /// Cancelling found it had moved on ([RegistrationRequestPage
  /// .changedMeanwhile]).
  String? _notice;
  bool _busy = false;

  /// Whether the event is online, for an iPhone's paid ticket (not sold in
  /// the iOS app); null when not asked, or not known.
  bool? _isOnline;

  /// The page has handed over to the ticket or the claim screen.
  bool _movedOn = false;

  /// [RegistrationRequestPage.askWithdraw] has been asked, once.
  bool _askedWithdraw = false;

  RegistrationRequestsApi get _api => ref.read(registrationRequestsApiProvider);

  bool get _hasToken => widget.token.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _request = initial;
      _stage = _Stage.ready;
      // A ticket to pay for: whether this phone may sell it, even if the
      // registration can't be read again now.
      if (initial.awaitingPayment) _readOnline(initial);
    }
    if (_hasToken) {
      _load(quiet: initial != null);
    } else if (initial == null) {
      _stage = _Stage.notFound;
    }
  }

  Future<void> _load({bool quiet = false}) async {
    if (!_hasToken) return;
    if (!quiet) {
      setState(() {
        _stage = _Stage.loading;
        _loadProblem = null;
      });
    }
    try {
      final fresh = await _api.byToken(widget.token);
      if (!mounted) return;
      final request = _request?.mergedWith(fresh) ?? fresh;
      setState(() {
        _request = request;
        _stage = _Stage.ready;
        _loadProblem = null;
      });
      ref.read(myRegistrationRequestsProvider.notifier).remember(request);
      await _afterRead(request);
    } catch (e) {
      if (!mounted) return;
      final missing = statusCodeOf(e) == 404;
      if (missing && widget.openPay && _request == null) {
        // The "confirmed, pay" push's token may be the claim link's own.
        _replaceWith(claimRoute(widget.token));
        return;
      }
      // A registration on screen already stays as it is: pulling down
      // reads it again.
      if (_request != null) {
        debugPrint('Request ${widget.token}: $e');
        return;
      }
      setState(() {
        _stage = missing ? _Stage.notFound : _Stage.failed;
        _loadProblem = statusCodeOf(e) == 429
            ? _tooManyTries
            : "We couldn't reach MyOtherApp to read this registration. "
                'Check your connection and try again.';
      });
    }
  }

  /// Where a registration read just now leads: the ticket once there is
  /// one; the claim screen for the "pay" push.
  Future<void> _afterRead(RegistrationRequest request) async {
    if (_movedOn) return;
    final ticketId = request.ticketId;
    if (request.hasTicket && ticketId != null) {
      _keepTicket(request);
      _replaceWith(ticketRoute(ticketId));
      return;
    }
    final pay = request.pay;
    if (request.awaitingPayment) {
      await _readOnline(request);
      if (!mounted) return;
    }
    if (widget.askWithdraw && !_askedWithdraw && request.isOpen) {
      // The email's "Cancel my registration": asked here, as the button is.
      _askedWithdraw = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _withdraw();
      });
      return;
    }
    if (widget.openPay && request.awaitingPayment && pay != null) {
      _replaceWith(claimRoute(pay.claimToken));
    }
  }

  /// A confirmed free ticket (or a paid one, paid): saved on the phone for
  /// the door, with its type, as a registration's is.
  void _keepTicket(RegistrationRequest request) {
    if (!ref.read(isAuthenticatedProvider)) return;
    final tickets = ref.read(savedTicketsProvider.notifier);
    final ticketId = request.ticketId;
    final type = request.ticketTypeName;
    if (ticketId != null && type != null) {
      tickets.rememberTicketType(ticketId, type);
    }
    tickets.refresh();
  }

  /// This page gives way to [location] (the ticket, or the claim screen):
  /// Back then goes where it would have from here.
  void _replaceWith(String location) {
    _movedOn = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      context.pushReplacement(location);
    });
  }

  /// Whether the event is online is known, or doesn't matter: only an
  /// iPhone asks (a paid online event isn't sold in the iOS app).
  bool get _onlineKnown =>
      _onlineChecked || defaultTargetPlatform != TargetPlatform.iOS;
  bool _onlineChecked = false;

  /// On an iPhone, whether the event is online, from its public page; until
  /// it is known no price shows. Elsewhere nothing to ask.
  Future<void> _readOnline(RegistrationRequest request) async {
    if (_onlineKnown) return;
    final event = request.event;
    final page = event == null
        ? null
        : await ref
            .read(ticketingApiProvider)
            .publicEvent(event.slug.isNotEmpty ? event.slug : event.id);
    if (!mounted) return;
    setState(() {
      _isOnline = jsonBool(page?['is_online']);
      _onlineChecked = true;
    });
  }

  /// This phone may sell the confirmed paid ticket (canSellInApp): known,
  /// and not a paid online event on an iPhone.
  bool get _sellable =>
      _onlineKnown && canSellInApp(hasFee: true, isOnline: _isOnline ?? false);

  Future<void> _pay() async {
    final pay = _request?.pay;
    if (pay == null) return;
    await context.push(claimRoute(pay.claimToken));
    // Paid there, or not: read again. A ticket now goes straight to it.
    if (mounted) await _load(quiet: true);
  }

  /// "Cancel my registration" (the API's withdraw), asked first.
  Future<void> _withdraw() async {
    final request = _request;
    if (request == null || _busy || !_hasToken) return;
    final held = request.awaitingPayment;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel your registration?'),
        content: Text(held
            ? "Your ticket will go to someone else, and you can't undo this."
            : "${request.clubName} won't review it any more. You can "
                'register again while registration is open.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my registration'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _ink),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, cancel it'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() {
      _busy = true;
      _problem = null;
      _notice = null;
    });
    try {
      final answer = await _api.withdraw(widget.token);
      if (!mounted) return;
      final now = request.mergedWith(answer);
      setState(() => _request = now);
      ref.read(myRegistrationRequestsProvider.notifier).remember(now);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your registration was cancelled.')));
    } catch (e) {
      if (!mounted) return;
      final status = statusCodeOf(e);
      // It moved on meanwhile (decided, paid, closed): 409
      // REQUEST_NOT_WITHDRAWABLE says how it stands now (`errors.request`);
      // any other refusal, it is read again.
      final now = errorCodeOf(e) == ApprovalErrorCodes.requestNotWithdrawable
          ? RegistrationRequest.fromJson(
              apiExceptionOf(e)?.errors?['request'],
              token: widget.token,
            )
          : null;
      if (now != null) {
        final merged = request.mergedWith(now);
        setState(() {
          _request = merged;
          _notice = RegistrationRequestPage.changedMeanwhile;
        });
        ref.read(myRegistrationRequestsProvider.notifier).remember(merged);
        await _afterRead(merged);
        return;
      }
      if (status == 409 || status == 404 || status == 400) {
        await _load(quiet: true);
        if (!mounted) return;
        if (!(_request?.isOpen ?? true)) {
          setState(() => _notice = RegistrationRequestPage.changedMeanwhile);
          return;
        }
      }
      setState(() => _problem = _said(e, fallback: 'Try again in a moment.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Your registration',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Center(
          child: CircularProgressIndicator(
              semanticsLabel: 'Loading your registration'),
        );
      case _Stage.notFound:
        return _scroll(_header(
          icon: Icons.link_off,
          color: Colors.grey[500]!,
          title: "This link isn't valid",
          text: "We couldn't find a registration at this address. Check that "
              'the whole link was copied from your email: each link shows '
              'one registration.',
        ));
      case _Stage.failed:
        return _scroll(Column(
          children: [
            _header(
              icon: Icons.cloud_off,
              color: Colors.grey[500]!,
              title: "Your registration didn't load",
              text: _loadProblem ?? 'Try again in a moment.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: RegistrationRequestPage.retryKey,
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: _ink),
              child: const Text('Try again'),
            ),
          ],
        ));
      case _Stage.ready:
        return RefreshIndicator(
          onRefresh: () => _load(quiet: true),
          child: _scroll(_requestView(context, _request!)),
        );
    }
  }

  Widget _scroll(Widget child) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: child,
      );

  Widget _header({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    String? chip,
  }) {
    return Column(
      key: RegistrationRequestPage.statusKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 16),
        if (chip != null) ...[
          Center(child: _StatusChip(word: chip, color: color)),
          const SizedBox(height: 10),
        ],
        Text(title,
            key: RegistrationRequestPage.titleKey,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.4, color: _muted)),
      ],
    );
  }

  /// Sent again, signed out or as someone else, for an address with a
  /// registration open: the answer has no link (whoever typed the address
  /// hasn't shown it is theirs); the link went to the address again.
  bool get _sentAgain => widget.justSent && !_hasToken;

  /// What the page says of [request]: its icon, colour, title and text
  /// (`review-wording-contract.md` §1.3 and §1.4).
  (IconData, Color, String, String) _words(RegistrationRequest request) {
    final club = request.clubName;
    final clubMid = request.clubMidSentence;
    final event = request.eventName;
    final eventFirst = event == 'the event' ? 'The event' : event;
    final pay = request.pay;
    final payBy = pay?.payBy;
    const reviews = 'reviews every registration. If yours is confirmed, '
        'your ticket will come by email.';
    if (_sentAgain) {
      final to = widget.sentTo?.trim() ?? '';
      return (
        Icons.mark_email_read_outlined,
        _blue,
        "You've already registered",
        to.isEmpty
            ? "We've emailed the link to your registration again."
            : "We've emailed the link to your registration to $to again.",
      );
    }
    return switch (request.status) {
      RequestStatus.pending when widget.justSent => (
          Icons.how_to_reg_outlined,
          _blue,
          "You're registered!",
          '$club $reviews',
        ),
      RequestStatus.pending => (
          Icons.hourglass_top,
          _blue,
          'Your registration is under review',
          '${request.firstName == null ? "You're" : "${request.firstName}, you're"} '
              'registered for $event. $club $reviews There\'s nothing else '
              'to do.',
        ),
      RequestStatus.approved when request.hasTicket => (
          Icons.verified,
          _green,
          "You're in",
          '$club confirmed your registration for $event. Your ticket is in '
              'your email too.',
        ),
      RequestStatus.approved when pay != null && _sellable => (
          Icons.celebration_outlined,
          _deepGreen,
          'Your registration is confirmed',
          payBy == null
              ? 'Pay ${formatRupees(pay.amount)} to get your ticket for '
                  '$event.'
              : 'Pay ${formatRupees(pay.amount)} by ${requestMoment(payBy)} '
                  'to get your ticket for $event. Your ticket is held for '
                  'you until then.',
        ),
      // No price: an iPhone doesn't sell a paid online event.
      RequestStatus.approved when pay != null => (
          Icons.celebration_outlined,
          _deepGreen,
          'Your registration is confirmed',
          payBy == null
              ? 'Your ticket for $event is held for you.'
              : 'Your ticket for $event is held for you until '
                  '${requestMoment(payBy)}.',
        ),
      RequestStatus.approved => (
          Icons.verified,
          _green,
          'Your registration is confirmed',
          'Look in your email for your ticket, or for the link to pay for it.',
        ),
      RequestStatus.declined => (
          Icons.event_busy,
          Colors.grey[600]!,
          "Your registration wasn't confirmed",
          'Thank you for your interest in $event. $club couldn\'t confirm '
              'your registration this time.',
        ),
      RequestStatus.withdrawn => (
          Icons.undo,
          Colors.grey[600]!,
          'You cancelled your registration',
          "$club won't review it any more. If you change your mind, you can "
              'register again while registration is open.',
        ),
      RequestStatus.lapsed => (
          Icons.timer_off_outlined,
          _amber,
          'Your registration has expired',
          "$club confirmed your registration for $event, but it wasn't paid "
              'in time. If registration is still open, you can register '
              'again.',
        ),
      RequestStatus.closed when request.registeredDirectly => (
          Icons.confirmation_number_outlined,
          _green,
          "You're registered",
          'You have a ticket for $event already.',
        ),
      RequestStatus.closed
          when request.closedReason == RequestClosedReasons.eventCancelled =>
        (
          Icons.event_busy,
          Colors.grey[600]!,
          'This registration is closed',
          "$eventFirst was cancelled. We've emailed you about it.",
        ),
      // The event ended or was deleted while it was under review, or the
      // server didn't say why.
      RequestStatus.closed => (
          Icons.lock_clock,
          Colors.grey[600]!,
          'This registration is closed',
          '$eventFirst ended before $clubMid could confirm your '
              'registration.',
        ),
      RequestStatus.unknown => (
          Icons.help_outline,
          Colors.grey[600]!,
          'Your registration',
          'Check your email for the latest from $clubMid about your '
              'registration.',
        ),
    };
  }

  Widget _requestView(BuildContext context, RegistrationRequest request) {
    final (icon, color, title, text) = _words(request);
    final note = request.declineNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          icon: icon,
          color: color,
          title: title,
          text: text,
          chip: request.statusWord,
        ),
        // Just registered: the link to it went to their email.
        if (widget.justSent && _hasToken) ...[
          const SizedBox(height: 16),
          Container(
            key: RegistrationRequestPage.emailedKey,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mail_outline, size: 20, color: _blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    emailedLine(widget.sentTo),
                    style: const TextStyle(
                        fontSize: 14, height: 1.35, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (request.status == RequestStatus.declined && note != null) ...[
          const SizedBox(height: 16),
          Container(
            key: RegistrationRequestPage.noteKey,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text('${request.clubName} said: $note',
                style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
          ),
        ],
        const SizedBox(height: 20),
        _RequestCard(request: request),
        if (_notice != null) ...[
          const SizedBox(height: 12),
          Text(_notice!,
              key: RegistrationRequestPage.noticeKey,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
        ],
        if (_problem != null) ...[
          const SizedBox(height: 12),
          Column(
            key: RegistrationRequestPage.problemKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("We couldn't cancel your registration",
                  style: TextStyle(
                      color: Color(0xFFCC0000),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(_problem!,
                  style:
                      const TextStyle(color: Color(0xFFCC0000), fontSize: 14)),
            ],
          ),
        ],
        const SizedBox(height: 20),
        ..._actions(context, request),
      ],
    );
  }

  /// The buttons under [request]: the first filled, the rest outlined,
  /// then "Cancel my registration" while it can be.
  List<Widget> _actions(BuildContext context, RegistrationRequest request) {
    final event = request.event;
    final pay = request.pay;
    final token = _hasToken ? widget.token : request.token;
    final back = event == null
        ? null
        : (
            RegistrationRequestPage.eventKey,
            'Back to the event',
            () => context.push(event.route),
          );
    final find = (
      RegistrationRequestPage.findEventsKey,
      'Find other events',
      () => context.push(findEventsPath),
    );
    final myTickets = (
      RegistrationRequestPage.myTicketsKey,
      'My tickets',
      () => context.go('/events'),
    );
    final buttons = <(Key, String, VoidCallback?)>[];
    Widget? instead;
    var canCancel = false;
    if (_sentAgain) {
      if (back != null) buttons.add(back);
    } else {
      switch (request.status) {
        case RequestStatus.pending when widget.justSent:
          if (token != null && token.trim().isNotEmpty) {
            buttons.add((
              RegistrationRequestPage.seeKey,
              'See your registration',
              () => context.push(requestRoute(token), extra: {
                    'request': request,
                  }),
            ));
          }
          if (back != null) buttons.add(back);
        case RequestStatus.pending:
          if (back != null) buttons.add(back);
          canCancel = true;
        case RequestStatus.approved when request.hasTicket:
          buttons.add((
            RegistrationRequestPage.ticketKey,
            'View your ticket',
            () => context.push(ticketRoute(request.ticketId!)),
          ));
          if (back != null) buttons.add(back);
        case RequestStatus.approved when request.awaitingPayment && pay != null:
          if (_sellable) {
            buttons.add((
              RegistrationRequestPage.payKey,
              'Pay ${formatRupees(pay.amount)}',
              _busy ? null : _pay,
            ));
          } else {
            instead = _onlineKnown
                ? const IosSaleBlockedNotice()
                : const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
            if (back != null) buttons.add(back);
          }
          canCancel = true;
        case RequestStatus.approved:
          buttons.add(myTickets);
          if (back != null) buttons.add(back);
        case RequestStatus.declined:
          buttons.add(find);
          if (back != null) buttons.add(back);
        case RequestStatus.withdrawn:
          if (event != null) {
            buttons.add((
              RegistrationRequestPage.registerAgainKey,
              'Register again',
              () => context.push('${event.route}/register'),
            ));
          }
          if (back != null) buttons.add(back);
        case RequestStatus.closed when request.registeredDirectly:
          buttons.add(myTickets);
          if (back != null) buttons.add(back);
        case RequestStatus.lapsed:
        case RequestStatus.closed:
          if (back != null) buttons.add(back);
          buttons.add(find);
        case RequestStatus.unknown:
          if (back != null) buttons.add(back);
      }
    }
    return [
      if (instead != null) ...[instead, const SizedBox(height: 8)],
      for (final (i, (key, label, onPressed)) in buttons.indexed) ...[
        if (i > 0) const SizedBox(height: 8),
        if (i == 0 && instead == null)
          FilledButton(
            key: key,
            onPressed: onPressed,
            style: _primary,
            child: Text(label),
          )
        else
          OutlinedButton(
            key: key,
            onPressed: onPressed,
            style: _secondary,
            child: Text(label),
          ),
      ],
      if (canCancel && _hasToken) ...[
        const SizedBox(height: 8),
        TextButton(
          key: RegistrationRequestPage.withdrawKey,
          onPressed: _busy ? null : _withdraw,
          style: TextButton.styleFrom(foregroundColor: _ink),
          child: Text(_busy
              ? 'Cancelling…'
              : request.awaitingPayment
                  ? "I can't come: cancel my registration"
                  : 'Cancel my registration'),
        ),
      ],
    ];
  }

  /// [e] in words: the server's limits (30 reads, 10 cancellations a
  /// minute) plainly, anything else as the events screens say it.
  static String _said(Object e, {required String fallback}) =>
      statusCodeOf(e) == 429
          ? _tooManyTries
          : readableError(e, fallback: fallback);

  /// "We've emailed you a link to check on your registration, at
  /// asha@example.com."
  static String emailedLine(String? email) {
    final to = email?.trim() ?? '';
    return to.isEmpty
        ? "We've emailed you a link to check on your registration."
        : "We've emailed you a link to check on your registration, at $to.";
  }

  static final _primary = FilledButton.styleFrom(
    backgroundColor: _ink,
    padding: const EdgeInsets.symmetric(vertical: 14),
  );

  static final _secondary = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 14),
  );
}

/// Where the registration stands, in a word ([RegistrationRequest
/// .statusWord]), over the title.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.word, required this.color});

  final String word;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: RegistrationRequestPage.chipKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        word,
        textAlign: TextAlign.center,
        style:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// The event, the ticket chosen, who for and when they registered.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final RegistrationRequest request;

  @override
  Widget build(BuildContext context) {
    final event = request.event;
    final when = event?.eventDateTime;
    final registered = request.submittedAt;
    final type = request.ticketTypeName;
    final name = request.fullName;
    const detail = TextStyle(fontSize: 13.5, color: _muted);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event == null || event.name.isEmpty
                ? 'Your registration'
                : event.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (event?.clubName != null) Text(event!.clubName!, style: detail),
          if (when != null)
            Text(DateFormat('EEE d MMM yyyy, h:mm a').format(when.toLocal()),
                style: detail),
          if (type != null || name != null || registered != null)
            const Divider(height: 20),
          if (type != null)
            Text(type,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (name != null) Text('For $name', style: detail),
          if (registered != null)
            Text('Registered ${requestMoment(registered)}', style: detail),
        ],
      ),
    );
  }
}
