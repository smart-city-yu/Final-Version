import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';

void showSuccessDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  final done = AppLocalizations.of(context).done;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E1), shape: BoxShape.circle),
                child: const Center(
                    child: Text('✅', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.greenDark),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textGrey, height: 1.4),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: 130,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(done,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
