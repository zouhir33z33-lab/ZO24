import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/academic_providers.dart';
import '../providers/core_providers.dart';
import '../providers/stats_providers.dart';
import '../providers/students_provider.dart';
import '../themes/app_colors.dart';
import '../utils/status_utils.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/student_form_sheet.dart';
import 'attendance_screen.dart';
import 'class_stats_screen.dart';
import 'evaluations_screen.dart';
import 'term_closing_screen.dart';

/// Détail d'une classe : trimestres, actions, recherche, tri, liste des élèves (CRUD).
class ClassDetailScreen extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  const ClassDetailScreen({super.key, required this.schoolClass});
  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  final _search = TextEditingController();
  bool _onlyExempt = false;
  SortMode _sort = SortMode.lastAsc; // tri par défaut observé dans la vidéo

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Student s) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_student_q')),
        content: Text(tr('delete_student_msg')),
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
      await ref.read(studentsProvider(widget.schoolClass.id!).notifier).remove(s.id!);
      if (mounted) showSuccessSnack(context, tr('student_deleted'));
    }
  }

  List<Student> _sorted(List<Student> list) {
    int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
    final l = [...list];
    switch (_sort) {
      case SortMode.original:
        l.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      case SortMode.lastAsc:
        l.sort((a, b) => cmp(a.lastName, b.lastName));
      case SortMode.lastDesc:
        l.sort((a, b) => cmp(b.lastName, a.lastName));
      case SortMode.firstAsc:
        l.sort((a, b) => cmp(a.firstName, b.firstName));
      case SortMode.firstDesc:
        l.sort((a, b) => cmp(b.firstName, a.firstName));
      case SortMode.femaleFirst:
        l.sort((a, b) {
          final g = (a.gender == 'F' ? 0 : 1) - (b.gender == 'F' ? 0 : 1);
          return g != 0 ? g : cmp(a.lastName, b.lastName);
        });
      case SortMode.maleFirst:
        l.sort((a, b) {
          final g = (a.gender == 'M' ? 0 : 1) - (b.gender == 'M' ? 0 : 1);
          return g != 0 ? g : cmp(a.lastName, b.lastName);
        });
      case SortMode.numberAsc:
        l.sort((a, b) => cmp(a.studentNumber ?? '', b.studentNumber ?? ''));
      case SortMode.numberDesc:
        l.sort((a, b) => cmp(b.studentNumber ?? '', a.studentNumber ?? ''));
    }
    return l;
  }

  Map<SortMode, (String, String)> _labels(String Function(String) tr) => {
        SortMode.original: (tr('so_default'), tr('so_default_sub')),
        SortMode.lastAsc: (tr('so_last_asc'), tr('so_alpha_sub')),
        SortMode.lastDesc: (tr('so_last_desc'), tr('so_alpha_rev')),
        SortMode.firstAsc: (tr('so_first_asc'), tr('so_first_sub')),
        SortMode.firstDesc: (tr('so_first_desc'), tr('so_first_rev')),
        SortMode.femaleFirst: (tr('so_female'), tr('so_female_sub')),
        SortMode.maleFirst: (tr('so_male'), tr('so_male_sub')),
        SortMode.numberAsc: (tr('so_num_asc'), tr('so_num_asc_sub')),
        SortMode.numberDesc: (tr('so_num_desc'), tr('so_num_desc_sub')),
      };

  @override
  Widget build(BuildContext context) {
    final c = widget.schoolClass;
    final tr = ref.watch(trProvider);
    final studentsAsync = ref.watch(studentsProvider(c.id!));
    final last = ref.watch(lastMarksProvider(c.id!)).valueOrNull ?? const <int, ({String date, String colorHex})>{};
    final all = studentsAsync.valueOrNull ?? const <Student>[];
    final exemptCount = all.where((s) => s.isExempt).length;
    final q = _search.text.trim().toLowerCase();
    final shown = _sorted(all.where((s) {
      if (_onlyExempt && !s.isExempt) return false;
      if (q.isEmpty) return true;
      return s.fullName.toLowerCase().contains(q) || (s.studentNumber ?? '').toLowerCase().contains(q);
    }).toList());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${c.level} • ${tr('student_manage')}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStudentFormSheet(context, ref, schoolClass: c),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('add_student')),
      ),
      body: Column(
        children: [
          _TermRow(schoolClass: c),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(schoolClass: c)))
                      .then((_) => ref.invalidate(lastMarksProvider)),
                  icon: const Icon(Icons.how_to_reg, size: 18),
                  label: Text(tr('btn_attendance')),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), minimumSize: const Size.fromHeight(46)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EvaluationsScreen(schoolClass: c))),
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: Text(tr('btn_grades')),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(46)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClassStatsScreen(schoolClass: c))),
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: Text(tr('btn_stats'), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary, backgroundColor: const Color(0xFFE3EEFB),
                    side: BorderSide(color: Colors.blue.shade200), minimumSize: const Size.fromHeight(46)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final m = await showSortSheet(context, current: _sort, title: tr('so_title'), labels: _labels(tr));
                  if (m != null) setState(() => _sort = m);
                },
                icon: const Icon(Icons.sort, size: 18),
                label: Text(tr('sort')),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: Colors.black87),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr('search_student'),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              ChoiceChip(
                label: Text('${tr('filter_all')} (${all.length})'),
                selected: !_onlyExempt,
                onSelected: (_) => setState(() => _onlyExempt = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const Icon(Icons.medical_services_outlined, size: 14),
                label: Text('${tr('filter_exempt')} ($exemptCount)'),
                selected: _onlyExempt,
                onSelected: (_) => setState(() => _onlyExempt = true),
              ),
            ]),
          ),
          Expanded(
            child: studentsAsync.isLoading && all.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.person_off_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(tr('no_students'), style: TextStyle(color: Colors.grey.shade600)),
                        ]),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = shown[i];
                          final girl = s.gender == 'F';
                          final tint = girl ? const Color(0xFFD81B60) : AppColors.primary;
                          final ls = last[s.id];
                          final reason = (s.medicalReason ?? '').trim();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: s.isExempt ? const Color(0xFFE8F4FD) : Colors.white,
                              border: s.isExempt ? Border.all(color: const Color(0xFF0288D1), width: 1.5) : null,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Column(mainAxisSize: MainAxisSize.min, children: [
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    InkWell(onTap: () => _confirmDelete(s),
                                        child: const Icon(Icons.delete_outline, size: 22, color: AppColors.absent)),
                                    const SizedBox(width: 14),
                                    InkWell(
                                      onTap: () => showStudentFormSheet(context, ref, schoolClass: c, existing: s),
                                      child: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                                    ),
                                  ]),
                                ]),
                                const Spacer(),
                                Flexible(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (s.hasPai) const Padding(
                                          padding: EdgeInsets.only(left: 6),
                                          child: Icon(Icons.health_and_safety, size: 16, color: AppColors.absent)),
                                        Flexible(
                                          child: Text(s.fullName, overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                        ),
                                      ]),
                                      if (s.isExempt)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Flexible(
                                              child: Text(reason.isEmpty ? "Dispensé(e) d'EPS" : reason,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic,
                                                      fontWeight: FontWeight.bold, color: Color(0xFF0277BD))),
                                            ),
                                            const Text(' : ', style: TextStyle(fontSize: 11, color: Color(0xFF0277BD))),
                                            Text(tr('ex_status'), style: const TextStyle(fontSize: 11, color: Color(0xFF0277BD))),
                                            const Icon(Icons.medical_services, size: 12, color: Color(0xFF0277BD)),
                                          ]),
                                        ),
                                      if (ls != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Text('${ls.date.substring(8)}/${ls.date.substring(5, 7)}',
                                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                                            const SizedBox(width: 4),
                                            Container(width: 9, height: 9, decoration: BoxDecoration(color: hexColor(ls.colorHex), shape: BoxShape.circle)),
                                          ]),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Stack(clipBehavior: Clip.none, children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: tint.withOpacity(0.12),
                                    child: Text(girl ? 'F' : 'M', style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  if (s.isExempt)
                                    const Positioned(bottom: -2, right: -2,
                                        child: CircleAvatar(radius: 8, backgroundColor: Color(0xFF0288D1),
                                            child: Icon(Icons.lock, size: 9, color: Colors.white))),
                                ]),
                              ],
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

/// Puces de trimestre + bouton « إغلاق » (clôture). Reflète l'écran d'origine.
class _TermRow extends ConsumerWidget {
  final SchoolClass schoolClass;
  const _TermRow({required this.schoolClass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final terms = ref.watch(termsProvider).valueOrNull ?? const <Term>[];
    final selected = ref.watch(selectedTermIdProvider) ??
        terms.where((t) => t.isCurrent).map((t) => t.id).firstOrNull;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final t in terms)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                avatar: Icon(t.isLocked ? Icons.lock : (t.isCurrent ? Icons.star : Icons.lock_outline), size: 14,
                    color: t.isCurrent ? Colors.amber : Colors.orange.shade700),
                label: Text(t.name.split(' (').first, style: const TextStyle(fontSize: 12)),
                selected: selected == t.id,
                onSelected: (_) => ref.read(selectedTermIdProvider.notifier).state = t.id,
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => TermClosingScreen(initialClass: schoolClass))),
            icon: const Icon(Icons.lock_open, size: 14),
            label: Text(tr('tc_close_short'), style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.orange, side: const BorderSide(color: AppColors.orange),
              backgroundColor: const Color(0xFFFFF3E0), minimumSize: const Size(0, 36)),
          ),
        ],
      ),
    );
  }
}
