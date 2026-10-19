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

/// The host of the media CDN (`infra/cloudflare/media`). Its addresses are
/// permanent: the path names the picture, and the Worker caches by the path
/// alone, ignoring any query.
const mediaCdnHost = 'media.myotherapp.in';

/// Query parameters that sign a URL rather than name what it points at: an
/// S3 presigned link's `X-Amz-*`, and CloudFront's and older S3's signing
/// fields. Compared in lower case.
const _signingParams = {
  'signature',
  'expires',
  'key-pair-id',
  'policy',
  'awsaccesskeyid',
  'x-id',
};

bool _isSigningParam(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('x-amz-') || _signingParams.contains(lower);
}

/// The key an image is cached under: its address without what changes from
/// one API call to the next.
///
/// Pictures reach the app as presigned S3 links, re-signed on every call, so
/// a cache keyed on the full URL never hit -- each screen downloaded each
/// picture again, and again after every restart. The path is the S3 object,
/// a fresh name per upload, so it is stable for one picture and changes when
/// the picture does.
///
/// - A media CDN address ([mediaCdnHost]) is its path: the CDN ignores the
///   query, so the key does too.
/// - Elsewhere only the signing parameters are dropped. Any other parameter
///   may name the picture (`?seed=` on an avatar service), so it is kept,
///   in a fixed order.
/// - A fragment never reaches the server, and is dropped.
String imageCacheKey(String url) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return _withoutQuery(trimmed);
  }
  final base = '${uri.scheme}://${uri.host.toLowerCase()}'
      '${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
  if (uri.host.toLowerCase() == mediaCdnHost || !uri.hasQuery) return base;

  final kept = <String>[];
  uri.queryParametersAll.forEach((name, values) {
    if (_isSigningParam(name)) return;
    for (final value in values) {
      kept.add('${Uri.encodeQueryComponent(name)}='
          '${Uri.encodeQueryComponent(value)}');
    }
  });
  if (kept.isEmpty) return base;
  kept.sort();
  return '$base?${kept.join('&')}';
}

String _withoutQuery(String url) {
  var end = url.length;
  final query = url.indexOf('?');
  if (query >= 0) end = query;
  final fragment = url.indexOf('#');
  if (fragment >= 0 && fragment < end) end = fragment;
  return url.substring(0, end);
}

/// Whether [url] is an http(s) address with a host: something worth asking
/// the network for. Relative paths, `file:` and blank strings are not.
bool isWebImageUrl(String? url) {
  final value = url?.trim() ?? '';
  if (value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.isScheme('https') || uri.isScheme('http')) &&
      uri.host.isNotEmpty;
}
