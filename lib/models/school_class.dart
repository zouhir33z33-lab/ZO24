class SchoolClass {
  final int? id;
  final int academicYearId;
  final String name;
  final String level; // ex: 1AM, 3AS
  final String colorCode;
  final int sortOrder;
  final int studentCount; // calculé (non stocké)
  const SchoolClass({
    this.id,
    required this.academicYearId,
    required this.name,
    required this.level,
    this.colorCode = '#1976D2',
    this.sortOrder = 0,
    this.studentCount = 0,
  });

  factory SchoolClass.fromMap(Map<String, dynamic> m) => SchoolClass(
        id: m['id'] as int?,
        academicYearId: m['academic_year_id'] as int,
        name: m['name'] as String,
        level: m['level'] as String,
        colorCode: (m['color_code'] as String?) ?? '#1976D2',
        sortOrder: m['sort_order'] as int? ?? 0,
        studentCount: (m['student_count'] as int?) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'academic_year_id': academicYearId,
        'name': name,
        'level': level,
        'color_code': colorCode,
        'sort_order': sortOrder,
      };
}
