import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/incident_constants.dart';
import '../providers/core_providers.dart';
import '../providers/incident_providers.dart';
import '../providers/pdf_context.dart';
import '../services/incident_repository.dart';
import '../services/pdf_export_service.dart';
import '../themes/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/export_sheet.dart';
import 'incident_form_screen.dart';

/// « سجل الحوادث الجسدية » : liste des déclarations d'accident.
class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  Map<String, String> _labels(String Function(String) tr) => {
        'preview': tr('ex_preview'), 'previewSub': tr('ex_preview_sub'),
        'folder': tr('ex_folder'), 'folderSub': tr('ex_folder_sub'),
        'phone': tr('ex_phone'), 'phoneSub': tr('ex_phone_sub'),
        'share': tr('ex_share'), 'shareSub': tr('ex_share_sub'),
        'sheet': tr('ex_sheet'), 'sheetSub': tr('ex_sheet_sub'),
        'saved': tr('ex_saved'),
      };

  Future<void> _pdf(BuildContext context, WidgetRef ref, IncidentRow r) async {
    final tr = ref.read(trProvider);
    final pc = await loadPdfContext(ref);
    if (!context.mounted) return;
    return showExportSheet(
      context,
      title: '${tr('inc_export_title')} : ${r.studentName}',
      subtitle: tr('export_official_sub'),
      fileName: 'Accident_${r.studentName.replaceAll(' ', '_')}_${r.report.incidentDate}.pdf',
      buildPdf: () => PdfExportService.incidentPdf(
        report: r.report, studentName: r.studentName, gender: r.gender,
        className: r.className, level: r.level, ctx: pc),
      labels: _labels(tr),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, IncidentRow r) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('inc_delete_q')),
        content: Text(tr('inc_delete_msg')),
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
      await ref.read(incidentRepositoryProvider).delete(r.report.id!);
      ref.invalidate(incidentsProvider);
      if (context.mounted) showSuccessSnack(context, tr('inc_deleted'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final async = ref.watch(incidentsProvider);
    final rows = async.valueOrNull ?? const <IncidentRow>[];

    return Scaffold(
      appBar: AppBar(title: Text(tr('inc_title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentFormScreen()))
            .then((_) => ref.invalidate(incidentsProvider)),
        backgroundColor: AppColors.absent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(tr('inc_new')),
      ),
      body: async.isLoading && rows.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user, size: 72, color: AppColors.present),
                        const SizedBox(height: 12),
                        Text(tr('inc_none'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(tr('inc_none_sub'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final inc = r.report;
                    final injury = choiceOf(kInjuryTypes, inc.injuryType);
                    final locChoice = choiceOf(kLocations, inc.location);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => IncidentFormScreen(existing: inc)))
                                        .then((_) => ref.invalidate(incidentsProvider));
                                  } else if (v == 'pdf') {
                                    _pdf(context, ref, r);
                                  } else {
                                    _delete(context, ref, r);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'edit', child: Text(tr('edit'))),
                                  PopupMenuItem(value: 'pdf', child: Text(tr('inc_pdf_sheet'))),
                                  PopupMenuItem(value: 'delete', child: Text(tr('delete'))),
                                ],
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(r.studentName,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    Text('${r.className} • ${inc.incidentDate} ${inc.incidentTime}',
                                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.warning_amber_rounded, color: AppColors.absent),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            children: [
                              _Pill(text: injury?.label(lang) ?? inc.injuryType, color: AppColors.absent),
                              _Pill(text: lang == 'ar' ? (locChoice?.ar ?? inc.location) : inc.location,
                                  color: Colors.blueGrey),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(inc.circumstances,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              InkWell(
                                onTap: () => _pdf(context, ref, r),
                                child: Row(children: [
                                  const Icon(Icons.picture_as_pdf, size: 16, color: AppColors.absent),
                                  const SizedBox(width: 4),
                                  const Text('Fiche PDF',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.absent)),
                                ]),
                              ),
                              const Spacer(),
                              if (inc.parentContacted)
                                Row(children: [
                                  const Icon(Icons.check_circle, size: 15, color: AppColors.present),
                                  const SizedBox(width: 4),
                                  const Text('Parents prévenus',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.present)),
                                ]),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
