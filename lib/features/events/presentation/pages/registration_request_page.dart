import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
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

/// `/requests/{token}`: where a request for a place stands, at an event
/// whose club confirms each registration (feature-register
/// `approvals-contract.md`). The link in the request's emails (`https://
/// myotherapp.in/requests/{token}`), the request pushes, My events'
/// "Waiting for confirmation", and the form once a request is sent
/// (`/events/request-sent`, [justSent]) all open it. The token is the only
/// credential, so it opens signed out too.
///
/// - **pending:** "You're on the waiting list", and Withdraw (asked first).
/// - **confirmed, with its ticket:** straight on to the ticket.
/// - **confirmed, to pay:** "Pay ₹X by {time}", which opens the claim
///   screen (`/claim/{claim_token}`) that pays; [openPay] (the "confirmed,
///   pay" push) goes there at once.
/// - **declined, withdrawn, lapsed, closed:** each says what happened.
class RegistrationRequestPage extends ConsumerStatefulWidget {
  const RegistrationRequestPage({
    super.key,
    required this.token,
    this.initial,
    this.justSent = false,
    this.openPay = false,
    this.askWithdraw = false,
  });

  final String token;

  /// What the opener knows already (the form's answer, a row of My events):
  /// shown at once, then read again.
  final RegistrationRequest? initial;

  /// Opened by the form, the moment the request was sent.
  final bool justSent;

  /// Go on to the claim screen as soon as the request says what to pay
  /// (the `request_approved_pay` push, or `?next=pay`).
  final bool openPay;

  /// Ask at once whether to withdraw it (`?withdraw=1`: "Changed your
  /// mind? Withdraw your request" in the request's email).
  final bool askWithdraw;

  static const statusKey = ValueKey('request-status');
  static const titleKey = ValueKey('request-title');
  static const withdrawKey = ValueKey('request-withdraw');
  static const payKey = ValueKey('request-pay');
  static const ticketKey = ValueKey('request-ticket');
  static const eventKey = ValueKey('request-event');
  static const retryKey = ValueKey('request-retry');
  static const problemKey = ValueKey('request-problem');
  static const noteKey = ValueKey('request-decline-note');

  @override
  ConsumerState<RegistrationRequestPage> createState() =>
      _RegistrationRequestPageState();
}

enum _Stage { loading, notFound, failed, ready }

class _RegistrationRequestPageState
    extends ConsumerState<RegistrationRequestPage> {
  _Stage _stage = _Stage.loading;
  RegistrationRequest? _request;
  String? _problem;
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
      // A place to pay for: whether this phone may sell it, even if the
      // request can't be read again now.
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
        _problem = null;
      });
    }
    try {
      final fresh = await _api.byToken(widget.token);
      if (!mounted) return;
      final request = _request?.mergedWith(fresh) ?? fresh;
      setState(() {
        _request = request;
        _stage = _Stage.ready;
        _problem = null;
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
      // A request on screen already stays as it is: pulling down reads it
      // again.
      if (_request != null) {
        debugPrint('Request ${widget.token}: $e');
        return;
      }
      setState(() {
        _stage = missing ? _Stage.notFound : _Stage.failed;
        _problem = readableError(e,
            fallback: "We couldn't read your request. Try again in a moment.");
      });
    }
  }

  /// Where a request read just now leads: the ticket once there is one;
  /// the claim screen for the "pay" push.
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
      // The email's "Withdraw your request": asked here, as the button is.
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

  /// This phone may sell the confirmed paid place (canSellInApp): known,
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

  Future<void> _withdraw() async {
    final request = _request;
    if (request == null || _busy || !_hasToken) return;
    final held = request.awaitingPayment;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(held ? 'Give up your place?' : 'Withdraw your request?'),
        content: Text(held
            ? 'The place ${request.clubName} is holding for you at '
                '${request.eventName} goes to someone else.'
            : "${request.clubName} won't see your request any more. You can "
                'ask for a place again while registration is open.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _ink),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(held ? 'Give it up' : 'Withdraw'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final answer = await _api.withdraw(widget.token);
      if (!mounted) return;
      final now = request.mergedWith(answer);
      setState(() => _request = now);
      ref.read(myRegistrationRequestsProvider.notifier).remember(now);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(held
              ? 'You gave up your place.'
              : 'Your request was withdrawn.')));
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
        setState(() => _request = merged);
        ref.read(myRegistrationRequestsProvider.notifier).remember(merged);
        await _afterRead(merged);
        if (!mounted) return;
      } else if (status == 409 || status == 404 || status == 400) {
        await _load(quiet: true);
        if (!mounted) return;
      }
      setState(() => _problem = readableError(e,
          fallback: "We couldn't withdraw your request. Try again."));
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
          'Your request',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Center(child: CircularProgressIndicator());
      case _Stage.notFound:
        return _scroll(_header(
          icon: Icons.link_off,
          color: Colors.grey[500]!,
          title: "This link isn't valid",
          text: 'Check you opened the whole link from your email or message.',
        ));
      case _Stage.failed:
        return _scroll(Column(
          children: [
            _header(
              icon: Icons.cloud_off,
              color: Colors.grey[500]!,
              title: "We couldn't open your request",
              text: _problem ?? 'Try again in a moment.',
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
  }) {
    return Column(
      key: RegistrationRequestPage.statusKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 16),
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

  Widget _requestView(BuildContext context, RegistrationRequest request) {
    final club = request.clubName;
    final event = request.eventName;
    final pay = request.pay;
    final payBy = pay?.payBy;
    final (IconData icon, Color color, String title, String text) =
        switch (request.status) {
      RequestStatus.pending => (
          Icons.hourglass_top,
          const Color(0xFF1D4ED8),
          "You're on the waiting list",
          '$club confirms each registration. We\'ll notify you and email '
              'your ticket as soon as they confirm your place.',
        ),
      RequestStatus.approved when request.hasTicket => (
          Icons.verified,
          const Color(0xFF16A34A),
          '$club confirmed your place',
          'Your ticket is ready.',
        ),
      RequestStatus.approved when pay != null && _sellable => (
          Icons.celebration_outlined,
          const Color(0xFF047857),
          '$club confirmed your place',
          payBy == null
              ? 'Pay ${formatRupees(pay.amount)} to get your ticket.'
              : 'Pay ${formatRupees(pay.amount)} by ${requestMoment(payBy)} '
                  'to get your ticket.',
        ),
      RequestStatus.approved when pay != null => (
          Icons.celebration_outlined,
          const Color(0xFF047857),
          '$club confirmed your place',
          payBy == null
              ? 'Your place is held for you.'
              : 'Your place is held for you until ${requestMoment(payBy)}.',
        ),
      RequestStatus.approved => (
          Icons.verified,
          const Color(0xFF16A34A),
          '$club confirmed your place',
          "Your ticket is on its way to your email. It'll be in My events "
              'too.',
        ),
      RequestStatus.declined => (
          Icons.event_busy,
          Colors.grey[600]!,
          "$club couldn't offer you a place",
          "Sorry, $club couldn't offer you a place at $event this time.",
        ),
      RequestStatus.withdrawn => (
          Icons.undo,
          Colors.grey[600]!,
          'You withdrew your request',
          "$club won't see it any more. You can ask for a place again while "
              'registration is open.',
        ),
      RequestStatus.lapsed => (
          Icons.timer_off_outlined,
          const Color(0xFFB45309),
          'Your place was released',
          '$club confirmed your place, but the payment didn\'t arrive in '
              'time, so it has gone to someone else.',
        ),
      RequestStatus.closed => (
          Icons.lock_clock,
          Colors.grey[600]!,
          'This request is closed',
          '$event is over or was cancelled, so its requests are closed.',
        ),
      RequestStatus.unknown => (
          Icons.help_outline,
          Colors.grey[600]!,
          "We can't show this request",
          'Open the event for the latest.',
        ),
    };

    final note = request.declineNote;
    final canWithdraw =
        _hasToken && (request.isPending || request.awaitingPayment);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(icon: icon, color: color, title: title, text: text),
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
            child: Text('$club said: $note',
                style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
          ),
        ],
        const SizedBox(height: 20),
        _RequestCard(request: request),
        if (_problem != null) ...[
          const SizedBox(height: 12),
          Text(_problem!,
              key: RegistrationRequestPage.problemKey,
              style: const TextStyle(color: Color(0xFFCC0000), fontSize: 14)),
        ],
        const SizedBox(height: 20),
        if (request.hasTicket)
          FilledButton(
            key: RegistrationRequestPage.ticketKey,
            onPressed: () => context.push(ticketRoute(request.ticketId!)),
            style: _primary,
            child: const Text('VIEW TICKET'),
          )
        else if (request.awaitingPayment && pay != null) ...[
          if (_sellable)
            FilledButton(
              key: RegistrationRequestPage.payKey,
              onPressed: _busy ? null : _pay,
              style: _primary,
              child: Text('PAY ${formatRupees(pay.amount)}'),
            )
          else if (_onlineKnown)
            const IosSaleBlockedNotice()
          else
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
        if (request.event != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: RegistrationRequestPage.eventKey,
            onPressed: () => context.push(request.event!.route),
            child: const Text('See the event'),
          ),
        ],
        if (canWithdraw) ...[
          const SizedBox(height: 8),
          TextButton(
            key: RegistrationRequestPage.withdrawKey,
            onPressed: _busy ? null : _withdraw,
            style: TextButton.styleFrom(foregroundColor: _ink),
            child: Text(request.awaitingPayment
                ? "I can't make it, give up my place"
                : 'Withdraw my request'),
          ),
        ],
      ],
    );
  }

  static final _primary = FilledButton.styleFrom(
    backgroundColor: _ink,
    padding: const EdgeInsets.symmetric(vertical: 14),
  );
}

/// The event, the ticket asked for, who for and when.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final RegistrationRequest request;

  @override
  Widget build(BuildContext context) {
    final event = request.event;
    final when = event?.eventDateTime;
    final asked = request.submittedAt;
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
            event == null || event.name.isEmpty ? 'Your request' : event.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (event?.clubName != null) Text(event!.clubName!, style: detail),
          if (when != null)
            Text(DateFormat('EEE d MMM yyyy, h:mm a').format(when.toLocal()),
                style: detail),
          if (type != null || name != null || asked != null)
            const Divider(height: 20),
          if (type != null)
            Text(type,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (name != null) Text('For $name', style: detail),
          if (asked != null)
            Text('Asked ${requestMoment(asked)}', style: detail),
        ],
      ),
    );
  }
}
