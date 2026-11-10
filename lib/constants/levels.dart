import 'package:flutter/material.dart';
import 'app_constants.dart';

/// Niveau scolaire. Libellés arabes des niveaux 1AM–4AM relevés dans la vidéo ;
/// les libellés des autres niveaux suivent le même schéma (APPROXIMATION à valider).
class LevelInfo {
  final String code;
  final String ar;
  final String fr;
  final Color color; // couleur de sélection (déduite de 2 captures : à affiner)
  const LevelInfo(this.code, this.ar, this.fr, this.color);
}

const Color _blue = Color(0xFF1565C0);
const Color _green = Color(0xFF2E7D32);
const Color _orange = Color(0xFFEF6C00);
const Color _purple = Color(0xFF6A1B9A);

const Map<String, LevelInfo> kLevels = {
  '1AP': LevelInfo('1AP', '1 ابتدائي (سنة أولى)', '1ère année primaire', _blue),
  '2AP': LevelInfo('2AP', '2 ابتدائي (سنة ثانية)', '2ème année primaire', _green),
  '3AP': LevelInfo('3AP', '3 ابتدائي (سنة ثالثة)', '3ème année primaire', _orange),
  '4AP': LevelInfo('4AP', '4 ابتدائي (سنة رابعة)', '4ème année primaire', _purple),
  '5AP': LevelInfo('5AP', '5 ابتدائي (سنة خامسة)', '5ème année primaire', _blue),
  '1AM': LevelInfo('1AM', '1 متوسط (سنة أولى)', '1ère année moyenne', _blue),
  '2AM': LevelInfo('2AM', '2 متوسط (سنة ثانية)', '2ème année moyenne', _green),
  '3AM': LevelInfo('3AM', '3 متوسط (سنة ثالثة)', '3ème année moyenne', _orange),
  '4AM': LevelInfo('4AM', '4 متوسط (نهاية التعليم المتوسط)', '4ème année moyenne', _purple),
  '1AS': LevelInfo('1AS', '1 ثانوي (سنة أولى)', '1ère année secondaire', _blue),
  '2AS': LevelInfo('2AS', '2 ثانوي (سنة ثانية)', '2ème année secondaire', _green),
  '3AS': LevelInfo('3AS', '3 ثانوي (سنة ثالثة)', '3ème année secondaire', _orange),
};

List<LevelInfo> levelsOf(EducationCycle cycle) {
  final data = kCycles.firstWhere((c) => c.cycle == cycle);
  return [for (final l in data.levels) kLevels[l]!];
}

/// Palette des bandes de couleur des cartes de classe (ordre de création).
const List<String> kClassColors = [
  '#1976D2', '#EF6C00', '#2E7D32', '#6A1B9A', '#C62828', '#00838F',
];

Color colorFromHex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}
