import 'dart:math' show Random;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/core/themes/app_colors.dart';
import 'package:myotherapp/features/clubs/presentation/pages/club_events_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myotherapp/shared/widgets/error_view.dart';
import 'package:myotherapp/shared/widgets/shimmer_widgets.dart';

class ClubProfilePage extends StatefulWidget {
  final int id;
  const ClubProfilePage({super.key, required this.id});

  @override
  State<ClubProfilePage> createState() => _ClubProfilePageState();
}

class _ClubProfilePageState extends State<ClubProfilePage> {
  final Random random = Random();
  final List<Color> colorList = [
    const Color(0xFFE1C9FF),
    const Color(0xFFF9FFA1),
    const Color(0xFFB8DFF2),
    const Color(0xFFFFC84A),
    const Color(0xFFFFDEDD),
  ];
  ClubInfo? clubInfo;
  // State variables for club fields.
  int? id;
  String? name;
  String? slug;
  Map<String, dynamic>? logo;
  String? locationName;
  String? locationLink;
  String? about;
  double? rating;
  int? totalRatings;
  Map<String, dynamic>? socials;
  List<Interest> interests = [];
  int? followersCount;
  String? contactPhone;
  String? contactEmail;
  Map<String, dynamic>? userData;
  Org? org;

  bool isLoading = true;
  String? errorMessage;
  bool _expanded = false;
  Future<void> _toggleFollow() async {
    if (clubInfo == null) return;

    final isCurrentlyFollowing = clubInfo!.userData['is_following'] ?? false;
    final endpoint = isCurrentlyFollowing
        ? '/clubs/unfollow/${clubInfo!.id}'
        : '/clubs/follow/${clubInfo!.id}';

    // Optimistically update UI
    setState(() {
      userData?['is_following'] = !isCurrentlyFollowing;
      followersCount = (followersCount ?? 0) + (isCurrentlyFollowing ? -1 : 1);
    });

    try {
      await APIService.instance.request(
        endpoint,
        DioMethod.post,
      );
      // Update clubInfo as well
      clubInfo!.userData['is_following'] = !isCurrentlyFollowing;
    } catch (e) {
      // Revert on error
      setState(() {
        userData?['is_following'] = isCurrentlyFollowing;
        followersCount =
            (followersCount ?? 0) + (isCurrentlyFollowing ? 1 : -1);
      });
      debugPrint('Follow/Unfollow failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Please try again.')),
        );
      }
    }
  }

  Future<void> _fetchData() async {
    try {
      Response<dynamic> res = await APIService.instance.request(
        '/clubs/info/${widget.id}',
        DioMethod.get,
      );
      // Parse the response into our model.
      clubInfo = ClubInfo.fromJson(res.data);
      setState(() {
        id = clubInfo!.id;
        name = clubInfo!.name;
        slug = clubInfo!.slug;
        logo = clubInfo!.logo;
        locationName = clubInfo!.locationName;
        locationLink = clubInfo!.locationLink;
        about = clubInfo!.about;
        rating = clubInfo!.rating;
        //rating = 2;
        totalRatings = clubInfo!.totalRatings;
        socials = clubInfo!.socials;
        interests = clubInfo!.interests;
        followersCount = clubInfo!.followersCount;
        contactPhone = clubInfo!.contactPhone;
        contactEmail = clubInfo!.contactEmail;
        userData = clubInfo!.userData;
        org = clubInfo!.org;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _navigateToClubEvents(BuildContext context, {required bool isPast}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubEventsPage(
          clubId: widget.id,
          clubName: name ?? 'Club',
          clubLogo: logo?['thumbnail'] ?? '',
          isPastEvents: isPast,
        ),
      ),
    );
  }

  // Build UI using stored values.
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: ShimmerClubDetail(),
      );
    }
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header row: Club logo, club name, followers, and interests.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Club logo using thumbnail from logo map if available.
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    (logo != null &&
                            logo!.isNotEmpty &&
                            logo!['thumbnail'] != null &&
                            (logo!['thumbnail'] as String).isNotEmpty)
                        ? logo!['thumbnail']
                        : 'https://picsum.photos/200',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Club Name',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$followersCount Followers',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      // Interests as tags with a color selected by index.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interests.asMap().entries.map((entry) {
                          int index = entry.key;
                          final interest = entry.value;
                          final color = colorList[index % colorList.length];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              interest.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Buttons: JOIN THE TEAM and FOLLOW.
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // Implement "Join the Team" logic.
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(
                        width: 1.5,
                        color: Color(0xFF2C333D),
                      ),
                    ),
                    child: const Text(
                      'JOIN THE TEAM',
                      style: TextStyle(
                        fontSize: 24,
                        color: Color(0xFF2C333D),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C333D),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      userData?['is_following'] == true ? 'UNFOLLOW' : 'FOLLOW',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            // Description section with Read More/Show Less.
            _buildDescriptionSection(context),
            const SizedBox(height: 16),
            // Info cards for College (Organisation) and Location - tappable with popups.
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showOrganizationPopup(context),
                    child: _infoCard(
                      context,
                      icon: AssetResources.college,
                      title: 'College',
                      value: org?.name ?? 'N/A',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
            const SizedBox(height: 12),
            // Event redirect cards: Past Events and Upcoming Events.
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToClubEvents(context, isPast: true),
                    child: _eventRedirectCard(context, value: "PAST EVENTS"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToClubEvents(context, isPast: false),
                    child:
                        _eventRedirectCard(context, value: "UPCOMING EVENTS"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Social links row.
            Row(
              children: [
                Expanded(
                    child: _buildSocialCard(socials?['instagram'] ?? '',
                        'assets/images/Instagram.png')),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildSocialCard(socials?['linkedin'] ?? '',
                        'assets/images/LinkedIn.png')),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildSocialCard(socials?['youtube'] ?? '',
                        'assets/images/YouTube.png')),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildSocialCard(socials?['website'] ?? '',
                        'assets/images/Website.png')),
              ],
            ),

            const SizedBox(height: 24),

            // Rating section - shows average rating of all club events
            if (rating != null && rating! > 0) ...[
              _buildRatingSection(context),
              const SizedBox(height: 24),
            ],

            // // Achievements section.
            // Text(
            //   'ACHIEVEMENTS',
            //   style: Theme.of(context).textTheme.titleMedium?.copyWith(
            //         fontWeight: FontWeight.bold,
            //       ),
            // ),
            // const SizedBox(height: 16),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     _buildAchievementPlaceholder(),
            //     _buildAchievementPlaceholder(),
            //     _buildAchievementPlaceholder(),
            //   ],
            // ),
            // const SizedBox(height: 32),
            // // Need Help section.
            const Text(
              'Need Help?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Got any questions? We're here to help—hit us up!",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final phoneNumber =
                    contactPhone ?? ''; // contactPhone from your model.
                final telUrl = 'tel:$phoneNumber';
                if (await canLaunchUrl(Uri.parse(telUrl))) {
                  await launchUrl(Uri.parse(telUrl));
                } else {
                  // Handle the error, e.g. show a message to the user.
                  debugPrint('Could not launch $telUrl');
                }
              },
              child: const Text(
                'Call Committee',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget buildRatingStars(double rating) {
    // Calculate full stars.
    int fullStars = rating.floor();
    // Check for half star (if the fractional part is 0.5 or more).
    bool hasHalfStar = (rating - fullStars) >= 0.5;
    // Build the star widgets.
    List<Widget> stars = [];
    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(Icons.star, color: Colors.amber, size: 32));
    }
    if (hasHalfStar) {
      stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 32));
    }
    // Add empty stars until there are 5 in total.
    while (stars.length < 5) {
      stars.add(const Icon(Icons.star_border, color: Colors.amber, size: 32));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stars,
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    // Use dynamic 'about' field from API
    final description = about ?? 'No description available.';
    final maxLines = _expanded ? null : 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          maxLines: maxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(height: 1.4, fontSize: 14),
        ),
        if (description.length > 200)
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Text(
              _expanded ? 'Show Less' : 'Read More',
              style: const TextStyle(
                color: Color(0xFF17A58F),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                fontSize: 14,
              ),
            ),
          )
      ],
    );
  }

  /// Show organization details popup (matching event page style)
  void _showOrganizationPopup(BuildContext context) {
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
                    Image.asset(AssetResources.college, height: 28, width: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Organization',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                (org?.name ?? 'N/A').toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasNeue',
                ),
              ),
              if (org?.type != null && org!.type.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  org!.type,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
              if (org?.address != null && org!.address.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  org!.address,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C333D),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
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

  /// Show location details popup (matching event page style)
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

  /// Build rating section showing average rating of all club events
  Widget _buildRatingSection(BuildContext context) {
    // Rating is 0-5 scale
    double avgRating = rating ?? 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return Icon(
              index < avgRating.round() ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 28,
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          '${avgRating.toStringAsFixed(1)} RATED',
          style: const TextStyle(
            fontSize: 28,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Rated by ${totalRatings ?? 0} Participants',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _infoCard(BuildContext context,
      {required String icon, required String title, required String value}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xffF3F3F3),
            radius: 24,
            child: Image.asset(
              icon,
              height: 25,
              width: 25,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
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

  Widget _eventRedirectCard(BuildContext context, {required String value}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Center(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontFamily: 'BebasNeue',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialCard(String url, String assetPath) {
    return InkWell(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        } else {
          // You might want to handle the error gracefully.
          throw 'Could not launch $url';
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Center(
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // Widget _buildRatingSection(BuildContext context) {
  //   // Assume rating is returned as int, but convert to double.
  //   // If your API returns a double, you can use it directly.
  //   double avgRating = rating != null ? rating!.toDouble() : 0;
  //   return Column(
  //     children: [
  //       buildRatingStars(avgRating),
  //       const SizedBox(height: 8),
  //       Text(
  //         "$avgRating (${totalRatings ?? 0} ratings)",
  //         style: const TextStyle(fontSize: 20),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildAchievementPlaceholder() {
  //   return Container(
  //     width: 64,
  //     height: 64,
  //     decoration: BoxDecoration(
  //       color: Colors.grey.shade200,
  //       shape: BoxShape.circle,
  //     ),
  //   );
  // }
}

// Models for ClubInfo, Interest, and Org.
class ClubInfo {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic> logo;
  final String locationName;
  final String locationLink;
  final String about;
  final double rating;
  final int totalRatings;
  final Map<String, dynamic> socials;
  final List<Interest> interests;
  final int followersCount;
  final String contactPhone;
  final String contactEmail;
  final Map<String, dynamic> userData;
  final Org org;

  ClubInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.logo,
    required this.locationName,
    required this.locationLink,
    required this.about,
    required this.rating,
    required this.totalRatings,
    required this.socials,
    required this.interests,
    required this.followersCount,
    required this.contactPhone,
    required this.contactEmail,
    required this.userData,
    required this.org,
  });

  factory ClubInfo.fromJson(Map<String, dynamic> json) {
    return ClubInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      logo: json['logo'] ?? {},
      locationName: json['location_name'] ?? '',
      locationLink: json['location_link'] ?? '',
      about: json['about'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['total_ratings'] as num?)?.toInt() ?? 0,
      socials: json['socials'] ?? {},
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => Interest.fromJson(e))
              .toList() ??
          [],
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      contactPhone: json['contact_phone'] ?? '',
      contactEmail: json['contact_email'] ?? '',
      userData: json['user_data'] ?? {},
      org: Org.fromJson(json['org'] ?? {}),
    );
  }
}

class Interest {
  final int id;
  final String name;
  final String icon;
  final String iconType;

  Interest({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconType,
  });

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      iconType: json['icon_type'] ?? '',
    );
  }
}

class Org {
  final int id;
  final String name;
  final String type;
  final String address;
  final String phone;
  final String email;

  Org({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.phone,
    required this.email,
  });

  factory Org.fromJson(Map<String, dynamic> json) {
    return Org(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
    );
  }
}
