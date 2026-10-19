import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// Model for a networking attendee.
class NetworkingAttendee {
  final int userId;
  final String name;
  final String? profilePicUrl;
  final String? organization;
  final List<SharedInterest> sharedInterests;
  final int matchCount;

  NetworkingAttendee({
    required this.userId,
    required this.name,
    this.profilePicUrl,
    this.organization,
    required this.sharedInterests,
    required this.matchCount,
  });

  factory NetworkingAttendee.fromJson(Map<String, dynamic> json) {
    return NetworkingAttendee(
      userId: json['user_id'],
      name: json['name'] ?? '',
      profilePicUrl: json['profile_pic_url'],
      organization: json['organization'],
      sharedInterests: (json['shared_interests'] as List? ?? [])
          .map((i) => SharedInterest.fromJson(i))
          .toList(),
      matchCount: json['match_count'] ?? 0,
    );
  }
}

class SharedInterest {
  final int id;
  final String name;
  final String? icon;
  final String? iconType;

  SharedInterest({
    required this.id,
    required this.name,
    this.icon,
    this.iconType,
  });

  factory SharedInterest.fromJson(Map<String, dynamic> json) {
    return SharedInterest(
      id: json['id'],
      name: json['name'] ?? '',
      icon: json['icon'],
      iconType: json['icon_type'],
    );
  }
}

/// "People Like You" networking discovery page.
class NetworkingPage extends StatefulWidget {
  final int eventId;
  final String eventName;

  const NetworkingPage({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<NetworkingPage> createState() => _NetworkingPageState();
}

class _NetworkingPageState extends State<NetworkingPage> {
  bool isLoading = true;
  String? errorMessage;
  bool unavailable = false;
  List<NetworkingAttendee> attendees = [];
  DateTime? windowClosesAt;
  int total = 0;

  @override
  void initState() {
    super.initState();
    _fetchNetworking();
  }

  Future<void> _fetchNetworking() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      unavailable = false;
    });

    try {
      Response<dynamic> res = await APIService.instance.request(
        '/events/${widget.eventId}/networking',
        DioMethod.get,
      );

      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        attendees = (data['attendees'] as List? ?? [])
            .map((a) => NetworkingAttendee.fromJson(a as Map<String, dynamic>))
            .toList();
        total = data['total'] ?? 0;
        if (data['window_closes_at'] != null) {
          windowClosesAt = DateTime.parse(data['window_closes_at']);
        }
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = networkingErrorMessage(e);
        // The club's plan doesn't include networking: trying again won't
        // change that.
        unavailable = errorCodeOf(e) == networkingUnavailableCode;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'People Like You',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      // Not the shared ErrorView: it shows generic copy in place of the
      // message it is given.
      return _NetworkingProblem(
        message: errorMessage!,
        onRetry: unavailable ? null : _fetchNetworking,
      );
    }

    if (attendees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'No matches yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasNeue',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Other attendees with similar interests will show up here once they check in.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Group by match count
    final Map<int, List<NetworkingAttendee>> grouped = {};
    for (final a in attendees) {
      grouped.putIfAbsent(a.matchCount, () => []).add(a);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _fetchNetworking,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _calculateItemCount(sortedKeys, grouped),
        itemBuilder: (context, index) {
          return _buildItem(index, sortedKeys, grouped);
        },
      ),
    );
  }

  int _calculateItemCount(
      List<int> keys, Map<int, List<NetworkingAttendee>> grouped) {
    int count = 1; // Header
    for (final k in keys) {
      count += 1; // Section header
      count += grouped[k]!.length; // Cards
    }
    return count;
  }

  Widget _buildItem(
      int index, List<int> keys, Map<int, List<NetworkingAttendee>> grouped) {
    // Header = index 0
    if (index == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$total attendee${total != 1 ? 's' : ''} with shared interests',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (windowClosesAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Available until ${_formatTime(windowClosesAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    int runningIndex = 1;
    for (final k in keys) {
      // Section header
      if (index == runningIndex) {
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            k > 0
                ? '🤝 $k shared interest${k != 1 ? 's' : ''}'
                : '👋 Other attendees',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'BebasNeue',
              letterSpacing: 0.5,
            ),
          ),
        );
      }
      runningIndex++;

      for (int i = 0; i < grouped[k]!.length; i++) {
        if (index == runningIndex) {
          return _buildAttendeeCard(grouped[k]![i]);
        }
        runningIndex++;
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildAttendeeCard(NetworkingAttendee attendee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE8F5E9),
              backgroundImage: attendee.profilePicUrl != null
                  ? appImageProvider(
                      attendee.profilePicUrl!,
                      privacy: ImagePrivacy.private,
                      decodeWidth: decodeWidthFor(
                          48, 48, MediaQuery.devicePixelRatioOf(context)),
                    )
                  : null,
              onBackgroundImageError: attendee.profilePicUrl != null
                  ? (_, __) {}
                  : null,
              child: attendee.profilePicUrl == null
                  ? Text(
                      attendee.name.isNotEmpty
                          ? attendee.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attendee.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (attendee.organization != null &&
                      attendee.organization!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      attendee.organization!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  if (attendee.sharedInterests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: attendee.sharedInterests.map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${interest.icon ?? ''} ${interest.name}'.trim(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    int hour = dt.toLocal().hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    String minute = dt.toLocal().minute.toString().padLeft(2, '0');
    return "$hour12:$minute $period";
  }
}

/// Why the page has no one to show, and a retry when one could help.
class _NetworkingProblem extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _NetworkingProblem({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey[500]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[800]),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
