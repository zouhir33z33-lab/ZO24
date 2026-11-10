import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import 'repository_providers.dart';

class TeacherProfile {
  final String lastName, firstName, school, place, rank, grade;
  const TeacherProfile({
    this.lastName = '', this.firstName = '', this.school = '',
    this.place = '', this.rank = '', this.grade = '',
  });
  bool get isEmpty => lastName.isEmpty && firstName.isEmpty;
  String get fullName => '$lastName $firstName'.trim();
}

class TeacherNotifier extends AsyncNotifier<TeacherProfile> {
  @override
  Future<TeacherProfile> build() async {
    final r = ref.read(settingsRepositoryProvider);
    Future<String> g(String k) async => (await r.get(k)) ?? '';
    return TeacherProfile(
      lastName: await g(SettingsKeys.teacherLastName),
      firstName: await g(SettingsKeys.teacherFirstName),
      school: await g(SettingsKeys.teacherSchool),
      place: await g(SettingsKeys.teacherPlace),
      rank: await g(SettingsKeys.teacherRank),
      grade: await g(SettingsKeys.teacherGrade),
    );
  }

  Future<void> save(TeacherProfile p) async {
    final r = ref.read(settingsRepositoryProvider);
    await r.set(SettingsKeys.teacherLastName, p.lastName);
    await r.set(SettingsKeys.teacherFirstName, p.firstName);
    await r.set(SettingsKeys.teacherSchool, p.school);
    await r.set(SettingsKeys.teacherPlace, p.place);
    await r.set(SettingsKeys.teacherRank, p.rank);
    await r.set(SettingsKeys.teacherGrade, p.grade);
    state = AsyncData(p);
  }
}

final teacherProvider = AsyncNotifierProvider<TeacherNotifier, TeacherProfile>(TeacherNotifier.new);
