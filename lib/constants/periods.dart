/// Périodes de la journée (relevées dans la vue hebdomadaire et l'écran
/// « Assigner une séance » de la vidéo). Pause déjeuner : 12:00–13:30.
class Period {
  final String id; // M1 M2 E1 E2
  final String start;
  final String end;
  final bool morning;
  const Period(this.id, this.start, this.end, this.morning);
  String get key => 'period_$id';
  String get longKey => 'period_long_$id';
}

const List<Period> kPeriods = [
  Period('M1', '08:00', '10:00', true),
  Period('M2', '10:00', '12:00', true),
  Period('E1', '13:30', '15:30', false),
  Period('E2', '15:30', '17:30', false),
];

const String kLunchStart = '12:00';
const String kLunchEnd = '13:30';

Period? periodOf(String start, String end) {
  for (final p in kPeriods) {
    if (p.start == start && p.end == end) return p;
  }
  return null;
}

/// Terrains proposés (puces de la vidéo ; la liste complète n'est pas visible).
const List<String> kFacilities = [
  'Terrain Extérieur 1',
  'Terrain Extérieur 2',
  'Salle de gymnastique',
  'Plateau sportif',
  'Omnisports',
];
