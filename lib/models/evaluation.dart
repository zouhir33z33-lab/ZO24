class Evaluation {
  final int? id;
  final int classId;
  final int termId;
  final String title;
  final String evaluationDate;
  final double maxScore;
  final double coefficient;
  const Evaluation({
    this.id,
    required this.classId,
    required this.termId,
    required this.title,
    required this.evaluationDate,
    this.maxScore = 20.0,
    this.coefficient = 1.0,
  });

  factory Evaluation.fromMap(Map<String, dynamic> m) => Evaluation(
        id: m['id'] as int?,
        classId: m['class_id'] as int,
        termId: m['term_id'] as int,
        title: m['title'] as String,
        evaluationDate: m['evaluation_date'] as String,
        maxScore: (m['max_score'] as num?)?.toDouble() ?? 20.0,
        coefficient: (m['coefficient'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'class_id': classId,
        'term_id': termId,
        'title': title,
        'evaluation_date': evaluationDate,
        'max_score': maxScore,
        'coefficient': coefficient,
      };
}
