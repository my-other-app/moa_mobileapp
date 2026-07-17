import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:finnet/features/clubs/presentation/providers/clubs_provider.dart';
import 'package:finnet/features/clubs/domain/entities/club_entity.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';

/// Club profile/detail page.
class ClubDetailPage extends ConsumerStatefulWidget {
  final int clubId;

  const ClubDetailPage({super.key, required this.clubId});

  @override
  ConsumerState<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends ConsumerState<ClubDetailPage> {
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clubDetailProvider(widget.clubId).notifier).loadClubDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubDetailProvider(widget.clubId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: state.isLoading
          ? const ShimmerClubDetail()
          : state.error != null
              ? _buildErrorState(state.error!)
              : state.club != null
                  ? _buildClubContent(state.club!, state)
                  : const Center(child: Text('Club not found')),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref
                  .read(clubDetailProvider(widget.clubId).notifier)
                  .loadClubDetails(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubContent(Club club, ClubDetailState state) {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: const Color(0xFF2C333D),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(
                  club.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.white),
              onPressed: () => ref
                  .read(clubDetailProvider(widget.clubId).notifier)
                  .togglePin(),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: const Color(0xFF2C333D),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFF17A58F), width: 3),
                      ),
                      child: ClipOval(
                        child: club.logo?.original != null
                            ? Image.network(club.logo!.original,
                                fit: BoxFit.cover)
                            : const Icon(Icons.business, size: 40),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(club.name,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('${club.followersCount}', 'Followers'),
                    _buildStat(club.rating.toStringAsFixed(1), 'Rating'),
                    _buildStat('${club.totalRatings}', 'Reviews'),
                  ],
                ),
                const SizedBox(height: 24),

                // Follow button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.isTogglingFollow
                        ? null
                        : () => ref
                            .read(clubDetailProvider(widget.clubId).notifier)
                            .toggleFollow(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: club.isFollowing
                          ? Colors.grey[300]
                          : const Color(0xFF17A58F),
                      foregroundColor:
                          club.isFollowing ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: state.isTogglingFollow
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(club.isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),

                // Interests
                if (club.interests.isNotEmpty) ...[
                  const Text('Interests',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        club.interests.map((i) => _buildTag(i.name)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // About
                if (club.description != null) ...[
                  const Text('About',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(
                        () => _descriptionExpanded = !_descriptionExpanded),
                    child: Text(
                      club.description!,
                      maxLines: _descriptionExpanded ? null : 3,
                      overflow:
                          _descriptionExpanded ? null : TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700], height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Location
                if (club.locationName != null) ...[
                  const Text('Location',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: club.locationLink != null
                        ? () => _launchUrl(club.locationLink!)
                        : null,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF17A58F)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(club.locationName!,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: club.locationLink != null
                                        ? const Color(0xFF17A58F)
                                        : Colors.grey[700]))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Social links
                if (club.socials?.hasAnySocialLinks ?? false) ...[
                  const Text('Connect',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (club.socials?.instagram != null)
                        _buildSocialButton(
                            Icons.camera_alt, club.socials!.instagram!),
                      if (club.socials?.linkedin != null)
                        _buildSocialButton(Icons.work, club.socials!.linkedin!),
                      if (club.socials?.youtube != null)
                        _buildSocialButton(
                            Icons.play_circle, club.socials!.youtube!),
                      if (club.socials?.twitter != null)
                        _buildSocialButton(Icons.tag, club.socials!.twitter!),
                      if (club.socials?.website != null)
                        _buildSocialButton(
                            Icons.language, club.socials!.website!),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Contact
                const Text('Contact',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (club.contactPhone != null)
                  _buildContactRow(Icons.phone, club.contactPhone!,
                      () => _launchUrl('tel:${club.contactPhone}')),
                if (club.contactEmail != null)
                  _buildContactRow(Icons.email, club.contactEmail!,
                      () => _launchUrl('mailto:${club.contactEmail}')),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFF17A58F).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16)),
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF17A58F))),
    );
  }

  Widget _buildSocialButton(IconData icon, String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF17A58F)),
        onPressed: () => _launchUrl(url),
        style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF17A58F).withValues(alpha: 0.1)),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text(text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF17A58F))),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
