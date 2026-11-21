import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/home_widget/data/networking_store.dart';
import 'package:finnet/features/home_widget/data/widget_photos.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

/// "Show people's photos in widgets", in Settings (docs/HOME_WIDGETS.md,
/// "Photos"): whether the large Networking widget's "Recently met" shows
/// people's photos or, as it does unless this is on, their initials.
///
/// Null while the saved choice is read. Off by default, and off again at
/// every sign-out (the photos go with it). Turned off, every photo is
/// deleted at once and the widget drawn again with initials.
final widgetPhotosSettingProvider =
    StateNotifierProvider<WidgetPhotosSetting, bool?>((ref) {
  final networking = ref.watch(networkingStoreProvider);
  return WidgetPhotosSetting(
    ref.watch(widgetPhotosProvider),
    redraw: networking.redraw,
  );
});

class WidgetPhotosSetting extends StateNotifier<bool?> {
  WidgetPhotosSetting(this._photos, {Future<void> Function()? redraw})
      : _redraw = redraw,
        super(null) {
    _loaded = _load();
  }

  final WidgetPhotos _photos;
  final Future<void> Function()? _redraw;
  late final Future<void> _loaded;

  /// A tap before the saved choice is read wins over it.
  bool _changed = false;

  /// Completes once the saved choice is in [state].
  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    final on = await _photos.store.isOn();
    if (!mounted || _changed) return;
    state = on;
  }

  /// Turn the photos on or off. Off deletes every photo, then redraws the
  /// widgets (which show initials for anyone without one).
  Future<void> set(bool on) async {
    if (state == on) return;
    _changed = true;
    state = on;
    try {
      await _photos.store.setOn(on);
      if (!on) {
        await _photos.removeAll();
        await _redraw?.call();
      }
    } catch (e) {
      debugPrint('WidgetPhotosSetting: $e');
    }
  }
}

/// The Settings row: the switch, a line saying what it does, then a
/// divider. Nothing while the saved choice is read.
class WidgetPhotosRow extends ConsumerWidget {
  const WidgetPhotosRow({super.key});

  static const rowKey = ValueKey('settings-widget-photos');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(widgetPhotosSettingProvider);
    if (on == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          key: rowKey,
          emoji: '🖼️',
          label: 'Show people’s photos in widgets',
          value: on,
          onChanged: ref.read(widgetPhotosSettingProvider.notifier).set,
        ),
        const SettingsCaption(
          'The large Networking widget shows the people you met last. '
          'Off, it shows their initials. Anyone who can see your home '
          'screen sees the widget.',
        ),
        const SettingsDivider(),
      ],
    );
  }
}
