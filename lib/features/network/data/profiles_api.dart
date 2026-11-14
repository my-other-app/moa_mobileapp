import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_errors.dart';
import 'package:finnet/features/network/domain/profile.dart';

final profilesApiProvider = Provider<ProfilesApi>((ref) => ProfilesApi());

/// What `GET /profiles/{handle}` answered.
sealed class ProfileLookup {
  const ProfileLookup();
}

class ProfileFound extends ProfileLookup {
  const ProfileFound(this.profile);
  final PublicProfile profile;
}

/// Unknown, deleted, hidden by the moderators, or blocked either way: the
/// server says the same 404 for all four, and so does the app.
class ProfileMissing extends ProfileLookup {
  const ProfileMissing();
}

/// What a personal QR's code led to.
sealed class CodeLookup {
  const CodeLookup();
}

class CodeFound extends CodeLookup {
  const CodeFound(this.profile);
  final PublicProfile profile;
}

/// The owner replaced the code: it stopped working at once.
class CodeInactive extends CodeLookup {
  const CodeInactive();
}

/// The owner switched scanning off.
class CodeScanningOff extends CodeLookup {
  const CodeScanningOff();
}

class CodeMissing extends CodeLookup {
  const CodeMissing();
}

/// Profiles on the server (feature-register
/// `profiles-networking-contract.md`): the person's own, its links and
/// projects, their QR, and anyone's public page.
class ProfilesApi {
  ProfilesApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  /// `GET /me/profile`.
  Future<MyProfile> me() async {
    final res = await _client.request('/me/profile', DioMethod.get);
    return _mine(res.data);
  }

  /// `PATCH /me/profile` with [changes] (any of the contract's fields).
  /// `HANDLE_TAKEN`, `HANDLE_INVALID`, `HANDLE_RESERVED` are thrown as
  /// they came.
  Future<MyProfile> update(Map<String, dynamic> changes) async {
    final res =
        await _client.request('/me/profile', DioMethod.patch, param: changes);
    return _mine(res.data);
  }

  /// `PUT /me/profile/links`: the whole list, in order.
  Future<MyProfile> putLinks(List<ProfileLink> links) async {
    final res = await _client.request('/me/profile/links', DioMethod.put,
        param: {'links': [for (final l in links) l.toJson()]});
    return _mine(res.data);
  }

  Future<ProfileProject> addProject(ProfileProject project) async {
    final res = await _client.request('/me/profile/projects', DioMethod.post,
        param: project.toJson());
    return _project(res.data, project);
  }

  Future<ProfileProject> updateProject(int id, ProfileProject project) async {
    final res = await _client.request(
        '/me/profile/projects/$id', DioMethod.patch,
        param: project.toJson());
    return _project(res.data, project.copyWith(id: id));
  }

  Future<void> deleteProject(int id) =>
      _client.request('/me/profile/projects/$id', DioMethod.delete);

  /// `PUT /me/profile/projects/order`: every project's id, in order.
  Future<void> orderProjects(List<int> ids) => _client.request(
      '/me/profile/projects/order', DioMethod.put,
      param: {'ids': ids});

  /// The picture at [path] (any format; the server resizes it) for the
  /// project.
  Future<ProfileProject> uploadProjectImage(
      int id, ProfileProject project, String path) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path,
          filename: name, contentType: imageTypeOf(name)),
    });
    final res = await _client.request(
        '/me/profile/projects/$id/image', DioMethod.post,
        formData: form);
    return _project(res.data, project);
  }

  Future<ProfileProject> deleteProjectImage(
      int id, ProfileProject project) async {
    final res = await _client.request(
        '/me/profile/projects/$id/image', DioMethod.delete);
    final answer = ProfileProject.fromJson(jsonObject(res.data) ?? const {});
    return answer ?? project.copyWith(clearImage: true);
  }

  /// `GET /me/qr`: made on the first ask. Kept on the phone (cleared at
  /// sign-out), so My QR opens with no signal at the venue.
  Future<MyQr> myQr() async {
    final res = await _client.request('/me/qr', DioMethod.get,
        cache: CachePolicy.personalKept);
    return _qr(res.data);
  }

  /// `POST /me/qr/replace`: a new code; the old one stops at once.
  Future<MyQr> replaceQr() async {
    final res = await _client.request('/me/qr/replace', DioMethod.post);
    return _qr(res.data);
  }

  /// `GET /profiles/{handle}`, as this viewer may see it; [anonymous] asks
  /// as nobody in particular -- "preview as a stranger".
  Future<ProfileLookup> profile(String handle, {bool anonymous = false}) async {
    try {
      final res = await _client.request(
          '/profiles/${Uri.encodeComponent(handle)}', DioMethod.get,
          skipAuth: anonymous);
      final profile = PublicProfile.fromJson(res.data);
      return profile == null ? const ProfileMissing() : ProfileFound(profile);
    } catch (e) {
      if (statusCodeOf(e) == 404) return const ProfileMissing();
      rethrow;
    }
  }

  /// `GET /profiles/by-code/{code}`: whose personal QR this is.
  Future<CodeLookup> byCode(String code) async {
    try {
      final res = await _client.request(
          '/profiles/by-code/${Uri.encodeComponent(code)}', DioMethod.get);
      final json = jsonObject(res.data);
      final inner = jsonObject(json?['profile']);
      // The handle beside the profile, should the profile leave it out.
      final profile = PublicProfile.fromJson(
          inner == null ? null : {'handle': json?['handle'], ...inner});
      return profile == null ? const CodeMissing() : CodeFound(profile);
    } catch (e) {
      final code = errorCodeOf(e);
      if (code == profileCodeInactiveCode || statusCodeOf(e) == 410) {
        return const CodeInactive();
      }
      if (code == profileScanningOffCode) return const CodeScanningOff();
      if (statusCodeOf(e) == 404) return const CodeMissing();
      rethrow;
    }
  }

  /// `GET /profiles/{handle}/vcard`: their contact card, as text.
  Future<String> vcard(String handle) async {
    final res = await _client.request(
        '/profiles/${Uri.encodeComponent(handle)}/vcard', DioMethod.get);
    return textOfAnswer(res.data);
  }

  static MyProfile _mine(Object? data) {
    final mine = MyProfile.fromJson(data);
    if (mine == null) throw const FormatException('No profile in the answer');
    return mine;
  }

  static ProfileProject _project(Object? data, ProfileProject sent) =>
      ProfileProject.fromJson(jsonObject(data) ?? const {}) ?? sent;

  static MyQr _qr(Object? data) {
    final qr = MyQr.fromJson(data);
    if (qr == null) throw const FormatException('No code in the answer');
    return qr;
  }
}

/// A file's body as text: Dio hands a `text/*` answer back as a string,
/// and anything else as it decoded it.
String textOfAnswer(Object? data) {
  if (data is String) return data;
  if (data is List<int>) return utf8.decode(data, allowMalformed: true);
  return data?.toString() ?? '';
}

/// The type a picture is sent as: the server refuses anything not sent as
/// `image/*`, and Dio would say `application/octet-stream`.
DioMediaType imageTypeOf(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'png' => DioMediaType('image', 'png'),
    'webp' => DioMediaType('image', 'webp'),
    'gif' => DioMediaType('image', 'gif'),
    'heic' || 'heif' => DioMediaType('image', ext),
    _ => DioMediaType('image', 'jpeg'),
  };
}
