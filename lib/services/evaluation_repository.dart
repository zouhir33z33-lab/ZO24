import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import 'database_helper.dart';

/// Évaluation + agrégats pour l'affichage de la liste.
class EvaluationRow {
  final Evaluation evaluation;
  final int graded;
  final double? average; // moyenne des notes saisies (sur max_score)
  const EvaluationRow(this.evaluation, this.graded, this.average);
}

class StudentSummary {
  final Student student;
  final double? average; // /20, pondéré par les coefficients
  final int absences;
  final double? presencePct;
  final int gradedEvals;
  const StudentSummary(this.student, this.average, this.absences, this.presencePct, this.gradedEvals);
}

class TermSummary {
  final int sessions;
  final int evaluations;
  final double? classAverage;
  final double? passRate;
  final List<StudentSummary> students;
  const TermSummary(this.sessions, this.evaluations, this.classAverage, this.passRate, this.students);
}

class EvaluationRepository {
  Future<List<EvaluationRow>> rowsOf(int classId, int termId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT e.*,
        (SELECT COUNT(*) FROM student_grades g
           WHERE g.evaluation_id = e.id AND g.score IS NOT NULL) AS graded,
        (SELECT AVG(g.score) FROM student_grades g
           WHERE g.evaluation_id = e.id AND g.score IS NOT NULL) AS avg_score
      FROM evaluations e
      WHERE e.class_id = ? AND e.term_id = ?
      ORDER BY e.evaluation_date DESC, e.id DESC''', [classId, termId]);
    return [
      for (final r in rows)
        EvaluationRow(Evaluation.fromMap(r), (r['graded'] as int?) ?? 0,
            (r['avg_score'] as num?)?.toDouble()),
    ];
  }

  Future<int> insert(Evaluation e) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('evaluations', e.toMap());
  }

  Future<void> update(Evaluation e) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('evaluations', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('evaluations', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<int, StudentGrade>> gradesOf(int evaluationId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('student_grades',
        where: 'evaluation_id = ?', whereArgs: [evaluationId]);
    return {for (final r in rows) (r['student_id'] as int): StudentGrade.fromMap(r)};
  }

  Future<void> saveGrades(int evaluationId, int termId, List<StudentGrade> grades) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final g in grades) {
      batch.insert('student_grades', {
        'evaluation_id': evaluationId,
        'student_id': g.studentId,
        'term_id': termId,
        'score': g.score,
        'is_exempt': g.isExempt ? 1 : 0,
        'status_code': g.statusCode,
        'remarks': g.remarks,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Toutes les notes d'une classe pour un trimestre : evaluationId -> (studentId -> note).
  Future<Map<int, Map<int, double?>>> gradeMatrix(int classId, int termId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT g.evaluation_id, g.student_id, g.score
      FROM student_grades g JOIN evaluations e ON e.id = g.evaluation_id
      WHERE e.class_id = ? AND e.term_id = ?''', [classId, termId]);
    final out = <int, Map<int, double?>>{};
    for (final r in rows) {
      out.putIfAbsent(r['evaluation_id'] as int, () => {})[r['student_id'] as int] =
          (r['score'] as num?)?.toDouble();
    }
    return out;
  }

  Future<TermSummary> summary(int classId, int? termId, List<Student> students) async {
    final db = await DatabaseHelper.instance.database;
    final tc = termId == null ? '' : ' AND term_id = ?';
    final ta = termId == null ? [classId] : [classId, termId];
    final sessions = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM sessions WHERE class_id = ?$tc', ta)) ??
        0;
    final evals = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM evaluations WHERE class_id = ?$tc', ta)) ??
        0;
    final grades = await db.rawQuery('''
      SELECT g.student_id, g.score, e.max_score, e.coefficient
      FROM student_grades g JOIN evaluations e ON e.id = g.evaluation_id
      WHERE e.class_id = ? ${termId == null ? '' : 'AND e.term_id = ?'} AND g.score IS NOT NULL AND g.is_exempt = 0''',
        ta);
    final att = await db.rawQuery('''
      SELECT a.student_id,
             SUM(CASE WHEN st.counts_as_absence = 1 THEN 1 ELSE 0 END) AS abs_n,
             COUNT(*) AS total
      FROM attendances a
      JOIN sessions se ON se.id = a.session_id
      JOIN attendance_statuses st ON st.id = a.status_id
      WHERE se.class_id = ? ${termId == null ? '' : 'AND se.term_id = ?'}
      GROUP BY a.student_id''', ta);

    final sumN = <int, double>{}, den = <int, double>{}, cnt = <int, int>{};
    for (final g in grades) {
      final id = g['student_id'] as int;
      final max = (g['max_score'] as num).toDouble();
      final coef = (g['coefficient'] as num).toDouble();
      final score = (g['score'] as num).toDouble();
      sumN[id] = (sumN[id] ?? 0) + (score / max * 20) * coef;
      den[id] = (den[id] ?? 0) + coef;
      cnt[id] = (cnt[id] ?? 0) + 1;
    }
    final absBy = {for (final r in att) r['student_id'] as int: (r['abs_n'] as int?) ?? 0};
    final totBy = {for (final r in att) r['student_id'] as int: (r['total'] as int?) ?? 0};

    final list = <StudentSummary>[];
    final avgs = <double>[];
    for (final s in students) {
      final id = s.id!;
      final avg = (den[id] ?? 0) > 0 ? sumN[id]! / den[id]! : null;
      if (avg != null) avgs.add(avg);
      final tot = totBy[id] ?? 0;
      final ab = absBy[id] ?? 0;
      list.add(StudentSummary(s, avg, ab, tot == 0 ? null : (tot - ab) * 100.0 / tot, cnt[id] ?? 0));
    }
    final classAvg = avgs.isEmpty ? null : avgs.reduce((a, b) => a + b) / avgs.length;
    final pass = avgs.isEmpty ? null : avgs.where((a) => a >= 10).length * 100.0 / avgs.length;
    return TermSummary(sessions, evals, classAvg, pass, list);
  }
}
