class TimetableSlot {
  final int? id;
  final int academicYearId;
  final int classId;
  final int dayOfWeek; // 1..7
  final String startTime;
  final String endTime;
  final int? defaultSheetId;
  final String? fieldName;
  const TimetableSlot({
    this.id,
    required this.academicYearId,
    required this.classId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.defaultSheetId,
    this.fieldName,
  });

  factory TimetableSlot.fromMap(Map<String, dynamic> m) => TimetableSlot(
        id: m['id'] as int?,
        academicYearId: m['academic_year_id'] as int,
        classId: m['class_id'] as int,
        dayOfWeek: m['day_of_week'] as int,
        startTime: m['start_time'] as String,
        endTime: m['end_time'] as String,
        defaultSheetId: m['default_sheet_id'] as int?,
        fieldName: m['field_name'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'default_sheet_id': defaultSheetId,
        'field_name': fieldName,
      };
}
