import '../models/models.dart';
import 'database_helper.dart';

/// Années scolaires et trimestres.
class AcademicRepository {
  Future<AcademicYear?> activeYear() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('academic_years',
        where: 'is_active = 1', limit: 1);
    return rows.isEmpty ? null : AcademicYear.fromMap(rows.first);
  }

  Future<List<Term>> termsOf(int academicYearId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('terms',
        where: 'academic_year_id = ?',
        whereArgs: [academicYearId],
        orderBy: 'term_number');
    return rows.map(Term.fromMap).toList();
  }

  Future<Term?> currentTerm(int academicYearId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('terms',
        where: 'academic_year_id = ? AND is_current = 1',
        whereArgs: [academicYearId],
        limit: 1);
    return rows.isEmpty ? null : Term.fromMap(rows.first);
  }

  /// Clôture un trimestre (lecture seule) et active le suivant.
  Future<void> closeTerm(Term t) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update('terms', {'is_locked': 1, 'is_current': 0},
          where: 'id = ?', whereArgs: [t.id]);
      await txn.update('terms', {'is_current': 1},
          where: 'academic_year_id = ? AND term_number = ?',
          whereArgs: [t.academicYearId, t.termNumber + 1]);
    });
  }
}
