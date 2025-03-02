import 'package:flutter/material.dart';

class CertificateListCard extends StatelessWidget {
  final String title;
  final String organization;
  final String type;
  final String date;
  final String imageUrl;
  final VoidCallback? onTap;

  const CertificateListCard({
    super.key,
    required this.title,
    required this.organization,
    required this.type,
    required this.date,
    required this.imageUrl,
    this.onTap,
  });

  Widget _buildStarIcon() {
    return Container(
      width: 12,
      height: 12,
      decoration: ShapeDecoration(
        color: Color(0xFF1E1E1E),
        shape: StarBorder(
          points: 12,
          innerRadiusRatio: 0.38,
          pointRounding: 0,
          valleyRounding: 0,
          rotation: 0,
          squash: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 361,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 0.50),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          children: [
            // Certificate Image
            Container(
              width: 48,
              height: 48,
              decoration: ShapeDecoration(
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.fill,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Certificate Details
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 11),
                  // Details Row
                  Row(
                    children: [
                      Text(
                        organization,
                        style: TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontSize: 12,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStarIcon(),
                      const SizedBox(width: 8),
                      Text(
                        type,
                        style: TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontSize: 12,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStarIcon(),
                      const SizedBox(width: 8),
                      Text(
                        date,
                        style: TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontSize: 12,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios,
              size: 24,
              color: Color(0xFF2C333D),
            ),
          ],
        ),
      ),
    );
  }
}
