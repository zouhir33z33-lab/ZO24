class Term {
  final int? id;
  final int academicYearId;
  final int termNumber; // 1..3
  final String name;
  final String? startDate;
  final String? endDate;
  final bool isCurrent;
  final bool isLocked;
  const Term({
    this.id,
    required this.academicYearId,
    required this.termNumber,
    required this.name,
    this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.isLocked = false,
  });

  factory Term.fromMap(Map<String, dynamic> m) => Term(
        id: m['id'] as int?,
        academicYearId: m['academic_year_id'] as int,
        termNumber: m['term_number'] as int,
        name: m['name'] as String,
        startDate: m['start_date'] as String?,
        endDate: m['end_date'] as String?,
        isCurrent: (m['is_current'] as int? ?? 0) == 1,
        isLocked: (m['is_locked'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'academic_year_id': academicYearId,
        'term_number': termNumber,
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'is_current': isCurrent ? 1 : 0,
        'is_locked': isLocked ? 1 : 0,
      };
}
