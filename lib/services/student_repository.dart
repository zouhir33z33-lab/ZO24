import '../models/models.dart';
import 'database_helper.dart';

class StudentRepository {
  Future<List<Student>> byClass(int classId, {bool activeOnly = true}) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('students',
        where: activeOnly ? 'class_id = ? AND is_active = 1' : 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'sort_order, last_name COLLATE NOCASE, first_name COLLATE NOCASE');
    return rows.map(Student.fromMap).toList();
  }

  Future<int> insert(Student s) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('students', s.toMap());
  }

  Future<void> update(Student s) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('students', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  /// Recherche d'élèves dans toutes les classes de l'année active.
  Future<List<Map<String, Object?>>> search(String q, {bool onlyExempt = false}) async {
    final db = await DatabaseHelper.instance.database;
    final like = '%${q.replaceAll('%', '')}%';
    return db.rawQuery('''
      SELECT s.*, c.name AS class_name, c.level AS class_level
      FROM students s
      JOIN classes c ON c.id = s.class_id
      JOIN academic_years y ON y.id = c.academic_year_id AND y.is_active = 1
      WHERE s.is_active = 1
        ${onlyExempt ? 'AND s.is_exempt = 1' : ''}
        AND (? = '' OR s.last_name LIKE ? OR s.first_name LIKE ? OR s.student_number LIKE ? OR c.name LIKE ? OR s.medical_reason LIKE ?)
      ORDER BY s.last_name COLLATE NOCASE, s.first_name COLLATE NOCASE
      LIMIT 500''', [q.trim(), like, like, like, like, like]);
  }

  /// Dernier statut de présence de chaque élève de la classe : studentId -> (date, couleur, code).
  Future<Map<int, ({String date, String color, String code})>> lastStatus(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT a.student_id, se.session_date, st.color_hex, st.code
      FROM attendances a
      JOIN sessions se ON se.id = a.session_id
      JOIN attendance_statuses st ON st.id = a.status_id
      WHERE se.class_id = ?
      ORDER BY se.session_date ASC, se.start_time ASC''', [classId]);
    final out = <int, ({String date, String color, String code})>{};
    for (final r in rows) {
      out[r['student_id'] as int] = (
        date: r['session_date'] as String,
        color: r['color_hex'] as String,
        code: r['code'] as String,
      );
    }
    return out;
  }

  Future<void> setExempt(List<int> ids, bool value) async {
    if (ids.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final q = List.filled(ids.length, '?').join(',');
    await db.rawUpdate('UPDATE students SET is_exempt = ? WHERE id IN ($q)', [value ? 1 : 0, ...ids]);
  }

  /// Supprime tous les élèves d'une classe (« إفراغ القسم »).
  Future<void> deleteAllOfClass(int classId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('students', where: 'class_id = ?', whereArgs: [classId]);
  }

  /// Dernière saisie d'appel par élève : studentId -> (date yyyy-MM-dd, couleur du statut).
  Future<Map<int, ({String date, String color})>> lastMarks(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT a.student_id, se.session_date, st.color_hex
      FROM attendances a
      JOIN sessions se ON se.id = a.session_id
      JOIN attendance_statuses st ON st.id = a.status_id
      WHERE se.class_id = ?
      ORDER BY se.session_date DESC, se.start_time DESC''', [classId]);
    final out = <int, ({String date, String color})>{};
    for (final r in rows) {
      out.putIfAbsent(r['student_id'] as int,
          () => (date: r['session_date'] as String, color: r['color_hex'] as String));
    }
    return out;
  }

  Future<void> markExempt(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    await db.update('students', {'is_exempt': 1},
        where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
  }

}
