import '../models/models.dart';
import '../utils/status_utils.dart';
import 'database_helper.dart';
import 'evaluation_repository.dart';

class StatusCount {
  final AttendanceStatus status;
  final int n;
  const StatusCount(this.status, this.n);
}

class SessionLine {
  final int id;
  final String date, start, end;
  final int present, total;
  const SessionLine(this.id, this.date, this.start, this.end, this.present, this.total);
  double get pct => total == 0 ? 0 : present * 100.0 / total;
}

class StudentLine {
  final Student student;
  final int marks; // séances saisies
  final int presentLike;
  final int absences;
  const StudentLine(this.student, this.marks, this.presentLike, this.absences);
  double get pct => marks == 0 ? 0 : presentLike * 100.0 / marks;
}

class ClassStats {
  final int sessions, students, males, females, evaluations, marks, presentLike, absences;
  final double? average;
  final List<StatusCount> distribution;
  final List<SessionLine> sessionLines; // plus récentes d'abord
  final List<StudentLine> studentLines;
  const ClassStats({
    required this.sessions, required this.students, required this.males, required this.females,
    required this.evaluations, required this.marks, required this.presentLike, required this.absences,
    required this.average, required this.distribution, required this.sessionLines, required this.studentLines,
  });
  double? get presencePct => marks == 0 ? null : presentLike * 100.0 / marks;
}

class HistoryItem {
  final String date, start, end;
  final AttendanceStatus status;
  final String? observation;
  const HistoryItem(this.date, this.start, this.end, this.status, this.observation);
}

class GradeItem {
  final String title, date;
  final double? score;
  final double max;
  const GradeItem(this.title, this.date, this.score, this.max);
}

class StudentDetail {
  final StudentLine line;
  final double? average;
  final List<StatusCount> distribution;
  final List<HistoryItem> history;
  final List<GradeItem> grades;
  const StudentDetail(this.line, this.average, this.distribution, this.history, this.grades);
}

/// Matrice « السجل الفصلي » : élèves × séances.
class RecordMatrix {
  final List<SessionLine> sessions; // plus anciennes d'abord
  final List<StudentLine> students;
  final Map<int, Map<int, AttendanceStatus>> cell; // studentId -> sessionId -> statut
  final double? avgPresence;
  const RecordMatrix(this.sessions, this.students, this.cell, this.avgPresence);
}

class StatsRepository {
  Future<List<AttendanceStatus>> _statuses() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('attendance_statuses', orderBy: 'sort_order, id');
    return rows.map(AttendanceStatus.fromMap).toList();
  }

  Future<List<Student>> _students(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('students',
        where: 'class_id = ? AND is_active = 1', whereArgs: [classId],
        orderBy: 'last_name COLLATE NOCASE, first_name COLLATE NOCASE');
    return rows.map(Student.fromMap).toList();
  }

  Future<ClassStats> classStats(int classId, int? termId) async {
    final db = await DatabaseHelper.instance.database;
    final statuses = await _statuses();
    final byId = {for (final s in statuses) s.id!: s};
    final students = await _students(classId);
    final tc = termId == null ? '' : ' AND se.term_id = ?';
    final args = termId == null ? [classId] : [classId, termId];

    final sess = await db.rawQuery(
        'SELECT se.id, se.session_date, se.start_time, se.end_time FROM sessions se '
        'WHERE se.class_id = ?$tc ORDER BY se.session_date DESC, se.start_time DESC', args);
    final att = await db.rawQuery(
        'SELECT a.session_id, a.student_id, a.status_id FROM attendances a '
        'JOIN sessions se ON se.id = a.session_id WHERE se.class_id = ?$tc', args);

    final perSessionPresent = <int, int>{}, perSessionTotal = <int, int>{};
    final perStudent = <int, List<AttendanceStatus>>{};
    final distCount = <int, int>{};
    var marks = 0, pres = 0, abs = 0;
    for (final r in att) {
      final st = byId[r['status_id'] as int];
      if (st == null) continue;
      final sid = r['session_id'] as int;
      final stu = r['student_id'] as int;
      marks++;
      distCount[st.id!] = (distCount[st.id!] ?? 0) + 1;
      perSessionTotal[sid] = (perSessionTotal[sid] ?? 0) + 1;
      perStudent.putIfAbsent(stu, () => []).add(st);
      if (isPresentLike(st.code)) {
        pres++;
        perSessionPresent[sid] = (perSessionPresent[sid] ?? 0) + 1;
      }
      if (st.countsAsAbsence) abs++;
    }
    final sessionLines = [
      for (final r in sess)
        SessionLine(r['id'] as int, r['session_date'] as String, r['start_time'] as String,
            r['end_time'] as String, perSessionPresent[r['id'] as int] ?? 0,
            students.length),
    ];
    final studentLines = [
      for (final s in students)
        StudentLine(s, (perStudent[s.id] ?? []).length,
            (perStudent[s.id] ?? []).where((x) => isPresentLike(x.code)).length,
            (perStudent[s.id] ?? []).where((x) => x.countsAsAbsence).length),
    ];
    final summary = await EvaluationRepository().summary(classId, termId, students);
    return ClassStats(
      sessions: sess.length,
      students: students.length,
      males: students.where((s) => s.gender == 'M').length,
      females: students.where((s) => s.gender == 'F').length,
      evaluations: summary.evaluations,
      marks: marks,
      presentLike: pres,
      absences: abs,
      average: summary.classAverage,
      distribution: [for (final s in statuses) StatusCount(s, distCount[s.id] ?? 0)],
      sessionLines: sessionLines,
      studentLines: studentLines,
    );
  }

  Future<StudentDetail> studentDetail(Student student, int classId, int? termId) async {
    final db = await DatabaseHelper.instance.database;
    final statuses = await _statuses();
    final byId = {for (final s in statuses) s.id!: s};
    final tc = termId == null ? '' : ' AND se.term_id = ?';
    final args = termId == null ? [student.id!] : [student.id!, termId];
    final rows = await db.rawQuery(
        'SELECT se.session_date, se.start_time, se.end_time, a.status_id, a.observation '
        'FROM attendances a JOIN sessions se ON se.id = a.session_id '
        'WHERE a.student_id = ?$tc ORDER BY se.session_date DESC, se.start_time DESC', args);
    final history = <HistoryItem>[];
    final dist = <int, int>{};
    var pres = 0, abs = 0;
    for (final r in rows) {
      final st = byId[r['status_id'] as int];
      if (st == null) continue;
      history.add(HistoryItem(r['session_date'] as String, r['start_time'] as String,
          r['end_time'] as String, st, r['observation'] as String?));
      dist[st.id!] = (dist[st.id!] ?? 0) + 1;
      if (isPresentLike(st.code)) pres++;
      if (st.countsAsAbsence) abs++;
    }
    final gTc = termId == null ? '' : ' AND e.term_id = ?';
    final gArgs = termId == null ? [student.id!] : [student.id!, termId];
    final gr = await db.rawQuery(
        'SELECT e.title, e.evaluation_date, e.max_score, g.score FROM student_grades g '
        'JOIN evaluations e ON e.id = g.evaluation_id WHERE g.student_id = ?$gTc '
        'ORDER BY e.evaluation_date DESC', gArgs);
    final grades = [
      for (final r in gr)
        GradeItem(r['title'] as String, r['evaluation_date'] as String,
            (r['score'] as num?)?.toDouble(), (r['max_score'] as num).toDouble()),
    ];
    final scored = grades.where((g) => g.score != null).toList();
    final avg = scored.isEmpty
        ? null
        : scored.map((g) => g.score! / g.max * 20).reduce((a, b) => a + b) / scored.length;
    return StudentDetail(
      StudentLine(student, history.length, pres, abs),
      avg,
      [for (final s in statuses) StatusCount(s, dist[s.id] ?? 0)],
      history,
      grades,
    );
  }

  Future<RecordMatrix> recordMatrix(int classId, int termId) async {
    final db = await DatabaseHelper.instance.database;
    final statuses = await _statuses();
    final byId = {for (final s in statuses) s.id!: s};
    final students = await _students(classId);
    final sess = await db.rawQuery(
        'SELECT id, session_date, start_time, end_time FROM sessions '
        'WHERE class_id = ? AND term_id = ? ORDER BY session_date, start_time', [classId, termId]);
    final att = await db.rawQuery(
        'SELECT a.session_id, a.student_id, a.status_id FROM attendances a '
        'JOIN sessions se ON se.id = a.session_id WHERE se.class_id = ? AND se.term_id = ?',
        [classId, termId]);
    final cell = <int, Map<int, AttendanceStatus>>{};
    final perStudent = <int, List<AttendanceStatus>>{};
    for (final r in att) {
      final st = byId[r['status_id'] as int];
      if (st == null) continue;
      cell.putIfAbsent(r['student_id'] as int, () => {})[r['session_id'] as int] = st;
      perStudent.putIfAbsent(r['student_id'] as int, () => []).add(st);
    }
    final lines = [
      for (final s in students)
        StudentLine(s, (perStudent[s.id] ?? []).length,
            (perStudent[s.id] ?? []).where((x) => isPresentLike(x.code)).length,
            (perStudent[s.id] ?? []).where((x) => x.countsAsAbsence).length),
    ];
    final withMarks = lines.where((l) => l.marks > 0).toList();
    final avgPresence = withMarks.isEmpty
        ? null
        : withMarks.map((l) => l.pct).reduce((a, b) => a + b) / withMarks.length;
    return RecordMatrix(
      [for (final r in sess) SessionLine(r['id'] as int, r['session_date'] as String, r['start_time'] as String, r['end_time'] as String, 0, students.length)],
      lines,
      cell,
      avgPresence,
    );
  }

  /// Dernière saisie d'assiduité par élève (date + couleur du statut).
  Future<Map<int, ({String date, String colorHex})>> lastMarks(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT a.student_id, se.session_date, st.color_hex
      FROM attendances a
      JOIN sessions se ON se.id = a.session_id
      JOIN attendance_statuses st ON st.id = a.status_id
      WHERE se.class_id = ?
      ORDER BY se.session_date ASC, se.start_time ASC''', [classId]);
    final out = <int, ({String date, String colorHex})>{};
    for (final r in rows) {
      out[r['student_id'] as int] = (date: r['session_date'] as String, colorHex: r['color_hex'] as String);
    }
    return out;
  }

  /// Dernier statut saisi par élève (date yyyy-MM-dd + statut) pour la liste des élèves.
  Future<Map<int, (String, AttendanceStatus)>> lastStatus(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final statuses = {for (final s in await _statuses()) s.id!: s};
    final rows = await db.rawQuery(
        'SELECT a.student_id, se.session_date, a.status_id FROM attendances a '
        'JOIN sessions se ON se.id = a.session_id WHERE se.class_id = ? '
        'ORDER BY se.session_date ASC, se.start_time ASC', [classId]);
    final out = <int, (String, AttendanceStatus)>{};
    for (final r in rows) {
      final st = statuses[r['status_id'] as int];
      if (st != null) out[r['student_id'] as int] = (r['session_date'] as String, st);
    }
    return out;
  }
}
