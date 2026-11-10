import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'classes_provider.dart';
import 'repository_providers.dart';

class StudentsNotifier extends FamilyAsyncNotifier<List<Student>, int> {
  @override
  Future<List<Student>> build(int classId) {
    return ref.read(studentRepositoryProvider).byClass(classId);
  }

  Future<void> _reload() async {
    state = AsyncData(await ref.read(studentRepositoryProvider).byClass(arg));
    // met à jour le compteur d'élèves affiché sur les cartes de classe
    await ref.read(classesProvider.notifier).refresh();
  }

  Future<void> add(Student s) async {
    final count = state.valueOrNull?.length ?? 0;
    await ref.read(studentRepositoryProvider).insert(Student(
          classId: arg,
          firstName: s.firstName,
          lastName: s.lastName,
          gender: s.gender,
          studentNumber: s.studentNumber,
          sortOrder: count,
        ));
    await _reload();
  }

  Future<void> edit(Student s) async {
    await ref.read(studentRepositoryProvider).update(s);
    await _reload();
  }

  Future<void> remove(int id) async {
    await ref.read(studentRepositoryProvider).delete(id);
    await _reload();
  }
}

final studentsProvider =
    AsyncNotifierProvider.family<StudentsNotifier, List<Student>, int>(
        StudentsNotifier.new);
