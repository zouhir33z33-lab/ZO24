/// Statuts de présence par défaut.
/// Libellés FR/AR/EN, ordre et caractère « compte comme absence » : relevés sur
/// l'écran « Statuts d'appel » de l'application d'origine. Les codes techniques
/// (PRESENT, NO_KIT…) et les couleurs exactes restent des approximations.
class DefaultStatus {
  final String code, labelFr, labelAr, labelEn, colorHex, icon;
  final bool countsAsAbsence;
  const DefaultStatus(this.code, this.labelFr, this.labelAr, this.labelEn,
      this.colorHex, this.icon, this.countsAsAbsence);
}

const List<DefaultStatus> kDefaultStatuses = [
  DefaultStatus('PRESENT', 'Présent', 'حاضر', 'Present', '#2E7D32', 'check', false),
  DefaultStatus('ABSENT', 'Absent', 'غائب', 'Absent', '#C62828', 'close', true),
  DefaultStatus('LATE', 'Retard', 'تأخر', 'Late', '#EF6C00', 'schedule', false),
  DefaultStatus('NO_KIT', 'Sans tenue', 'بدون بدلة', 'No Sportswear', '#6A1B9A', 'checkroom', false),
  DefaultStatus('SICK', 'Malade', 'مريض', 'Sick', '#4E342E', 'sick', false),
  DefaultStatus('EXPELLED', 'Expulsion', 'طرد', 'Expelled', '#880E4F', 'block', true),
  DefaultStatus('RUNAWAY', 'Fuite', 'هروب', 'Truancy / Left', '#D84315', 'directions_run', true),
  DefaultStatus('EXEMPT', 'Dispensé', 'معفى', 'Exempted', '#0277BD', 'medical', false),
  DefaultStatus('EMERGENCY', 'Imprévu', 'طارئ', 'Unforeseen', '#455A64', 'warning', false),
];
