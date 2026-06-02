import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/map_issue.dart';
import '../models/app_category.dart';

class MapIssueParser {
  static MapIssue fromJson(Map<String, dynamic> json) {
    final categoryValue = json['category'] as String? ?? '';
    final cat = reportCategoryFromValue(categoryValue);

    final emoji = cat?.emoji ?? json['emoji'] as String? ?? '📍';
    final title = cat?.displayName ?? json['title'] as String? ?? 'Road Issue';

    return MapIssue(
      id: json['reportId']?.toString() ?? json['id']?.toString() ?? '',
      emoji: emoji,
      title: title,
      sub: json['status']?.toString() ?? 'Reported',
      desc: json['description']?.toString() ?? '',
      color: cat?.color ?? const Color(0xFF607D8B),
      position: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lon'] as num?)?.toDouble() ?? 0.0,
      ),
      stillThereCount: (json['stillVotes'] as num? ?? json['stillThereCount'] as num? ?? json['still_there_count'] as num?)?.toInt() ?? 0,
      fixedCount: (json['fixedVotes'] as num? ?? json['fixedCount'] as num? ?? json['fixed_count'] as num?)?.toInt() ?? 0,
      isVoted: (json['isVoted'] ?? json['is_voted']) as bool? ?? false,
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

  static List<MapIssue> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
