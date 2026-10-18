import 'dart:convert';

/// The claims in [token]'s payload, read without checking the signature.
///
/// For the app's own bookkeeping only -- which session a token belongs to --
/// never for a decision the server has to trust. Null when [token] is not a
/// JWT.
Map<String, dynamic>? unverifiedJwtClaims(String? token) {
  if (token == null) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final claims = jsonDecode(payload);
    return claims is Map<String, dynamic> ? claims : null;
  } catch (_) {
    return null;
  }
}

/// The id of the session [token] belongs to: the `sid` claim the backend
/// puts in every access and refresh token it issues, which
/// `DELETE /auth/sessions/{sid}` ends. Null for tokens issued before sessions
/// existed, and for anything that is not a JWT.
String? sessionIdOf(String? token) {
  final sid = unverifiedJwtClaims(token)?['sid'];
  if (sid == null) return null;
  final text = sid.toString().trim();
  return text.isEmpty ? null : text;
}
