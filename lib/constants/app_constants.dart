/// Constantes générales de l'application (extraites de l'APK d'origine v1.2.0).
class AppConstants {
  static const String appName = 'EPS Assistant';
  static const String appVersion = '1.2.0';
  static const String dbName = 'eps_assistant.db';
  static const int dbVersion = 2;
  static const String fontFamily = 'Arial';
}

/// Clés de la table app_settings et de shared_preferences.
class SettingsKeys {
  static const String locale = 'locale';
  static const String themeMode = 'theme_mode'; // light | dark | national
  static const String educationCycle = 'education_cycle'; // primary | middle | secondary
  static const String onboardingDone = 'onboarding_done';
  static const String autoDetectSession = 'auto_detect_session';
  static const String pinEnabled = 'pin_enabled';
  static const String pinHash = 'pin_hash';
  static const String teacherLastName = 'teacher_last_name';
  static const String teacherFirstName = 'teacher_first_name';
  static const String teacherSchool = 'teacher_school';
  static const String teacherPlace = 'teacher_place';
  static const String teacherRank = 'teacher_rank';
  static const String teacherGrade = 'teacher_grade';
}

/// Cycles d'enseignement (visibles sur l'écran de choix du cycle).
enum EducationCycle { primary, middle, secondary, mixed }

class CycleData {
  final EducationCycle cycle;
  final String code;
  final List<String> levels;
  const CycleData(this.cycle, this.code, this.levels);
}

const List<CycleData> kCycles = [
  CycleData(EducationCycle.primary, 'primary', ['1AP', '2AP', '3AP', '4AP', '5AP']),
  CycleData(EducationCycle.middle, 'middle', ['1AM', '2AM', '3AM', '4AM']),
  CycleData(EducationCycle.secondary, 'secondary', ['1AS', '2AS', '3AS']),
  CycleData(EducationCycle.mixed, 'mixed', [
    '1AP', '2AP', '3AP', '4AP', '5AP', '1AM', '2AM', '3AM', '4AM', '1AS', '2AS', '3AS'
  ]),
];

/// Jours de la semaine (day_of_week 1..7). Semaine algérienne : dimanche = 1.
/// NOTE : la correspondance exacte numéro/jour dans l'original est déduite de
/// la vue hebdomadaire (dimanche → jeudi) ; à confirmer en phase 5.
const List<int> kSchoolDays = [1, 2, 3, 4, 5];
