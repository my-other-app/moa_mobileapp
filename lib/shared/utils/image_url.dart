/// The first usable URL in a server image value, or null when there is none.
///
/// The backend stores images as an S3 dict -- `{original, large, medium,
/// thumbnail}` -- but older rows carry a bare URL string, and a club that never
/// uploaded a logo has `null`. Reading such a value with
/// `club['logo']['thumbnail']` throws on the null (a red screen on the clubs
/// tab), and on a bare string, so every read of one goes through here instead.
///
/// [prefer] is the order the dict's keys are tried in: the smallest size that
/// will do first, so an avatar does not download the original.
String? imageUrlFrom(
  dynamic value, {
  List<String> prefer = const ['thumbnail', 'medium', 'large', 'original'],
}) {
  if (value is String) {
    final url = value.trim();
    return url.isEmpty ? null : url;
  }
  if (value is Map) {
    for (final key in prefer) {
      final url = value[key];
      if (url is String && url.trim().isNotEmpty) return url.trim();
    }
  }
  return null;
}
