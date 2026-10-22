import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/common/models/events/event_page_model.dart'
    show PersonLink, PersonLinkKind;
import 'package:finnet/shared/utils/external_links.dart';

IconData personLinkIcon(PersonLinkKind kind) => switch (kind) {
      PersonLinkKind.linkedin => Icons.work_outline,
      PersonLinkKind.instagram => Icons.camera_alt_outlined,
      PersonLinkKind.x => Icons.alternate_email,
      PersonLinkKind.youtube => Icons.play_circle_outline,
      PersonLinkKind.website => Icons.link,
    };

/// Opens [sheet] from the bottom: the event page's speakers and team, the
/// club page's team and partners. A swipe down, a tap above it or the drag
/// handle closes it.
Future<void> showDetailSheet(BuildContext context, Widget sheet) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => sheet,
  );
}

/// One person or one partner, in a sheet: their picture, their name, what
/// they do, a line more, what they wrote about themselves, and their links,
/// each opening outside the app.
class DetailSheet extends ConsumerWidget {
  /// A face, or a logo, about 88 across.
  final Widget picture;
  final String name;

  /// A role, a designation, a tier.
  final String? role;

  /// A quieter line under [role]: "Partner of Respawn Room since 2022".
  final String? note;

  /// A bio, a description.
  final String? body;
  final List<PersonLink> links;

  const DetailSheet({
    super.key,
    required this.picture,
    required this.name,
    this.role,
    this.note,
    this.body,
    this.links = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      // The sheet's full width. Left to its content, a sheet with no bio
      // shrank to the width of a name.
      child: Container(
        width: double.infinity,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              picture,
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              if (role != null) ...[
                const SizedBox(height: 4),
                Text(
                  role!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                ),
              ],
              if (body != null) ...[
                const SizedBox(height: 16),
                Text(
                  body!,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
              if (links.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final link in links)
                      OutlinedButton.icon(
                        key: ValueKey('detail-link-${link.kind.name}'),
                        onPressed: () async {
                          final opened =
                              await ref.read(linkLauncherProvider)(link.uri);
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Couldn't open that link")),
                            );
                          }
                        },
                        icon: Icon(personLinkIcon(link.kind), size: 18),
                        label: Text(link.label),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2C333D),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
