import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/common/models/events/event_model.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/core/themes/app_colors.dart';
import 'package:myotherapp/core/utils/error_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myotherapp/shared/widgets/error_view.dart';
import 'package:myotherapp/shared/widgets/shimmer_widgets.dart';
import 'package:myotherapp/features/events/presentation/pages/ticket_view_page.dart';
import 'package:myotherapp/features/events/presentation/pages/networking_page.dart';

class IndividualEventPage extends StatefulWidget {
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
  State<IndividualEventPage> createState() => _IndividualEventPageState();
}

class _IndividualEventPageState extends State<IndividualEventPage> {
  // State variables for event fields.
  int? id;
  String? name;
  String? slug;
  Map<String, dynamic>? poster;
  DateTime? eventDateTime;
  int? duration;
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
  int? rating;
  int? totalRating;
  String? about;
  String? contactPhone;
  String? contactEmail;
  String? url;

  // Registration/Attendance status
  bool isRegistered = false;
  bool isAttended = false;
  String? ticketUrl;
  String? certificateUrl;
  int? userRating;
  int? userPosition;
  String? positionLabel;
  List<EventDownload> downloads = [];

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
      }
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      Response<dynamic> res = await APIService.instance.request(
        '/events/info/${widget.eventId}',
        DioMethod.get,
      );

      // Parse the JSON response into an EventInfo model.
      EventInfo eventInfo = EventInfo.fromJson(res.data);

      // Update state with the parsed values.
      setState(() {
        id = eventInfo.id;
        name = eventInfo.name;
        slug = eventInfo.slug;
        poster = eventInfo.poster;
        eventDateTime = eventInfo.eventDateTime;
        duration = eventInfo.duration;
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
        // This ensures status from EventCard navigation is not lost
        if (eventInfo.isRegistered == true) {
          isRegistered = true;
        }
        if (eventInfo.isAttended == true) {
          isAttended = true;
        }
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
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
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
                '$duration Hours',
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
    if (eventDateTime == null || duration == null) return false;
    final now = DateTime.now();
    final eventEnd = eventDateTime!.add(Duration(hours: duration!));
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
        userRating = ratingValue;
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
            content: Text('Failed to submit rating: ${extractErrorMessage(e)}'),
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
        // Share button removed - event page doesn't need it since users can share from bottom sheet or event card
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0).copyWith(
          bottom: 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event poster.
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  poster != null && poster!.isNotEmpty
                      ? poster!['medium'] ?? 'https://via.placeholder.com/300'
                      : 'https://via.placeholder.com/300',
                  fit: BoxFit.cover,
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
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: NetworkImage(
                      club != null && club!.logo.isNotEmpty
                          ? club!.logo['thumbnail'] ??
                              'https://via.placeholder.com/150'
                          : 'https://via.placeholder.com/150',
                    ),
                  ),
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
                      value: "$duration Hours",
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
                        Row(
                          children: List.generate(5, (index) {
                            // Rating is 0-5 scale, compare directly with index+1
                            return Icon(
                              index < rating!.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            );
                          }),
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
                    const Spacer(),
                    // Right side: View All Reviews link
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to all reviews page
                      },
                      child: Text(
                        'View All Reviews',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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

    // Priority 2: Check if user is registered (upcoming event they registered for)
    if (isRegistered) {
      return _buildTicketBottomSheet(context);
    }

    // Default: Show registration UI
    return _buildRegistrationBottomSheet(context);
  }

  /// Bottom sheet for registration state
  Widget _buildRegistrationBottomSheet(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only show the countdown container if registration is not closed.
          if (!registrationClosed)
            Container(
              width: double.infinity,
              height: 25,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDEDD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                regEndDate != null
                    ? countdownText
                    : 'Registration details not available',
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
                  : () {
                      context.push('/events/${id ?? 0}/register', extra: {
                        'additionalDetails': additionalDetails,
                      });
                    },
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
              onPressed: () {
                if (ticketUrl != null && ticketUrl!.isNotEmpty) {
                  // Extract ticket ID from URL
                  String extractedTicketId = '';
                  if (ticketUrl!.startsWith('/api/v1/events/tickets/')) {
                    extractedTicketId =
                        ticketUrl!.replaceFirst('/api/v1/events/tickets/', '');
                  } else if (ticketUrl!.contains('/tickets/')) {
                    extractedTicketId = ticketUrl!.split('/tickets/').last;
                  } else {
                    extractedTicketId = ticketUrl!;
                  }

                  // Navigate to in-app ticket viewer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TicketViewPage(
                        ticketId: extractedTicketId,
                        eventName: name ?? 'Event',
                        eventDateTime: eventDateTime,
                        locationName: locationName,
                        durationHours: duration,
                        ticketUrl: ticketUrl,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Ticket is being generated. Please check back later.'),
                    ),
                  );
                }
              },
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

                  // Handle old format: /api/v1/events/certificates/{id} → https://events.myotherapp.com/certificates/{id}
                  if (certificateUrl!
                      .startsWith('/api/v1/events/certificates/')) {
                    final certId = certificateUrl!
                        .replaceFirst('/api/v1/events/certificates/', '');
                    finalUrl =
                        'https://events.myotherapp.com/certificates/$certId';
                  } else if (certificateUrl!.startsWith('/')) {
                    // Other relative URLs - use API domain
                    finalUrl = 'https://api.myotherapp.com$certificateUrl';
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
