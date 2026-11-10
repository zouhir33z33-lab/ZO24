import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'repository_providers.dart';

final lastStatusProvider =
    FutureProvider.autoDispose.family<Map<int, (String, AttendanceStatus)>, int>((ref, classId) {
  return ref.read(statsRepositoryProvider).lastStatus(classId);
});
