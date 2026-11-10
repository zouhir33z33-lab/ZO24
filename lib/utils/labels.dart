import '../constants/app_constants.dart';

/// Libellés administratifs utilisés dans les PDF (relevés sur les PDF d'origine).
String directorTitle(EducationCycle? c) => switch (c) {
      EducationCycle.primary => 'مدير المدرسة',
      EducationCycle.middle => 'مدير المتوسطة',
      EducationCycle.secondary => 'مدير الثانوية',
      _ => 'مدير المؤسسة',
    };

String cycleNoun(EducationCycle? c) => switch (c) {
      EducationCycle.primary => 'ابتدائية',
      EducationCycle.middle => 'متوسطة',
      EducationCycle.secondary => 'ثانوية',
      _ => 'مؤسسة',
    };

const List<String> kTermNamesAr = ['الفصل الأول', 'الفصل الثاني', 'الفصل الثالث'];

String two(int v) => v.toString().padLeft(2, '0');

/// « 07:29 02/11/2026 » comme dans l'en-tête des PDF.
String stampNow() {
  final n = DateTime.now();
  return '${two(n.hour)}:${two(n.minute)} ${two(n.day)}/${two(n.month)}/${n.year}';
}
