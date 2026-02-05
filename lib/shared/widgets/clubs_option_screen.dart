import 'package:flutter/material.dart';
import 'package:myotherapp/common/widgets/custom_option_tile.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/core/utils/error_utils.dart';

class ClubsOptionScreen extends StatefulWidget {
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
  State<ClubsOptionScreen> createState() => _ClubsOptionScreenState();
}

class _ClubsOptionScreenState extends State<ClubsOptionScreen> {
  bool _isLoading = false;
  late bool _isPinned;
  late bool _isHidden;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.isPinned;
    _isHidden = widget.isHidden;
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
    return Padding(
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
                backgroundImage: NetworkImage(widget.imageUrl),
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
              children: [
                CustomOptionTile(
                  leadingImageName: AssetResources.unfollow,
                  title: const Text('Unfollow'),
                  onTap: _unfollowClub,
                ),
                const Divider(height: 0),
                CustomOptionTile(
                  leadingImageName: AssetResources.hideevents,
                  title: Text(_isHidden ? 'Show Events' : 'Hide Events'),
                  onTap: _toggleHideClub,
                ),
                const Divider(height: 0),
                CustomOptionTile(
                  leadingImageName: AssetResources.pinit,
                  title: Text(_isPinned ? 'Unpin' : 'Pin It'),
                  onTap: _togglePinClub,
                ),
              ],
            )
        ],
      ),
    );
  }
}
