class AttendanceStatus {
  final int? id;
  final String code;
  final String labelFr, labelAr, labelEn;
  final String colorHex;
  final String? iconName;
  final bool countsAsAbsence;
  final bool isSystem;
  final int sortOrder;
  const AttendanceStatus({
    this.id,
    required this.code,
    required this.labelFr,
    required this.labelAr,
    required this.labelEn,
    required this.colorHex,
    this.iconName,
    this.countsAsAbsence = false,
    this.isSystem = false,
    this.sortOrder = 0,
  });

  String label(String lang) =>
      lang == 'ar' ? labelAr : (lang == 'en' ? labelEn : labelFr);

  factory AttendanceStatus.fromMap(Map<String, dynamic> m) => AttendanceStatus(
        id: m['id'] as int?,
        code: m['code'] as String,
        labelFr: m['label_fr'] as String,
        labelAr: m['label_ar'] as String,
        labelEn: m['label_en'] as String,
        colorHex: m['color_hex'] as String,
        iconName: m['icon_name'] as String?,
        countsAsAbsence: (m['counts_as_absence'] as int? ?? 0) == 1,
        isSystem: (m['is_system'] as int? ?? 0) == 1,
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'code': code,
        'label_fr': labelFr,
        'label_ar': labelAr,
        'label_en': labelEn,
        'color_hex': colorHex,
        'icon_name': iconName,
        'counts_as_absence': countsAsAbsence ? 1 : 0,
        'is_system': isSystem ? 1 : 0,
        'sort_order': sortOrder,
      };
}
