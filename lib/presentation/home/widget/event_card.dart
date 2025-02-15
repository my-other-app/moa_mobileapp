import 'package:flutter/material.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/core/resources/color_resources.dart';
import 'package:myotherapp/presentation/home/pages/individual_event_page.dart';
import 'package:myotherapp/presentation/home/widget/svg_icon.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String organizer;
  final String imageUrl;
  final List<String> tags;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.title,
    required this.organizer,
    required this.imageUrl,
    required this.tags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.network(
                'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 52,
                    height: 52,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported),
                  );
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      organizer,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: SvgIcon(svgIconPath: AssetResources.share),
              ),
            ],
          ),
          SizedBox(
            height: 10,
          ),
          Container(
            height: size.height * .5,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              image: DecorationImage(
                image: NetworkImage(
                  imageUrl,
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: tags.asMap().entries.map((entry) {
              int index = entry.key;
              String tag = entry.value;
              return Row(
                children: [
                  if (index != 0) ...[
                    const SvgIcon(svgIconPath: AssetResources.star),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          SizedBox(
            height: 20,
          ),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => IndividualEventPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorResources.buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'TAKE A CLOSER LOOK OF THE EVENT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: 'BebasNeue'),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }
}
