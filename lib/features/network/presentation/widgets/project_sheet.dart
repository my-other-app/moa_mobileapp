import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/features/profile/data/photo_picker.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// Adding or changing one project: title, one line, a link, the person's
/// role, the month, tags -- and its picture once it is saved. Saved from
/// the sheet itself; answers true when anything changed.
Future<bool?> showProjectSheet(BuildContext context,
    {ProfileProject? project}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => ProjectSheet(project: project),
  );
}

class ProjectSheet extends ConsumerStatefulWidget {
  const ProjectSheet({super.key, this.project});

  final ProfileProject? project;

  static const titleKey = ValueKey('project-title');
  static const summaryKey = ValueKey('project-summary');
  static const urlKey = ValueKey('project-url');
  static const roleKey = ValueKey('project-role');
  static const tagKey = ValueKey('project-tag');
  static const saveKey = ValueKey('project-save');
  static const deleteKey = ValueKey('project-delete');
  static const pictureKey = ValueKey('project-picture');

  @override
  ConsumerState<ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends ConsumerState<ProjectSheet> {
  late ProfileProject? _saved = widget.project;
  late final _title = TextEditingController(text: _saved?.title ?? '');
  late final _summary = TextEditingController(text: _saved?.summary ?? '');
  late final _url = TextEditingController(text: _saved?.uri?.toString() ?? '');
  late final _role = TextEditingController(text: _saved?.role ?? '');
  final _tag = TextEditingController();
  late final List<String> _tags = List.of(_saved?.tags ?? const []);
  late DateTime? _month = _saved?.month;
  bool _busy = false;
  String? _error;
  bool _changed = false;

  @override
  void dispose() {
    for (final c in [_title, _summary, _url, _role, _tag]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  void _addTag([String? typed]) {
    final tag = (typed ?? _tag.text).trim();
    if (tag.isEmpty) return;
    setState(() {
      _error = null;
      if (_tags.length >= ProfileProject.maxTags) {
        _error = 'At most ${ProfileProject.maxTags} tags.';
      } else if (!_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
        _tags.add(tag);
      }
      _tag.clear();
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _month ?? DateTime(now.year, now.month),
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 1, 12),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'When was it?',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _save() async {
    if (_tag.text.trim().isNotEmpty) _addTag();
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give it a title.');
      return;
    }
    final urlText = _url.text.trim();
    final uri = urlText.isEmpty ? null : profileLinkUri(urlText);
    if (urlText.isNotEmpty && uri == null) {
      setState(() => _error = "The link doesn't look right: paste one that "
          'starts with https://');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(myProfileProvider.notifier).saveProject(
            ProfileProject(
              id: _saved?.id,
              title: title,
              summary: _nullIfEmpty(_summary),
              uri: uri,
              image: _saved?.image,
              tags: _tags,
              role: _nullIfEmpty(_role),
              month: _month,
            ),
          );
      if (!mounted) return;
      final isNew = _saved?.id == null;
      setState(() {
        _saved = saved;
        _busy = false;
        _changed = true;
      });
      // A new one stays open, to add its picture.
      if (!isNew) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = extractErrorMessage(e,
            defaultMessage: "Couldn't save the project. Try again.");
      });
    }
  }

  Future<void> _picture({bool remove = false}) async {
    final project = _saved;
    if (project?.id == null) return;
    final notifier = ref.read(myProfileProvider.notifier);
    try {
      String? path;
      if (!remove) {
        path = await ref.read(photoPickerProvider).pick(PhotoSource.library);
        if (path == null) return;
      }
      setState(() => _busy = true);
      if (remove) {
        await notifier.removeProjectImage(project!);
      } else {
        await notifier.setProjectImage(project!, path!);
      }
      final now = ref
          .read(myProfileProvider)
          .profile
          ?.profile
          .projects
          .where((p) => p.id == project.id)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _saved = now ?? _saved;
        _changed = true;
      });
    } on PhotoPickFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = extractErrorMessage(e,
            defaultMessage: "Couldn't change the picture. Try again."));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final id = _saved?.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(myProfileProvider.notifier).deleteProject(id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = extractErrorMessage(e,
            defaultMessage: "Couldn't delete the project. Try again.");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    final image = saved?.image;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(saved?.id == null ? 'Add a project' : 'Project',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                if (saved?.id != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_changed),
                    child: const Text('Close'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: ProjectSheet.titleKey,
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              key: ProjectSheet.summaryKey,
              controller: _summary,
              maxLength: 160,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'In one line',
                  hintText: 'Tickets and check-in for 40 college clubs',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              key: ProjectSheet.urlKey,
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              maxLength: 500,
              decoration: const InputDecoration(
                  labelText: 'Link (optional)',
                  hintText: 'https://github.com/you/project',
                  counterText: '',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: ProjectSheet.roleKey,
              controller: _role,
              maxLength: 60,
              decoration: const InputDecoration(
                  labelText: 'Your role (optional)',
                  hintText: 'Design lead',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_month == null
                  ? 'When (optional)'
                  : DateFormat('MMMM yyyy').format(_month!)),
            ),
            const SizedBox(height: 12),
            TextField(
              key: ProjectSheet.tagKey,
              controller: _tag,
              maxLength: ProfileProject.maxTagLength,
              onSubmitted: _addTag,
              decoration: InputDecoration(
                labelText: 'Tags (up to ${ProfileProject.maxTags})',
                hintText: 'flutter',
                counterText: '',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                    tooltip: 'Add tag',
                    icon: const Icon(Icons.add),
                    onPressed: _addTag),
              ),
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
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
            if (saved?.id != null) ...[
              const SizedBox(height: 16),
              const Text('Picture',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 96,
                      height: 54,
                      child: image == null
                          ? Container(
                              color: AppColors.softGrey,
                              child: const Icon(Icons.image_outlined))
                          : AppNetworkImage(url: image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    key: ProjectSheet.pictureKey,
                    onPressed: _busy ? null : () => _picture(),
                    child: Text(image == null ? 'Add a picture' : 'Change'),
                  ),
                  if (image != null)
                    TextButton(
                      onPressed: _busy ? null : () => _picture(remove: true),
                      child: const Text('Remove'),
                    ),
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
              key: ProjectSheet.saveKey,
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(saved?.id == null ? 'Save project' : 'Save changes'),
            ),
            if (saved?.id != null) ...[
              const SizedBox(height: 4),
              TextButton(
                key: ProjectSheet.deleteKey,
                onPressed: _busy ? null : _delete,
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C)),
                child: const Text('Delete project'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
