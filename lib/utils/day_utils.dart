/// Jours de la semaine. day_of_week : dimanche = 1 … samedi = 7
/// (déduit de la vidéo : semaine algérienne ; à confirmer).
int appDayOf(DateTime d) => d.weekday % 7 + 1; // Dart : lundi=1 … dimanche=7

const List<String> kDayNamesAr = [
  'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
];
const List<String> kDayNamesFr = [
  'Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
];
const List<String> kDayNamesEn = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
];
const List<String> kMonthsAr = [
  'جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان', 'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];

String dayName(String lang, int appDay) {
  final i = appDay - 1;
  return lang == 'ar' ? kDayNamesAr[i] : (lang == 'en' ? kDayNamesEn[i] : kDayNamesFr[i]);
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

int minutesOf(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String durationLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}min';
}
