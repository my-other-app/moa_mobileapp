import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/network/data/network_api.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';

/// "Add a note": the owner's private note and tags for someone in their
/// network. Answers the person as saved, or null when nothing changed.
Future<NetworkPerson?> showNoteSheet(
  BuildContext context,
  NetworkPerson person,
) {
  return showModalBottomSheet<NetworkPerson>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => NoteSheet(person: person),
  );
}

class NoteSheet extends ConsumerStatefulWidget {
  const NoteSheet({super.key, required this.person});

  final NetworkPerson person;

  static const noteKey = ValueKey('network-note-field');
  static const tagKey = ValueKey('network-tag-field');
  static const saveKey = ValueKey('network-note-save');

  @override
  ConsumerState<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<NoteSheet> {
  late final _note = TextEditingController(text: widget.person.note ?? '');
  final _tag = TextEditingController();
  late final List<String> _tags = List.of(widget.person.tags);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _addTag([String? typed]) {
    final tag = (typed ?? _tag.text).trim();
    if (tag.isEmpty) return;
    setState(() {
      _error = null;
      if (_tags.length >= NetworkPerson.maxTags) {
        _error = 'At most ${NetworkPerson.maxTags} tags.';
      } else if (tag.length > NetworkPerson.maxTagLength) {
        _error = 'A tag is at most ${NetworkPerson.maxTagLength} characters.';
      } else if (!_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
        _tags.add(tag);
      }
      _tag.clear();
    });
  }

  Future<void> _save() async {
    if (_tag.text.trim().isNotEmpty) _addTag();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(networkApiProvider)
          .update(widget.person.id, note: _note.text, tags: _tags);
      ref.invalidate(networkListProvider);
      ref.invalidate(networkPersonProvider(widget.person.id));
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = extractErrorMessage(e,
            defaultMessage: "Couldn't save the note. Try again.");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.person.person.fullName.split(' ').first;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('A note about $name',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Only you see your notes and tags.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            TextField(
              key: NoteSheet.noteKey,
              controller: _note,
              maxLength: NetworkPerson.maxNote,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Where you met, what you talked about…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: NoteSheet.tagKey,
              controller: _tag,
              maxLength: NetworkPerson.maxTagLength,
              textInputAction: TextInputAction.done,
              onSubmitted: _addTag,
              decoration: InputDecoration(
                hintText: 'Add a tag: designer, hiring, Flutter…',
                border: const OutlineInputBorder(),
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Add tag',
                  icon: const Icon(Icons.add),
                  onPressed: _addTag,
                ),
              ),
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in _tags)
                    TagPill(tag,
                        onDeleted: () => setState(() => _tags.remove(tag))),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style:
                      const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: NoteSheet.saveKey,
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save note'),
            ),
          ],
        ),
      ),
    );
  }
}
