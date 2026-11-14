import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/network/data/profiles_api.dart';
import 'package:finnet/features/network/domain/network_errors.dart';
import 'package:finnet/features/network/domain/profile.dart';

class MyProfileState {
  const MyProfileState({this.profile, this.loading = false, this.error});

  /// Null until read.
  final MyProfile? profile;
  final bool loading;

  /// Why it could not be read, when there is nothing to show.
  final Object? error;
}

/// The person's public profile and its settings, for the editor, the
/// Profile tab's header and My QR. Each change is the server's answer
/// once it has one; the caller shows why one failed (it is thrown).
class MyProfileNotifier extends StateNotifier<MyProfileState> {
  MyProfileNotifier(this._api) : super(const MyProfileState());

  final ProfilesApi _api;

  MyProfile? get _mine => state.profile;

  void _set(MyProfile profile) {
    if (mounted) state = MyProfileState(profile: profile);
  }

  Future<void> load() async {
    if (mounted) {
      state = MyProfileState(profile: _mine, loading: true);
    }
    try {
      _set(await _api.me());
    } catch (e) {
      if (mounted) state = MyProfileState(profile: _mine, error: e);
    }
  }

  /// Read only if not read yet.
  Future<void> ensureLoaded() async {
    if (_mine == null && !state.loading) await load();
  }

  /// `PATCH /me/profile` with [changes].
  Future<void> update(Map<String, dynamic> changes) async =>
      _set(await _api.update(changes));

  Future<void> setLinks(List<ProfileLink> links) async =>
      _set(await _api.putLinks(links));

  List<ProfileProject> get _projects => _mine?.profile.projects ?? const [];

  void _setProjects(List<ProfileProject> projects) {
    final mine = _mine;
    if (mine != null) _set(mine.withProjects(projects));
  }

  /// A new project, or changes to one; answers it as saved.
  Future<ProfileProject> saveProject(ProfileProject project) async {
    final id = project.id;
    if (id == null) {
      final added = await _api.addProject(project);
      _setProjects([..._projects, added]);
      unawaited(_refreshQuietly());
      return added;
    }
    final saved = await _api.updateProject(id, project);
    _setProjects([for (final p in _projects) p.id == id ? saved : p]);
    return saved;
  }

  Future<void> deleteProject(int id) async {
    await _api.deleteProject(id);
    _setProjects([
      for (final p in _projects)
        if (p.id != id) p
    ]);
    unawaited(_refreshQuietly());
  }

  /// Shown in the new order at once; the server's answer once it has one.
  /// Refused, it goes back -- and when the server's projects are not the
  /// ones on screen (`ORDER_INVALID`), they are read again.
  Future<void> reorderProjects(List<ProfileProject> order) async {
    final before = _projects;
    _setProjects(order);
    try {
      _set(await _api.orderProjects([
        for (final p in order)
          if (p.id != null) p.id!
      ]));
    } catch (e) {
      _setProjects(before);
      if (errorCodeOf(e) == orderInvalidCode) unawaited(_refreshQuietly());
      rethrow;
    }
  }

  Future<void> setProjectImage(ProfileProject project, String path) async {
    final saved = await _api.uploadProjectImage(project.id!, project, path);
    _setProjects([for (final p in _projects) p.id == project.id ? saved : p]);
  }

  Future<void> removeProjectImage(ProfileProject project) async {
    final saved = await _api.deleteProjectImage(project.id!, project);
    _setProjects([for (final p in _projects) p.id == project.id ? saved : p]);
  }

  /// The completeness score follows the projects; read it again without
  /// putting the editor into its loading state.
  Future<void> _refreshQuietly() async {
    try {
      _set(await _api.me());
    } catch (_) {
      // What is on screen stays.
    }
  }
}

final myProfileProvider =
    StateNotifierProvider<MyProfileNotifier, MyProfileState>((ref) {
  // Another person signing in starts from nothing.
  ref.watch(isAuthenticatedProvider);
  return MyProfileNotifier(ref.watch(profilesApiProvider));
});
