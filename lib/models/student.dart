class Student {
  final int? id;
  final int classId;
  final String firstName;
  final String lastName;
  final String? gender; // 'M' | 'F'
  final String? studentNumber;
  final bool isExempt;
  final String? medicalReason;
  final String paiConditions;
  final String paiInstructions;
  final int sortOrder;
  final bool isActive;
  const Student({
    this.id,
    required this.classId,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.studentNumber,
    this.isExempt = false,
    this.medicalReason,
    this.paiConditions = '',
    this.paiInstructions = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  String get fullName => '$lastName $firstName';
  bool get hasPai => paiConditions.isNotEmpty || paiInstructions.isNotEmpty;

  factory Student.fromMap(Map<String, dynamic> m) => Student(
        id: m['id'] as int?,
        classId: m['class_id'] as int,
        firstName: m['first_name'] as String,
        lastName: m['last_name'] as String,
        gender: m['gender'] as String?,
        studentNumber: m['student_number'] as String?,
        isExempt: (m['is_exempt'] as int? ?? 0) == 1,
        medicalReason: m['medical_reason'] as String?,
        paiConditions: (m['pai_conditions'] as String?) ?? '',
        paiInstructions: (m['pai_instructions'] as String?) ?? '',
        sortOrder: m['sort_order'] as int? ?? 0,
        isActive: (m['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'class_id': classId,
        'first_name': firstName,
        'last_name': lastName,
        'gender': gender,
        'student_number': studentNumber,
        'is_exempt': isExempt ? 1 : 0,
        'medical_reason': medicalReason,
        'pai_conditions': paiConditions,
        'pai_instructions': paiInstructions,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
      };
}
