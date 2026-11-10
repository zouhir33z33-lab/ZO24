import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../themes/app_theme.dart';
import '../utils/app_translations.dart';

/// Injecté au démarrage dans main.dart (ProviderScope.overrides).
final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.read(sharedPrefsProvider).getString(SettingsKeys.locale);
    return Locale(code ?? 'ar');
  }

  Future<void> setLanguage(String code) async {
    state = Locale(code);
    await ref.read(sharedPrefsProvider).setString(SettingsKeys.locale, code);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class ThemeKindNotifier extends Notifier<AppThemeKind> {
  @override
  AppThemeKind build() {
    final v = ref.read(sharedPrefsProvider).getString(SettingsKeys.themeMode);
    return AppThemeKind.values.firstWhere(
      (k) => k.name == v,
      orElse: () => AppThemeKind.light,
    );
  }

  Future<void> setKind(AppThemeKind kind) async {
    state = kind;
    await ref.read(sharedPrefsProvider).setString(SettingsKeys.themeMode, kind.name);
  }
}

final themeKindProvider =
    NotifierProvider<ThemeKindNotifier, AppThemeKind>(ThemeKindNotifier.new);

class CycleNotifier extends Notifier<EducationCycle?> {
  @override
  EducationCycle? build() {
    final v = ref.read(sharedPrefsProvider).getString(SettingsKeys.educationCycle);
    for (final c in EducationCycle.values) {
      if (c.name == v) return c;
    }
    return null;
  }

  Future<void> setCycle(EducationCycle cycle) async {
    state = cycle;
    await ref.read(sharedPrefsProvider).setString(SettingsKeys.educationCycle, cycle.name);
  }
}

final cycleProvider =
    NotifierProvider<CycleNotifier, EducationCycle?>(CycleNotifier.new);

/// Onglet sélectionné de la navigation principale (0 = Emploi du temps).
final navIndexProvider = StateProvider<int>((ref) => 0);

/// Raccourci de traduction : ref.watch(trProvider)('nav_classes').
final trProvider = Provider<String Function(String)>((ref) {
  final lang = ref.watch(localeProvider).languageCode;
  return (key) => AppTranslations.tr(lang, key);
});

/// « الكشف التلقائي عند بدء التشغيل ».
class AutoDetectNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(SettingsKeys.autoDetectSession) ?? false;

  Future<void> set(bool v) async {
    state = v;
    await ref.read(sharedPrefsProvider).setBool(SettingsKeys.autoDetectSession, v);
  }
}

final autoDetectProvider = NotifierProvider<AutoDetectNotifier, bool>(AutoDetectNotifier.new);
