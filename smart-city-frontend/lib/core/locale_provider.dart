import 'package:flutter/material.dart';

final localeNotifier = ValueNotifier<Locale>(const Locale('en'));

void toggleLocale() {
  localeNotifier.value = localeNotifier.value.languageCode == 'en'
      ? const Locale('ar')
      : const Locale('en');
}
