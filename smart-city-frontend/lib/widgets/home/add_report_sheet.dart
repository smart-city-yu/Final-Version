import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../models/app_category.dart';
import '../sheet_handle.dart';

void showAddReportSheet({
  required BuildContext context,
  required void Function(AppCategory category) onCategorySelected,
}) {
  final l = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 24),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 14),

                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.selectIssueType,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 20, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category grid (excludes "other")
                  GridView.builder(
                    shrinkWrap: true,
                    itemCount: reportCategories
                        .where((c) => c.backendValue != 'other')
                        .length,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemBuilder: (_, index) {
                      final cat = reportCategories
                          .where((c) => c.backendValue != 'other')
                          .elementAt(index);
                      return _categoryTile(
                        context: context,
                        cat: cat,
                        l: l,
                        onCategorySelected: onCategorySelected,
                      );
                    },
                  ),

                  // "Other" full-width button
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 14),
                  _otherButton(context, onCategorySelected, l),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _categoryTile({
  required BuildContext context,
  required AppCategory cat,
  required AppLocalizations l,
  required void Function(AppCategory) onCategorySelected,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () {
      Navigator.pop(context);
      onCategorySelected(cat);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF6E6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD4ECBF)),
            ),
            child:
                Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.catDisplayName(cat),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _otherButton(
  BuildContext context,
  void Function(AppCategory) onCategorySelected,
  AppLocalizations l,
) {
  final cat = reportCategories.firstWhere((c) => c.backendValue == 'other');
  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () {
      Navigator.pop(context);
      onCategorySelected(cat);
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
                child: Text('❓', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.otherIssue,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  l.cantFindIssueType,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
        ],
      ),
    ),
  );
}
