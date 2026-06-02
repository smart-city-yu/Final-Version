import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_localizations.dart';
import '../core/locale_provider.dart';

class SearchBarWidget extends StatelessWidget {
  final VoidCallback onLogout;

  const SearchBarWidget({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Positioned(
      top: 12,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              color: Color.fromRGBO(0, 0, 0, 0.14),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: AppColors.textGrey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.searchPlaceholder,
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ),
            // Language toggle
            InkWell(
              onTap: toggleLocale,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.green.withOpacity(0.30)),
                ),
                child: Text(
                  l.languageLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenDark,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onLogout,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
