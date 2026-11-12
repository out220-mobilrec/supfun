// Утилиты разбора JSON: сервер отдаёт null почти в любом поле,
// поэтому каждый читатель должен быть терпимым к пропущенным значениям.
library;

String? asStringOrNull(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

String asString(Object? value, [String fallback = '']) =>
    asStringOrNull(value) ?? fallback;

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return fallback;
}

DateTime? asDateOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

DateTime asDate(Object? value) =>
    asDateOrNull(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

List<String> asStringList(Object? value) {
  if (value is List) {
    return value
        .map((e) => asStringOrNull(e))
        .whereType<String>()
        .toList(growable: false);
  }
  return const [];
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is List) {
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }
  return const [];
}

Map<String, dynamic> asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// GeoJSON Point → (lat, lng). Сервер отдаёт и GeoJSON, и плоские
/// latitude/longitude — пользуемся и тем, и другим.
(double, double)? geoPoint(Map<String, dynamic> json) {
  final lat = asDoubleOrNull(json['latitude']);
  final lng = asDoubleOrNull(json['longitude']);
  if (lat != null && lng != null) return (lat, lng);
  final location = asMap(json['location']);
  final coordinates = location['coordinates'];
  if (coordinates is List && coordinates.length >= 2) {
    return (asDouble(coordinates[1]), asDouble(coordinates[0]));
  }
  return null;
}
