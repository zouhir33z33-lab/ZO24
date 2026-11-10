class StudentGrade {
  final int? id;
  final int evaluationId;
  final int studentId;
  final int termId;
  final double? score; // 0..20
  final bool isExempt;
  final String statusCode;
  final String? remarks;
  const StudentGrade({
    this.id,
    required this.evaluationId,
    required this.studentId,
    required this.termId,
    this.score,
    this.isExempt = false,
    this.statusCode = 'PRESENT',
    this.remarks,
  });

  factory StudentGrade.fromMap(Map<String, dynamic> m) => StudentGrade(
        id: m['id'] as int?,
        evaluationId: m['evaluation_id'] as int,
        studentId: m['student_id'] as int,
        termId: m['term_id'] as int,
        score: (m['score'] as num?)?.toDouble(),
        isExempt: (m['is_exempt'] as int? ?? 0) == 1,
        statusCode: (m['status_code'] as String?) ?? 'PRESENT',
        remarks: m['remarks'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'evaluation_id': evaluationId,
        'student_id': studentId,
        'term_id': termId,
        'score': score,
        'is_exempt': isExempt ? 1 : 0,
        'status_code': statusCode,
        'remarks': remarks,
      };
}
