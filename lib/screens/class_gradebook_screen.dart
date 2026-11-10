import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/evaluation_providers.dart';
import '../providers/students_provider.dart';
import '../providers/academic_providers.dart';
import '../providers/pdf_context.dart';
import '../services/pdf_export_service.dart';
import '../themes/app_colors.dart';
import '../utils/xlsx_writer.dart';
import '../widgets/export_sheet.dart';

/// Relevé de notes d'une classe pour un trimestre (élèves × évaluations + moyenne).
/// NB : l'aperçu de l'original n'est pas visible dans la vidéo ; mise en page simple.
class ClassGradebookScreen extends ConsumerWidget {
  final SchoolClass schoolClass;
  final int termId;
  const ClassGradebookScreen({super.key, required this.schoolClass, required this.termId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final key = (classId: schoolClass.id!, termId: termId);
    final students = ref.watch(studentsProvider(schoolClass.id!)).valueOrNull ?? const <Student>[];
    final rows = ref.watch(evaluationRowsProvider(key)).valueOrNull ?? const [];
    final matrix = ref.watch(gradeMatrixProvider(key)).valueOrNull ?? const <int, Map<int, double?>>{};
    final summary = ref.watch(termSummaryProvider(key)).valueOrNull;
    final avgOf = {
      for (final s in summary?.students ?? const []) s.student.id!: s.average,
    };

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${tr('gb_title')} • ${schoolClass.name}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(schoolClass.level, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          if (summary != null && rows.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () async {
                final terms = ref.read(termsProvider).valueOrNull ?? const <Term>[];
                final term = terms.firstWhere((t) => t.id == termId);
                final pc = await loadPdfContext(ref);
                final evals = rows.reversed.toList();
                if (!context.mounted) return;
                await showExportSheet(
                  context,
                  title: '${tr('gb_title')} • ${schoolClass.name}',
                  subtitle: tr('export_official_sub'),
                  fileName: 'Releve_notes_${schoolClass.name}_T${term.termNumber}.pdf',
                  buildPdf: () => PdfExportService.gradeSheetPdf(
                      cls: schoolClass, term: term, evals: evals, matrix: matrix,
                      summary: summary, ctx: pc),
                  buildSpreadsheet: () async => Uint8List.fromList(toXlsxBytes(
                      PdfExportService.gradeSheetCsv(schoolClass, term, evals, matrix, summary))),
                  spreadsheetName: 'Releve_notes_${schoolClass.name}_T${term.termNumber}.xlsx',
                  labels: exportLabels(tr),
                );
              },
            ),
        ],
      ),
      body: rows.isEmpty
          ? Center(child: Text(tr('ev_none')))
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFE3EAF3)),
                  columns: [
                    const DataColumn(label: Text('#')),
                    DataColumn(label: Text(tr('last_name').replaceAll(' *', ''))),
                    for (final r in rows.reversed)
                      DataColumn(
                        numeric: true,
                        label: Text('${r.evaluation.title}\n/${r.evaluation.maxScore.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    DataColumn(numeric: true, label: Text(tr('gb_avg'))),
                  ],
                  rows: [
                    for (var i = 0; i < students.length; i++)
                      DataRow(cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(students[i].fullName)),
                        for (final r in rows.reversed)
                          DataCell(Text(matrix[r.evaluation.id]?[students[i].id] == null
                              ? '--'
                              : matrix[r.evaluation.id]![students[i].id]!.toStringAsFixed(2))),
                        DataCell(Text(
                          avgOf[students[i].id] == null ? '--' : avgOf[students[i].id]!.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        )),
                      ]),
                  ],
                ),
              ),
            ),
    );
  }
}
