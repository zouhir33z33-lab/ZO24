import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'repository_providers.dart';

/// Année scolaire active.
final activeYearProvider = FutureProvider<AcademicYear?>((ref) {
  return ref.read(academicRepositoryProvider).activeYear();
});

/// Trimestres de l'année active.
final termsProvider = FutureProvider<List<Term>>((ref) async {
  final year = await ref.watch(activeYearProvider.future);
  if (year == null) return [];
  return ref.read(academicRepositoryProvider).termsOf(year.id!);
});

/// Trimestre sélectionné (par défaut : le trimestre courant).
final selectedTermIdProvider = StateProvider<int?>((ref) => null);
