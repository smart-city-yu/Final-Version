import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../models/app_category.dart';
import '../sheet_handle.dart';

void showGoToSheet({
  required BuildContext context,
  required void Function(AppCategory category) onCategorySelected,
}) {
  final l = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.goToNearest,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              ...placeCategories.map((cat) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    onCategorySelected(cat);
                  },
                  leading: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F8EA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(cat.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  title: Text(
                    l.catDisplayName(cat),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    l.findNearestAvailable,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 30),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
