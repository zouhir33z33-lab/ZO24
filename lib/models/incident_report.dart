class IncidentReport {
  final int? id;
  final int studentId;
  final int classId;
  final int? sessionId;
  final String incidentDate;
  final String incidentTime;
  final String location;
  final String? activity;
  final String injuryType;
  final String? injuryLocation;
  final String circumstances;
  final String? firstAidGiven;
  final String evacuationType;
  final String? witnessStudents;
  final bool parentContacted;
  final String? notes;
  final String? createdAt;
  const IncidentReport({
    this.id,
    required this.studentId,
    required this.classId,
    this.sessionId,
    required this.incidentDate,
    required this.incidentTime,
    required this.location,
    this.activity,
    required this.injuryType,
    this.injuryLocation,
    required this.circumstances,
    this.firstAidGiven,
    this.evacuationType = 'Infirmerie scolaire',
    this.witnessStudents,
    this.parentContacted = false,
    this.notes,
    this.createdAt,
  });

  factory IncidentReport.fromMap(Map<String, dynamic> m) => IncidentReport(
        id: m['id'] as int?,
        studentId: m['student_id'] as int,
        classId: m['class_id'] as int,
        sessionId: m['session_id'] as int?,
        incidentDate: m['incident_date'] as String,
        incidentTime: m['incident_time'] as String,
        location: m['location'] as String,
        activity: m['activity'] as String?,
        injuryType: m['injury_type'] as String,
        injuryLocation: m['injury_location'] as String?,
        circumstances: m['circumstances'] as String,
        firstAidGiven: m['first_aid_given'] as String?,
        evacuationType: (m['evacuation_type'] as String?) ?? 'Infirmerie scolaire',
        witnessStudents: m['witness_students'] as String?,
        parentContacted: (m['parent_contacted'] as int? ?? 0) == 1,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'class_id': classId,
        'session_id': sessionId,
        'incident_date': incidentDate,
        'incident_time': incidentTime,
        'location': location,
        'activity': activity,
        'injury_type': injuryType,
        'injury_location': injuryLocation,
        'circumstances': circumstances,
        'first_aid_given': firstAidGiven,
        'evacuation_type': evacuationType,
        'witness_students': witnessStudents,
        'parent_contacted': parentContacted ? 1 : 0,
        'notes': notes,
      };
}
