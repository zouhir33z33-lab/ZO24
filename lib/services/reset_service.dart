import 'database_helper.dart';

/// « Réinitialiser » : supprime classes, élèves, présences, évaluations, notes,
/// incidents et créneaux (cascade). Conserve trimestres, barèmes et fiches.
class ResetService {
  Future<void> resetClassesAndStudents() async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete('classes'); // ON DELETE CASCADE : students, sessions, attendances, evaluations, grades, timetable, incidents
    });
  }
}
