import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pdf_export_service.dart';
import '../utils/labels.dart';
import 'academic_providers.dart';
import 'core_providers.dart';
import 'teacher_provider.dart';

/// Construit le contexte administratif des PDF (enseignant, année, cycle).
Future<PdfContext> loadPdfContext(WidgetRef ref) async {
  final teacher = await ref.read(teacherProvider.future);
  final year = await ref.read(activeYearProvider.future);
  final cycle = ref.read(cycleProvider);
  return PdfContext(
    teacher: teacher,
    yearName: year?.name ?? '',
    directorLabel: directorTitle(cycle),
    cycleWord: cycleNoun(cycle),
  );
}
