class Attendance {
  final int? id;
  final int sessionId;
  final int studentId;
  final int termId;
  final int statusId;
  final String? observation;
  const Attendance({
    this.id,
    required this.sessionId,
    required this.studentId,
    required this.termId,
    required this.statusId,
    this.observation,
  });

  factory Attendance.fromMap(Map<String, dynamic> m) => Attendance(
        id: m['id'] as int?,
        sessionId: m['session_id'] as int,
        studentId: m['student_id'] as int,
        termId: m['term_id'] as int,
        statusId: m['status_id'] as int,
        observation: m['observation'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'student_id': studentId,
        'term_id': termId,
        'status_id': statusId,
        'observation': observation,
      };
}
