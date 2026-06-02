import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'app_category.dart';

class MapIssue {
  final String id;
  final String emoji;
  final String title;
  final String sub;
  final String desc;
  final Color color;
  final LatLng position;

  final int stillThereCount;
  final int fixedCount;
  final bool isVoted;
  final List<String> imageUrls;

  /// The predefined option the user selected (null for "other" paths).
  final String? subProblem;

  /// The ID of the user who submitted this report.
  /// Used to prevent self-voting on the map sheet.
  final int? ownerId;

  // ── AI analysis fields ──────────────────────────────────────────────────
  /// 0.0–1.0 confidence score returned by the AI service.
  final double validationScore;

  /// Human-readable reason from the AI (null = analysis not done yet).
  final String? validationReason;

  /// Priority level: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL" (null = not set).
  final String? priority;

  /// Who last set the priority — "AI" or "ADMIN".
  final String? prioritySetBy;

  /// Number of times the AI has (re-)analysed this report.
  final int revalidationCount;

  bool get hasValidPosition =>
      position.latitude != 0.0 || position.longitude != 0.0;

  const MapIssue({
    required this.id,
    required this.emoji,
    required this.title,
    required this.sub,
    required this.desc,
    required this.color,
    required this.position,

    this.stillThereCount = 0,
    this.fixedCount = 0,
    this.isVoted = false,
    this.imageUrls = const [],
    this.subProblem,

    this.validationScore = 0.0,
    this.validationReason,
    this.priority,
    this.prioritySetBy,
    this.revalidationCount = 0,
    this.ownerId,
  });

  /// Builds a [MapIssue] from a backend Report JSON object.
  ///
  /// Expected shape (mirrors the Report JPA entity):
  /// ```json
  /// {
  ///   "reportId":    "abc123",
  ///   "description": "Large pothole near intersection",
  ///   "lat":         31.9632,
  ///   "lon":         35.9304,
  ///   "category":    "pothole"   // exact ReportCategory enum value
  /// }
  /// ```
  factory MapIssue.fromJson(Map<String, dynamic> json) {
    final categoryValue = json['category'] as String? ?? '';
    final cat = reportCategoryFromValue(categoryValue);

    return MapIssue(
      id: json['reportId'] as String? ?? '',
      emoji: cat?.emoji ?? '📍',
      title: cat?.displayName ?? 'Road Issue',
      sub: 'Reported',
      desc: json['description'] as String? ?? '',
      color: cat?.color ?? const Color(0xFF607D8B),
      position: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lon'] as num?)?.toDouble() ?? 0.0,
      ),
      stillThereCount: (json['stillVotes'] as num?)?.toInt() ?? 0,
      fixedCount: (json['fixedVotes'] as num?)?.toInt() ?? 0,
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      subProblem: json['subProblem'] as String?,
      validationScore:
          (json['validationScore'] as num?)?.toDouble() ?? 0.0,
      validationReason: json['validationReason'] as String?,
      priority: json['priority'] as String?,
      prioritySetBy: json['prioritySetBy'] as String?,
      revalidationCount:
          (json['revalidationCount'] as num?)?.toInt() ?? 0,
      ownerId: (json['userId'] as num?)?.toInt(),
    );
  }

  MapIssue copyWith({
    String? id,
    String? emoji,
    String? title,
    String? sub,
    String? desc,
    Color? color,
    LatLng? position,
    int? stillThereCount,
    int? fixedCount,
    bool? isVoted,
    List<String>? imageUrls,
    String? subProblem,
    double? validationScore,
    String? validationReason,
    String? priority,
    String? prioritySetBy,
    int? revalidationCount,
    int? ownerId,
  }) {
    return MapIssue(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      title: title ?? this.title,
      sub: sub ?? this.sub,
      desc: desc ?? this.desc,
      color: color ?? this.color,
      position: position ?? this.position,
      stillThereCount: stillThereCount ?? this.stillThereCount,
      fixedCount: fixedCount ?? this.fixedCount,
      isVoted: isVoted ?? this.isVoted,
      imageUrls: imageUrls ?? this.imageUrls,
      subProblem: subProblem ?? this.subProblem,
      validationScore: validationScore ?? this.validationScore,
      validationReason: validationReason ?? this.validationReason,
      priority: priority ?? this.priority,
      prioritySetBy: prioritySetBy ?? this.prioritySetBy,
      revalidationCount: revalidationCount ?? this.revalidationCount,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}
