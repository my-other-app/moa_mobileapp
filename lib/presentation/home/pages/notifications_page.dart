import 'package:flutter/material.dart';

class NotificationsNewPage extends StatelessWidget {
  const NotificationsNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontSize: 24,
            fontFamily: "BebasNeue",
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'Bebas Neue',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            _buildNotificationItem(
              image:
                  "https://avatars.githubusercontent.com/u/98015594?s=280&v=4",
              isHighlighted: true,
              title: 'Your Certificate for the event, ',
              boldText: 'Ideatank 4.0',
              subtitle: ' is generated',
              time: '2 hour ago',
            ),
            const SizedBox(height: 16),
            _buildNotificationItem(
              image:
                  "https://avatars.githubusercontent.com/u/98015594?s=280&v=4",
              title: '',
              boldText: 'Oasis Hackathon ',
              subtitle: 'starts in 1 hour',
              time: '2 hour ago',
            ),
            const SizedBox(height: 43),
            // This Week's Notifications
            Text(
              'This Week',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'Bebas Neue',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            _buildNotificationItem(
              image:
                  "https://avatars.githubusercontent.com/u/98015594?s=280&v=4",
              title: '',
              boldText: 'Oasis Hackathon ',
              subtitle: 'starts in 24 hours',
              time: '2 hour ago',
            ),
            const SizedBox(height: 16),
            _buildNotificationItem(
              image:
                  "https://avatars.githubusercontent.com/u/98015594?s=280&v=4",
              title: 'You are invited for an event by RoboCET. ',
              boldText: 'View Details',
              subtitle: '',
              time: '2 hour ago',
              isViewDetails: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String image,
    required String title,
    required String boldText,
    required String subtitle,
    required String time,
    bool isHighlighted = false,
    bool isViewDetails = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: ShapeDecoration(
        color: isHighlighted ? Color(0xFFF8FFA0) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              image: DecorationImage(
                image: NetworkImage(image),
                fit: BoxFit.fill,
              ),
              shape: OvalBorder(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      TextSpan(
                        text: boldText,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w600,
                          decoration:
                              isViewDetails ? TextDecoration.underline : null,
                        ),
                      ),
                      TextSpan(
                        text: subtitle,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: Color(0xFF979797),
                    fontSize: 12,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
