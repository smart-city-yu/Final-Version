import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';
import '../core/api_constants.dart';

/// Connects to:
///   POST  /api/report/create  — submit a new road issue report
///   GET   /api/report/all     — fetch all existing reports
///   POST  /api/report/vote    — vote on a report (Still / Fixed)
///
/// Note: the backend methods are currently stubs (empty bodies).
/// The frontend still makes the proper HTTP calls so that everything
/// works automatically once the backend is implemented.
class ReportService {
  static const String _baseUrl = '$kApiHost/api/report';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // -------------------------------------------------------------------------
  // POST /api/report/create
  //
  // Params (multipart/form-data):
  //   image        — MultipartFile  (required by backend signature)
  //   category     — ReportCategory enum value, e.g. "pothole"
  //   description  — String
  //   lat          — double
  //   lon          — double
  //
  // [imageBytes] is optional; an empty placeholder is sent when null so the
  // required `image` request-part is always present.
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> createReport({
    required String category,
    String? subProblem,
    String? description,
    String? note,
    required double lat,
    required double lon,
    List<XFile>? images,
  }) async {
    try {
      final token = await _authService.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/create'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['category'] = category;
      if (subProblem != null) request.fields['subProblem'] = subProblem;
      if (description != null) request.fields['description'] = description;
      if (note != null && note.isNotEmpty) request.fields['note'] = note;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();

      if (images != null) {
        for (final image in images) {
          final bytes = await image.readAsBytes();
          // Detect MIME type so Cloudinary accepts the upload.
          // XFile.mimeType is set by image_picker on Android/iOS;
          // fall back to extension detection, then default to jpeg
          // (camera captures are always JPEG on Android).
          final mime = _resolveMime(image);
          request.files.add(http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: image.name,
            contentType: MediaType.parse(mime),
          ));
        }
      }

      final streamed  = await request.send();
      final response  = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Report submitted successfully.'};
      }

      String errorMessage = 'Failed to submit report.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          errorMessage = body['message'] as String;
        }
      } catch (_) {}

      return {'success': false, 'message': errorMessage};
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to server.'};
    }
  }

  // -------------------------------------------------------------------------
  // GET /api/report/user  — current user's own reports
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getUserReports() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body == 'null') {
          return {'success': true, 'data': <dynamic>[]};
        }
        final decoded = jsonDecode(body);
        if (decoded is List) {
          return {'success': true, 'data': decoded};
        }
        return {'success': true, 'data': <dynamic>[]};
      }
      return {
        'success': false,
        'message': 'Failed to load your reports.',
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
  // GET /api/report/{id}  — single report (used for polling until AI finishes)
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getReportById(String reportId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$reportId'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'Report not found.', 'data': null};
    } catch (_) {
      return {'success': false, 'message': 'Could not connect.', 'data': null};
    }
  }

  // -------------------------------------------------------------------------
  // GET /api/report/all
  //
  // Returns a list of report JSON maps. The backend is currently a stub that
  // returns void/empty, so an empty list is returned in that case and the
  // caller falls back to local dummy data.
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getAllReports() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/all'),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body == 'null') {
          return {'success': true, 'data': <dynamic>[]};
        }
        final decoded = jsonDecode(body);
        if (decoded is List) {
          return {'success': true, 'data': decoded};
        }
        return {'success': true, 'data': <dynamic>[]};
      }
      return {
        'success': false,
        'message': 'Failed to load reports.',
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
  // GET /api/report/{id}/ai-history
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getAiHistory(String reportId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$reportId/ai-history'),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body == 'null') {
          return {'success': true, 'data': <dynamic>[]};
        }
        final decoded = jsonDecode(body);
        if (decoded is List) {
          return {'success': true, 'data': decoded};
        }
        return {'success': true, 'data': <dynamic>[]};
      }
      return {'success': false, 'message': 'Failed to load AI history.', 'data': null};
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to server.', 'data': null};
    }
  }

  // -------------------------------------------------------------------------
  // GET /api/report/all/summary
  //
  // Returns clustered summary markers for the given viewport when zoom < 12.
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getViewportSummary({
    required double northLat,
    required double northLng,
    required double southLat,
    required double southLng,
    required int zoom,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/all/summary').replace(
        queryParameters: {
          'northLat': northLat.toString(),
          'northLng': northLng.toString(),
          'southLat': southLat.toString(),
          'southLng': southLng.toString(),
          'zoom': zoom.toString(),
        },
      );
      final response = await http.get(uri, headers: await _authHeaders());

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body == 'null') {
          return {'success': true, 'data': <dynamic>[]};
        }
        final decoded = jsonDecode(body);
        if (decoded is List) {
          return {'success': true, 'data': decoded};
        }
        return {'success': true, 'data': <dynamic>[]};
      }
      return {
        'success': false,
        'message': 'Failed to load summary.',
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
  // GET /api/report/all/viewport
  //
  // Returns the full report list within the viewport when zoom >= 12.
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getViewportReports({
    required double northLat,
    required double northLng,
    required double southLat,
    required double southLng,
    required int zoom,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/all/viewport').replace(
        queryParameters: {
          'northLat': northLat.toString(),
          'northLng': northLng.toString(),
          'southLat': southLat.toString(),
          'southLng': southLng.toString(),
          'zoom': zoom.toString(),
        },
      );
      final response = await http.get(uri, headers: await _authHeaders());

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body == 'null') {
          return {'success': true, 'data': <dynamic>[]};
        }
        final decoded = jsonDecode(body);
        if (decoded is List) {
          return {'success': true, 'data': decoded};
        }
        return {'success': true, 'data': <dynamic>[]};
      }
      return {
        'success': false,
        'message': 'Failed to load reports.',
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
  // Resolves the MIME type for a camera-captured XFile.
  // image_picker sets XFile.mimeType on most platforms; when it's null
  // we fall back to the file extension, then to image/jpeg as a safe default
  // (Android camera always produces JPEG).
  // -------------------------------------------------------------------------
  static String _resolveMime(XFile file) {
    final declared = file.mimeType;
    if (declared != null && declared.isNotEmpty) return declared;

    final ext = file.name.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // camera default
    }
  }

  // -------------------------------------------------------------------------
  // POST /api/report/vote
  //
  // Params (query):
  //   reportId  — String
  //   voteType  — VoteType enum value: "Still" | "Fixed"
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> voteReport({
    required String reportId,
    required String voteType,
  }) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/vote').replace(queryParameters: {
        'reportId': reportId,
        'voteType': voteType,
      });
      final response = await http.post(uri, headers: await _authHeaders());

      if (response.statusCode == 200) {
        return {'success': true};
      }

      // Parse the backend's JSON error body to show the real message
      // e.g. "You can change your vote in 23 hour(s)."
      String errorMessage = 'Failed to submit vote.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          errorMessage = body['message'] as String;
        }
      } catch (_) {}

      return {'success': false, 'message': errorMessage};
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to server.'};
    }
  }
}
