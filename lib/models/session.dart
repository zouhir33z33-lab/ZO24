class Session {
  final int? id;
  final int classId;
  final int termId;
  final String sessionDate; // yyyy-MM-dd
  final String startTime; // HH:mm
  final String endTime;
  final int? pedagogicalSheetId;
  final String status; // COMPLETED | CANCELLED
  final String? cancellationReason;
  const Session({
    this.id,
    required this.classId,
    required this.termId,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    this.pedagogicalSheetId,
    this.status = 'COMPLETED',
    this.cancellationReason,
  });

  factory Session.fromMap(Map<String, dynamic> m) => Session(
        id: m['id'] as int?,
        classId: m['class_id'] as int,
        termId: m['term_id'] as int,
        sessionDate: m['session_date'] as String,
        startTime: m['start_time'] as String,
        endTime: m['end_time'] as String,
        pedagogicalSheetId: m['pedagogical_sheet_id'] as int?,
        status: (m['status'] as String?) ?? 'COMPLETED',
        cancellationReason: m['cancellation_reason'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'class_id': classId,
        'term_id': termId,
        'session_date': sessionDate,
        'start_time': startTime,
        'end_time': endTime,
        'pedagogical_sheet_id': pedagogicalSheetId,
        'status': status,
        'cancellation_reason': cancellationReason,
      };
}
