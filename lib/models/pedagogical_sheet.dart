class PedagogicalSheet {
  final int? id;
  final String title;
  final String? sportDiscipline;
  final String fileType; // PDF | IMAGE | TEXT
  final String? filePath;
  final String? textContent;
  final String? createdAt;
  const PedagogicalSheet({
    this.id,
    required this.title,
    this.sportDiscipline,
    required this.fileType,
    this.filePath,
    this.textContent,
    this.createdAt,
  });

  factory PedagogicalSheet.fromMap(Map<String, dynamic> m) => PedagogicalSheet(
        id: m['id'] as int?,
        title: m['title'] as String,
        sportDiscipline: m['sport_discipline'] as String?,
        fileType: m['file_type'] as String,
        filePath: m['file_path'] as String?,
        textContent: m['text_content'] as String?,
        createdAt: m['created_at'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'sport_discipline': sportDiscipline,
        'file_type': fileType,
        'file_path': filePath,
        'text_content': textContent,
      };
}
