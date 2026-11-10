import '../models/models.dart';
import 'database_helper.dart';

class TimetableRepository {
  Future<List<TimetableSlot>> slotsOfYear(int yearId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('timetable_slots',
        where: 'academic_year_id = ?', whereArgs: [yearId],
        orderBy: 'day_of_week, start_time');
    return rows.map(TimetableSlot.fromMap).toList();
  }

  Future<int> insertSlot(TimetableSlot s) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('timetable_slots', s.toMap());
  }

  Future<void> updateSlot(TimetableSlot s) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('timetable_slots', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteSlot(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('timetable_slots', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PedagogicalSheet>> sheets() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('pedagogical_sheets', orderBy: 'created_at DESC, id DESC');
    return rows.map(PedagogicalSheet.fromMap).toList();
  }

  /// « إفراغ كامل التوقيت » : libère tous les créneaux.
  Future<void> clearAll(int yearId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('timetable_slots', where: 'academic_year_id = ?', whereArgs: [yearId]);
  }

  /// « النموذج الافتراضي » : emploi du temps type du dimanche (3 premières classes,
  /// terrains et fiches d'après le PDF d'origine). Remplace les créneaux actuels.
  Future<void> applyDefault(int yearId, List<SchoolClass> classes, List<PedagogicalSheet> sheets) async {
    final db = await DatabaseHelper.instance.database;
    int? sheetOf(String discipline) {
      for (final s in sheets) {
        if (s.sportDiscipline == discipline) return s.id;
      }
      return null;
    }

    const plan = [
      ('08:00', '10:00', 'Terrain Extérieur 1', 'Course de vitesse'),
      ('10:00', '12:00', 'Gymnase Omnisports', 'Course de demi-fond'),
      ('13:30', '15:30', "Piste d'athlétisme", 'Gymnastique'),
    ];
    await db.transaction((txn) async {
      await txn.delete('timetable_slots', where: 'academic_year_id = ?', whereArgs: [yearId]);
      for (var i = 0; i < plan.length && i < classes.length; i++) {
        await txn.insert('timetable_slots', {
          'academic_year_id': yearId,
          'class_id': classes[i].id,
          'day_of_week': 1,
          'start_time': plan[i].$1,
          'end_time': plan[i].$2,
          'default_sheet_id': sheetOf(plan[i].$4),
          'field_name': plan[i].$3,
        });
      }
    });
  }

  /// Supprime le créneau d'une classe un jour donné (utilisé à la suppression d'une séance).
  Future<void> deleteSlotOf(int yearId, int classId, int day) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('timetable_slots',
        where: 'academic_year_id = ? AND class_id = ? AND day_of_week = ?',
        whereArgs: [yearId, classId, day]);
  }

  /// Supprime le créneau (classe, jour, début) et la séance du jour.
  Future<void> deleteSessionAndSlot({
    required int yearId, required int classId, required int day,
    required String start, required String date,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('timetable_slots',
        where: 'academic_year_id = ? AND class_id = ? AND day_of_week = ? AND start_time = ?',
        whereArgs: [yearId, classId, day, start]);
    await db.delete('sessions', where: 'class_id = ? AND session_date = ?', whereArgs: [classId, date]);
  }
}
