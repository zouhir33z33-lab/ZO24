import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_constants.dart';
import 'providers/core_providers.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/database_helper.dart';
import 'themes/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await DatabaseHelper.instance.database; // crée le schéma au premier lancement
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const EpsAssistantApp(),
  ));
}

class EpsAssistantApp extends ConsumerWidget {
  const EpsAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final kind = ref.watch(themeKindProvider);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(kind),
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: const _Root(),
    );
  }
}

/// Premier lancement → choix du cycle ; sinon navigation principale.
class _Root extends ConsumerStatefulWidget {
  const _Root();
  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  late bool _done =
      ref.read(sharedPrefsProvider).getBool(SettingsKeys.onboardingDone) ?? false;

  @override
  Widget build(BuildContext context) {
    return _done
        ? const MainNavigationScreen()
        : OnboardingScreen(onDone: () => setState(() => _done = true));
  }
}
