class AcademicYear {
  final int? id;
  final String name;
  final bool isActive;
  final String? createdAt;
  const AcademicYear({this.id, required this.name, this.isActive = false, this.createdAt});

  factory AcademicYear.fromMap(Map<String, dynamic> m) => AcademicYear(
        id: m['id'] as int?,
        name: m['name'] as String,
        isActive: (m['is_active'] as int? ?? 0) == 1,
        createdAt: m['created_at'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'is_active': isActive ? 1 : 0,
      };
}
