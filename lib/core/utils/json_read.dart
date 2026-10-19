/// Forgiving readers for JSON from the server.
///
/// A model that reads a field with `as int` or `as String` throws a
/// TypeError when the server sends `3.0`, `"12"` or null instead -- and a
/// list mapped through that model loses every row for one odd field. These
/// read what is there when it can be read and answer null otherwise, so the
/// model decides the fallback.
library;

/// A string, or a number or bool written out; null for anything else.
String? jsonString(Object? value) {
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  return null;
}

/// [jsonString], or [fallback].
String jsonText(Object? value, [String fallback = '']) =>
    jsonString(value) ?? fallback;

/// An int from an int, a whole double, or a numeric string.
int? jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.isFinite ? value.toInt() : null;
  if (value is String) {
    final text = value.trim();
    return int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }
  return null;
}

/// A double from any number or numeric string.
double? jsonDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// A bool from a bool, 0/1, or "true"/"false".
bool? jsonBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
  }
  return null;
}

/// An object, with its keys as strings; null for anything else.
Map<String, dynamic>? jsonObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return {for (final entry in value.entries) '${entry.key}': entry.value};
  }
  return null;
}

/// The objects in a list, skipping anything that is not one; empty for
/// anything that is not a list.
List<Map<String, dynamic>> jsonObjects(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (jsonObject(item) case final object?) object,
  ];
}

/// A date from an ISO 8601 string; null for anything else.
DateTime? jsonDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
