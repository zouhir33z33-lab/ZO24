import '../models/models.dart';
import 'database_helper.dart';

class ClassRepository {
  /// Classes de l'année donnée, avec le nombre d'élèves actifs.
  Future<List<SchoolClass>> all(int academicYearId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT c.*, (SELECT COUNT(*) FROM students s
                   WHERE s.class_id = c.id AND s.is_active = 1) AS student_count
      FROM classes c
      WHERE c.academic_year_id = ?
      ORDER BY c.sort_order, c.id''', [academicYearId]);
    return rows.map(SchoolClass.fromMap).toList();
  }

  Future<int> insert(SchoolClass c) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('classes', c.toMap());
  }

  Future<void> update(SchoolClass c) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('classes', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  /// Suppression en cascade (élèves, séances, etc.) via les clés étrangères.
  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('classes', where: 'id = ?', whereArgs: [id]);
  }

  /// « Vider la classe » : supprime les élèves mais conserve la classe.
  Future<void> emptyStudents(int classId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('students', where: 'class_id = ?', whereArgs: [classId]);
  }

  /// Supprime uniquement les élèves de la classe (et leurs données liées par cascade).
  Future<void> deleteStudents(int classId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('students', where: 'class_id = ?', whereArgs: [classId]);
  }

  /// « إفراغ القسم » : supprime tous les élèves (et leurs présences, notes, incidents) mais garde la classe.
  Future<void> emptyClass(int classId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('students', where: 'class_id = ?', whereArgs: [classId]);
  }
}
