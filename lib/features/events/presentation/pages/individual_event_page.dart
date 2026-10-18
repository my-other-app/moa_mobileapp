import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/shared/widgets/rating_stars.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/common/models/events/agenda_model.dart';
import 'package:finnet/common/models/events/live_model.dart';
import 'package:finnet/common/models/events/store_model.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/presentation/finish_payment.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/events/presentation/widgets/merch_picker.dart';
import 'package:finnet/features/events/presentation/widgets/registration_feedback.dart';
import 'package:finnet/features/payments/checkout.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:intl/intl.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/events/presentation/pages/networking_page.dart';
import 'package:finnet/core/utils/hours.dart';
import 'package:finnet/core/config/app_config.dart';

class IndividualEventPage extends ConsumerStatefulWidget {
  final int eventId;
  final String? initialStatus;
  final String? initialTicketUrl;
  final String? initialCertificateUrl;

  const IndividualEventPage({
    super.key,
    required this.eventId,
    this.initialStatus,
    this.initialTicketUrl,
    this.initialCertificateUrl,
  });

  @override
  ConsumerState<IndividualEventPage> createState() =>
      _IndividualEventPageState();
}

class _IndividualEventPageState extends ConsumerState<IndividualEventPage> {
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
  List<AdditionalDetail> additionalDetails = [];
  double? rating;
  int? totalRating;
  String? about;
  String? contactPhone;
  String? contactEmail;
  String? url;

  // Registration/Attendance status
  bool isRegistered = false;
  bool isAttended = false;

  /// Registered for a paid event and not paid: no ticket until they pay.
  bool awaitingPayment = false;

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
    _fetchData();
  }

  RegistrationStatus get _status {
    if (isAttended) return RegistrationStatus.attended;
    if (awaitingPayment) return RegistrationStatus.awaitingPayment;
    if (isRegistered) return RegistrationStatus.registered;
    return RegistrationStatus.none;
  }

  Future<void> _fetchData() async {
    try {
      Response<dynamic> res = await APIService.instance.request(
        '/events/info/${widget.eventId}',
        DioMethod.get,
      );
      final Map<String, dynamic> raw = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : const <String, dynamic>{};

      // Parse the JSON response into an EventInfo model.
      EventInfo eventInfo = EventInfo.fromJson(raw);
      final status = registrationStatusFrom(raw, carried: _status);
      if (!mounted) return;

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

        isLoading = false;

        // CRITICAL: Check if registration is already closed IMMEDIATELY
        if (regEndDate != null && regEndDate!.isBefore(DateTime.now())) {
          registrationClosed = true;
          countdownText = 'Registration Closed';
        }
      });

      // Start the countdown timer if regEndDate is available and not already closed.
      if (regEndDate != null && !registrationClosed) {
        _startTimer();
      }
      if (_finishPaymentOnLoad) {
        _finishPaymentOnLoad = false;
        if (awaitingPayment && !_eventEnded) unawaited(_finishPayment());
      }
      await _fetchAgenda();
      await _fetchCatalog();
      await _fetchLive();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = readableError(
          e,
          fallback: 'Could not load this event.',
        );
        isLoading = false;
      });
    }
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
        ),
      ).run(
        eventId: id ?? widget.eventId,
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
    final result = await context.push<Object?>(
      '/events/${id ?? widget.eventId}/register',
      extra: {'additionalDetails': additionalDetails},
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

  /// Shares the event's page on the website.
  Future<void> _shareEvent() async {
    final link = eventShareUrl(id: id ?? widget.eventId, slug: slug);
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
        '/events/${widget.eventId}/agenda',
        DioMethod.get,
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

  Future<void> _fetchLive() async {
    try {
      final Response<dynamic> res = await APIService.instance.request(
        '/events/${widget.eventId}/live',
        DioMethod.get,
      );
      final data = res.data;
      if (data is Map<String, dynamic> && mounted) {
        setState(() => live = LiveFeed.fromJson(data));
      }
    } catch (_) {
      // The room is optional; the event itself has loaded.
    }
  }

  /// The room is the web page, so voting, polls and the quiz are the same on every phone.
  Future<void> _openLiveRoom() async {
    final url = Uri.parse('${AppConfig.publicSiteUrl}/${widget.eventId}/live');
    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
  }

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
        '/events/${widget.eventId}/store/catalog',
        DioMethod.get,
        skipAuth: true,
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
                    await launchUrl(url, mode: LaunchMode.externalApplication);
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

  /// Check if current time is within the networking window (event start → end + 1hr).
  bool _isWithinNetworkingWindow() {
    if (eventDateTime == null) return false;
    final now = DateTime.now();
    final eventEnd = eventDateTime!.add(hoursToDuration(duration ?? 0));
    final windowEnd = eventEnd.add(const Duration(hours: 1));
    return now.isAfter(eventDateTime!) && now.isBefore(windowEnd);
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
        '/events/rate/${widget.eventId}',
        DioMethod.post,
        param: {
          'rating': ratingValue,
          if (review != null && review.isNotEmpty) 'review': review,
        },
      );

      setState(() {
        // The picker offers whole stars; the field holds the
        // server's float, so widen rather than narrow.
        userRating = ratingValue.toDouble();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your rating!'),
            backgroundColor: Colors.green,
          ),
        );
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
        body: const ShimmerEventDetail(),
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
            // Event poster, or its drawn cover when it has none.
            AspectRatio(
              aspectRatio: 1.0,
              child: EventPosterImage(
                poster: poster,
                eventId: id ?? widget.eventId,
                // A missing category parses as id 0 and an empty name.
                categoryId:
                    (category?.id ?? 0) != 0 ? category!.id : null,
                categoryName: category?.name,
                startsAt: eventDateTime,
                isOnline: isOnline ?? false,
                slot: PosterSlot.hero,
                borderRadius: BorderRadius.circular(8.0),
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
                    ],
                  ),
                ),
              ],
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
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
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

              // 4. "People Like You" networking button (only during event + 1hr)
              if (_isWithinNetworkingWindow()) ...[
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NetworkingPage(
                          eventId: widget.eventId,
                          eventName: name ?? 'Event',
                        ),
                      ),
                    );
                  },
                  icon: const Text('🤝', style: TextStyle(fontSize: 18)),
                  label: const Text(
                    'People Like You',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover attendees who share your interests',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // ========== THE LIVE ROOM (while something is up) ==========
            if (live.isActive) _buildLiveStrip(context),

            // ========== AGENDA (when the organiser has written one) ==========
            if (agenda.items.isNotEmpty) _buildAgendaSection(context),

            // ========== ON SALE WITH THE TICKET ==========
            if (catalog.hasAnything) _buildStoreSection(context),

            // ========== MAIN DESCRIPTION ==========
            Text(
              about ?? 'Event description not available.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),

            // ========== RATE AND RATING SECTION (only for attended) ==========
            if (isAttended) ...[
              // Rate the Event button (only if not rated yet)
              if (userRating == null || userRating == 0) ...[
                OutlinedButton(
                  onPressed: () => _showRatingDialog(context),
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

            // Need Help.
            const Text(
              'Need Help?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Got any questions? We\'re here to help—hit us up!',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                if (contactPhone != null && contactPhone!.isNotEmpty) {
                  final Uri url = Uri.parse('tel:$contactPhone');
                  await launchUrl(url);
                }
              },
              child: Text(
                'Call Organizer',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
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
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Bottom sheet for registration state
  Widget _buildRegistrationBottomSheet(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The countdown, when there is a deadline and it hasn't passed.
          if (!registrationClosed && regEndDate != null)
            Container(
              width: double.infinity,
              height: 25,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (isLoading || registrationClosed)
                  ? null
                  : _openRegistrationForm,
              child: Text(isLoading
                  ? 'LOADING...'
                  : registrationClosed
                      ? 'REGISTRATION CLOSED'
                      : 'REGISTER NOW'),
            ),
          ),
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
    // Extract ticket ID from URL
    final String ticketId;
    if (url.startsWith('/api/v1/events/tickets/')) {
      ticketId = url.replaceFirst('/api/v1/events/tickets/', '');
    } else if (url.contains('/tickets/')) {
      ticketId = url.split('/tickets/').last;
    } else {
      ticketId = url;
    }
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
        ),
      ),
    );
  }

  /// Bottom sheet for ticket state (registered but event not over)
  Widget _buildTicketBottomSheet(BuildContext context) {
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
              color: const Color(0xFFFFF9C4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Registered and Generated Ticket',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
                color: Color(0xFF5D4037),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _openTicket,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C333D),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('VIEW TICKET'),
            ),
          ),
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
            child: FilledButton(
              onPressed: () async {
                if (certificateUrl != null && certificateUrl!.isNotEmpty) {
                  String finalUrl = certificateUrl!;

                  // Handle old format: /api/v1/events/certificates/{id} → {publicSiteUrl}/certificates/{id}
                  if (certificateUrl!
                      .startsWith('/api/v1/events/certificates/')) {
                    final certId = certificateUrl!
                        .replaceFirst('/api/v1/events/certificates/', '');
                    finalUrl =
                        '${AppConfig.publicSiteUrl}/certificates/$certId';
                  } else if (certificateUrl!.startsWith('/')) {
                    // Other relative URLs - use API domain
                    finalUrl = 'https://api.myotherapp.in$certificateUrl';
                  }
                  // else: Already a full URL, use as-is

                  final Uri url = Uri.parse(finalUrl);
                  await launchUrl(url, mode: LaunchMode.externalApplication);
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
      foregroundImage: hasUrl ? NetworkImage(url) : null,
      onForegroundImageError: hasUrl ? (_, __) {} : null,
      child: const Icon(Icons.group, color: Colors.grey),
    );
  }
}
