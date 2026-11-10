import '../models/models.dart';
import 'database_helper.dart';

class IncidentRow {
  final IncidentReport report;
  final String studentName;
  final String className;
  final String level;
  final String gender; // 'M' | 'F' | ''
  const IncidentRow(this.report, this.studentName, this.className, this.level, this.gender);
}

class IncidentRepository {
  Future<List<IncidentRow>> all({int? classId}) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT i.*, s.last_name, s.first_name, s.gender AS student_gender, c.name AS class_name, c.level AS class_level
      FROM incident_reports i
      JOIN students s ON s.id = i.student_id
      JOIN classes c ON c.id = i.class_id
      ${classId == null ? '' : 'WHERE i.class_id = ?'}
      ORDER BY i.incident_date DESC, i.incident_time DESC, i.id DESC''',
        classId == null ? [] : [classId]);
    return [
      for (final r in rows)
        IncidentRow(IncidentReport.fromMap(r), '${r['last_name']} ${r['first_name']}',
            r['class_name'] as String, r['class_level'] as String,
            (r['student_gender'] as String?) ?? ''),
    ];
  }

  Future<int> insert(IncidentReport r) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('incident_reports', r.toMap());
  }

  Future<void> update(IncidentReport r) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('incident_reports', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('incident_reports', where: 'id = ?', whereArgs: [id]);
  }
}
