import 'package:flutter/material.dart';

/// Lettre affichée pour un statut (matrice trimestrielle, mode terrain).
/// Lettres confirmées par le propriétaire : P A R T M E F D (dispensé) U (imprévu).
const Map<String, String> _letters = {
  'PRESENT': 'P', 'ABSENT': 'A', 'LATE': 'R', 'NO_KIT': 'T', 'SICK': 'M',
  'EXPELLED': 'E', 'RUNAWAY': 'F', 'EXEMPT': 'D', 'EMERGENCY': 'U',
};

String statusLetter(String code, String labelFr) {
  final l = _letters[code];
  if (l != null) return l;
  return labelFr.isEmpty ? '?' : labelFr.substring(0, 1).toUpperCase();
}

/// Statuts comptés comme « présent » dans les statistiques d'assiduité
/// (présent, retard, sans tenue = l'élève a participé à la séance).
bool isPresentLike(String code) => code == 'PRESENT' || code == 'LATE' || code == 'NO_KIT';

Color hexColor(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
