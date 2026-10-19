import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

class ClubsOptionScreen extends ConsumerStatefulWidget {
  final String clubName;
  final String imageUrl;
  final int clubId;
  final bool isPinned;
  final bool isHidden;

  const ClubsOptionScreen({
    super.key,
    required this.clubName,
    required this.imageUrl,
    required this.clubId,
    this.isPinned = false,
    this.isHidden = false,
  });

  @override
  ConsumerState<ClubsOptionScreen> createState() => _ClubsOptionScreenState();
}

class _ClubsOptionScreenState extends ConsumerState<ClubsOptionScreen> {
  bool _isLoading = false;
  late bool _isPinned;
  late bool _isHidden;

  /// Whether the club is muted; null until known, and on a server that
  /// keeps no mutes (then there is no option to show).
  bool? _isMuted;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.isPinned;
    _isHidden = widget.isHidden;
    _loadMuted();
  }

  Future<void> _loadMuted() async {
    final result = await ref
        .read(pushSettingsRepositoryProvider)
        .isClubMuted(widget.clubId);
    if (!mounted) return;
    result.fold((_) {}, (muted) => setState(() => _isMuted = muted));
  }

  /// Mute or unmute: still following, but no pushes or inbox lines from the
  /// club. The push service then takes this device out of (or back into) the
  /// club's FCM topic.
  Future<void> _toggleMute() async {
    final muted = _isMuted;
    if (_isLoading || muted == null) return;
    setState(() => _isLoading = true);
    final result = await ref
        .read(pushSettingsRepositoryProvider)
        .setClubMuted(widget.clubId, muted: !muted);
    if (!mounted) return;
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change notifications: ${failure.message}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!muted
                ? '${widget.clubName} muted'
                : '${widget.clubName} unmuted'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(
            context, {'action': 'mute', 'success': true, 'isMuted': !muted});
      },
    );
  }

  Future<void> _unfollowClub() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await APIService.instance.request(
        '/clubs/unfollow/${widget.clubId}',
        DioMethod.post,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfollowed ${widget.clubName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, {'action': 'unfollow', 'success': true});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unfollow: ${extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleHideClub() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await APIService.instance.request(
        '/clubs/hide/${widget.clubId}',
        DioMethod.post,
      );
      final newHiddenState = !_isHidden;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newHiddenState
                ? 'Events from ${widget.clubName} hidden'
                : 'Events from ${widget.clubName} shown'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context,
            {'action': 'hide', 'success': true, 'isHidden': newHiddenState});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to hide events: ${extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePinClub() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await APIService.instance.request(
        '/clubs/pin/${widget.clubId}',
        DioMethod.post,
      );
      final newPinnedState = !_isPinned;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newPinnedState
                ? '${widget.clubName} pinned'
                : '${widget.clubName} unpinned'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context,
            {'action': 'pin', 'success': true, 'isPinned': newPinnedState});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pin: ${extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scrolls when the options are taller than the sheet may be (a short
    // screen, large text): four options and the header can be.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                // A club without a logo has no address to load.
                backgroundImage: widget.imageUrl.isEmpty
                    ? null
                    : appImageProvider(
                        widget.imageUrl,
                        decodeWidth: decodeWidthFor(
                            48, 48, MediaQuery.devicePixelRatioOf(context)),
                      ),
                onBackgroundImageError:
                    widget.imageUrl.isEmpty ? null : (_, __) {},
              ),
              const SizedBox(height: 8),
              Text(
                widget.clubName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: dividedRows([
                SettingsRow(
                  asset: AssetResources.unfollow,
                  label: 'Unfollow',
                  onTap: _unfollowClub,
                  padding: EdgeInsets.zero,
                ),
                SettingsRow(
                  asset: AssetResources.hideevents,
                  label: _isHidden ? 'Show Events' : 'Hide Events',
                  onTap: _toggleHideClub,
                  padding: EdgeInsets.zero,
                ),
                SettingsRow(
                  asset: AssetResources.pinit,
                  label: _isPinned ? 'Unpin' : 'Pin It',
                  onTap: _togglePinClub,
                  padding: EdgeInsets.zero,
                ),
                // Its pushes, on until muted: still following, but nothing
                // from it arrives.
                if (_isMuted != null)
                  SettingsRow(
                    key: const ValueKey('club-option-mute'),
                    asset: AssetResources.notifications,
                    label: 'Notifications',
                    value: !_isMuted!,
                    onChanged: (_) => _toggleMute(),
                    padding: EdgeInsets.zero,
                  ),
              ], indent: 0),
            )
        ],
      ),
    );
  }
}
