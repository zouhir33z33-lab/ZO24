import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'academic_providers.dart';
import 'repository_providers.dart';

class ClassesNotifier extends AsyncNotifier<List<SchoolClass>> {
  @override
  Future<List<SchoolClass>> build() async {
    final year = await ref.watch(activeYearProvider.future);
    if (year == null) return [];
    return ref.read(classRepositoryProvider).all(year.id!);
  }

  Future<void> _reload() async {
    final year = await ref.read(activeYearProvider.future);
    if (year == null) return;
    state = AsyncData(await ref.read(classRepositoryProvider).all(year.id!));
  }

  Future<void> add({
    required String name,
    required String level,
    required String colorCode,
  }) async {
    final year = await ref.read(activeYearProvider.future);
    if (year == null) return;
    final count = state.valueOrNull?.length ?? 0;
    await ref.read(classRepositoryProvider).insert(SchoolClass(
          academicYearId: year.id!,
          name: name,
          level: level,
          colorCode: colorCode,
          sortOrder: count,
        ));
    await _reload();
  }

  Future<void> edit(SchoolClass c, {required String name, required String level}) async {
    await ref.read(classRepositoryProvider).update(SchoolClass(
          id: c.id,
          academicYearId: c.academicYearId,
          name: name,
          level: level,
          colorCode: c.colorCode,
          sortOrder: c.sortOrder,
        ));
    await _reload();
  }

  Future<void> remove(int id) async {
    await ref.read(classRepositoryProvider).delete(id);
    await _reload();
  }

  Future<void> emptyClass(int id) async {
    await ref.read(classRepositoryProvider).emptyStudents(id);
    await _reload();
  }

  Future<void> emptyStudents(int classId) async {
    await ref.read(classRepositoryProvider).emptyStudents(classId);
    await _reload();
  }

  Future<void> refresh() => _reload();
}

final classesProvider =
    AsyncNotifierProvider<ClassesNotifier, List<SchoolClass>>(ClassesNotifier.new);
