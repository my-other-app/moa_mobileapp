import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/shared/widgets/rating_stars.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/common/models/events/agenda_model.dart';
import 'package:finnet/common/models/events/cohost_model.dart';
import 'package:finnet/common/models/events/live_model.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/common/models/events/store_model.dart';
import 'package:finnet/features/events/data/datasources/live_remote_datasource.dart';
import 'package:finnet/features/events/data/live/live_stream_client.dart';
import 'package:finnet/features/live/live_routes.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/presentation/providers/event_page_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_calendar.dart';
import 'package:finnet/features/events/presentation/utils/event_sign_in.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_contact.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_backers.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/hosted_by.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_people.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_rail.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_section.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_venue.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/registration_countdown.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_entries.dart';
import 'package:finnet/features/events/presentation/finish_payment.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/events/presentation/widgets/merch_picker.dart';
import 'package:finnet/features/events/presentation/widgets/registration_feedback.dart';
import 'package:finnet/features/payments/checkout.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_tag_strip.dart';
import 'package:intl/intl.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';
import 'package:finnet/shared/widgets/high_demand_chip.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/events/presentation/widgets/networking/people_like_you_card.dart';
import 'package:finnet/core/utils/hours.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/shared/widgets/poster_hero.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:finnet/shared/widgets/toast.dart';
import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/cancelled_notice.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/ticket_type_picker.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/waitlist_widgets.dart';

class IndividualEventPage extends ConsumerStatefulWidget {
  /// The event's id, when it was opened by id.
  final int? eventId;

  /// The event's slug or id, as an address has it (`/events/hack-night`,
  /// `/events/42`). `/events/info/{ref}` takes either.
  final String? eventRef;
  final String? initialStatus;
  final String? initialTicketUrl;
  final String? initialCertificateUrl;

  /// Open the live room as soon as the page is up: a tapped "join now"
  /// push (`event_live_join`) lands here, so closing the room returns to
  /// the event.
  final bool openLiveRoom;

  /// The hero tag of the card's poster that opened this page, which flies
  /// into this page's poster; null from anywhere else.
  final String? posterHero;

  /// What that card knew of the poster, drawn while the event loads so the
  /// flight lands on the very poster the page then shows.
  final PosterHint? posterHint;

  /// A hidden ticket type a link named (`?ticket_type=`): shown with the
  /// others, and chosen on the form.
  final int? linkedTicketTypeId;

  const IndividualEventPage({
    super.key,
    this.eventId,
    this.eventRef,
    this.initialStatus,
    this.initialTicketUrl,
    this.initialCertificateUrl,
    this.openLiveRoom = false,
    this.posterHero,
    this.posterHint,
    this.linkedTicketTypeId,
  }) : assert(eventId != null || eventRef != null,
            'An event page needs an id or a slug');

  /// The line by the register button on an event whose club reviews every
  /// registration.
  static const approvalNoteKey = ValueKey('event-approval-note');

  /// Over [approvalNoteKey]'s line, when the person has registered: "Your
  /// registration is under review", or confirmed.
  static const approvalTitleKey = ValueKey('event-approval-title');

  /// The event as it was asked for: [eventRef] when given, else [eventId].
  String get ref {
    final given = eventRef?.trim() ?? '';
    return given.isNotEmpty ? given : '${eventId ?? 0}';
  }

  @override
  ConsumerState<IndividualEventPage> createState() =>
      _IndividualEventPageState();
}

class _IndividualEventPageState extends ConsumerState<IndividualEventPage>
    with WidgetsBindingObserver, RefreshWhenBackOnline<IndividualEventPage> {
  // State variables for event fields.
  int? id;
  String? name;
  String? slug;
  Map<String, dynamic>? poster;
  DateTime? eventDateTime;
  double? duration;
  String? locationName;
  String? locationLink;
  bool? hasFee;
  int? regFee;
  bool? hasPrize;
  int? prizeAmount;
  bool? isOnline;
  DateTime? regStartDate;
  DateTime? regEndDate;
  Club? club;

  /// The clubs co-hosting the event with [club], by `/events/info`'s word;
  /// empty when it has none, or from a server older than co-hosting.
  List<EventCohost> infoCohosts = const [];
  Category? category;
  List<Interest> interests = [];

  /// The event's `topics`; null from a server that does not send them.
  List<Topic>? topics;
  List<AdditionalDetail> additionalDetails = [];
  double? rating;
  int? totalRating;
  String? about;
  String? contactPhone;
  String? contactEmail;
  String? url;

  // From /events/info, for the sections the website shows. The website's
  // own page (/discover/events) has more, and wins where both say.
  List<EventPerson> infoSpeakers = const [];
  String? infoGuidelines;
  EventContact infoContact = EventContact.none;
  double? infoLat;
  double? infoLng;
  String? feedbackUrl;

  /// The event's id: known from the start when it was opened by id, and
  /// from `/events/info` when by slug. Null until then.
  int? get _eventId {
    final loaded = id;
    if (loaded != null && loaded > 0) return loaded;
    return widget.eventId ?? eventIdOf(widget.ref);
  }

  /// Whether this phone sells a place at this event: not a paid online
  /// event on an iPhone (canSellInApp, the owner's decision for 3.1.3(d)).
  bool get _sellable => canSellInApp(
        hasFee: hasFee ?? false,
        isOnline: isOnline ?? false,
      );

  /// The id, or 0 before it is known (no call is made with it then).
  int get _idOrZero => _eventId ?? 0;

  /// What the website's event page has for this event; null for a
  /// non-public event, before it loads, or when it can't. Watched at the
  /// top of [build], so tap handlers read the same copy the page shows.
  EventPageDetails? _page;

  // Registration/Attendance status
  bool isRegistered = false;
  bool isAttended = false;

  /// Whether the event has People Like You (its `networking`; null when
  /// not registered, or from an older server).
  bool? _networking;

  /// Registered for a paid event and not paid: no ticket until they pay.
  bool awaitingPayment = false;

  /// The organiser revoked this person's ticket (the event's own
  /// `ticket_revoked`).
  bool ticketRevoked = false;

  /// Revoked by the event's word, or by the saved tickets' (the list
  /// carries `ticket_revoked`; an event page from an older server may not).
  bool get _ticketRevoked {
    if (ticketRevoked) return true;
    final code = ticketCodeFromUrl(ticketUrl);
    if (code == null) return false;
    for (final saved in ref.read(savedTicketsProvider)) {
      if (saved.code == code) return saved.revoked;
    }
    return false;
  }

  /// The viewer's registration (`registration_id`), to pay for it directly.
  /// Null when not registered, or from an older server.
  String? registrationId;

  /// The server refused the payment because registration has closed. Only
  /// its word closes it: an unpaid registration can be paid for after the
  /// deadline, until the event ends.
  bool _paymentClosed = false;

  /// A payment for the registration is under way.
  bool _paying = false;

  /// Opened from "Finish payment" on a list: start paying once loaded, once.
  bool _finishPaymentOnLoad = false;
  String? ticketUrl;
  String? certificateUrl;
  double? userRating;
  int? userPosition;
  String? positionLabel;
  List<EventDownload> downloads = [];

  // The run of show, when the organiser has written one.
  Agenda agenda = const Agenda(items: []);

  bool isLoading = true;
  String? errorMessage;

  /// The deadline passed: at load, or while the countdown was showing.
  bool registrationClosed = false;

  /// The event's ticket types, what is left and the person's place in line
  /// (`ticketing`); null from a server without them.
  EventTicketing? _ticketing;

  /// The club called the event off (`status: "cancelled"`), by
  /// `/events/info`'s word.
  EventCancellation? _infoCancellation;

  /// Leaving the waiting list is under way.
  bool _leavingWaitlist = false;

  /// The club reviews every registration, by `/events/info`'s word
  /// (`requires_approval`).
  bool _infoRequiresApproval = false;

  /// The club reviews every registration ("Review registrations"): the
  /// button says how, and the form sends one for review (the API's
  /// request). By the event's word, its ticket types' or the website
  /// page's; false when none says.
  bool get _requiresApproval =>
      _infoRequiresApproval ||
      (_ticketing?.requiresApproval ?? false) ||
      (_page?.requiresApproval ?? false);

  /// The event's tickets as the page offers them: an event whose club
  /// reviews every registration has no waiting list, whatever its tickets
  /// say (people register, and the club reviews each one).
  EventTicketing? get _tickets =>
      _requiresApproval ? _ticketing?.withoutWaitlist() : _ticketing;

  /// The club's "High demand" label (no number), while the event is still
  /// to come or on.
  bool get _showsHighDemand => showsHighDemand(
        highDemand: _page?.highDemand ?? false,
        ended: _page?.phase == EventPhase.ended ||
            _registerState.kind == RegisterKind.ended,
        cancelled: _cancellation != null,
      );

  /// Cancelled, by `/events/info`'s word or the website page's.
  EventCancellation? get _cancellation =>
      _infoCancellation ?? _page?.cancellation;

  /// The clubs co-hosting the event with its host, by `/events/info`'s word
  /// or the website page's; none on an event only its club hosts (and from
  /// an older server), which the page then shows as it always did.
  List<EventCohost> get _cohosts => infoCohosts.isNotEmpty
      ? infoCohosts
      : (_page?.cohosts ?? const <EventCohost>[]);

  /// The event's own club, its host, in the co-hosts' shape.
  EventCohost get _host {
    final info = club;
    final page = _page?.club;
    final named = info != null && info.name.trim().isNotEmpty;
    return EventCohost(
      clubId: info != null && info.id > 0 ? info.id : (page?.id ?? 0),
      name: named ? info.name.trim() : (page?.name ?? 'Organizer'),
      slug: info != null && info.slug.isNotEmpty ? info.slug : (page?.slug ?? ''),
      logo: imageUrlFrom(info?.logo) ?? page?.logo,
    );
  }

  /// A club's page: the host's, or a co-host's.
  void _openClub(EventCohost club) => openDiscoverClub(context,
      id: club.clubId, slug: club.slug, name: club.name);

  /// The title, then "Hosted by A and B" (or "A, B and C"): the host's logo
  /// first, then each co-host's, and each name opening its club.
  Widget _buildCohostedTitle() {
    return Column(
      key: const ValueKey('event-title-cohosted'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name ?? 'Event Name',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        HostedByLine(host: _host, cohosts: _cohosts, onOpen: _openClub),
      ],
    );
  }

  /// A ticket held on it was paid for: a cancelled event's refund applies.
  bool get _paidTicket =>
      isRegistered && !awaitingPayment && (hasFee ?? false);

  @override
  void initState() {
    super.initState();
    // Set initial status from navigation if provided
    if (widget.initialStatus != null) {
      if (widget.initialStatus == 'registered') {
        isRegistered = true;
        ticketUrl = widget.initialTicketUrl;
      } else if (widget.initialStatus == 'attended') {
        isAttended = true;
        certificateUrl = widget.initialCertificateUrl;
      } else if (widget.initialStatus == finishPaymentStatus ||
          widget.initialStatus == RegistrationStatus.awaitingPayment.name) {
        isRegistered = true;
        awaitingPayment = true;
        _finishPaymentOnLoad = widget.initialStatus == finishPaymentStatus;
      }
    }
    final liveSource = ref.read(liveRemoteDataSourceProvider);
    _live = LiveStreamClient<LiveFeed>(
      // Started only once the event has loaded, when its id is known.
      open: ({lastEventId, required abort}) => liveSource.openBannerStream(
        _idOrZero,
        lastEventId: lastEventId,
        abort: abort,
      ),
      poll: () => liveSource.fetchBanner(_idOrZero),
      parse: LiveFeed.tryParse,
      onData: (feed) {
        if (mounted) setState(() => live = feed);
      },
      // As the website: a stream only while the event is happening.
      shouldStream: (feed) => feed.isEventLive,
      // Without a stream (today's server), the strip is read every 30 s
      // while the page is in front, around the event's time.
      pollEvery: const Duration(seconds: 30),
      shouldPoll: _stripWorthPolling,
    );
    WidgetsBinding.instance.addObserver(this);
    _fetchData();
    if (widget.openLiveRoom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openLiveRoom();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _live.shown();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _live.hidden();
      case AppLifecycleState.inactive:
        // A call coming in, the app switcher opening: still on screen.
        break;
    }
  }

  /// Back online: the event again, over the saved copy shown offline. A
  /// failure on screen retries by itself (ErrorView).
  @override
  void onBackOnline() {
    if (!isLoading && errorMessage == null) _fetchData();
  }

  RegistrationStatus get _status {
    if (isAttended) return RegistrationStatus.attended;
    if (awaitingPayment) return RegistrationStatus.awaitingPayment;
    if (isRegistered) return RegistrationStatus.registered;
    return RegistrationStatus.none;
  }

  /// The event: the saved copy at once when there is one, then the
  /// network's. It carries the person's registration and ticket, so it is
  /// saved encrypted (personal). The steps that need the server's word --
  /// finishing a payment, the agenda, the store, the live room -- run once,
  /// after the fresh answer (or after the saved one, offline).
  Future<void> _fetchData() async {
    var gotFresh = false;
    try {
      await APIService.instance.getSavedThenFresh(
        '/events/info/${Uri.encodeComponent(widget.ref)}',
        policy: CachePolicy.personal,
        onData: (data, {required fresh}) {
          _applyEvent(data);
          gotFresh = gotFresh || fresh;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = readableError(
          e,
          fallback: 'Could not load this event.',
        );
        isLoading = false;
      });
      return;
    }
    if (!mounted || isLoading) return;
    // A link that named a hidden ticket type: the types again, with it.
    if (widget.linkedTicketTypeId != null) await _loadTicketing();
    if (!mounted) return;
    // A club that reviews every registration: the person's own registration
    // for it, if there is one, so the button opens it rather than
    // registering again. The event's `viewer_request` says it; a server
    // without it, My events' list.
    if (_requiresApproval &&
        !(_ticketing?.saysViewerRequest ?? false) &&
        ref.read(isAuthenticatedProvider)) {
      unawaited(ref
          .read(myRegistrationRequestsProvider.notifier)
          .refreshIfOlderThan(const Duration(seconds: 30)));
    }

    if (_finishPaymentOnLoad && gotFresh) {
      _finishPaymentOnLoad = false;
      if (awaitingPayment && !_eventEnded && _sellable) {
        unawaited(_finishPayment());
      }
    }
    await _fetchAgenda();
    await _fetchCatalog();
    if (!mounted) return;
    // The room fetched, as on every load; the stream follows while the
    // event is live, and while it streams there is nothing to fetch.
    _live.refresh();
  }

  /// Show [data], an `/events/info` answer (saved or fresh).
  void _applyEvent(Object? data) {
    if (!mounted) return;
    final Map<String, dynamic> raw = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};

    // Parse the JSON response into an EventInfo model.
    EventInfo eventInfo = EventInfo.fromJson(raw);
    final status = registrationStatusFrom(raw, carried: _status);

    // Update state with the parsed values.
    setState(() {
      id = eventInfo.id;
      name = eventInfo.name;
      slug = eventInfo.slug;
      poster = eventInfo.poster;
      eventDateTime = eventInfo.eventDateTime;
      // EventInfo reads a missing or zero length as 0; the page shows "—".
      duration = eventInfo.duration > 0 ? eventInfo.duration : null;
      locationName = eventInfo.locationName;
      locationLink = eventInfo.locationLink;
      hasFee = eventInfo.hasFee;
      regFee = eventInfo.regFee;
      hasPrize = eventInfo.hasPrize;
      prizeAmount = eventInfo.prizeAmount;
      isOnline = eventInfo.isOnline;
      regStartDate = eventInfo.regStartDate;
      regEndDate = eventInfo.regEndDate;
      club = eventInfo.club;
      infoCohosts = eventInfo.cohosts;
      category = eventInfo.category;
      interests = eventInfo.interests;
      topics = eventInfo.topics;
      additionalDetails = eventInfo.additionalDetails;
      rating = eventInfo.rating;
      totalRating = eventInfo.totalRating;
      about = eventInfo.about;
      contactPhone = eventInfo.contactPhone;
      contactEmail = eventInfo.contactEmail;
      url = eventInfo.url;

      // New registration/attendance fields
      // IMPORTANT: Use API values if available, otherwise preserve navigation values
      // This ensures status from EventCard navigation is not lost.
      // `is_paid: false` is a registration still waiting for its payment:
      // it has no ticket to view yet.
      isAttended = status == RegistrationStatus.attended;
      isRegistered = status != RegistrationStatus.none;
      awaitingPayment = status == RegistrationStatus.awaitingPayment;
      ticketRevoked = eventInfo.ticketRevoked;
      _networking = raw['networking'] is bool ? raw['networking'] as bool : null;
      registrationId = eventInfo.registrationId;
      // Only update URLs if API provides them
      if (eventInfo.ticketUrl != null && eventInfo.ticketUrl!.isNotEmpty) {
        ticketUrl = eventInfo.ticketUrl;
      }
      if (eventInfo.certificateUrl != null &&
          eventInfo.certificateUrl!.isNotEmpty) {
        certificateUrl = eventInfo.certificateUrl;
      }
      userRating = eventInfo.userRating;
      userPosition = eventInfo.userPosition;
      positionLabel = eventInfo.positionLabel;
      downloads = eventInfo.downloads;
      infoSpeakers = eventInfo.speakers;
      infoGuidelines = eventInfo.guidelines;
      infoContact = eventInfo.contact;
      infoLat = eventInfo.lat;
      infoLng = eventInfo.lng;
      feedbackUrl = eventInfo.feedbackUrl;
      _infoCancellation = EventCancellation.of(raw);
      _infoRequiresApproval = jsonBool(raw['requires_approval']) ?? false;
      // An older server sends no `ticketing`: the page is as it was. The
      // hidden type a link named stays until the types are read again.
      final ticketing = EventTicketing.fromJson(raw['ticketing']);
      if (ticketing != null &&
          (widget.linkedTicketTypeId == null || _ticketing == null)) {
        _ticketing = ticketing;
      }

      isLoading = false;

      // CRITICAL: Check if registration is already closed IMMEDIATELY
      if (regEndDate != null && regEndDate!.isBefore(DateTime.now())) {
        registrationClosed = true;
      }
    });
  }

  /// Registers again with the same details: for a signed-in person's unpaid
  /// registration the server answers with that registration and what it owes.
  Future<Map<String, dynamic>> _registerAgain(
    int eventId,
    Map<String, dynamic> body,
  ) async {
    final response = await APIService.instance.request(
      '/events/registration/$eventId/register',
      DioMethod.post,
      param: body,
    );
    final data = response.data;
    return data is Map<String, dynamic> ? data : const <String, dynamic>{};
  }

  /// Pays for this event's unpaid registration, then refreshes the event so
  /// the ticket shows.
  Future<void> _finishPayment() async {
    if (_paying) return;
    if (!_sellable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(iosOnlineSaleBlockedMessage)),
      );
      return;
    }
    setState(() => _paying = true);
    try {
      var profile = ref.read(profileProvider).profile;
      if (profile == null) {
        await ref.read(profileProvider.notifier).loadProfile();
        profile = ref.read(profileProvider).profile;
      }
      final phone = (profile?.phone?.isNotEmpty ?? false)
          ? profile!.phone
          : profile?.whatsapp;
      final repository = ref.read(paymentRepositoryProvider);
      final outcome = await FinishPayment(
        register: _registerAgain,
        pay: ({
          required int eventId,
          required String registrationId,
          required String name,
          required String email,
          required String phone,
        }) =>
            RegistrationCheckout.pay(
          repository: repository,
          eventId: eventId,
          registrationId: registrationId,
          name: name,
          email: email,
          phone: phone,
          sellable: _sellable,
        ),
      ).run(
        eventId: _idOrZero,
        questions: additionalDetails,
        name: profile?.fullName ?? '',
        email: profile?.email ?? '',
        phone: phone,
        registrationId: registrationId,
      );
      if (!mounted) return;

      switch (outcome.result) {
        case FinishPaymentResult.paid:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Payment received. Your ticket is ready.')),
          );
          // Paid, whatever an older server (one without `is_paid`) can say;
          // the refresh brings the ticket.
          setState(() => awaitingPayment = false);
          await _fetchData();
        case FinishPaymentResult.notCompleted:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment not completed. Your registration is saved — tap Finish payment to try again.'),
            ),
          );
        case FinishPaymentResult.needsForm:
          await _openRegistrationForm();
        case FinishPaymentResult.closed:
          setState(() => _paymentClosed = true);
          await showRegistrationRefusal(context, outcome.refusal!);
        case FinishPaymentResult.refused:
          await showRegistrationRefusal(context, outcome.refusal!);
          await _fetchData();
        case FinishPaymentResult.failed:
          showPaymentFailure(context, outcome.failure!);
          await _fetchData();
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// The registration form, then whatever it was closed with: straight to
  /// the ticket or the payment when a refusal offered it. The event is
  /// fetched again either way -- a registration may now exist.
  Future<void> _openRegistrationForm() async {
    final signedIn = await ensureSignedInFor(
      context,
      ref,
      reason: 'Sign in to register for ${name ?? 'this event'}. '
          "You'll come back here.",
    );
    if (!signedIn || !mounted) return;
    final result = await context.push<Object?>(
      '/events/$_idOrZero/register',
      extra: {
        'additionalDetails': additionalDetails,
        'hasFee': hasFee ?? false,
        'isOnline': isOnline ?? false,
        // "Get updates from <club> on WhatsApp", for a club that offers it.
        'clubName': club?.name ?? '',
        'clubUpdates': club?.whatsappUpdates == true,
        if (widget.linkedTicketTypeId != null)
          'linkedTicketType': widget.linkedTicketTypeId,
        if (name != null) 'eventName': name,
        'requiresApproval': _requiresApproval,
      },
    );
    if (!mounted) return;
    await _fetchData();
    if (!mounted) return;
    if (result == RegistrationAction.viewTicket && isRegistered) {
      if (awaitingPayment) return;
      _openTicket();
    } else if (result == RegistrationAction.finishPayment && awaitingPayment) {
      await _finishPayment();
    } else if (result == RegistrationAction.joinWaitlist &&
        !isRegistered &&
        !_requiresApproval) {
      await _joinWaitlist();
    }
  }

  /// The ticket types again: with the hidden type a link named, and the
  /// person's place in line. A failure keeps what the page has.
  Future<void> _loadTicketing() async {
    final id = _eventId;
    if (id == null) return;
    try {
      final ticketing = await ref
          .read(ticketingApiProvider)
          .ticketTypes(id, linked: widget.linkedTicketTypeId);
      if (ticketing != null && mounted) {
        setState(() => _ticketing = ticketing);
      }
    } catch (e) {
      debugPrint('Ticket types for $id: $e');
    }
  }

  /// "Join the waiting list": signed in (the offer comes by push to the
  /// account too, and leaving needs it), then who to tell and for which
  /// ticket. [type] is the one asked for, from the list of tickets.
  Future<void> _joinWaitlist({TicketType? type}) async {
    final signedIn = await ensureSignedInFor(
      context,
      ref,
      reason: 'Sign in to join the waiting list for ${name ?? 'this event'}.',
    );
    if (!signedIn || !mounted) return;
    var profile = ref.read(profileProvider).profile;
    if (profile == null) {
      await ref.read(profileProvider.notifier).loadProfile();
      if (!mounted) return;
      profile = ref.read(profileProvider).profile;
    }
    final phone = (profile?.phone?.isNotEmpty ?? false)
        ? profile!.phone
        : profile?.whatsapp;
    final entry = await showJoinWaitlistSheet(
      context,
      event: _idOrZero,
      ticketing: _tickets,
      api: ref.read(ticketingApiProvider),
      name: profile?.fullName,
      email: profile?.email,
      phone: phone,
      ticketTypeId: type?.id,
      clubName: _page?.club?.name ?? club?.name,
    );
    if (entry == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(joinedWaitlistMessage(entry))),
    );
    await _fetchData();
  }

  /// Leaves every place in line, once the person says so.
  Future<void> _leaveWaitlist() async {
    if (_leavingWaitlist || !await confirmLeaveWaitlist(context) || !mounted) {
      return;
    }
    setState(() => _leavingWaitlist = true);
    try {
      await ref.read(ticketingApiProvider).leaveWaitlist(_idOrZero);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You've left the waiting list.")),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(readableError(e,
            fallback: "We couldn't take you off the waiting list. Try again.")),
      ));
    } finally {
      if (mounted) setState(() => _leavingWaitlist = false);
    }
  }

  /// The event's canonical address on the website.
  String get _canonicalUrl => eventCanonicalUrl(
        id: _idOrZero,
        slug: slug ?? _page?.slug,
        apiUrl: _page?.url,
      );

  /// Shares the event's page on the website.
  Future<void> _shareEvent() async {
    final link = _canonicalUrl;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      name == null || name!.isEmpty ? link : '$name\n$link',
      subject: name,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  /// The agenda is public and optional: an event without one, or a failed
  /// call, simply shows no agenda section.
  Future<void> _fetchAgenda() async {
    try {
      final Response<dynamic> res = await APIService.instance.request(
        '/events/$_idOrZero/agenda',
        DioMethod.get,
        cache: CachePolicy.shared,
      );
      final data = res.data;
      if (data is Map<String, dynamic> && mounted) {
        setState(() => agenda = Agenda.fromJson(data));
      }
    } catch (_) {
      // Nothing to show; the event itself has loaded.
    }
  }

  /// The live room: a banner, a poll or a quiz up right now earns a strip.
  LiveFeed live = LiveFeed.empty;

  /// Keeps [live] current. The page fetches the room as it always has (on
  /// load and on each reload); while that -- or a snapshot -- says the event
  /// is live (`event.status`), the room's stream (`view=room`) keeps the
  /// strip current as long as the page is open and the app in front. Before
  /// the event, after it, and on a server without streams (today's answers
  /// 404) the one fetch is all there is. A failed fetch leaves the strip as
  /// it was: the room is optional; the event itself has loaded.
  late final LiveStreamClient<LiveFeed> _live;

  /// Whether the strip is worth reading every 30 s: from three hours before
  /// the event until six after it (or while its room says it is live), and
  /// never once the room has closed.
  bool _stripWorthPolling(LiveFeed? feed) {
    if (feed != null && feed.isClosed) return false;
    if (feed != null && feed.isEventLive) return true;
    final start = feed?.startsAt ?? eventDateTime;
    if (start == null) return false;
    final end = feed?.endsAt ?? start.add(hoursToDuration(duration ?? 0));
    final now = DateTime.now();
    return now.isAfter(start.subtract(const Duration(hours: 3))) &&
        now.isBefore(end.add(const Duration(hours: 6)));
  }

  /// Whether the live room is open to go into: the room says the event is
  /// live, or -- from a server that does not say -- the event's dates do.
  bool get _liveRoomOpen => live.eventStatus != null
      ? live.isEventLive
      : _registerState.kind == RegisterKind.live;

  /// The live room, in the app, on top of this page: Back comes back here.
  /// The strip rests while it is open, and is read again on the way back.
  Future<void> _openLiveRoom() async {
    _live.hidden();
    await openLiveRoom(context, _eventId ?? widget.ref, eventName: name);
    if (mounted) _live.shown();
  }

  /// "OPEN THE LIVE ROOM" beside the ticket or the certificate, while the
  /// room is open.
  Widget _liveRoomButton() => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('open-live-room'),
            onPressed: _openLiveRoom,
            icon: const Icon(Icons.podcasts, size: 18),
            label: const Text('OPEN THE LIVE ROOM'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2C333D),
              side: const BorderSide(color: Color(0xFF2C333D)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      );

  Widget _buildLiveStrip(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF14B8A6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(live.headline, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _openLiveRoom,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2C333D),
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('Open the live room'),
          ),
        ],
      ),
    );
  }

  /// What the event sells with its ticket; shown so people know before they register.
  StoreCatalog catalog = StoreCatalog.empty;

  Future<void> _fetchCatalog() async {
    try {
      final Response<dynamic> res = await APIService.instance.request(
        '/events/$_idOrZero/store/catalog',
        DioMethod.get,
        skipAuth: true,
        cache: CachePolicy.shared,
      );
      final data = res.data;
      if (data is Map<String, dynamic> && mounted) {
        setState(() => catalog = StoreCatalog.fromJson(data));
      }
    } catch (_) {
      // Nothing on sale, or nothing reachable; the event itself has loaded.
    }
  }

  Widget _buildStoreSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('On sale with your ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Pick these when you register and pay once.', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        for (final item in catalog.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      if (item.hasSizes) Text(item.variants.map((v) => v.label).join(' · '), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Text(item.isFree ? 'Free' : MerchPicker.rupees(item.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAgendaSection(BuildContext context) {
    final time = DateFormat('HH:mm');
    final dayFormat = DateFormat('EEEE d MMMM');
    final days = agenda.byDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Agenda',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final entry in days.entries) ...[
          if (days.length > 1) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                dayFormat.format(entry.key).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey.shade300),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                time.format(entry.value[i].startsAt.toLocal()),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (entry.value[i].endsAt != null)
                                Text(
                                  '– ${time.format(entry.value[i].endsAt!.toLocal())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.value[i].title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (entry.value[i].parallel)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Parallel',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (entry.value[i].detail.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    entry.value[i].detail,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              if (entry.value[i].description != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    entry.value[i].description!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ------------------------------------------- what the website shows too

  /// The speakers: the website API's, else /events/info's.
  List<EventPerson> get _speakers {
    final fromPage = _page?.speakers ?? const <EventPerson>[];
    return fromPage.isNotEmpty ? fromPage : infoSpeakers;
  }

  String? get _guidelines => _page?.guidelines ?? infoGuidelines;

  EventContact get _contact =>
      (_page?.contact ?? EventContact.none).or(infoContact);

  double? get _lat => _page?.lat ?? infoLat;
  double? get _lng => _page?.lng ?? infoLng;

  /// Directions to the venue in the phone's maps app; null with nothing to
  /// go on.
  Uri? get _directions => directionsUri(
        ios: defaultTargetPlatform == TargetPlatform.iOS,
        lat: _lat,
        lng: _lng,
        name: locationName ?? _page?.locationName,
        link: (locationLink?.isNotEmpty ?? false)
            ? locationLink
            : _page?.locationLink,
      );

  Future<void> _openDirections() async {
    final uri = _directions;
    if (uri == null) return;
    final opened = await ref.read(linkLauncherProvider)(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open your maps app")),
      );
    }
  }

  Future<void> _openLink(Uri uri, String failure) async {
    final opened = await ref.read(linkLauncherProvider)(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  /// "Add to calendar": the phone's calendar, or Google Calendar's page
  /// when there is no calendar app to take it.
  Future<void> _addToCalendar() async {
    final entry = calendarEntryFor(
      name: name ?? '',
      startsAt: eventDateTime,
      endsAt: _page?.endsAt,
      durationHours: duration,
      isOnline: isOnline ?? false,
      locationName: locationName,
      about: about,
      url: _canonicalUrl,
    );
    if (entry == null) return;
    final outcome = await addToCalendarWith(ref, entry);
    if (outcome == CalendarOutcome.failed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open your calendar")),
      );
    }
  }

  /// Another event, from a rail: by id, which every router reads.
  void _openRailEvent(EventSummary event) {
    context.push(event.route);
  }

  /// "Your team": the competition page for this event.
  void _openCompetition() {
    context.push('/events/$_idOrZero/compete',
        extra: {'eventName': name ?? 'Event'});
  }

  /// The feedback survey: here, natively, from the link the server gave;
  /// the website's page inside the app for any other link.
  Future<void> _openFeedback() async {
    final link = feedbackUrl;
    if (link == null) return;
    final route = feedbackRouteFrom(link);
    if (route != null) {
      await context.push(route);
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri != null) await _openLink(uri, "Couldn't open the survey");
  }

  /// Speakers, the agenda, the sponsors and partners, the venue,
  /// guidelines, the team, contact, and the rails -- the website's order --
  /// each only when there is something to show.
  List<Widget> _buildWebsiteSections(BuildContext context) {
    final page = _page;
    final speakers = _speakers;
    final guidelines = _guidelines;
    final contact = _contact;
    final online = isOnline ?? page?.isOnline ?? false;
    final hasVenue = online ||
        (locationName?.isNotEmpty ?? false) ||
        (_lat != null && _lng != null);
    final team = page?.team ?? const <EventPerson>[];
    final clubName = page?.club?.name ?? club?.name;
    final clubId = club?.id ?? page?.club?.id;
    final more = page?.moreFromClub ?? const <EventSummary>[];
    final similar = page?.similar ?? const <EventSummary>[];
    final sponsors = page?.sponsors ?? const <EventBacker>[];
    final partners = page?.partners ?? const <EventBacker>[];
    return [
      if (speakers.isNotEmpty)
        EventPeopleSection(
          key: const ValueKey('event-speakers'),
          title: speakers.length == 1 ? 'Speaker' : 'Speakers',
          people: speakers,
          speakers: true,
        ),
      // The run of show, when the organiser has written one: after the
      // speakers, as on the website.
      if (agenda.items.isNotEmpty) _buildAgendaSection(context),
      // The event's own sponsors, then its partners: after the agenda, as on
      // the website.
      if (sponsors.isNotEmpty)
        EventBackersSection(
          key: const ValueKey('event-sponsors'),
          title: sponsors.length == 1 ? 'Sponsor' : 'Sponsors',
          backers: sponsors,
          onOpen: (uri) => _openLink(uri, "Couldn't open the link"),
        ),
      if (partners.isNotEmpty)
        EventBackersSection(
          key: const ValueKey('event-partners'),
          title: partners.length == 1 ? 'Partner' : 'Partners',
          backers: partners,
          onOpen: (uri) => _openLink(uri, "Couldn't open the link"),
        ),
      if (hasVenue)
        EventVenueSection(
          isOnline: online,
          locationName: locationName ?? page?.locationName,
          lat: _lat,
          lng: _lng,
          onDirections: _directions == null ? null : _openDirections,
        ),
      if (guidelines != null)
        EventSection(
          key: const ValueKey('event-guidelines'),
          title: 'Guidelines',
          child: ExpandableText(guidelines),
        ),
      if (team.isNotEmpty)
        EventPeopleSection(
          key: const ValueKey('event-team'),
          // The host's team. On a co-hosted event "Hosted by" is the line
          // under the title, naming every club; this is only the host's.
          title: page?.teamSource == TeamSource.club
              ? (_cohosts.isEmpty
                  ? 'Hosted by ${clubName ?? 'the club'}'
                  : 'The team at ${clubName ?? 'the host'}')
              : 'Organising team',
          people: team,
          trailing: page?.teamSource == TeamSource.club &&
                  clubId != null &&
                  clubId > 0
              ? TextButton(
                  onPressed: () => context.push('/clubs/$clubId', extra: {
                    'clubSlug': club?.slug ?? page?.club?.slug ?? '',
                    'clubName': clubName ?? '',
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2C333D),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('About the club'),
                )
              : null,
        ),
      if (!contact.isEmpty)
        EventContactSection(
          key: const ValueKey('event-contact'),
          contact: contact,
          onEmail: contact.email == null
              ? null
              : () => _openLink(
                  Uri(scheme: 'mailto', path: contact.email),
                  "Couldn't open your email app"),
          onCall: contact.dialable == null
              ? null
              : () => _openLink(Uri(scheme: 'tel', path: contact.dialable),
                  "Couldn't start a call"),
        ),
      if (more.isNotEmpty)
        EventRail(
          key: const ValueKey('rail-more-from-club'),
          title: 'More from ${clubName ?? 'this club'}',
          events: more,
          onOpen: _openRailEvent,
          onSeeAll: clubId == null || clubId <= 0
              ? null
              : () => context.push('/clubs/$clubId', extra: {
                    'clubSlug': club?.slug ?? page?.club?.slug ?? '',
                    'clubName': clubName ?? '',
                  }),
        ),
      if (similar.isNotEmpty)
        EventRail(
          key: const ValueKey('rail-similar'),
          title: 'Similar events',
          events: similar,
          onOpen: _openRailEvent,
        ),
    ];
  }

  /// The countdown reached the deadline while the page was open.
  void _onRegistrationClosed() {
    if (mounted && !registrationClosed) {
      setState(() => registrationClosed = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live.close();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    int hour = dt.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    String minute = dt.minute.toString().padLeft(2, '0');
    return "$hour12:$minute $period";
  }

  /// Shows date of event popup
  void _showDatePopup(BuildContext context) {
    final List<String> months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    String formattedDate = eventDateTime != null
        ? "${_getOrdinal(eventDateTime!.day)} ${months[eventDateTime!.month - 1]} ${eventDateTime!.year}"
        : 'N/A';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 28,
                child: Image.asset(AssetResources.eventdate,
                    height: 28, width: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Date of Event',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasNeue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows registration fee popup
  void _showFeePopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 28,
                child:
                    Image.asset(AssetResources.regfee, height: 28, width: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Registration Fee',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                hasFee == true ? '₹ $regFee' : 'Free',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasNeue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows location popup with Open Maps button
  void _showLocationPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 28,
                child:
                    Image.asset(AssetResources.location, height: 28, width: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Location',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                locationName?.toUpperCase() ?? 'N/A',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasNeue',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Try locationLink first, fallback to Google Maps search
                    String mapsUrl;
                    if (locationLink != null && locationLink!.isNotEmpty) {
                      mapsUrl = locationLink!;
                    } else if (locationName != null &&
                        locationName!.isNotEmpty) {
                      mapsUrl =
                          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationName!)}';
                    } else {
                      return;
                    }
                    final Uri url = Uri.parse(mapsUrl);
                    // Never throws: no maps app is a no-op, not a crash.
                    await openExternally(url);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C333D),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OPEN MAPS',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'BebasNeue',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows prize worth popup
  void _showPrizePopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 28,
                child: Image.asset(AssetResources.prize, height: 28, width: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Prize Worth',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                hasPrize == true ? '₹ $prizeAmount' : 'None',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasNeue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows time of event popup
  void _showTimePopup(BuildContext context) {
    String formattedTime =
        eventDateTime != null ? _formatTime(eventDateTime!) : 'N/A';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 28,
                child: Image.asset(AssetResources.eventtime,
                    height: 28, width: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Time of Event',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                formattedTime,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasNeue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows duration popup
  void _showDurationPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 28,
                child:
                    Image.asset(AssetResources.duration, height: 28, width: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Duration',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                duration == null ? '—' : hoursLabel(duration!),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasNeue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to get ordinal suffix (1st, 2nd, 3rd, etc.)
  String _getOrdinal(int day) {
    if (day >= 11 && day <= 13) return '${day}TH';
    switch (day % 10) {
      case 1:
        return '${day}ST';
      case 2:
        return '${day}ND';
      case 3:
        return '${day}RD';
      default:
        return '${day}TH';
    }
  }

  /// Helper to get ordinal position text (1st, 2nd, 3rd, etc. lowercase)
  String _getOrdinalPosition(int position) {
    if (position >= 11 && position <= 13) return '${position}th';
    switch (position % 10) {
      case 1:
        return '${position}st';
      case 2:
        return '${position}nd';
      case 3:
        return '${position}rd';
      default:
        return '${position}th';
    }
  }

  /// Shows rating bottom sheet
  void _showRatingDialog(BuildContext context) {
    int selectedRating = 0;
    final reviewController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'RATE YOUR EXPERIENCE',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Description with club name
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'How '),
                    TextSpan(
                      text: club?.name ?? 'the organizer',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text:
                          ' do? Let them know your thoughts and help them improve for future events. Your feedback means everything! 💬✨',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cat Emoji Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final ratingEmojis = ['😾', '😿', '🐱', '😸', '😻'];
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedRating = index + 1;
                      });
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedRating == index + 1
                            ? const Color(0xFFE8F5E9)
                            : Colors.transparent,
                      ),
                      child: Center(
                        child: Text(
                          ratingEmojis[index],
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Review Text Field
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: reviewController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Write Your Review',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selectedRating > 0
                      ? () async {
                          Navigator.pop(context);
                          await _submitRating(
                              selectedRating, reviewController.text);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C333D),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SUBMIT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Submit rating to API
  Future<void> _submitRating(int ratingValue, String? review) async {
    try {
      await APIService.instance.request(
        '/events/rate/$_idOrZero',
        DioMethod.post,
        param: {
          'rating': ratingValue,
          if (review != null && review.isNotEmpty) 'review': review,
        },
      );

      if (!mounted) return;
      setState(() {
        // The picker offers whole stars; the field holds the
        // server's float, so widen rather than narrow.
        userRating = ratingValue.toDouble();
      });

      if (mounted) {
        showToast(context, 'Thanks for your rating!',
            icon: Icons.star_rounded);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(readableError(
              e,
              fallback: "We couldn't submit your rating. Please try again.",
            )),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _page = ref.watch(eventPageDetailsProvider(widget.ref)).valueOrNull;
    // Loading and error handling.
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Event Details',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
          ),
        ),
        body: ShimmerEventDetail(
          poster: widget.posterHero == null
              ? null
              : PosterHero(
                  tag: widget.posterHero,
                  child: AspectRatio(
                    aspectRatio: posterAspectRatio,
                    child: EventPosterImage(
                      poster: widget.posterHint?.poster,
                      eventId: widget.eventId ?? widget.ref,
                      categoryId: widget.posterHint?.categoryId,
                      categoryName: widget.posterHint?.categoryName,
                      startsAt: widget.posterHint?.startsAt,
                      isOnline: widget.posterHint?.isOnline ?? false,
                      slot: PosterSlot.hero,
                      borderRadius: BorderRadius.circular(8.0),
                      placeholder: widget.posterHint
                          ?.cardPoster(widget.eventId ?? widget.ref),
                    ),
                  ),
                ),
        ),
      );
    }
    if (errorMessage != null) {
      debugPrint(errorMessage);
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Event Details',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
          ),
        ),
        body: ErrorView(
          message: errorMessage,
          onRetry: () {
            setState(() {
              isLoading = true;
              errorMessage = null;
            });
            _fetchData();
          },
        ),
      );
    }

    // Build the UI.
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // Use category name in the AppBar title if available.
        title: Text(
          category?.name ?? 'Event Details',
          style: const TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        actions: [
          if (eventDateTime != null && !_eventEnded)
            IconButton(
              tooltip: 'Add to calendar',
              icon: const Icon(Icons.event_available_outlined),
              onPressed: _addToCalendar,
            ),
          IconButton(
            tooltip: 'Share event',
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareEvent,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0).copyWith(
          bottom: 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event poster, or its drawn cover when it has none -- where a
            // card's poster flies to (and back from).
            PosterHero(
              tag: widget.posterHero,
              // 4:5, the poster's own shape: shown whole, never cropped.
              child: AspectRatio(
                aspectRatio: posterAspectRatio,
                child: EventPosterImage(
                  poster: poster,
                  eventId: _eventId ?? widget.ref,
                  // A missing category parses as id 0 and an empty name.
                  categoryId:
                      (category?.id ?? 0) != 0 ? category!.id : null,
                  categoryName: category?.name,
                  startsAt: eventDateTime,
                  isOnline: isOnline ?? false,
                  slot: PosterSlot.hero,
                  borderRadius: BorderRadius.circular(8.0),
                  // Opened from a card: its poster until this one loads.
                  placeholder:
                      widget.posterHint?.cardPoster(_eventId ?? widget.ref),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Title & Organizer. On an event other clubs co-host: the title,
            // then "Hosted by A and B", with every club's logo and name.
            if (_cohosts.isNotEmpty)
              _buildCohostedTitle()
            else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Club logo - tap to go to club page
                InkWell(
                  onTap: () {
                    if (club != null) {
                      context.push('/clubs/${club!.id}', extra: {
                        'clubSlug': club!.slug,
                        'clubName': club!.name,
                      });
                    }
                  },
                  child: _ClubLogo(url: imageUrlFrom(club?.logo)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Event Name',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Club name - tap to go to club page
                      InkWell(
                        onTap: () {
                          if (club != null) {
                            context.push('/clubs/${club!.id}', extra: {
                              'clubSlug': club!.slug,
                              'clubName': club!.name,
                            });
                          }
                        },
                        child: Text(
                          club?.name ?? 'Organizer',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((_page?.club?.followers ?? 0) > 0)
                        Text(
                          _page!.club!.followers == 1
                              ? '1 follower'
                              : '${NumberFormat.compact(locale: 'en').format(_page!.club!.followers)} followers',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // The club's "High demand" label, beside the topics' chips.
            if (_showsHighDemand) ...[
              const SizedBox(height: 16),
              const HighDemandChip(),
            ],
            // Its topics in their colours, then its interests. A topic
            // opens its own page, as on the site.
            TopicTagStrip(
              topGap: 16,
              declared: topics,
              interests: [for (final i in interests) i.toEntity()],
              showInterests: true,
              onTopicTap: (topic) => context.push(topicLocation(topic.slug)),
            ),
            // Called off: said first, with the club's reason and, for a
            // paid ticket, the refund.
            if (_cancellation case final cancelled?) ...[
              const SizedBox(height: 16),
              CancelledNotice(
                cancellation: cancelled,
                registered: isRegistered,
                paid: _paidTicket,
              ),
            ],
            // People Like You: the way in while checked in, a word on the
            // day before that; nothing otherwise.
            PeopleLikeYouCard(
              eventId: _eventId,
              eventName: name,
              status: _status,
              networking: _networking,
              startsAt: eventDateTime,
              durationHours: duration,
              revoked: _ticketRevoked,
            ),

            const SizedBox(height: 16),
            // Info Grid.
            // Info Grid.
            // Row 1: Date | (Fee or Location)
            // Info Grid.
            // Row 1: Date | Fee
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showDatePopup(context),
                    child: _infoCard(
                      context,
                      icon: AssetResources.eventdate,
                      title: 'Date of Event',
                      value: eventDateTime != null
                          ? "${eventDateTime!.day}-${eventDateTime!.month}-${eventDateTime!.year}"
                          : 'N/A',
                    ),
                  ),
                ),
                // No price on an iPhone for an event it doesn't sell: a
                // price reads as an offer.
                if (_sellable) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showFeePopup(context),
                      child: _infoCard(
                        context,
                        icon: AssetResources.regfee,
                        title: 'Registration Fee',
                        // Several ticket types: their prices, low to high.
                        value: (_ticketing?.types.length ?? 0) > 1
                            ? _ticketing!.priceRange!
                            : hasFee == true
                                ? '₹ $regFee'
                                : 'Free',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Row 2: Time | Duration
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showTimePopup(context),
                    child: _infoCard(
                      context,
                      icon: AssetResources.eventtime,
                      title: 'Time of Event',
                      value: eventDateTime != null
                          ? _formatTime(eventDateTime!)
                          : 'N/A',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showDurationPopup(context),
                    child: _infoCard(
                      context,
                      icon: AssetResources.duration,
                      title: 'Duration',
                      value: duration == null ? '—' : hoursLabel(duration!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 3: Location | Prize (or Location Full Width)
            if (hasPrize == true)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showLocationPopup(context),
                      child: _infoCard(
                        context,
                        icon: AssetResources.location,
                        title: 'Location',
                        value: locationName ?? 'N/A',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showPrizePopup(context),
                      child: _infoCard(
                        context,
                        icon: AssetResources.prize,
                        title: 'Prize Worth',
                        value: '₹ $prizeAmount',
                      ),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: () => _showLocationPopup(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(7.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 4),
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 24,
                        child: Image.asset(
                          AssetResources.location,
                          height: 25,
                          width: 25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 16,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locationName?.toUpperCase() ?? 'N/A',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontFamily: 'BebasNeue',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // ========== ATTENDED SECTION (before description) ==========
            if (isAttended) ...[
              // 1. Congrats message (grey box)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Congrats on crushing it! 🎉 You\'ve successfully attended the event',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Position highlight (yellow/amber box - only if position available)
              if (userPosition != null && userPosition! > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🏆 Woohoo! You nailed it! Secured an impressive ${_getOrdinalPosition(userPosition!)} position${positionLabel != null ? ' in the $positionLabel' : ''}.',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 3. Downloads section (blue box - only if downloads available)
              if (downloads.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📁 Grab the files from the session here!',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      ...downloads.map((download) => InkWell(
                            onTap: () async {
                              final Uri url = Uri.parse(download.url);
                              await openExternally(url);
                            },
                            child: Text(
                              download.name.isEmpty
                                  ? 'Download now'
                                  : download.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 4),
              ],

            ],

            // ========== FEEDBACK (after attending) ==========
            if (isAttended)
              FeedbackEntryCard(
                clubName: club?.name,
                onOpen: feedbackUrl == null ? null : _openFeedback,
              ),

            // ========== THE LIVE ROOM (while something is up) ==========
            if (live.isActive) _buildLiveStrip(context),

            // ========== YOUR TEAM (an event with a competition) ==========
            if ((isRegistered || isAttended) &&
                !awaitingPayment &&
                _eventId != null &&
                (ref.watch(competitionEnabledProvider(_eventId!)).valueOrNull ??
                    false))
              CompetitionEntryCard(onTap: _openCompetition),

            // ========== TICKETS (an event selling several types) ==========
            if (_cancellation == null &&
                _sellable &&
                (_ticketing?.types.length ?? 0) > 1) ...[
              TicketTypesList(
                types: _tickets!.types,
                // None on an event whose club reviews every registration.
                onJoinWaitlist: isRegistered || _requiresApproval
                    ? null
                    : (type) => _joinWaitlist(type: type),
              ),
              const SizedBox(height: 8),
            ],

            // ========== MAIN DESCRIPTION ==========
            Text(
              about ?? 'Event description not available.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),

            // ========== ON SALE WITH THE TICKET ==========
            // Bought with the ticket, so not offered where the ticket isn't.
            if (catalog.hasAnything && _sellable) _buildStoreSection(context),

            // ========== RATE AND RATING SECTION (only for attended) ==========
            if (isAttended) ...[
              // Rate the Event button (only if not rated yet)
              if (userRating == null || userRating == 0) ...[
                OutlinedButton(
                  onPressed: () async {
                    if (await ensureSignedInFor(context, ref,
                            reason: 'Sign in to rate this event.') &&
                        context.mounted) {
                      _showRatingDialog(context);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Rate the Event',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Rating display section (if event has ratings)
              if (rating != null && rating! > 0) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Stars and rating
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RatingStars(
                          rating: rating!,
                          size: 20,
                          alignment: MainAxisAlignment.start,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // Rating is already 0-5 scale, display directly
                          '${rating!.toStringAsFixed(1)} RATED',
                          style: const TextStyle(
                            fontSize: 20,
                            fontFamily: 'BebasNeue',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rated by $totalRating Participants',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],

            // ========== WHAT THE WEBSITE'S PAGE SHOWS ==========
            ..._buildWebsiteSections(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
      // BottomSheet - different UI based on status
      bottomSheet: _buildBottomSheet(context),
    );
  }

  /// Builds the bottom sheet based on event status
  Widget _buildBottomSheet(BuildContext context) {
    // Called off: nothing to register, pay or show at the door.
    if (_cancellation != null) return _buildCancelledBottomSheet(context);

    // Priority 1: Check if user has attended (past event they attended)
    if (isAttended) {
      return _buildCertificateBottomSheet(context);
    }

    // Priority 2: Registered for a paid event and not paid: no ticket yet.
    if (awaitingPayment) {
      return _buildFinishPaymentBottomSheet(context);
    }

    // Priority 3: Check if user is registered (upcoming event they registered for)
    if (isRegistered) {
      return _buildTicketBottomSheet(context);
    }

    // Default: Show registration UI
    return _buildRegistrationBottomSheet(context);
  }

  /// A cancelled event: one line, no button that does anything. The notice
  /// on the page says why and what happens to a payment.
  Widget _buildCancelledBottomSheet(BuildContext context) {
    return Container(
      key: const ValueKey('event-cancelled-sheet'),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRegistered && _paidTicket)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                EventCancellation.refundNote,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              child: Text('EVENT CANCELLED'),
            ),
          ),
        ],
      ),
    );
  }

  /// Whether the event is over: an unpaid registration can be paid for after
  /// the registration deadline, but not once the event has ended.
  bool get _eventEnded {
    final start = eventDateTime;
    if (start == null) return false;
    return start.add(hoursToDuration(duration ?? 0)).isBefore(DateTime.now());
  }

  /// Bottom sheet for a registration still waiting for its payment.
  ///
  /// The registration deadline doesn't stop it: an existing registration
  /// can be paid for until the event ends. Closed is shown only once the
  /// server has refused the payment.
  Widget _buildFinishPaymentBottomSheet(BuildContext context) {
    if (!_sellable) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
        child: const IosSaleBlockedNotice(),
      );
    }
    final String banner;
    final String? blocked;
    if (_paymentClosed) {
      banner = 'Registration closed before your payment went through';
      blocked = 'REGISTRATION CLOSED';
    } else if (_eventEnded) {
      banner = 'This event ended before your payment went through';
      blocked = 'EVENT ENDED';
    } else {
      banner = 'Registered — finish the payment to get your ticket';
      blocked = null;
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              banner,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
                color: Color(0xFF8A4B00),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Pressable(
              enabled: !_paying && blocked == null,
              child: FilledButton(
                onPressed: (_paying || blocked != null) ? null : _finishPayment,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C333D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _paying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(blocked ?? 'FINISH PAYMENT'),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// What the register button can do now: from the website API's status
  /// and seats when it has them, else from the dates (the countdown's own
  /// "closed" included).
  RegisterState get _registerState {
    final page = _page;
    final state = registerStateFor(
      now: DateTime.now(),
      phase: page?.phase,
      registrationOpen: page?.registrationOpen,
      capacity: page?.capacity,
      seatsLeft: page?.seatsLeft,
      regOpensAt: page?.regOpensAt ?? regStartDate,
      regClosesAt: page?.regClosesAt ?? regEndDate,
      startsAt: eventDateTime,
      endsAt: page?.endsAt ??
          eventDateTime?.add(hoursToDuration(duration ?? 0)),
    );
    // The countdown reached nought while the page was open.
    if (registrationClosed && state.canRegister) {
      return const RegisterState(
          kind: RegisterKind.closed, label: 'REGISTRATION CLOSED');
    }
    return state;
  }

  /// Bottom sheet for registration state: the countdown or a note, the
  /// seats, and the one button -- or, on an iPhone, for a paid online
  /// event, the line saying it isn't sold here, with no price and no button.
  Widget _buildRegistrationBottomSheet(BuildContext context) {
    final state = _registerState;
    final page = _page;
    final showCountdown =
        state.canRegister && !registrationClosed && regEndDate != null;
    final showMeter = page != null &&
        page.capacity != null &&
        (state.kind == RegisterKind.open || state.kind == RegisterKind.full);
    // The waiting list: the person's places in line, and whether one can
    // be joined (a sold-out type with its list open). Never on an event
    // whose club reviews every registration ([_tickets]).
    final ticketing = _tickets;
    final places = ticketing?.openPlaces ?? const <WaitlistEntry>[];
    final canWait = (ticketing?.canJoinWaitlist ?? false) &&
        state.kind != RegisterKind.ended;
    // Nothing left to buy, and the list is open: the button joins it.
    final joinInstead =
        canWait && ((ticketing?.soldOut ?? false) || !state.canRegister);
    final VoidCallback? onPressed;
    var label = isLoading ? 'LOADING...' : state.label;
    if (isLoading) {
      onPressed = null;
    } else if (places.isNotEmpty && (joinInstead || !state.canRegister)) {
      onPressed = null;
      label = "YOU'RE ON THE WAITING LIST";
    } else if (joinInstead) {
      onPressed = _joinWaitlist;
      label = 'JOIN THE WAITING LIST';
    } else if (state.canRegister) {
      onPressed = _openRegistrationForm;
    } else if (state.kind == RegisterKind.live) {
      onPressed = _openLiveRoom;
    } else {
      onPressed = null;
    }
    // The club reviews every registration: the button registers as on any
    // event, with a word on how it works -- or opens their registration.
    final approval = isLoading
        ? null
        : _approvalButton(
            registering: places.isEmpty && !joinInstead && state.canRegister);
    // A registration of theirs decides the button, even when it can't be
    // opened.
    final VoidCallback? pressed = approval == null
        ? onPressed
        : approval.request != null
            ? approval.onPressed
            : approval.onPressed ?? onPressed;
    if (approval?.label case final said?) label = said;
    // Some types on sale, another sold out with its list open: both.
    final alsoJoin =
        canWait && !joinInstead && places.isEmpty && approval?.request == null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_sellable) ...[
            const IosSaleBlockedNotice(),
            const SizedBox(height: 10),
          ] else ...[
            // The countdown, when there is a deadline and it hasn't passed.
            // It ticks on its own: the page isn't rebuilt every second.
            if (showCountdown)
              RegistrationCountdown(
                closesAt: regEndDate!,
                onClosed: _onRegistrationClosed,
              ),
            if (approval != null)
              Padding(
                padding: EdgeInsets.only(
                    top: showCountdown ? 8 : 0,
                    bottom: state.note != null ? 6 : 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (approval.title case final title?)
                        Text(
                          title,
                          key: IndividualEventPage.approvalTitleKey,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E3A8A)),
                        ),
                      Text(
                        approval.note,
                        key: IndividualEventPage.approvalNoteKey,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.note != null)
              Padding(
                padding: EdgeInsets.only(top: showCountdown ? 8 : 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    state.note!,
                    key: const ValueKey('register-note'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          state.urgent ? FontWeight.w600 : FontWeight.normal,
                      color: state.urgent
                          ? const Color(0xFFB45309)
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (places.isNotEmpty) ...[
              WaitlistPlacesCard(
                places: places,
                leaving: _leavingWaitlist,
                onLeave: _leaveWaitlist,
              ),
              const SizedBox(height: 10),
            ],
            if (showMeter && !joinInstead)
              SeatsMeter(
                going: page.going,
                capacity: page.capacity,
                seatsLeft: page.seatsLeft,
                confirmsEach: _requiresApproval,
                clubName: page.club?.name ?? club?.name,
              ),
            SizedBox(
              width: double.infinity,
              child: Pressable(
                enabled: pressed != null,
                child: FilledButton(
                  key: const ValueKey('event-register-button'),
                  onPressed: pressed,
                  child: Text(label),
                ),
              ),
            ),
            if (alsoJoin && !isLoading)
              TextButton(
                key: const ValueKey('event-also-waitlist'),
                onPressed: _joinWaitlist,
                child: const Text('Or join the waiting list for a sold-out ticket'),
              ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// The register button on an event whose club reviews every
  /// registration; null for any other event, or when the button doesn't
  /// register now ([registering]) and there is no registration of theirs to
  /// open.
  ///
  /// With a registration of theirs still open -- the event's
  /// `viewer_request`, or, from a server without it,
  /// `/registration-requests/mine` -- it says "Your registration is under
  /// review" (or confirmed, to pay) and the button opens it; otherwise the
  /// button registers as on any event ([label] null keeps its word), with
  /// a note on how the club reviews.
  ({
    String? title,
    String? label,
    String note,
    VoidCallback? onPressed,
    RegistrationRequest? request,
  })? _approvalButton({required bool registering}) {
    if (!_requiresApproval || isRegistered || _cancellation != null) {
      return null;
    }
    final clubName = (_page?.club?.name ?? club?.name)?.trim();
    final named = clubName != null && clubName.isNotEmpty;
    final who = named ? clubName : 'The club';
    final mine = _viewerRequest;
    if (mine != null) {
      final confirmed = mine.status == RequestStatus.approved;
      final route = mine.route;
      // What to pay, and by when: the event's `viewer_request` doesn't
      // say; My events' list may.
      final pay = mine.pay ?? _listedPay(mine);
      final amount = pay == null || pay.amount <= 0
          ? null
          : formatRupees(pay.amount);
      final by = pay?.payBy;
      return (
        title: confirmed
            ? 'Your registration is confirmed'
            : 'Your registration is under review',
        // Without its link (none sent), the button only says where it
        // stands.
        label: route == null
            ? confirmed
                ? 'CONFIRMED'
                : 'UNDER REVIEW'
            : confirmed
                ? amount == null
                    ? 'PAY NOW'
                    : 'PAY $amount'
                : 'SEE YOUR REGISTRATION',
        note: confirmed
            ? 'Pay${amount == null ? '' : ' $amount'}'
                '${by == null ? '' : ' by ${requestMoment(by)}'} to get your '
                'ticket.'
            : '$who reviews every registration. If yours is confirmed, your '
                'ticket will come by email.',
        onPressed: route == null ? null : () => _openRequest(route, mine),
        request: mine,
      );
    }
    if (!registering) return null;
    return (
      title: null,
      label: null,
      note: reviewsEveryRegistrationNote(clubName),
      onPressed: null,
      request: null,
    );
  }

  /// What My events' list says [mine] has to pay, when it lists the same
  /// registration: the event's `viewer_request` carries no amount.
  RequestPay? _listedPay(RegistrationRequest mine) {
    final listed = ref.watch(myRegistrationRequestsProvider).openFor(_eventId);
    if (listed == null) return null;
    final same = (mine.id.isNotEmpty && listed.id == mine.id) ||
        (mine.token != null && listed.token == mine.token);
    return same ? listed.pay : null;
  }

  /// The signed-in person's open registration for this event (under review,
  /// or confirmed and not paid): the event's own `viewer_request`, or
  /// -- from a server without it -- the one My events' list has. Null when
  /// signed out, or there is none. Read while building.
  RegistrationRequest? get _viewerRequest {
    if (!ref.watch(isAuthenticatedProvider)) return null;
    final ticketing = _ticketing;
    final RegistrationRequest? found;
    if (ticketing != null && ticketing.saysViewerRequest) {
      found = ticketing.viewerRequest;
    } else {
      found = ref.watch(myRegistrationRequestsProvider).openFor(_eventId);
    }
    if (found == null || found.hasTicket) return null;
    final open = found.status == RequestStatus.pending ||
        found.status == RequestStatus.approved;
    return open ? found : null;
  }

  /// The registration's screen; the event is read again after, since it may
  /// have been cancelled or paid there.
  Future<void> _openRequest(String route, RegistrationRequest request) async {
    await context.push(route, extra: {'request': request});
    if (mounted) await _fetchData();
  }

  /// Opens the ticket in the in-app viewer.
  void _openTicket() {
    final url = ticketUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket is being generated. Please check back later.'),
        ),
      );
      return;
    }
    // The ticket code from its address (the QR is drawn from it).
    final ticketId = ticketCodeFromUrl(url) ?? url;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketViewPage(
          ticketId: ticketId,
          eventName: name ?? 'Event',
          eventDateTime: eventDateTime,
          locationName: locationName,
          durationHours: duration,
          ticketUrl: url,
          revoked: _ticketRevoked,
          eventId: _eventId,
        ),
      ),
    );
  }

  /// Bottom sheet for ticket state (registered but event not over)
  Widget _buildTicketBottomSheet(BuildContext context) {
    final revoked = _ticketRevoked;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Yellow banner - same style as countdown
          Container(
            width: double.infinity,
            height: 25,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: revoked ? const Color(0xFFEEEEEE) : const Color(0xFFFFF9C4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              revoked
                  ? 'Your ticket was revoked by the organiser'
                  : 'Registered and Generated Ticket',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
                color: revoked ? const Color(0xFF424242) : const Color(0xFF5D4037),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Pressable(
              child: FilledButton(
                onPressed: _openTicket,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      revoked ? Colors.grey.shade600 : const Color(0xFF2C333D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(revoked ? 'TICKET REVOKED' : 'VIEW TICKET'),
              ),
            ),
          ),
          if (_liveRoomOpen) _liveRoomButton(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Bottom sheet for certificate state (attended)
  Widget _buildCertificateBottomSheet(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Green banner - same style as countdown
          Container(
            width: double.infinity,
            height: 25,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Attended and Certificate Generated',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Pressable(
              child: FilledButton(
                onPressed: () {
                  // The certificate inside the app, as the club designed it
                  // and saved for offline -- not the website's page, which
                  // draws one stand-in design for every club.
                  final id = certificateIdFromUrl(certificateUrl);
                  if (id != null) {
                    context.push(certificateRoute(id));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Certificate is being generated. Please check back later.'),
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C333D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('VIEW CERTIFICATE'),
              ),
            ),
          ),
          if (_liveRoomOpen) _liveRoomButton(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// Helper Widget for info items.
Widget _infoCard(BuildContext context,
    {required String icon, required String title, required String value}) {
  return Container(
    width: MediaQuery.of(context).size.width * 0.4,
    padding: const EdgeInsets.all(7.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        CircleAvatar(
          backgroundColor: Colors.white,
          radius: 24,
          child: Image.asset(
            icon,
            height: 25,
            width: 25,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontFamily: 'BebasNeue',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

// A simple bullet-list widget.
class BulletList extends StatelessWidget {
  final List<String> items;
  const BulletList(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 14))),
              ],
            ),
          )
          .toList(),
    );
  }
}

/// The club's logo beside the event's title: a grey disc with a group icon
/// when there is no logo or it fails, rather than a placeholder service's
/// image.
class _ClubLogo extends StatelessWidget {
  final Object? url;

  const _ClubLogo({this.url});

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    // Whole when it is not square (a wordmark), on a white disc.
    return ClubLogo(
      url: url is String ? url : null,
      size: 48,
      circle: true,
      fallback: Container(
        width: 48,
        height: 48,
        color: const Color(0xFFF3F3F3),
        child: const Icon(Icons.group, color: Colors.grey),
      ),
    );
  }
}
