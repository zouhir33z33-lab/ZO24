import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/evaluation_repository.dart';
import 'repository_providers.dart';
import 'students_provider.dart';

typedef ClassTerm = ({int classId, int termId});

final evaluationRowsProvider =
    FutureProvider.autoDispose.family<List<EvaluationRow>, ClassTerm>((ref, k) {
  return ref.read(evaluationRepositoryProvider).rowsOf(k.classId, k.termId);
});

final termSummaryProvider =
    FutureProvider.autoDispose.family<TermSummary, ClassTerm>((ref, k) async {
  final students = await ref.watch(studentsProvider(k.classId).future);
  return ref.read(evaluationRepositoryProvider).summary(k.classId, k.termId, students);
});

final gradeMatrixProvider =
    FutureProvider.autoDispose.family<Map<int, Map<int, double?>>, ClassTerm>((ref, k) {
  return ref.read(evaluationRepositoryProvider).gradeMatrix(k.classId, k.termId);
});
