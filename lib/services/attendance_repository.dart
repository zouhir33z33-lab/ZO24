import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import 'database_helper.dart';

class AttendanceEntry {
  final int statusId;
  final String? observation;
  const AttendanceEntry(this.statusId, [this.observation]);
}

class AttendanceRepository {
  Future<Session?> findSession(int classId, String date) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('sessions',
        where: 'class_id = ? AND session_date = ?',
        whereArgs: [classId, date], limit: 1);
    return rows.isEmpty ? null : Session.fromMap(rows.first);
  }

  Future<Map<int, Attendance>> attendanceOf(int sessionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('attendances',
        where: 'session_id = ?', whereArgs: [sessionId]);
    return {for (final r in rows) (r['student_id'] as int): Attendance.fromMap(r)};
  }

  /// Crée ou met à jour la séance puis enregistre l'appel (transaction).
  Future<void> saveSession({
    required int classId,
    required int termId,
    required String date,
    required String startTime,
    required String endTime,
    int? sheetId,
    required Map<int, AttendanceEntry> entries, // studentId -> statut
    bool cancelled = false,
    String? cancellationReason,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final existing = await txn.query('sessions',
          where: 'class_id = ? AND session_date = ?',
          whereArgs: [classId, date], limit: 1);
      int sessionId;
      if (existing.isEmpty) {
        sessionId = await txn.insert('sessions', {
          'class_id': classId,
          'term_id': termId,
          'session_date': date,
          'start_time': startTime,
          'end_time': endTime,
          'pedagogical_sheet_id': sheetId,
          'status': cancelled ? 'CANCELLED' : 'COMPLETED',
          'cancellation_reason': cancelled ? cancellationReason : null,
        });
      } else {
        sessionId = existing.first['id'] as int;
        await txn.update('sessions', {
          'start_time': startTime,
          'end_time': endTime,
          'pedagogical_sheet_id': sheetId,
          'status': cancelled ? 'CANCELLED' : 'COMPLETED',
          'cancellation_reason': cancelled ? cancellationReason : null,
        }, where: 'id = ?', whereArgs: [sessionId]);
      }
      final ex = await txn.query('attendance_statuses', columns: ['id'], where: "code = 'EXEMPT'", limit: 1);
      final exemptId = ex.isEmpty ? null : ex.first['id'] as int;
      for (final e in entries.entries) {
        if (exemptId != null && e.value.statusId == exemptId) {
          await txn.update('students', {'is_exempt': 1}, where: 'id = ?', whereArgs: [e.key]);
        }
        await txn.insert('attendances', {
          'session_id': sessionId,
          'student_id': e.key,
          'term_id': termId,
          'status_id': e.value.statusId,
          'observation': e.value.observation,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Un élève marqué « dispensé » devient dispensé dans sa fiche (déduit de la vidéo).
      await txn.rawUpdate('''
        UPDATE students SET is_exempt = 1
        WHERE id IN (SELECT a.student_id FROM attendances a
                     JOIN attendance_statuses st ON st.id = a.status_id
                     WHERE a.session_id = ? AND st.code = 'EXEMPT')''', [sessionId]);
    });
  }

  /// Supprime une séance (présences en cascade).
  Future<void> deleteSessionById(int sessionId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Supprime la séance d'une classe à une date donnée.
  Future<void> deleteSession(int classId, String date) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('sessions', where: 'class_id = ? AND session_date = ?', whereArgs: [classId, date]);
  }

  /// Taux de présence sur les 7 derniers jours (null si aucune donnée).
  Future<double?> presenceRate7d() async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('''
      SELECT COUNT(*) AS total,
             SUM(CASE WHEN st.code = 'PRESENT' THEN 1 ELSE 0 END) AS present
      FROM attendances a
      JOIN sessions se ON se.id = a.session_id
      JOIN attendance_statuses st ON st.id = a.status_id
      WHERE se.session_date >= date('now', '-7 day')''');
    final total = (r.first['total'] as int?) ?? 0;
    if (total == 0) return null;
    return ((r.first['present'] as int?) ?? 0) * 100.0 / total;
  }

  /// Élèves ayant au moins [min] occurrences du statut (par code ou « compte comme absence »).
  Future<List<Map<String, Object?>>> repeatAlerts({
    required int termId,
    required int min,
    String? statusCode,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final cond = statusCode == null ? 'st.counts_as_absence = 1' : "st.code = '$statusCode'";
    return db.rawQuery('''
      SELECT s.id, s.last_name, s.first_name, c.name AS class_name, COUNT(*) AS n
      FROM attendances a
      JOIN attendance_statuses st ON st.id = a.status_id
      JOIN students s ON s.id = a.student_id
      JOIN classes c ON c.id = s.class_id
      WHERE a.term_id = ? AND $cond
      GROUP BY s.id HAVING n >= ?
      ORDER BY n DESC LIMIT 10''', [termId, min]);
  }

  /// Absences des 7 derniers jours.
  Future<List<Map<String, Object?>>> recentAbsences() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT s.last_name, s.first_name, c.name AS class_name,
             se.session_date, st.label_fr, st.label_ar, st.label_en
      FROM attendances a
      JOIN sessions se ON se.id = a.session_id
      JOIN attendance_statuses st ON st.id = a.status_id
      JOIN students s ON s.id = a.student_id
      JOIN classes c ON c.id = s.class_id
      WHERE st.counts_as_absence = 1 AND se.session_date >= date('now', '-7 day')
      ORDER BY se.session_date DESC LIMIT 10''');
  }

  Future<List<Map<String, Object?>>> exemptIn(List<int> classIds) async {
    if (classIds.isEmpty) return [];
    final db = await DatabaseHelper.instance.database;
    final q = List.filled(classIds.length, '?').join(',');
    return db.rawQuery('''
      SELECT s.last_name, s.first_name, s.medical_reason, c.name AS class_name
      FROM students s JOIN classes c ON c.id = s.class_id
      WHERE s.is_exempt = 1 AND s.is_active = 1 AND s.class_id IN ($q)''', classIds);
  }

  /// Dates des séances déjà enregistrées pour la classe (yyyy-MM-dd).
  Future<Set<String>> sessionDates(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('SELECT session_date FROM sessions WHERE class_id = ?', [classId]);
    return {for (final x in r) x['session_date'] as String};
  }

  /// Dates d'évaluation de la classe.
  Future<Set<String>> evaluationDates(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('SELECT evaluation_date FROM evaluations WHERE class_id = ?', [classId]);
    return {for (final x in r) x['evaluation_date'] as String};
  }

  /// Séances enregistrées d'une classe (plus récentes d'abord), avec compteurs.
  Future<List<SessionSummary>> sessionsOfClass(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT se.id, se.session_date, se.start_time, se.end_time, se.status, t.name AS term_name,
        COUNT(a.id) AS total,
        SUM(CASE WHEN st.code IN ('PRESENT','LATE','NO_KIT') THEN 1 ELSE 0 END) AS present_n,
        SUM(CASE WHEN st.counts_as_absence = 1 THEN 1 ELSE 0 END) AS abs_n
      FROM sessions se
      JOIN terms t ON t.id = se.term_id
      LEFT JOIN attendances a ON a.session_id = se.id
      LEFT JOIN attendance_statuses st ON st.id = a.status_id
      WHERE se.class_id = ?
      GROUP BY se.id
      ORDER BY se.session_date DESC, se.start_time DESC''', [classId]);
    return [
      for (final r in rows)
        SessionSummary(
          id: r['id'] as int,
          date: r['session_date'] as String,
          start: r['start_time'] as String,
          end: r['end_time'] as String,
          cancelled: r['status'] == 'CANCELLED',
          termName: r['term_name'] as String,
          total: (r['total'] as int?) ?? 0,
          present: (r['present_n'] as int?) ?? 0,
          absent: (r['abs_n'] as int?) ?? 0,
        ),
    ];
  }

  /// Élèves de la classe ayant au moins un rapport d'incident (pastille cloche).
  Future<Set<int>> studentsWithIncidents(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('SELECT DISTINCT student_id FROM incident_reports WHERE class_id = ?', [classId]);
    return {for (final x in r) x['student_id'] as int};
  }
}

class SessionSummary {
  final int id, total, present, absent;
  final String date, start, end, termName;
  final bool cancelled;
  const SessionSummary({
    required this.id, required this.date, required this.start, required this.end,
    required this.cancelled, required this.termName, required this.total,
    required this.present, required this.absent,
  });
}
