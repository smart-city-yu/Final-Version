import 'package:flutter/material.dart';

/// A category with its exact backend enum value, display name, emoji, and color.
/// This is the single source of truth — frontend display and API calls both
/// derive from the same object, ensuring they always stay in sync.
class AppCategory {
  final String backendValue; // exact enum string sent to / received from the API
  final String displayName;
  final String emoji;
  final Color color;

  const AppCategory({
    required this.backendValue,
    required this.displayName,
    required this.emoji,
    required this.color,
  });
}

// ---------------------------------------------------------------------------
// Report categories — mirrors backend enum  com.smartcity.backend.enums.ReportCategory
// Values: pothole | brokenRoad | treeInRoad | unpavedStreet | manhole | lamppost | speedBump | other
// ---------------------------------------------------------------------------
const List<AppCategory> reportCategories = [
  AppCategory(
    backendValue: 'pothole',
    displayName: 'Pothole',
    emoji: '🕳️',
    color: Color(0xFF8E2922),
  ),
  AppCategory(
    backendValue: 'brokenRoad',
    displayName: 'Broken Road',
    emoji: '🚧',
    color: Color(0xFFBB6610),
  ),
  AppCategory(
    backendValue: 'treeInRoad',
    displayName: 'Tree in Road',
    emoji: '🌳',
    color: Color(0xFF3A7D1E),
  ),
  AppCategory(
    backendValue: 'unpavedStreet',
    displayName: 'Unpaved Street',
    emoji: '🛣️',
    color: Color(0xFF6F5647),
  ),
  AppCategory(
    backendValue: 'manhole',
    displayName: 'Manhole',
    emoji: '⭕',
    color: Color(0xFFD14E78),
  ),
  AppCategory(
    backendValue: 'lamppost',
    displayName: 'Lamppost',
    emoji: '💡',
    color: Color(0xFFF0B017),
  ),
  AppCategory(
    backendValue: 'speedBump',
    displayName: 'Speed Bump',
    emoji: '⛰️',
    color: Color(0xFF6C8A98),
  ),
  AppCategory(
    backendValue: 'other',
    displayName: 'Other',
    emoji: '❓',
    color: Color(0xFF607D8B),
  )

];

// ---------------------------------------------------------------------------
// Place categories — mirrors routing-engine enum  org.example.Graph.Element.PlaceCategory
// Values: RESTAURANT | FUEL | PARK | PARKING | SUPERMARKET | MOSQUE
// (only the subset shown in the Go-To sheet; the full enum has more values)
// ---------------------------------------------------------------------------
const List<AppCategory> placeCategories = [
  AppCategory(
    backendValue: 'RESTAURANT',
    displayName: 'Restaurant',
    emoji: '🍽️',
    color: Color(0xFF8E2922),
  ),
  AppCategory(
    backendValue: 'FUEL',
    displayName: 'Gas Station',
    emoji: '⛽',
    color: Color(0xFFBB6610),
  ),
  AppCategory(
    backendValue: 'PARK',
    displayName: 'Park',
    emoji: '🌳',
    color: Color(0xFF3A7D1E),
  ),
  AppCategory(
    backendValue: 'PARKING',
    displayName: 'Parking',
    emoji: '🅿️',
    color: Color(0xFF1565C0),
  ),
  AppCategory(
    backendValue: 'SUPERMARKET',
    displayName: 'Supermarket',
    emoji: '🛒',
    color: Color(0xFF6F5647),
  ),
  AppCategory(
    backendValue: 'MOSQUE',
    displayName: 'Mosque',
    emoji: '🕌',
    color: Color(0xFF2E7D32),
  ),
];

// ---------------------------------------------------------------------------
// Lookup helpers
// ---------------------------------------------------------------------------

/// Returns the [AppCategory] whose [backendValue] equals [value],
/// or null if not found.
AppCategory? reportCategoryFromValue(String value) {
  for (final c in reportCategories) {
    if (c.backendValue == value) return c;
  }
  return null;
}

AppCategory? placeCategoryFromValue(String value) {
  for (final c in placeCategories) {
    if (c.backendValue == value) return c;
  }
  return null;
}
