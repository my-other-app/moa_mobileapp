import 'package:flutter/material.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';

/// Adding or changing one link: paste it, and the type picks itself
/// (LinkedIn, GitHub...); a label is optional. Answers the link, or null.
Future<ProfileLink?> showLinkSheet(BuildContext context, {ProfileLink? link}) {
  return showModalBottomSheet<ProfileLink>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => LinkSheet(link: link),
  );
}

class LinkSheet extends StatefulWidget {
  const LinkSheet({super.key, this.link});

  final ProfileLink? link;

  static const urlKey = ValueKey('link-sheet-url');
  static const labelKey = ValueKey('link-sheet-label');
  static const typeKey = ValueKey('link-sheet-type');
  static const doneKey = ValueKey('link-sheet-done');

  @override
  State<LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<LinkSheet> {
  late final _url =
      TextEditingController(text: widget.link?.uri.toString() ?? '');
  late final _label = TextEditingController(text: widget.link?.label ?? '');
  late String _type = widget.link?.type ?? 'website';

  /// The person chose the type: a later paste doesn't change it.
  late bool _typeChosen = widget.link != null;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  void _onUrl(String text) {
    final uri = profileLinkUri(text);
    setState(() {
      _error = null;
      if (uri != null && !_typeChosen) _type = profileLinkTypeFor(uri);
    });
  }

  void _done() {
    final uri = profileLinkUri(_url.text);
    if (uri == null) {
      setState(() => _error = 'That doesn\'t look like a web link. Paste one '
          'that starts with https://');
      return;
    }
    final label = _label.text.trim();
    Navigator.of(context).pop(ProfileLink(
      type: _type,
      uri: uri,
      label: label.isEmpty ? null : label,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.link == null ? 'Add a link' : 'Change link',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              key: LinkSheet.urlKey,
              controller: _url,
              onChanged: _onUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Link',
                hintText: 'https://github.com/you',
                border: const OutlineInputBorder(),
                errorText: _error,
                counterText: '',
                prefixIcon: Icon(profileLinkIcon(_type)),
              ),
            ),
            const SizedBox(height: 12),
            // Follows the pasted link's type until the person picks one.
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: LinkSheet.typeKey,
                  value: _type,
                  isExpanded: true,
                  items: [
                    for (final type in profileLinkTypes)
                      DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(profileLinkIcon(type), size: 18),
                            const SizedBox(width: 8),
                            Text(type == 'other'
                                ? 'Other'
                                : profileLinkTypeLabel(type)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (type) => setState(() {
                    _type = type ?? _type;
                    _typeChosen = true;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: LinkSheet.labelKey,
              controller: _label,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'My blog',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: LinkSheet.doneKey,
              onPressed: _done,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
