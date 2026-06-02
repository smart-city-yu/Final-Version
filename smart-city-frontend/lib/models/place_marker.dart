import 'app_category.dart';

/// Represents one nearby place returned by GET /api/routing/places.
///
/// Built from a single H3PlaceWrapper JSON object:
/// ```json
/// {
///   "h3Index": 123456789,
///   "place": {
///     "name":     "McDonald's",
///     "category": "RESTAURANT",
///     "center":   { "lat": 31.96, "lon": 35.93 },
///     "points":   [ ... ]
///   }
/// }
/// ```
class PlaceMarker {
  final String name;
  final double lat;
  final double lon;
  final AppCategory category;

  const PlaceMarker({
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
  });

  factory PlaceMarker.fromH3Json(
    Map<String, dynamic> json,
    AppCategory category,
  ) {
    final placeInfo = json['place'] as Map<String, dynamic>;
    final center = placeInfo['center'] as Map<String, dynamic>;
    return PlaceMarker(
      name: placeInfo['name'] as String? ?? category.displayName,
      lat: (center['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (center['lon'] as num?)?.toDouble() ?? 0.0,
      category: category,
    );
  }
}
