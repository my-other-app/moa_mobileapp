import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/network/domain/network_errors.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/network/presentation/providers/my_profile_provider.dart';
import 'package:finnet/features/network/presentation/widgets/link_sheet.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';
import 'package:finnet/features/network/presentation/widgets/project_sheet.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/settings_row.dart';
import 'package:finnet/shared/widgets/toast.dart';

const _muted = Color(0xFF6B7280);
const maxLinks = 10;
const maxProjects = 12;

/// `/profile/public`: the profile people see when they scan the person's
/// QR or open their link -- handle, headline, bio, city, links (in their
/// order), projects with pictures -- and who sees each part, what contact
/// details are shared, and the switches for saves and recaps. "Preview"
/// shows it as a stranger does.
///
/// The name, photo and organisation are the account's, changed on Edit
/// Profile as before.
class EditPublicProfilePage extends ConsumerStatefulWidget {
  const EditPublicProfilePage({super.key});

  static const handleKey = ValueKey('public-handle');
  static const headlineKey = ValueKey('public-headline');
  static const bioKey = ValueKey('public-bio');
  static const cityKey = ValueKey('public-city');
  static const saveAboutKey = ValueKey('public-save-about');
  static const addLinkKey = ValueKey('public-add-link');
  static const addProjectKey = ValueKey('public-add-project');
  static const previewKey = ValueKey('public-preview');
  static const completenessKey = ValueKey('public-completeness');

  @override
  ConsumerState<EditPublicProfilePage> createState() =>
      _EditPublicProfilePageState();
}

class _EditPublicProfilePageState extends ConsumerState<EditPublicProfilePage> {
  final _handle = TextEditingController();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();

  /// The profile the fields were filled from: they are filled once.
  MyProfile? _filledFrom;
  String? _handleError;
  bool _savingAbout = false;

  /// Switches and choices on their way to the server, shown at once.
  final Map<String, Object> _pending = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(myProfileProvider.notifier).load());
    for (final c in [_handle, _headline, _bio, _city]) {
      c.addListener(_onEdit);
    }
  }

  @override
  void dispose() {
    for (final c in [_handle, _headline, _bio, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onEdit() => setState(() {});

  void _fill(MyProfile mine) {
    if (_filledFrom != null) return;
    _filledFrom = mine;
    _handle.text = mine.handle;
    _headline.text = mine.profile.headline ?? '';
    _bio.text = mine.profile.bio ?? '';
    _city.text = mine.profile.city ?? '';
  }

  Map<String, dynamic> _aboutChanges(MyProfile mine) {
    String? v(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final p = mine.profile;
    return {
      if (_handle.text.trim().toLowerCase() != mine.handle)
        'handle': _handle.text.trim().toLowerCase(),
      if (v(_headline) != p.headline) 'headline': v(_headline),
      if (v(_bio) != p.bio) 'bio': v(_bio),
      if (v(_city) != p.city) 'city': v(_city),
    };
  }

  Future<void> _saveAbout(MyProfile mine) async {
    final changes = _aboutChanges(mine);
    if (changes.isEmpty) return;
    final handle = changes['handle'] as String?;
    if (handle != null) {
      final problem = handleProblem(handle);
      if (problem != null) {
        setState(() => _handleError = problem);
        return;
      }
    }
    setState(() {
      _savingAbout = true;
      _handleError = null;
    });
    try {
      await ref.read(myProfileProvider.notifier).update(changes);
      final saved = ref.read(myProfileProvider).profile;
      if (saved != null) _filledFrom = saved;
      if (mounted) showToast(context, 'Saved.');
    } catch (e) {
      if (!mounted) return;
      final handleMessage = handleErrorMessage(e);
      if (handleMessage != null) {
        setState(() => _handleError = handleMessage);
      } else {
        showToast(context,
            extractErrorMessage(e, defaultMessage: "Couldn't save. Try again."),
            icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _savingAbout = false);
    }
  }

  /// One setting: shown at once, put back if the server refuses.
  Future<void> _set(String key, Object value, Map<String, dynamic> body) async {
    setState(() => _pending[key] = value);
    try {
      await ref.read(myProfileProvider.notifier).update(body);
    } catch (e) {
      if (mounted) {
        showToast(
            context,
            extractErrorMessage(e,
                defaultMessage: "Couldn't change that. Try again."),
            icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _pending.remove(key));
    }
  }

  Future<void> _setLinks(List<ProfileLink> links) async {
    try {
      await ref.read(myProfileProvider.notifier).setLinks(links);
    } catch (e) {
      if (!mounted) return;
      showToast(
          context,
          errorCodeOf(e) == linkInvalidCode
              ? "One of the links isn't allowed. Use an https:// web link."
              : extractErrorMessage(e,
                  defaultMessage: "Couldn't save your links. Try again."),
          icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileProvider);
    final mine = state.profile;
    if (mine != null) _fill(mine);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('MY PUBLIC PROFILE',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (mine != null)
            TextButton(
              key: EditPublicProfilePage.previewKey,
              onPressed: () => context.push(strangerPreviewLocation),
              child: const Text('Preview'),
            ),
        ],
      ),
      body: mine == null
          ? state.error != null
              ? ErrorView(
                  message: extractErrorMessage(state.error,
                      defaultMessage: "Couldn't load your profile."),
                  onRetry: () => ref.read(myProfileProvider.notifier).load(),
                )
              : const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.ink))
          : _form(mine),
    );
  }

  Widget _form(MyProfile mine) {
    final changed = _aboutChanges(mine).isNotEmpty;
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Completeness(mine: mine),
        _section('ABOUT YOU'),
        _pad(TextField(
          key: EditPublicProfilePage.handleKey,
          controller: _handle,
          autocorrect: false,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: 'Handle',
            prefixText: 'myotherapp.in/u/',
            errorText: _handleError,
            helperText: 'Changing it breaks links to the old one. Your QR '
                'keeps working.',
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        )),
        _pad(TextField(
          key: EditPublicProfilePage.headlineKey,
          controller: _headline,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Headline',
            hintText: "Flutter dev · CET '27",
            border: OutlineInputBorder(),
          ),
        )),
        _pad(TextField(
          key: EditPublicProfilePage.bioKey,
          controller: _bio,
          maxLength: 300,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Bio',
            hintText: 'What you build, what you are into',
            border: OutlineInputBorder(),
          ),
        )),
        _pad(TextField(
          key: EditPublicProfilePage.cityKey,
          controller: _city,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'City',
            hintText: 'Kochi',
            border: OutlineInputBorder(),
          ),
        )),
        _pad(FilledButton(
          key: EditPublicProfilePage.saveAboutKey,
          onPressed: !changed || _savingAbout ? null : () => _saveAbout(mine),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(46),
          ),
          child: Text(_savingAbout ? 'Saving…' : 'Save'),
        )),
        _pad(TextButton(
          onPressed: () => context.push('/profile/edit'),
          child: const Text('Name, photo and organisation are on Edit Profile'),
        )),
        _section('LINKS · ${mine.profile.links.length}/$maxLinks'),
        _links(mine),
        _section('PROJECTS · ${mine.profile.projects.length}/$maxProjects'),
        _projects(mine),
        _section('WHO SEES WHAT'),
        for (final section in profileSections)
          _ChoiceRow<Audience>(
            key: ValueKey('visibility-$section'),
            label: profileSectionLabel(section),
            value: _pending['vis:$section'] as Audience? ??
                mine.settings.audienceOf(section),
            values: Audience.values,
            labelOf: (a) => a.label,
            onChanged: (a) => _set('vis:$section', a, {
              'visibility': mine.settings.visibilityJson({section: a}),
            }),
          ),
        _ChoiceRow<ContactShare>(
          key: const ValueKey('share-email'),
          label: mine.email == null ? 'My email' : 'My email (${mine.email})',
          value: _pending['share_email'] as ContactShare? ??
              mine.settings.shareEmail,
          values: ContactShare.values,
          labelOf: (c) => c.label,
          onChanged: (c) => _set('share_email', c, {'share_email': c.name}),
        ),
        _ChoiceRow<ContactShare>(
          key: const ValueKey('share-phone'),
          label: mine.phone == null ? 'My phone' : 'My phone (${mine.phone})',
          value: _pending['share_phone'] as ContactShare? ??
              mine.settings.sharePhone,
          values: ContactShare.values,
          labelOf: (c) => c.label,
          onChanged: (c) => _set('share_phone', c, {'share_phone': c.name}),
        ),
        ..._switches(mine, [
          ('is_private', '🔒', 'Private profile', mine.settings.isPrivate),
          (
            'indexable',
            '🔎',
            'Let search engines find my profile',
            mine.settings.indexable
          ),
          (
            'show_events',
            '🎟️',
            'Show events I attended',
            mine.settings.showEvents
          ),
          (
            'show_certificates',
            '🏆',
            'Show my certificates',
            mine.settings.showCertificates
          ),
          ('show_talks', '🎤', 'Show talks I gave', mine.settings.showTalks),
          ('show_clubs', '🏛️', 'Show clubs I follow', mine.settings.showClubs),
        ]),
        if (_pending['is_private'] as bool? ?? mine.settings.isPrivate)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Strangers see only your name, photo and headline until you '
              'save them.',
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
          ),
        _section('QR AND SAVES'),
        ..._switches(mine, [
          (
            'scanning_enabled',
            '📷',
            'People can save me with my QR',
            mine.settings.scanningEnabled
          ),
          (
            'notify_saves',
            '🔔',
            'Tell me when someone saves me',
            mine.settings.notifySaves
          ),
          (
            'recap_emails',
            '📬',
            'Send me a recap after each event',
            mine.settings.recapEmails
          ),
        ]),
        SettingsRow(
          emoji: '🔁',
          label: 'Replace my QR code',
          onTap: () => context.push(myQrLocation),
        ),
      ],
    );
  }

  List<Widget> _switches(
      MyProfile mine, List<(String, String, String, bool)> rows) {
    return dividedRows([
      for (final (key, emoji, label, current) in rows)
        SettingsRow(
          key: ValueKey('switch-$key'),
          emoji: emoji,
          label: label,
          value: _pending[key] as bool? ?? current,
          onChanged: (on) => _set(key, on, {key: on}),
        ),
    ]);
  }

  Widget _links(MyProfile mine) {
    final links = mine.profile.links;
    return Column(
      children: [
        if (links.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              final order = List.of(links);
              order.insert(to, order.removeAt(from));
              _setLinks(order);
            },
            children: [
              for (final (i, link) in links.indexed)
                ListTile(
                  key: ValueKey('edit-link-$i-${link.uri}'),
                  leading: Icon(profileLinkIcon(link.type)),
                  title: Text(link.title),
                  subtitle: Text(link.uri.toString(),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    final changed = await showLinkSheet(context, link: link);
                    if (changed == null) return;
                    _setLinks([
                      for (final (j, l) in links.indexed) j == i ? changed : l
                    ]);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _setLinks([
                          for (final (j, l) in links.indexed)
                            if (j != i) l
                        ]),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        if (links.length < maxLinks)
          _pad(OutlinedButton.icon(
            key: EditPublicProfilePage.addLinkKey,
            onPressed: () async {
              final link = await showLinkSheet(context);
              if (link != null) _setLinks([...links, link]);
            },
            icon: const Icon(Icons.add_link),
            label: const Text('Add a link'),
          )),
      ],
    );
  }

  Widget _projects(MyProfile mine) {
    final projects = mine.profile.projects;
    return Column(
      children: [
        if (projects.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) async {
              final order = List.of(projects);
              order.insert(to, order.removeAt(from));
              try {
                await ref
                    .read(myProfileProvider.notifier)
                    .reorderProjects(order);
              } catch (e) {
                if (mounted) {
                  showToast(context, extractErrorMessage(e),
                      icon: Icons.error_outline);
                }
              }
            },
            children: [
              for (final (i, project) in projects.indexed)
                ListTile(
                  key: ValueKey('edit-project-${project.id ?? i}'),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 56,
                      height: 40,
                      child: project.image == null
                          ? Container(
                              color: AppColors.softGrey,
                              child: const Icon(Icons.work_outline, size: 20))
                          : AppNetworkImage(
                              url: project.image, fit: BoxFit.cover),
                    ),
                  ),
                  title: Text(project.title),
                  subtitle: project.summary == null
                      ? null
                      : Text(project.summary!,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => showProjectSheet(context, project: project),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
            ],
          ),
        if (projects.length < maxProjects)
          _pad(OutlinedButton.icon(
            key: EditPublicProfilePage.addProjectKey,
            onPressed: () => showProjectSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add a project'),
          )),
      ],
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(text,
            style: const TextStyle(fontFamily: 'BebasNeue', fontSize: 22)),
      );

  Widget _pad(Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: child,
      );
}

/// How much is filled in, and what to add next: "Make it easy for people
/// you meet to find your work."
class _Completeness extends StatelessWidget {
  const _Completeness({required this.mine});

  final MyProfile mine;

  @override
  Widget build(BuildContext context) {
    final c = mine.completeness;
    final missing = c.missing.map(ProfileCompleteness.missingLabel).toList();
    return Container(
      key: EditPublicProfilePage.completenessKey,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.complete ? AppColors.softGrey : AppColors.paleYellow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.complete
                ? 'Your profile is ready to share'
                : 'Make it easy for people you meet to find your work',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: c.score / 100,
              minHeight: 6,
              color: AppColors.ink,
              backgroundColor: Colors.white,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Add ${_join(missing)}.',
                style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  static String _join(List<String> parts) {
    if (parts.length == 1) return parts.single;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}

/// A setting with a few choices: who sees a part, who gets a detail.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            items: [
              for (final v in values)
                DropdownMenuItem(value: v, child: Text(labelOf(v))),
            ],
            onChanged: (v) {
              if (v != null && v != value) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
