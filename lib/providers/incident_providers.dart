import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/incident_repository.dart';
import 'repository_providers.dart';

final incidentRepositoryProvider = Provider((ref) => IncidentRepository());

final incidentsProvider = FutureProvider.autoDispose<List<IncidentRow>>((ref) {
  return ref.read(incidentRepositoryProvider).all();
});
