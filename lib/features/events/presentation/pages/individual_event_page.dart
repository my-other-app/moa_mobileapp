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
import 'package:finnet/features/events/presentation/widgets/event_page/event_people.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_rail.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_section.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_venue.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
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
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/events/presentation/widgets/networking/people_like_you_card.dart';
import 'package:finnet/core/utils/hours.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/shared/widgets/poster_hero.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:finnet/shared/widgets/toast.dart';

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
  }) : assert(eventId != null || eventRef != null,
            'An event page needs an id or a slug');

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

  // Timer variables for countdown.
  Timer? _timer;
  String countdownText = '';
  bool registrationClosed = false;

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

    // Start the countdown timer if regEndDate is available and not already closed.
    if (regEndDate != null && !registrationClosed) {
      _startTimer();
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

      isLoading = false;

      // CRITICAL: Check if registration is already closed IMMEDIATELY
      if (regEndDate != null && regEndDate!.isBefore(DateTime.now())) {
        registrationClosed = true;
        countdownText = 'Registration Closed';
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

  /// Speakers, the agenda, the venue, guidelines, the team, contact, and
  /// the rails -- the website's order -- each only when there is something
  /// to show.
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
          title: page?.teamSource == TeamSource.club
              ? 'Hosted by ${clubName ?? 'the club'}'
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

  void _startTimer() {
    // Cancel any existing timer.
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (regEndDate == null) return;
      final now = DateTime.now();
      final diff = regEndDate!.difference(now);
      if (diff.isNegative) {
        setState(() {
          registrationClosed = true;
          countdownText = 'Registration Closed';
        });
        _timer?.cancel();
      } else {
        final days = diff.inDays;
        final hours = (diff.inHours % 24).toString().padLeft(2, '0');
        final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          if (days > 0) {
            countdownText =
                'Registration closes in $days day${days > 1 ? 's' : ''} $hours hrs $minutes mins $seconds secs';
          } else {
            countdownText =
                'Registration closes in $hours hrs $minutes mins $seconds secs';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
                    aspectRatio: 1.0,
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
              child: AspectRatio(
                aspectRatio: 1.0,
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
            // Title & Organizer.
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
            // Its topics in their colours, then its interests. A topic
            // opens its own page, as on the site.
            TopicTagStrip(
              topGap: 16,
              declared: topics,
              interests: [for (final i in interests) i.toEntity()],
              showInterests: true,
              onTopicTap: (topic) => context.push(topicLocation(topic.slug)),
            ),
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
                        value: hasFee == true ? '₹ $regFee' : 'Free',
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
    final VoidCallback? onPressed;
    if (isLoading) {
      onPressed = null;
    } else if (state.canRegister) {
      onPressed = _openRegistrationForm;
    } else if (state.kind == RegisterKind.live) {
      onPressed = _openLiveRoom;
    } else {
      onPressed = null;
    }
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
            if (showCountdown)
              Container(
                width: double.infinity,
                height: 25,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDEDD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  countdownText,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                    color: Color(0xFFCD0000),
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
            if (showMeter)
              SeatsMeter(
                going: page.going,
                capacity: page.capacity,
                seatsLeft: page.seatsLeft,
              ),
            SizedBox(
              width: double.infinity,
              child: Pressable(
                enabled: onPressed != null,
                child: FilledButton(
                  onPressed: onPressed,
                  child: Text(isLoading ? 'LOADING...' : state.label),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
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
    final hasUrl = url is String && url.trim().isNotEmpty;
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFF3F3F3),
      foregroundImage: hasUrl
          ? appImageProvider(url,
              decodeWidth: decodeWidthFor(
                  48, 48, MediaQuery.devicePixelRatioOf(context)))
          : null,
      onForegroundImageError: hasUrl ? (_, __) {} : null,
      child: const Icon(Icons.group, color: Colors.grey),
    );
  }
}
