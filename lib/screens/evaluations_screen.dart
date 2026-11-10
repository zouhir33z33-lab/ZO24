import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/academic_providers.dart';
import '../providers/core_providers.dart';
import '../providers/evaluation_providers.dart';
import '../providers/repository_providers.dart';
import '../services/evaluation_repository.dart';
import '../themes/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/evaluation_form_sheet.dart';
import 'class_gradebook_screen.dart';
import 'grade_entry_screen.dart';

/// Liste des évaluations d'une classe, par trimestre.
class EvaluationsScreen extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  const EvaluationsScreen({super.key, required this.schoolClass});
  @override
  ConsumerState<EvaluationsScreen> createState() => _EvaluationsScreenState();
}

class _EvaluationsScreenState extends ConsumerState<EvaluationsScreen> {
  int? _termId;

  Future<void> _delete(Evaluation e) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('ev_delete_q')),
        content: Text(tr('ev_delete_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete'), style: const TextStyle(color: AppColors.absent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(evaluationRepositoryProvider).delete(e.id!);
      ref.invalidate(evaluationRowsProvider);
      if (mounted) showSuccessSnack(context, tr('ev_deleted'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.schoolClass;
    final tr = ref.watch(trProvider);
    final terms = ref.watch(termsProvider).valueOrNull ?? const <Term>[];
    final current = terms.where((t) => t.isCurrent).firstOrNull ?? (terms.isNotEmpty ? terms.first : null);
    final termId = _termId ?? current?.id;
    final term = terms.where((t) => t.id == termId).firstOrNull;
    final locked = term?.isLocked ?? false;
    final rowsAsync = termId == null
        ? const AsyncValue<List<EvaluationRow>>.data([])
        : ref.watch(evaluationRowsProvider((classId: c.id!, termId: termId)));
    final rows = rowsAsync.valueOrNull ?? const <EvaluationRow>[];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${tr('ev_title')} • ${c.name}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('${c.level} • ${tr('ev_entry')}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(evaluationRowsProvider),
          ),
        ],
      ),
      floatingActionButton: locked || termId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showEvaluationFormSheet(context, ref, schoolClass: c, termId: termId),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(tr('ev_new')),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                for (final t in terms.reversed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _termId = t.id),
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: termId == t.id ? AppColors.primary : Colors.white,
                            border: Border.all(
                                color: termId == t.id ? AppColors.primary : Colors.black54),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (t.isCurrent) const Icon(Icons.star, size: 13, color: Colors.amber),
                              if (t.isLocked) const Icon(Icons.lock, size: 13, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text('Trim. ${t.termNumber}',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: termId == t.id ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (termId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ClassGradebookScreen(schoolClass: c, termId: termId)),
                ),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: Text('${tr('ev_view_sheet')} (${term?.name.split(' (').first ?? ''})'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: Colors.black87),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          Expanded(
            child: rowsAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text('${tr('ev_none')} — ${term?.name.split(' (').first ?? ''}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(tr('ev_none_hint'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              if (!locked) ...[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () => showEvaluationFormSheet(context, ref,
                                      schoolClass: c, termId: termId!),
                                  icon: const Icon(Icons.add),
                                  label: Text(tr('ev_create_test')),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    minimumSize: const Size(double.infinity, 48),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          final e = r.evaluation;
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GradeEntryScreen(
                                    schoolClass: c, evaluation: e, locked: locked),
                              ),
                            ).then((_) => ref.invalidate(evaluationRowsProvider)),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      if (!locked) ...[
                                        InkWell(
                                          onTap: () => _delete(e),
                                          child: const Icon(Icons.delete_outline, size: 20, color: AppColors.absent),
                                        ),
                                        const SizedBox(width: 12),
                                        InkWell(
                                          onTap: () => showEvaluationFormSheet(context, ref,
                                              schoolClass: c, termId: termId!, existing: e),
                                          child: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                                        ),
                                      ],
                                      const Spacer(),
                                      Flexible(
                                        child: Text(e.title,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.present.withOpacity(0.1),
                                          border: Border.all(color: AppColors.present.withOpacity(0.5)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          r.average == null
                                              ? 'Moy : N/A'
                                              : 'Moy : ${r.average!.toStringAsFixed(1)}/${e.maxScore.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.present),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${r.graded} ${tr('ev_graded')}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      Text('  •  ${e.evaluationDate}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
