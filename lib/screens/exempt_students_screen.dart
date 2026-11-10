import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/levels.dart';
import '../models/models.dart';
import '../providers/classes_provider.dart';
import '../providers/core_providers.dart';
import '../providers/pdf_context.dart';
import '../providers/repository_providers.dart';
import '../services/pdf_export_service.dart';
import '../themes/app_colors.dart';
import '../utils/xlsx_writer.dart';
import '../widgets/export_sheet.dart';
import 'class_detail_screen.dart';

/// « التلاميذ المعفون » : synthèse, recherche, filtre par niveau, export (PDF/CSV).
class ExemptStudentsScreen extends ConsumerStatefulWidget {
  const ExemptStudentsScreen({super.key});
  @override
  ConsumerState<ExemptStudentsScreen> createState() => _ExemptStudentsScreenState();
}

class _ExemptStudentsScreenState extends ConsumerState<ExemptStudentsScreen> {
  final _ctrl = TextEditingController();
  String? _level; // null = TOUS
  List<Map<String, Object?>> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(studentRepositoryProvider).search('', onlyExempt: true);
    if (mounted) setState(() => _all = r);
  }

  List<Map<String, Object?>> get _shown {
    final q = _ctrl.text.trim().toLowerCase();
    return _all.where((r) {
      if (_level != null && r['class_level'] != _level) return false;
      if (q.isEmpty) return true;
      return '${r['last_name']} ${r['first_name']} ${r['class_name']} ${r['medical_reason'] ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final classes = ref.watch(classesProvider).valueOrNull ?? const <SchoolClass>[];
    final levels = <String>[];
    for (final c in classes) {
      if (!levels.contains(c.level)) levels.add(c.level);
    }
    final shown = _shown;
    final males = shown.where((r) => r['gender'] == 'M').length;
    final females = shown.where((r) => r['gender'] == 'F').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('ex_students_title')),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: shown.isEmpty ? null : () async {
            final pc = await loadPdfContext(ref);
            if (!context.mounted) return;
            await showExportSheet(
              context,
              title: tr('ex_students_title'),
              subtitle: tr('export_official_sub'),
              fileName: 'Liste_Eleves_Dispenses_EPS_${pc.yearName.replaceAll('/', '_')}.pdf',
              buildPdf: () => PdfExportService.exemptListPdf(
                  rows: shown, levelLabel: _level ?? 'Tous les niveaux', ctx: pc),
              buildSpreadsheet: () async => Uint8List.fromList(toXlsxBytes(PdfExportService.exemptCsv(shown))),
              spreadsheetName: 'Liste_Eleves_Dispenses_EPS.xlsx',
              labels: exportLabels(tr),
            );
          }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0288D1), Color(0xFF00838F)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('♂ ${tr('ex_males')} : $males', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    Text('♀ ${tr('ex_females')} : $females', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ]),
                ),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(tr('ex_total'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Row(children: [
                    Text('élève(s)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 6),
                    Text('${shown.length}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ]),
                ]),
                const SizedBox(width: 10),
                const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.verified_user, color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _ctrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: tr('ex_search_hint'),
                suffixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final l in [...levels.reversed, null])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(l ?? 'TOUS', style: const TextStyle(fontWeight: FontWeight.bold)),
                      selected: _level == l,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: _level == l ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _level = l),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.verified_user, size: 64, color: AppColors.present),
                        const SizedBox(height: 10),
                        Text(tr('ex_none'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(tr('ex_none_sub'), textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = shown[i];
                      final girl = r['gender'] == 'F';
                      final tint = girl ? const Color(0xFFD81B60) : AppColors.primary;
                      final reason = ((r['medical_reason'] as String?) ?? '').trim();
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final m = classes.where((c) => c.id == r['class_id']);
                          if (m.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ClassDetailScreen(schoolClass: m.first)));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('${r['last_name']} ${r['first_name']}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF90CAF9))),
                                        child: Text('${r['class_name']} (${r['class_level']})',
                                            style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('N° ${r['student_number'] ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ]),
                                  ]),
                                ),
                                const SizedBox(width: 10),
                                Stack(clipBehavior: Clip.none, children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: tint.withOpacity(0.12),
                                    child: Text(girl ? 'F' : 'M', style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 18)),
                                  ),
                                  const Positioned(bottom: -2, right: -2,
                                      child: CircleAvatar(radius: 9, backgroundColor: Color(0xFF0288D1),
                                          child: Icon(Icons.lock, size: 10, color: Colors.white))),
                                ]),
                              ]),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(color: const Color(0xFFE1F5FE), borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFB3E5FC))),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFF0277BD), borderRadius: BorderRadius.circular(4)),
                                    child: Text(tr('ex_status'), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                  const Spacer(),
                                  Text(reason.isEmpty ? "Dispensé(e) d'EPS" : reason,
                                      style: const TextStyle(color: Color(0xFF0277BD), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.medical_information_outlined, size: 16, color: Color(0xFF0277BD)),
                                ]),
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
