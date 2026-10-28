import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart'
    show ticketRoute;
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/utils/event_sign_in.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:finnet/features/events/presentation/widgets/registration_feedback.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/cancelled_notice.dart';
import 'package:finnet/features/payments/checkout.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:finnet/shared/utils/external_links.dart';

const _ink = Color(0xFF2C333D);

/// `/claim/{token}`: a place offered from a waiting list -- the link in the
/// offer's email, WhatsApp message and push (`https://myotherapp.in/claim/
/// {token}`). The token is the only credential, so it opens signed out too.
///
/// Claiming registers the person the place was offered to, on the offer's
/// ticket type. A free ticket is theirs at once; a paid one is paid here,
/// as a registration is -- unless the server made the registration a
/// guest's (the offer is another address's than the account's, or nobody is
/// signed in): that one is paid on the website, which keeps a guest's
/// session. "No thanks" passes the place to the next person in line.
///
/// The same link pays for a ticket a club confirmed on an event whose club
/// reviews every registration (the offer's `reason: "approved"`): then the
/// page says "{Club} confirmed your registration" (feature-register
/// `review-wording-contract.md` §1.6) and never speaks of a place or a
/// waiting list.
class ClaimOfferPage extends ConsumerStatefulWidget {
  const ClaimOfferPage({super.key, required this.token});

  final String token;

  static const claimKey = ValueKey('claim-offer-claim');
  static const declineKey = ValueKey('claim-offer-decline');
  static const emailKey = ValueKey('claim-offer-email');
  static const doneKey = ValueKey('claim-offer-done');
  static const problemKey = ValueKey('claim-offer-problem');
  static const websiteKey = ValueKey('claim-offer-website');
  static const statusKey = ValueKey('claim-offer-status');
  static const titleKey = ValueKey('claim-offer-title');

  /// A confirmed registration's "Pay ₹199 by {time} to get your ticket."
  static const payByKey = ValueKey('claim-offer-pay-by');

  @override
  ConsumerState<ClaimOfferPage> createState() => _ClaimOfferPageState();
}

/// What the page is showing.
enum _Stage { loading, notFound, failed, offer, done, declined, payOnWebsite }

class _ClaimOfferPageState extends ConsumerState<ClaimOfferPage> {
  _Stage _stage = _Stage.loading;
  WaitlistOffer? _offer;
  EventCancellation? _cancellation;
  bool? _isOnline;
  String? _problem;
  String? _emailError;
  bool _busy = false;
  RegistrationResult? _result;
  final _email = TextEditingController();

  TicketingApi get _api => ref.read(ticketingApiProvider);

  /// The website's page for this offer, where a guest's claim is paid.
  Uri get _websiteLink => Uri.parse(
      '${AppConfig.publicSiteUrl}/claim/${Uri.encodeComponent(widget.token)}');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _stage = _Stage.loading;
      _problem = null;
    });
    try {
      final offer = await _api.offer(widget.token);
      // The event itself: whether it was called off, and whether it is
      // online (an iPhone doesn't sell a paid online event).
      final event = await _api.publicEvent(
          offer.eventSlug.isNotEmpty ? offer.eventSlug : offer.eventId);
      if (!mounted) return;
      setState(() {
        _offer = offer;
        _cancellation = EventCancellation.of(event);
        _isOnline = jsonBool(event?['is_online']);
        _stage = _Stage.offer;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = errorCodeOf(e) == TicketingErrorCodes.offerNotFound ||
                statusCodeOf(e) == 404
            ? _Stage.notFound
            : _Stage.failed;
        _problem = readableError(e,
            fallback: "We couldn't open this offer. Try again in a moment.");
      });
    }
  }

  bool get _sellable => canSellInApp(hasFee: true, isOnline: _isOnline ?? false);

  Future<void> _claim() async {
    final offer = _offer;
    if (offer == null || _busy) return;
    final email = _email.text.trim();
    if (offer.needsEmail &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      setState(() => _emailError = 'Enter the email address for your ticket.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
      _emailError = null;
    });
    try {
      // A confirmed request's place registers the request's own name and
      // code: nothing of them goes from here (an email only if the offer
      // somehow lacks one, as any claim).
      final result =
          await _api.claim(widget.token, email: offer.needsEmail ? email : null);
      if (!mounted) return;
      _result = result;
      if (!result.needsPayment) return _finish(result);
      if (result.forGuest) {
        // The registration is a guest's, not this account's: paid where
        // the guest's session is kept.
        setState(() => _stage = _Stage.payOnWebsite);
        return;
      }
      await _pay(result);
    } catch (e) {
      if (!mounted) return;
      _refused(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(RegistrationResult result) async {
    final registrationId = result.registrationId;
    final offer = _offer!;
    if (registrationId == null) {
      setState(() => _problem =
          "We couldn't start the payment. Try again in a moment.");
      return;
    }
    final paid = await RegistrationCheckout.pay(
      repository: ref.read(paymentRepositoryProvider),
      eventId: result.eventId ?? offer.eventId,
      registrationId: registrationId,
      name: result.fullName ?? offer.fullName,
      email: result.email ?? '',
      phone: result.phone ?? '',
      sellable: _sellable,
    );
    if (!mounted) return;
    if (paid.isLeft) {
      final failure = paid.left;
      if (failure.code == eventCancelledCode) {
        setState(() => _cancellation ??= const EventCancellation());
        return;
      }
      showPaymentFailure(context, failure);
      return;
    }
    if (!paid.right) {
      final until = offer.expiresAt;
      final what = offer.fromApproval ? 'ticket' : 'place';
      setState(() => _problem = until == null
          ? 'Payment not completed. Your $what is still held: tap Pay to try again.'
          : 'Payment not completed. Your $what is held until '
              '${_when(until)}: tap Pay to try again.');
      return;
    }
    _finish(result);
  }

  void _finish(RegistrationResult result) {
    final ticketId = result.ticketId;
    final type = result.ticketTypeName ?? _offer?.ticketTypeName;
    if (!result.forGuest && ref.read(isAuthenticatedProvider)) {
      final tickets = ref.read(savedTicketsProvider.notifier);
      if (ticketId != null && type != null) {
        tickets.rememberTicketType(ticketId, type);
      }
      tickets.refresh();
    }
    setState(() {
      _result = result;
      _stage = _Stage.done;
    });
  }

  void _refused(Object e) {
    final code = errorCodeOf(e);
    if (isCancelledRefusal(e)) {
      setState(() => _cancellation ??= const EventCancellation());
      return;
    }
    switch (code) {
      case TicketingErrorCodes.offerExpired:
      case TicketingErrorCodes.offerClaimed:
      case TicketingErrorCodes.offerNotFound:
        // Read again: the page then says what became of it.
        _load();
        return;
      case TicketingErrorCodes.emailRequired:
        setState(() => _emailError = 'Enter the email address for your ticket.');
        return;
      case TicketingErrorCodes.alreadyRegistered:
        setState(() => _problem = 'You already have a ticket for this event.');
        return;
      case TicketingErrorCodes.clubEmail:
        setState(() => _problem =
            "This email belongs to a club's account. Use your own email.");
        return;
    }
    if (statusCodeOf(e) == 429) {
      setState(() => _problem = 'Too many tries. Wait a minute, then try again.');
      return;
    }
    setState(() => _problem = readableError(e,
        fallback: (_offer?.fromApproval ?? false)
            ? "We couldn't get your ticket. Try again in a moment."
            : "We couldn't claim this place. Try again in a moment."));
  }

  Future<void> _decline() async {
    final offer = _offer;
    if (offer == null || _busy) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(offer.fromApproval
            ? 'Cancel your registration?'
            : 'Give up this place?'),
        content: Text(offer.fromApproval
            ? "Your ticket will go to someone else, and you can't undo this."
            : 'It goes to the next person in line for ${offer.eventName}. '
                "You can't take it back."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
                offer.fromApproval ? 'Keep my registration' : 'Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _ink),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(offer.fromApproval ? 'Yes, cancel it' : 'No thanks'),
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
      await _api.decline(widget.token);
      if (mounted) setState(() => _stage = _Stage.declined);
    } catch (e) {
      if (!mounted) return;
      final code = errorCodeOf(e);
      if (code == TicketingErrorCodes.offerExpired ||
          code == TicketingErrorCodes.offerClaimed) {
        await _load();
      } else {
        setState(() => _problem = readableError(e,
            fallback: offer.fromApproval
                ? "We couldn't cancel your registration. Try again."
                : "We couldn't pass the place on. Try again."));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _when(DateTime at) =>
      DateFormat("EEE d MMM 'at' h:mm a").format(at.toLocal());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          (_offer?.fromApproval ?? false) ? 'Your registration' : 'Your place',
          style: const TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
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
        return _message(
          icon: Icons.link_off,
          title: "This link isn't valid",
          text: 'Check you opened the whole link from your email or message.',
        );
      case _Stage.failed:
        return _message(
          icon: Icons.cloud_off,
          title: "We couldn't open this offer",
          text: _problem ?? 'Try again in a moment.',
          action: FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: _ink),
            child: const Text('Try again'),
          ),
        );
      case _Stage.declined:
        final approved = _offer?.fromApproval ?? false;
        return _message(
          icon: Icons.check_circle_outline,
          title: approved
              ? 'Your registration was cancelled'
              : 'Thanks for letting us know',
          text: approved
              ? 'Thanks for letting us know. ${_offer!.clubOrDefault} can '
                  'give your ticket to someone else.'
              : 'The place has gone to the next person in line.',
          action: _eventButton(),
        );
      case _Stage.done:
        return _done();
      case _Stage.payOnWebsite:
      case _Stage.offer:
        return _offerView(context);
    }
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String text,
    Widget? action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          key: ClaimOfferPage.statusKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[500]),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563))),
            if (action != null) ...[const SizedBox(height: 20), action],
          ],
        ),
      ),
    );
  }

  Widget? _eventButton() {
    final offer = _offer;
    if (offer == null) return null;
    return OutlinedButton(
      onPressed: () => context.push(offer.eventRoute),
      child: const Text('See the event'),
    );
  }

  Widget _done() {
    final result = _result!;
    final offer = _offer!;
    final ticketId = result.ticketId;
    final paid = result.needsPayment;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        key: ClaimOfferPage.doneKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified, size: 56, color: Color(0xFF16A34A)),
          const SizedBox(height: 12),
          const Text("You're in!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '${result.ticketTypeName ?? offer.ticketTypeName} for '
            '${result.eventName ?? offer.eventName}'
            '${paid ? ', paid' : ''}. Your ticket is on its way to '
            '${result.email ?? 'your email'}.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 24),
          if (ticketId != null)
            FilledButton(
              onPressed: () => context.push(ticketRoute(ticketId)),
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('VIEW TICKET'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push(offer.eventRoute),
            child: const Text('See the event'),
          ),
        ],
      ),
    );
  }

  Widget _offerView(BuildContext context) {
    final offer = _offer!;
    final cancelled = _cancellation;
    final club = offer.clubOrDefault;
    final statusView = switch (offer.status) {
      OfferStatus.expired when offer.fromApproval => (
          Icons.timer_off_outlined,
          'Your registration has expired',
          '$club confirmed your registration for ${offer.eventName}, but it '
              "wasn't paid in time. If registration is still open, you can "
              'register again.',
        ),
      OfferStatus.expired => (
          Icons.timer_off_outlined,
          'This offer ran out',
          'The place was held until ${offer.expiresAt == null ? 'its time ran out' : _when(offer.expiresAt!)}, '
              'and has gone to the next person in line.'
        ),
      OfferStatus.claimed when offer.fromApproval => (
          Icons.confirmation_number_outlined,
          "You're in",
          'Your ticket went to your email. Find it in My events, or in that '
              'email.'
        ),
      OfferStatus.claimed => (
          Icons.confirmation_number_outlined,
          'This place has been claimed',
          'The ticket went to the email it was offered to. Find it in My '
              'events, or in that email.'
        ),
      OfferStatus.left when offer.fromApproval => (
          Icons.logout,
          'You cancelled your registration',
          '$club can now give your ticket to someone else.'
        ),
      OfferStatus.removed when offer.fromApproval => (
          Icons.person_remove_outlined,
          'This registration is closed',
          '$club took this ticket back. Open the event for the latest.'
        ),
      OfferStatus.left => (
          Icons.logout,
          'You left the waiting list',
          'This place went to the next person in line.'
        ),
      OfferStatus.removed => (
          Icons.person_remove_outlined,
          'This offer was withdrawn',
          'The organiser took this place off the waiting list.'
        ),
      OfferStatus.unknown when offer.fromApproval => (
          Icons.help_outline,
          'Your registration',
          'Check your email for the latest from '
              '${offer.clubName ?? 'the club'} about your registration.'
        ),
      OfferStatus.unknown => (
          Icons.help_outline,
          "This offer can't be claimed",
          'Open the event for the latest.'
        ),
      OfferStatus.offered => null,
    };
    if (cancelled == null && statusView != null) {
      return _message(
        icon: statusView.$1,
        title: statusView.$2,
        text: statusView.$3,
        action: _eventButton(),
      );
    }
    final signedIn = ref.watch(isAuthenticatedProvider);
    final expires = offer.expiresAt;
    final pending = offer.registrationId != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cancelled != null
                ? offer.eventName
                : offer.fromApproval
                    ? '$club confirmed your registration'
                    : 'A place opened up for you',
            key: ClaimOfferPage.titleKey,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _OfferCard(offer: offer, showPrice: _sellable),
          const SizedBox(height: 16),
          if (cancelled != null)
            CancelledNotice(cancellation: cancelled)
          else ...[
            // A confirmed registration: what to pay, by when (no price on
            // an iPhone for a paid online event).
            if (offer.fromApproval && offer.needsPayment)
              Text(
                _sellable
                    ? 'Pay ${formatRupees(offer.payable)}'
                        '${expires == null ? '' : ' by ${_when(expires)}'} to '
                        'get your ticket.'
                    : expires == null
                        ? 'Your ticket is held for you.'
                        : 'Your ticket is held for you until '
                            '${_when(expires)}.',
                key: ClaimOfferPage.payByKey,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309)),
              )
            else if (expires != null)
              Text(
                'Held for you until ${_when(expires)}.',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309)),
              ),
            if (offer.needsEmail && _stage == _Stage.offer) ...[
              const SizedBox(height: 16),
              TextField(
                key: ClaimOfferPage.emailKey,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email for your ticket',
                  errorText: _emailError,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            if (!signedIn && _stage == _Stage.offer) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sign in with the account for this email to keep the '
                      'ticket in the app.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ensureSignedInFor(context, ref,
                        reason: offer.fromApproval
                            ? 'Sign in to get your ticket for '
                                '${offer.eventName}.'
                            : 'Sign in to claim your place for '
                                '${offer.eventName}.'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
            if (_problem != null) ...[
              const SizedBox(height: 12),
              Text(
                _problem!,
                key: ClaimOfferPage.problemKey,
                style: const TextStyle(color: Color(0xFFCC0000), fontSize: 14),
              ),
            ],
            const SizedBox(height: 20),
            if (_stage == _Stage.payOnWebsite)
              ..._payOnWebsite()
            else if (offer.needsPayment && !_sellable)
              const IosSaleBlockedNotice()
            else ...[
              FilledButton(
                key: ClaimOfferPage.claimKey,
                onPressed: _busy ? null : _claim,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(!offer.needsPayment
                        ? offer.fromApproval
                            ? 'GET MY TICKET'
                            : 'CLAIM MY PLACE'
                        : pending || _result != null || offer.fromApproval
                            ? 'PAY ${formatRupees(offer.payable).toUpperCase()}'
                            : 'CLAIM AND PAY ${formatRupees(offer.payable)}'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: ClaimOfferPage.declineKey,
                onPressed: _busy ? null : _decline,
                child: Text(offer.fromApproval
                    ? "I can't come: cancel my registration"
                    : 'No thanks, give it to the next person'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _payOnWebsite() {
    final email = _result?.email ?? _offer?.email;
    return [
      Text(
        (_offer?.fromApproval ?? false)
            ? 'This ticket is held for ${email ?? 'another email address'}, '
                "which isn't the account you're signed in with. Pay on the "
                'website to keep it, before the time to pay runs out.'
            : 'This place is held for ${email ?? 'another email address'}, '
                "which isn't the account you're signed in with. Pay on the "
                'website to keep it, before the offer runs out.',
        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
      ),
      const SizedBox(height: 12),
      FilledButton(
        key: ClaimOfferPage.websiteKey,
        onPressed: () => openExternally(_websiteLink),
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('PAY ON THE WEBSITE'),
      ),
    ];
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.showPrice});

  final WaitlistOffer offer;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final when = offer.eventDateTime;
    final holder = [
      if (offer.fullName.isNotEmpty) offer.fullName,
      if (offer.email != null) offer.email!,
      if (offer.email == null && offer.phone != null) offer.phone!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(offer.eventName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (when != null)
            Text(DateFormat("EEE d MMM yyyy, h:mm a").format(when.toLocal()),
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563))),
          if (offer.locationName != null)
            Text(offer.locationName!,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563))),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(offer.ticketTypeName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (showPrice)
                Text(priceLabel(offer.payable),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          if (holder.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('For $holder',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ],
      ),
    );
  }
}
