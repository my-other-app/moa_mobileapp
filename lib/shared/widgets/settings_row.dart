import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/widgets/app_toggle.dart';

/// A row of the Settings and Profile menus, after the Settings design: an
/// emoji in a soft grey circle, then the name -- and, for a row that is a
/// switch, an [AppToggle] at the right. No subtitle and no chevron.
///
/// The emoji is an [asset] (the app's emoji pictures) or an [emoji] drawn as
/// text in the same circle; on an iPhone the two look alike.
class SettingsRow extends StatelessWidget {
  final String label;

  /// One of the emoji pictures under `assets/icons`.
  final String? asset;

  /// An emoji to draw as text, when there is no picture of it.
  final String? emoji;

  /// Something to fill the circle with instead of an emoji: the person's
  /// own picture, on "Change Avatar".
  final Widget? picture;

  /// What a tap does, for a row that opens something.
  final VoidCallback? onTap;

  /// On or off, for a row that is a switch; null for one that is not.
  final bool? value;

  /// Told the new value when the switch, or the row around it, is tapped.
  final ValueChanged<bool>? onChanged;

  /// Left and right of the circle and the switch.
  final EdgeInsetsGeometry padding;

  const SettingsRow({
    super.key,
    required this.label,
    this.asset,
    this.emoji,
    this.picture,
    this.onTap,
    this.value,
    this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: gutter),
  }) : assert(asset != null || emoji != null || picture != null,
            'a row has its emoji');

  /// The space at the screen's edge.
  static const gutter = 16.0;

  /// The emoji's circle.
  static const circle = 48.0;

  /// Between the circle and the name.
  static const gap = 16.0;

  /// A row's height: the circle and eight above and below.
  static const height = circle + 16;

  bool get _isSwitch => value != null;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<bool>? change = onChanged;
    final VoidCallback? tap =
        _isSwitch ? (change == null ? null : () => change(!value!)) : onTap;

    return Semantics(
      container: true,
      button: !_isSwitch,
      toggled: value,
      enabled: tap != null,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tap,
          child: Padding(
            padding: padding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: height),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _EmojiCircle(
                        asset: asset, emoji: emoji, picture: picture),
                    const SizedBox(width: gap),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 15,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ),
                    if (_isSwitch) ...[
                      const SizedBox(width: 12),
                      AppToggle(value: value!, onChanged: onChanged),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiCircle extends StatelessWidget {
  final String? asset;
  final String? emoji;
  final Widget? picture;

  const _EmojiCircle({required this.asset, required this.emoji, this.picture});

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('settings-row-emoji'),
      width: SettingsRow.circle,
      height: SettingsRow.circle,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.softGrey,
        shape: BoxShape.circle,
      ),
      clipBehavior: picture != null ? Clip.antiAlias : Clip.none,
      child: picture != null
          ? SizedBox.expand(child: picture)
          : asset != null
          ? Image.asset(asset!, width: _size, height: _size)
          // Not scaled with the text, like the picture beside it.
          : Text(
              emoji!,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 21, height: 1.15),
            ),
    );
  }
}

/// The thin line between two rows: from the circle's edge to the screen's.
class SettingsDivider extends StatelessWidget {
  /// Where it starts: the circle's left edge.
  final double indent;

  const SettingsDivider({super.key, this.indent = SettingsRow.gutter});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      color: const Color(0xFFEDEDED),
    );
  }
}

/// A short grey line under a group of rows, for what the names alone do
/// not say.
class SettingsCaption extends StatelessWidget {
  final String text;
  final Color? color;

  const SettingsCaption(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SettingsRow.gutter + SettingsRow.circle + SettingsRow.gap,
          0,
          SettingsRow.gutter,
          14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: color ?? const Color(0xFF8A8A8A),
        ),
      ),
    );
  }
}

/// [rows] with a [SettingsDivider] between each two, starting [indent]
/// from the left: the circle's edge, which is the gutter on a screen and
/// nothing in a sheet that has its own.
List<Widget> dividedRows(List<Widget> rows,
        {double indent = SettingsRow.gutter}) =>
    [
      for (final (index, row) in rows.indexed) ...[
        if (index > 0) SettingsDivider(indent: indent),
        row,
      ],
    ];
