import 'package:flutter/material.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/presentation/home/pages/club_individual_page.dart';
import 'package:myotherapp/presentation/home/pages/individual_event_page.dart';
import 'package:myotherapp/presentation/home/widget/svg_icon.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String organizer;
  final String imageUrl;
  final List<String> tags;
  final VoidCallback onTap;
  final String orgImage;
  final int eventId;
  final int clubId;

  //link
  //club image

  const EventCard({
    super.key,
    required this.title,
    required this.organizer,
    required this.imageUrl,
    required this.tags,
    required this.onTap,
    required this.orgImage,
    required this.eventId,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ClubIndividualPage(
                            clubId: clubId,
                          )),
                );
              },
              child: SizedBox(
                child: Image.network(
                  orgImage,
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
              ),
            ),
            Expanded(
              child: Column(
                spacing: 4,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ClubIndividualPage(
                                  clubId: clubId,
                                )),
                      );
                    },
                    child: Text(
                      organizer,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(8.0).copyWith(right: 0),
                child: SvgIcon(svgIconPath: AssetResources.share),
              ),
            ),
          ],
        ),

        /// Event Image
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => IndividualEventPage(
                        eventId: eventId,
                      )),
            );
          },
          child: Container(
            height: size.height * .5,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        /// Tags
        Row(
          spacing: 16,
          children: tags.asMap().entries.map((entry) {
            int index = entry.key;
            String tag = entry.value;
            return Row(
              children: [
                if (index != 0) ...[
                  const SvgIcon(svgIconPath: AssetResources.star),
                  const SizedBox(width: 16),
                ],
                Text(
                  tag,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
        FilledButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => IndividualEventPage(
                        eventId: eventId,
                      )),
            );
          },
          child: Text('TAKE A CLOSER LOOK OF THE EVENT'),
        )
      ],
    );
  }
}
