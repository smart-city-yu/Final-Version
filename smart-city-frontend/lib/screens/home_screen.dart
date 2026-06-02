import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_colors.dart';
import '../core/app_localizations.dart';
import '../models/app_category.dart';
import '../models/map_issue.dart';
import '../models/path_node.dart';
import '../models/place_marker.dart';
import '../models/report_summary.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../services/user_service.dart';
import '../services/routing_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/home/add_report_sheet.dart';
import '../widgets/home/go_to_sheet.dart';
import '../widgets/home/home_map_view.dart';
import '../widgets/home/issue_details_sheet.dart';
import '../widgets/home/place_details_sheet.dart';
import '../widgets/home/report_form_sheet.dart';
import '../widgets/home/success_dialog.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();
  final RoutingService _routingService = RoutingService();
  final UserService _userService = UserService();

  int _selectedNavIndex = 0;

  MapLibreMapController? _mapController;
  LatLng? _currentLocation;

  List<MapIssue> _mapIssues = [];
  List<ReportSummary> _summaryMarkers = [];
  List<PlaceMarker> _placeMarkers = [];
  List<LatLng> _pathPoints = [];

  final Set<String> _votedIssueIds = {};
  bool _isLoading = false;
  Timer? _mapMoveDebounce;
  int _fetchGeneration = 0;

  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _requestPermissionsThenLoad();
    _loadCurrentUserId();
  }

  Future<void> _requestPermissionsThenLoad() async {
    final statuses = await [
      Permission.locationWhenInUse,
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ].request();

    final locationGranted =
        statuses[Permission.locationWhenInUse] == PermissionStatus.granted;

    if (locationGranted) {
      _loadLocation();
    } else {
      if (statuses[Permission.locationWhenInUse] ==
          PermissionStatus.permanentlyDenied) {
        if (mounted) {
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.locationPermRequired),
              action: SnackBarAction(
                label: l.settingsLabel,
                onPressed: openAppSettings,
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    final result = await _userService.getProfile();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _currentUserId = (data['id'] as num?)?.toInt();
        });
      }
    }
  }

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    super.dispose();
  }

  void _setLoading(bool v) {
    if (mounted) setState(() => _isLoading = v);
  }

  Future<void> _loadLocation() async {
    _setLoading(true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _snack(AppLocalizations.of(context).gpsOff);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.locationPermDenied),
              action: SnackBarAction(
                label: l.settingsLabel,
                onPressed: openAppSettings,
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }
      if (perm == LocationPermission.denied) return;

      // Step 1: show last-known position instantly
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() =>
            _currentLocation = LatLng(last.latitude, last.longitude));
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 16),
        );
      }

      // Step 2: fresh fix — .timeout() used because Samsung Android 14
      // ignores LocationSettings.timeLimit and the Future hangs forever.
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 20));
      } catch (_) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          ).timeout(const Duration(seconds: 10));
        } catch (_) {
          if (mounted && _currentLocation == null) {
            _snack(AppLocalizations.of(context).unableToGetLocation);
          }
          return;
        }
      }
      if (!mounted) return;
      setState(() => _currentLocation = LatLng(pos!.latitude, pos.longitude));
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
      );
    } catch (e) {
      if (mounted && _currentLocation == null) {
        _snack(AppLocalizations.of(context).unableToGetLocation);
      }
    } finally {
      _setLoading(false);
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _mapController = controller);
  }

  void _recenterMap() {
    if (_currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
      );
    } else {
      _loadLocation();
    }
  }

  Future<void> _onMapReady() async {
    if (_mapController == null) return;
    final bounds = await _mapController!.getVisibleRegion();
    final zoom = _mapController!.cameraPosition?.zoom ?? 7.5;
    if (!mounted) return;
    _fetchForViewport(bounds, zoom);
  }

  void _onMapMove(LatLngBounds bounds, double zoom) {
    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _fetchForViewport(bounds, zoom),
    );
  }

  Future<void> _fetchForViewport(LatLngBounds bounds, double zoom) async {
    final gen = ++_fetchGeneration;

    if (zoom < 12) {
      final result = await _reportService.getViewportSummary(
        northLat: bounds.northeast.latitude,
        northLng: bounds.northeast.longitude,
        southLat: bounds.southwest.latitude,
        southLng: bounds.southwest.longitude,
        zoom: zoom.floor(),
      );
      if (!mounted || gen != _fetchGeneration) return;
      if (result['success'] == true) {
        final list = result['data'] as List<dynamic>;
        setState(() {
          _summaryMarkers = list
              .map((j) => ReportSummary.fromJson(j as Map<String, dynamic>))
              .where((s) => s.hasValidPosition)
              .toList();
          _mapIssues = [];
        });
      } else {
        _snack(result['message'] as String? ??
            AppLocalizations.of(context).failedToLoadMapSummary);
      }
    } else {
      final result = await _reportService.getViewportReports(
        northLat: bounds.northeast.latitude,
        northLng: bounds.northeast.longitude,
        southLat: bounds.southwest.latitude,
        southLng: bounds.southwest.longitude,
        zoom: zoom.floor(),
      );
      if (!mounted || gen != _fetchGeneration) return;
      setState(() => _summaryMarkers = []);
      if (result['success'] == true) {
        final list = result['data'] as List<dynamic>;
        setState(() {
          _mapIssues = list
              .map((j) => MapIssue.fromJson(j as Map<String, dynamic>))
              .where((issue) => issue.hasValidPosition)
              .toList();
        });
      } else {
        _snack(result['message'] as String? ??
            AppLocalizations.of(context).failedToLoadMapReports);
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  void _showIssueSheet(MapIssue issue) {
    final isOwnReport = _currentUserId != null &&
        issue.ownerId != null &&
        issue.ownerId == _currentUserId;

    showIssueDetailsSheet(
      context: context,
      issue: issue,
      isOwnReport: isOwnReport,
      alreadyVoted: _votedIssueIds.contains(issue.id),
      onVoteStillThere: () async {
        final result = await _reportService.voteReport(
          reportId: issue.id,
          voteType: 'Still',
        );
        if (result['success'] == true) {
          setState(() {
            _votedIssueIds.add(issue.id);
            final idx = _mapIssues.indexWhere((e) => e.id == issue.id);
            if (idx != -1) {
              _mapIssues[idx] = _mapIssues[idx].copyWith(
                stillThereCount: _mapIssues[idx].stillThereCount + 1,
                isVoted: true,
              );
            }
          });
          return null;
        } else {
          return result['message'] as String? ??
              AppLocalizations.of(context).couldNotSubmitVote;
        }
      },
      onVoteFixed: () async {
        final result = await _reportService.voteReport(
          reportId: issue.id,
          voteType: 'Fixed',
        );
        if (result['success'] == true) {
          setState(() {
            _votedIssueIds.add(issue.id);
            final idx = _mapIssues.indexWhere((e) => e.id == issue.id);
            if (idx != -1) {
              _mapIssues[idx] = _mapIssues[idx].copyWith(
                fixedCount: _mapIssues[idx].fixedCount + 1,
                isVoted: true,
              );
            }
          });
          return null;
        } else {
          return result['message'] as String? ??
              AppLocalizations.of(context).couldNotSubmitVote;
        }
      },
    );
  }

  void _showAddReportSheet() {
    showAddReportSheet(
      context: context,
      onCategorySelected: (AppCategory cat) => _showReportForm(cat),
    );
  }

  void _showReportForm(AppCategory category) {
    showReportFormSheet(
      context: context,
      category: category,
      onSubmit: (String? subProblem, String? description, String? note,
              List<XFile> images) =>
          _submitReport(
            category: category,
            subProblem: subProblem,
            description: description,
            note: note,
            images: images,
          ),
    );
  }

  Future<void> _submitReport({
    required AppCategory category,
    String? subProblem,
    String? description,
    String? note,
    List<XFile> images = const [],
  }) async {
    if (_currentLocation == null) {
      _snack(AppLocalizations.of(context).locationUnavailableAllow2);
      return;
    }

    final result = await _reportService.createReport(
      category: category.backendValue,
      subProblem: subProblem,
      description: description,
      note: note,
      lat: _currentLocation!.latitude,
      lon: _currentLocation!.longitude,
      images: images.isEmpty ? null : images,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final l = AppLocalizations.of(context);
      setState(() {
        _mapIssues.add(MapIssue(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          emoji: category.emoji,
          title: '${l.catDisplayName(category)} Report',
          sub: 'Reported just now',
          desc: '',
          color: category.color,
          position: _currentLocation!,
          subProblem: subProblem,
        ));
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
      );
      showSuccessDialog(
        context: context,
        title: l.reportSubmittedTitle,
        message: l.reportPinnedMsg(l.catDisplayName(category)),
      );
    } else {
      _snack(result['message'] as String? ??
          AppLocalizations.of(context).couldNotSubmitReport);
    }
  }

  void _showGoToSheet() {
    showGoToSheet(
      context: context,
      onCategorySelected: (AppCategory category) async {
        if (_currentLocation == null) {
          _snack(AppLocalizations.of(context).locationUnavailableAllow);
          return;
        }

        _setLoading(true);

        final result = await _routingService.getNearbyPlaces(
          lat: _currentLocation!.latitude,
          lon: _currentLocation!.longitude,
          categoryBackendValue: category.backendValue,
        );

        _setLoading(false);
        if (!mounted) return;

        final rawList = result['data'] as List<dynamic>?;
        if (result['success'] != true ||
            rawList == null ||
            rawList.isEmpty) {
          final l = AppLocalizations.of(context);
          _snack(result['message'] as String? ??
              l.noPlacesFoundCategory(l.catDisplayName(category)));
          return;
        }

        final places = rawList
            .map((j) =>
                PlaceMarker.fromH3Json(j as Map<String, dynamic>, category))
            .toList();

        setState(() {
          _placeMarkers = places;
          _pathPoints = [];
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(places.first.lat, places.first.lon),
            14,
          ),
        );
      },
    );
  }

  void _clearPlaces() {
    setState(() {
      _placeMarkers = [];
      _pathPoints = [];
    });
  }

  void _onTapPlace(PlaceMarker place) {
    if (_currentLocation == null) {
      _snack(AppLocalizations.of(context).locationUnavailable);
      return;
    }

    final dist = Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      place.lat,
      place.lon,
    );

    showPlaceDetailsSheet(
      context: context,
      place: place,
      distanceStr: AppLocalizations.of(context).formatDistance(dist),
      onRoute: () => _routeToPlace(place),
    );
  }

  Future<void> _routeToPlace(PlaceMarker place) async {
    if (_currentLocation == null) return;

    _setLoading(true);

    final result = await _routingService.getRoute(
      lat1: _currentLocation!.latitude,
      lon1: _currentLocation!.longitude,
      lat2: place.lat,
      lon2: place.lon,
    );

    _setLoading(false);
    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      final rawNodes = data['pathNodes'] as List<dynamic>;
      final nodes = rawNodes
          .map((n) => PathNode.fromJson(n as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      setState(() {
        _pathPoints =
            nodes.map((n) => LatLng(n.latitude, n.longitude)).toList();
        _placeMarkers = [];
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      );

      final l = AppLocalizations.of(context);
      showSuccessDialog(
        context: context,
        title: l.navigationStartedTitle,
        message: l.routingToMsg(place.name),
      );
    } else {
      _snack(result['message'] as String? ??
          AppLocalizations.of(context).couldNotCalculateRoute);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildBody() {
    if (_selectedNavIndex == 2) return const ProfileScreen();

    if (_selectedNavIndex == 1) {
      return ReportsScreen(
        onNavigateToLocation: (latLng) {
          setState(() => _selectedNavIndex = 0);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(latLng, 17),
            );
          });
        },
      );
    }

    return HomeMapView(
      mapIssues: _mapIssues,
      summaryMarkers: _summaryMarkers,
      placeMarkers: _placeMarkers,
      currentLocation: _currentLocation,
      onLogout: _logout,
      onRecenter: _recenterMap,
      onShowAddReport: _showAddReportSheet,
      onShowGoTo: _showGoToSheet,
      onClearPlaces: _clearPlaces,
      onCancelRoute: _clearPlaces,
      onTapIssue: _showIssueSheet,
      onTapPlace: _onTapPlace,
      pathPoints: _pathPoints,
      onMapCreated: _onMapCreated,
      onMapMove: _onMapMove,
      onMapReady: _onMapReady,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildBody()),
                HomeBottomNavBar(
                  selectedIndex: _selectedNavIndex,
                  onTap: (i) {
                    setState(() => _selectedNavIndex = i);
                    // Navigate to user location when returning to map tab
                    if (i == 0 && _currentLocation != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }
}
