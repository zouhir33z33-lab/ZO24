import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_providers.dart';

/// Dernière saisie par élève pour une classe (point de couleur + date « dd/MM »).
final lastMarksProvider = FutureProvider.autoDispose
    .family<Map<int, ({String date, String colorHex})>, int>((ref, classId) {
  return ref.read(statsRepositoryProvider).lastMarks(classId);
});
