import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../core/api_constants.dart';

/// Connects to:
///   GET   /api/routing/places  — fetch nearby places by PlaceCategory enum value
///   POST  /api/routing/route   — calculate shortest route between two coordinates
///
/// Category values come from [AppCategory.backendValue] (e.g. 'RESTAURANT', 'FUEL').
/// No mapping layer lives here — callers pass the exact backend enum string directly.
class RoutingService {
  static const String _baseUrl = '$kApiHost/api/routing';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // -------------------------------------------------------------------------
  // GET /api/routing/places?lat=&lon=&category=
  //
  // [categoryBackendValue] must be the exact PlaceCategory enum string,
  // e.g. 'RESTAURANT', 'FUEL', 'PARK', 'PARKING', 'SUPERMARKET', 'MOSQUE'.
  //
  // Successful response: List of H3PlaceWrapper JSON objects, each shaped as:
  //   {
  //     "h3Index": <long>,
  //     "place": {
  //       "name": <string>,
  //       "category": <string>,
  //       "center": { "lat": <double>, "lon": <double> },
  //       "points": [ { "lat": <double>, "lon": <double> }, ... ]
  //     }
  //   }
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getNearbyPlaces({
    required double lat,
    required double lon,
    required String categoryBackendValue,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/places').replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'category': categoryBackendValue,
      });
      final response = await http.get(uri, headers: await _authHeaders());

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return {'success': true, 'data': decoded};
        }
        return {'success': true, 'data': <dynamic>[]};
      }
      return {
        'success': false,
        'message': 'Failed to load nearby places (${response.statusCode}).',
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server.',
        'data': null,
      };
    }
  }

  // -------------------------------------------------------------------------
  // POST /api/routing/route?lat1=&lon1=&lat2=&lon2=
  //
  // Successful response: RoutingPath JSON shaped as:
  //   {
  //     "pathNodes": [
  //       { "id": <long>, "latitude": <double>, "longitude": <double>, "order": <int> },
  //       ...
  //     ],
  //     "distance": <double>
  //   }
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getRoute({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/route').replace(queryParameters: {
        'lat1': lat1.toString(),
        'lon1': lon1.toString(),
        'lat2': lat2.toString(),
        'lon2': lon2.toString(),
      });
      final response = await http.post(uri, headers: await _authHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }
      String errorMessage = 'Failed to calculate route (${response.statusCode}).';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['message'] != null) errorMessage = body['message'] as String;
      } catch (_) {}
      return {
        'success': false,
        'message': errorMessage,
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server.',
        'data': null,
      };
    }
  }
}
