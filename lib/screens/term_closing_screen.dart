import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/academic_providers.dart';
import '../providers/classes_provider.dart';
import '../providers/core_providers.dart';
import '../providers/evaluation_providers.dart';
import '../providers/repository_providers.dart';
import '../services/evaluation_repository.dart';
import '../themes/app_colors.dart';
import '../providers/pdf_context.dart';
import '../services/pdf_export_service.dart';
import '../utils/xlsx_writer.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/export_sheet.dart';

/// Clôture trimestrielle : T1/T2/T3, statistiques par classe, verrouillage.
class TermClosingScreen extends ConsumerStatefulWidget {
  final SchoolClass? initialClass;
  const TermClosingScreen({super.key, this.initialClass});
  @override
  ConsumerState<TermClosingScreen> createState() => _TermClosingScreenState();
}

class _TermClosingScreenState extends ConsumerState<TermClosingScreen> {
  int? _classId;
  int? _termId;

  static String appreciation(double avg) {
    if (avg >= 16) return 'Très Bien';
    if (avg >= 14) return 'Bien';
    if (avg >= 12) return 'Assez Bien';
    if (avg >= 10) return 'Passable';
    return 'Insuffisant';
  }

  Future<void> _close(Term t) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock, color: AppColors.orange),
        title: Text(tr('tc_close_q')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('(${t.name})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(tr('tc_close_msg')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            child: Text(tr('tc_confirm')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(academicRepositoryProvider).closeTerm(t);
      ref.invalidate(termsProvider);
      ref.invalidate(termSummaryProvider);
      if (mounted) {
        setState(() => _termId = null);
        showSuccessSnack(context, tr('tc_closed_ok'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final terms = ref.watch(termsProvider).valueOrNull ?? const <Term>[];
    final classes = ref.watch(classesProvider).valueOrNull ?? const <SchoolClass>[];
    final cls = classes.where((c) => c.id == (_classId ?? widget.initialClass?.id)).firstOrNull ??
        (classes.isNotEmpty ? classes.first : null);
    final current = terms.where((t) => t.isCurrent).firstOrNull ?? (terms.isNotEmpty ? terms.first : null);
    final term = terms.where((t) => t.id == _termId).firstOrNull ?? current;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('tc_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(tr('tc_sub'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(termsProvider);
              ref.invalidate(termSummaryProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                for (final t in terms.reversed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _termId = t.id),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: term?.id == t.id ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (t.isCurrent) const Icon(Icons.star, size: 14, color: Colors.amber),
                              if (!t.isCurrent && !t.isLocked) Icon(Icons.lock, size: 13, color: Colors.orange.shade700),
                              if (t.isLocked) const Icon(Icons.lock, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('T${t.termNumber}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: term?.id == t.id ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (classes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: cls?.id,
                  items: [
                    for (final c in classes)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text('${tr('tc_class')} : ${c.name} (${c.level})',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _classId = v),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: (cls == null || term == null)
                ? Center(child: Text(tr('no_classes_level')))
                : _TermBody(
                    cls: cls,
                    term: term,
                    onClose: () => _close(term),
                    appreciation: appreciation,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TermBody extends ConsumerWidget {
  final SchoolClass cls;
  final Term term;
  final VoidCallback onClose;
  final String Function(double) appreciation;
  const _TermBody({required this.cls, required this.term, required this.onClose, required this.appreciation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(termSummaryProvider((classId: cls.id!, termId: term.id!)));
    final active = term.isCurrent && !term.isLocked;
    final closed = term.isLocked;
    final pending = !active && !closed;
    final headBg = active ? const Color(0xFFE3F2FD) : (closed ? const Color(0xFFF1F4F8) : const Color(0xFFFFF3E0));

    return ListView(
      children: [
        Container(
          color: headBg,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (active)
                    const Icon(Icons.star, color: AppColors.primary)
                  else
                    Icon(Icons.lock, color: pending ? AppColors.orange : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(term.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      active ? tr('tc_active') : (closed ? tr('tc_closed') : '…'),
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                active ? tr('tc_current_desc') : (pending ? tr('tc_pending_hint') : ''),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              if (active) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.lock, size: 16),
                    label: Text(tr('tc_close_btn')),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!pending)
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
            data: (TermSummary s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F7),
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _Kpi(value: '${s.sessions}', label: tr('tc_sessions')),
                      _Kpi(value: '${s.evaluations}', label: tr('tc_evals')),
                      _Kpi(
                          value: s.classAverage == null ? 'N/A' : '${s.classAverage!.toStringAsFixed(1)}/20',
                          label: tr('tc_avg'), color: AppColors.primary),
                      _Kpi(
                          value: s.passRate == null ? 'N/A' : '${s.passRate!.toStringAsFixed(1)}%',
                          label: tr('tc_pass')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          final pc = await loadPdfContext(ref);
                          if (!context.mounted) return;
                          await showExportSheet(
                            context,
                            title: '${tr('tc_bilan')} • ${cls.name}',
                            subtitle: tr('export_official_sub'),
                            fileName: 'Bilan_${cls.name}_T${term.termNumber}.pdf',
                            buildPdf: () => PdfExportService.termReportPdf(
                                cls: cls, term: term, summary: s, ctx: pc),
                            buildSpreadsheet: () async =>
                                Uint8List.fromList(toXlsxBytes(PdfExportService.termCsv(cls, term, s))),
                            spreadsheetName: 'Bilan_${cls.name}_T${term.termNumber}.xlsx',
                            labels: exportLabels(tr),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: Text(tr('tc_export_pdf')),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
                      ),
                      const Spacer(),
                      Text('${s.students.length} ${tr('tc_students')}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(),
                for (final st in s.students)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: (st.student.gender == 'F' ? const Color(0xFFD81B60) : AppColors.primary)
                          .withOpacity(0.12),
                      child: Text(st.student.gender == 'F' ? 'F' : 'G',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: st.student.gender == 'F' ? const Color(0xFFD81B60) : AppColors.primary)),
                    ),
                    title: Text(st.student.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Abs : ${st.absences} (${(st.presencePct ?? 100).toStringAsFixed(0)}%) · Éval : ${st.gradedEvals}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: st.average == null
                        ? const Text('--')
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.present.withOpacity(0.1),
                                  border: Border.all(color: AppColors.present),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${st.average!.toStringAsFixed(2)}/20',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.present)),
                              ),
                              Text(appreciation(st.average!),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.present)),
                            ],
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String value, label;
  final Color? color;
  const _Kpi({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
