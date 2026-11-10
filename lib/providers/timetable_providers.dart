import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'academic_providers.dart';
import 'classes_provider.dart';
import 'repository_providers.dart';

final slotsProvider = FutureProvider<List<TimetableSlot>>((ref) async {
  final year = await ref.watch(activeYearProvider.future);
  if (year == null) return [];
  return ref.read(timetableRepositoryProvider).slotsOfYear(year.id!);
});

final statusesProvider = FutureProvider<List<AttendanceStatus>>((ref) {
  return ref.read(statusRepositoryProvider).all();
});

final sheetsProvider = FutureProvider<List<PedagogicalSheet>>((ref) {
  return ref.read(timetableRepositoryProvider).sheets();
});

/// Donnée agrégée de l'onglet « اليوم والملعب ».
class TodayData {
  final List<TimetableSlot> slots; // créneaux du jour, triés
  final Map<int, SchoolClass> classes;
  final Map<int, PedagogicalSheet> sheets;
  final int expectedStudents;
  final double? presenceRate;
  final List<Map<String, Object?>> absenceAlerts;
  final List<Map<String, Object?>> noKitAlerts;
  final List<Map<String, Object?>> recentAbsences;
  final List<Map<String, Object?>> exemptToday;
  const TodayData({
    required this.slots,
    required this.classes,
    required this.sheets,
    required this.expectedStudents,
    required this.presenceRate,
    required this.absenceAlerts,
    required this.noKitAlerts,
    required this.recentAbsences,
    required this.exemptToday,
  });
}

/// Jour sélectionné dans la vue hebdomadaire (1..7), null = aujourd'hui.
final todayDataProvider = FutureProvider.autoDispose<TodayData>((ref) async {
  final slots = await ref.watch(slotsProvider.future);
  final classes = await ref.watch(classesProvider.future);
  final sheets = await ref.watch(sheetsProvider.future);
  final terms = await ref.watch(termsProvider.future);
  final repo = ref.read(attendanceRepositoryProvider);
  final studentsRepo = ref.read(studentRepositoryProvider);

  final today = DateTime.now();
  final day = today.weekday % 7 + 1;
  final todays = slots.where((s) => s.dayOfWeek == day).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final byId = {for (final c in classes) c.id!: c};

  var expected = 0;
  for (final s in todays) {
    expected += (await studentsRepo.byClass(s.classId)).length;
  }
  final termId = terms.where((t) => t.isCurrent).map((t) => t.id!).firstOrNull ??
      (terms.isNotEmpty ? terms.first.id! : 0);
  return TodayData(
    slots: todays,
    classes: byId,
    sheets: {for (final s in sheets) s.id!: s},
    expectedStudents: expected,
    presenceRate: await repo.presenceRate7d(),
    absenceAlerts: await repo.repeatAlerts(termId: termId, min: 3),
    noKitAlerts: await repo.repeatAlerts(termId: termId, min: 2, statusCode: 'NO_KIT'),
    recentAbsences: await repo.recentAbsences(),
    exemptToday: await repo.exemptIn(todays.map((s) => s.classId).toSet().toList()),
  );
});

/// Liste synchrone des classes (vide pendant le chargement).
final classesProviderForTimetable = Provider<List<SchoolClass>>(
  (ref) => ref.watch(classesProvider).valueOrNull ?? const <SchoolClass>[],
);
