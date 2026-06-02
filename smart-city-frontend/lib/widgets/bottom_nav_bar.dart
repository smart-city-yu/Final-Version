import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class HomeBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const HomeBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _item(Icons.home_filled, 'Home', 0),
          _item(Icons.description_outlined, 'Reports', 1),
          _item(Icons.person_outline, 'Profile', 2),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, int index) {
    final active = selectedIndex == index;
    final color = active ? AppColors.green : AppColors.textGrey;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              if (active)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.green,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}