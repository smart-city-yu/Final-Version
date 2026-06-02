import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Pin-style marker shown on the map for nearby places returned by
/// GET /api/routing/places.
///
/// Visually distinct from [MapMarker] (road issues) by using:
///  • A larger circle with a white border
///  • A thin tail anchored at the bottom (pointing to the exact coordinate)
///  • Always AppColors.primary green (instead of per-issue colours)
///
/// The parent [Marker] must use  alignment: Alignment.bottomCenter  so the
/// tip of the tail sits exactly on the geographic coordinate.
class MapPlaceMarker extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const MapPlaceMarker({
    super.key,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── circle head ────────────────────────────────────────────────
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
          ),
          // ── pin tail ───────────────────────────────────────────────────
          Container(
            width: 3,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
