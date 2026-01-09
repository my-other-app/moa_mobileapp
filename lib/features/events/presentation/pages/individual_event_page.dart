import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/common/models/events/event_model.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/core/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myotherapp/shared/widgets/svg_icon.dart';
import 'package:myotherapp/shared/widgets/error_view.dart';
import 'package:myotherapp/shared/widgets/shimmer_widgets.dart';

class IndividualEventPage extends StatefulWidget {
  final int eventId;
  const IndividualEventPage({super.key, required this.eventId});

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

  bool isLoading = true;
  String? errorMessage;

  // Timer variables for countdown.
  Timer? _timer;
  String countdownText = '';
  bool registrationClosed = false;

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
        isLoading = false;
      });

      // Start the countdown timer if regEndDate is available.
      if (regEndDate != null) {
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

  @override
  void initState() {
    super.initState();
    _fetchData();
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
                backgroundColor: const Color(0xffF3F3F3),
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
                backgroundColor: const Color(0xffF3F3F3),
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
                backgroundColor: const Color(0xffF3F3F3),
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
                backgroundColor: const Color(0xffF3F3F3),
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
            icon: SvgIcon(svgIconPath: AssetResources.share),
            onPressed: () async {
              final Uri url = Uri.parse("https://events.myotherapp.com/$slug");
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _infoCard(
                    context,
                    icon: AssetResources.eventtime,
                    title: 'Time of Event',
                    value: eventDateTime != null
                        ? _formatTime(eventDateTime!)
                        : 'N/A',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoCard(
                    context,
                    icon: AssetResources.duration,
                    title: 'Duration',
                    value: "$duration Hours",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                      value: hasPrize == true ? '₹ $prizeAmount' : 'None',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Main description.
            Text(
              about ?? 'Event description not available.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),

            // Need Help.
            const Text(
              'Need Help?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                // TODO: Implement call or contact.
              },
              child: Text(
                'Call Organizer',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
      // BottomSheet with countdown and button.
      bottomSheet: Container(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    ? null // Disable while loading or if registration is closed
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
          backgroundColor: Color(0xffF3F3F3),
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
