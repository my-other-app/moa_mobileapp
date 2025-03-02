import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/club_individual_page.dart';
import 'package:myotherapp/modules/home/pages/event_page/individual_event_page.dart';
import 'package:myotherapp/modules/home/custom_widgets/svg_icon.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String organizer;
  final String imageUrl;
  final List<String> tags;
  final VoidCallback onTap;
  final String orgImage;
  final int eventId;
  final int clubId;
  final String clubSlug;
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
    required this.clubSlug,
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
                            clubSlug: clubSlug,
                            clubname: organizer,
                          )),
                );
              },
              child: SizedBox(
                width: 48,
                height: 48,
                child: CachedNetworkImage(
                  imageUrl: orgImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      width: 48,
                      height: 48,
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
                                  clubSlug: clubSlug,
                                  clubname: organizer,
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
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              imageBuilder: (context, imageProvider) => Container(
                height: size.height * 0.5,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              placeholder: (context, url) => Container(
                height: size.height * 0.5,

                width: double.infinity,

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),

                  color: Colors.grey[300], // Placeholder color
                ),

                child: Center(
                    child:
                        CircularProgressIndicator()), // Optional loading indicator
              ),
              errorWidget: (context, url, error) => Container(
                height: size.height * 0.5,

                width: double.infinity,

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),

                  color: Colors.red, // Error color
                ),

                child: Center(child: Icon(Icons.error)), // Optional error icon
              ),
            )

            // Container(
            //   height: size.height * .5,
            //   width: double.infinity,
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(10.0),
            //     image: DecorationImage(
            //       image: NetworkImage(imageUrl),
            //       fit: BoxFit.cover,
            //     ),
            //   ),
            // ),
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
