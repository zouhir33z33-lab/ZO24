import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/academic_providers.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../services/stats_repository.dart';
import '../themes/app_colors.dart';
import '../utils/day_utils.dart';
import '../utils/status_utils.dart';
import 'incident_form_screen.dart';

typedef _Key = ({int classId, int? termId});

final _classStatsProvider = FutureProvider.autoDispose.family<ClassStats, _Key>((ref, k) {
  return ref.read(statsRepositoryProvider).classStats(k.classId, k.termId);
});

/// « إحصائيات القسم » : indicateurs, répartition des statuts, séances, suivi des élèves.
class ClassStatsScreen extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  const ClassStatsScreen({super.key, required this.schoolClass});
  @override
  ConsumerState<ClassStatsScreen> createState() => _ClassStatsScreenState();
}

class _ClassStatsScreenState extends ConsumerState<ClassStatsScreen> {
  int? _termId; // null avec _all = true : toute l'année
  bool _all = false;

  String _fmtDate(String ymdStr, String lang) {
    final d = parseYmd(ymdStr);
    const months = ['Jan.', 'Fév.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];
    final days = ['Dim.', 'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.'];
    return '${days[d.weekday % 7]} ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.schoolClass;
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final terms = ref.watch(termsProvider).valueOrNull ?? const <Term>[];
    final current = terms.where((t) => t.isCurrent).firstOrNull ?? (terms.isNotEmpty ? terms.first : null);
    final termId = _all ? null : (_termId ?? current?.id);
    final async = ref.watch(_classStatsProvider((classId: c.id!, termId: termId)));

    return Scaffold(
      appBar: AppBar(
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('cs_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${c.name} • ${c.level}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(_classStatsProvider))],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final t in terms)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text('${t.name}${t.isCurrent ? ' ${tr('cs_active')}' : ''}', style: const TextStyle(fontSize: 12)),
                      selected: !_all && termId == t.id,
                      onSelected: (_) => setState(() { _all = false; _termId = t.id; }),
                    ),
                  ),
                ChoiceChip(
                  label: Text(tr('cs_all_year'), style: const TextStyle(fontSize: 12)),
                  selected: _all,
                  onSelected: (_) => setState(() => _all = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (s) => ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                children: [
                  Row(children: [
                    Expanded(child: _Kpi(color: const Color(0xFFE3F2FD), icon: Icons.groups, iconColor: const Color(0xFF5E35B1),
                        value: '${s.students}', label: tr('cs_students'), sub: 'G : ${s.males} / F : ${s.females}')),
                    const SizedBox(width: 8),
                    Expanded(child: _Kpi(color: const Color(0xFFE8EAF6), icon: Icons.flag, iconColor: AppColors.primary,
                        value: '${s.sessions}', label: tr('cs_sessions'), sub: '${s.marks} ${tr('cs_marks')}')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _Kpi(color: const Color(0xFFE8F5E9), icon: Icons.check_circle_outline, iconColor: AppColors.present,
                        value: s.presencePct == null ? 'N/A' : '${s.presencePct!.toStringAsFixed(1)}%',
                        valueColor: AppColors.absent, label: tr('cs_presence'),
                        sub: 'présences : ${s.presentLike} • abs ${s.absences}')),
                    const SizedBox(width: 8),
                    Expanded(child: _Kpi(color: const Color(0xFFFFF3E0), icon: Icons.school, iconColor: AppColors.orange,
                        value: s.average == null ? 'N/A' : s.average!.toStringAsFixed(2),
                        valueColor: AppColors.orange, label: tr('cs_avg'), sub: 'évaluation(s) ${s.evaluations}')),
                  ]),
                  const SizedBox(height: 12),
                  _Card(
                    title: tr('cs_dist'),
                    icon: Icons.pie_chart_outline,
                    child: _Distribution(items: s.distribution, total: s.marks, lang: lang),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: '${tr('cs_sessions_detail')} (${s.sessions})',
                    subtitle: tr('cs_sessions_sub'),
                    icon: Icons.event_note,
                    child: s.sessionLines.isEmpty
                        ? Padding(padding: const EdgeInsets.all(8), child: Text(tr('cs_no_sessions'), style: TextStyle(color: Colors.grey.shade600)))
                        : Column(children: [
                            for (final l in s.sessionLines)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                                      child: Text(_fmtDate(l.date, lang),
                                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                                    Text('${l.start} - ${l.end}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.absent.withOpacity(0.1),
                                          border: Border.all(color: AppColors.absent.withOpacity(0.4)),
                                          borderRadius: BorderRadius.circular(6)),
                                        child: Text('${l.pct.toStringAsFixed(0)}% ${tr('cs_present_word')}',
                                            style: const TextStyle(fontSize: 10.5, color: AppColors.absent, fontWeight: FontWeight.bold)),
                                      ),
                                      Text('${tr('cs_present_word')} : ${l.present} / ${l.total}',
                                          style: const TextStyle(fontSize: 10.5, color: AppColors.present)),
                                    ]),
                                  ],
                                ),
                              ),
                          ]),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: tr('cs_follow'),
                    subtitle: tr('cs_follow_sub'),
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.orange,
                    child: Column(children: [
                      for (final l in s.studentLines) ...[
                        InkWell(
                          onTap: () => _openStudent(context, l.student, termId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (l.absences > 0 ? AppColors.absent : AppColors.present).withOpacity(0.08),
                                  border: Border.all(color: (l.absences > 0 ? AppColors.absent : AppColors.present).withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(6)),
                                child: Text('${l.absences} .abs',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                        color: l.absences > 0 ? AppColors.absent : AppColors.present)),
                              ),
                              const Spacer(),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(l.student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Taux de présence : ${l.pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11.5)),
                              ]),
                              const SizedBox(width: 8),
                              _Avatar(student: l.student),
                            ]),
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black87),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openStudent(BuildContext context, Student s, int? termId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _StudentSheet(student: s, schoolClass: widget.schoolClass, termId: termId),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Student student;
  const _Avatar({required this.student});
  @override
  Widget build(BuildContext context) {
    final girl = student.gender == 'F';
    final tint = girl ? const Color(0xFFD81B60) : AppColors.primary;
    return CircleAvatar(
      radius: 15,
      backgroundColor: tint.withOpacity(0.12),
      child: Text(girl ? 'F' : 'M', style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _Kpi extends StatelessWidget {
  final Color color, iconColor;
  final Color? valueColor;
  final IconData icon;
  final String value, label, sub;
  const _Kpi({required this.color, required this.icon, required this.iconColor,
      required this.value, required this.label, required this.sub, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, border: Border.all(color: iconColor.withOpacity(0.25)), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: iconColor),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87)),
          ]),
          const SizedBox(height: 2),
          Align(alignment: AlignmentDirectional.centerEnd,
              child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
          Align(alignment: AlignmentDirectional.centerEnd,
              child: Text(sub, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600))),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  const _Card({required this.title, this.subtitle, required this.icon, this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
        ]),
        if (subtitle != null) Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _Distribution extends StatelessWidget {
  final List<StatusCount> items;
  final int total;
  final String lang;
  const _Distribution({required this.items, required this.total, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(alignment: AlignmentDirectional.centerStart,
            child: Text('total $total', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(children: [
              Row(children: [
                Text('(${total == 0 ? '0.0' : (i.n * 100 / total).toStringAsFixed(1)}%) ',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text('${i.n}', style: TextStyle(fontWeight: FontWeight.bold, color: hexColor(i.status.colorHex))),
                const Spacer(),
                Text(i.status.label(lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 6),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: hexColor(i.status.colorHex), shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : i.n / total,
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade200,
                  color: hexColor(i.status.colorHex),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

class _StudentSheet extends ConsumerStatefulWidget {
  final Student student;
  final SchoolClass schoolClass;
  final int? termId;
  const _StudentSheet({required this.student, required this.schoolClass, required this.termId});
  @override
  ConsumerState<_StudentSheet> createState() => _StudentSheetState();
}

class _StudentSheetState extends ConsumerState<_StudentSheet> {
  int _tab = 1; // 0 = notes, 1 = historique

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final s = widget.student;
    final year = ref.watch(activeYearProvider).valueOrNull;
    final async = FutureBuilder<StudentDetail>(
      future: ref.read(statsRepositoryProvider).studentDetail(s, widget.schoolClass.id!, widget.termId),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
        final d = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7F9FC), border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.present.withOpacity(0.1), border: Border.all(color: AppColors.present), borderRadius: BorderRadius.circular(4)),
                    child: Text(tr('cs_registered'), style: const TextStyle(fontSize: 10, color: AppColors.present)),
                  ),
                  const Spacer(),
                  Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 6),
                  const Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
                  _Chip('${tr('cs_class')} : ${widget.schoolClass.name} (${widget.schoolClass.level})', Icons.class_outlined),
                  if (year != null) _Chip('${tr('cs_year')} : ${year.name.split('/').reversed.join('-')}', Icons.calendar_today),
                  _Chip(s.gender == 'F' ? tr('girl_short') : tr('boy_short'), Icons.person_outline),
                  if ((s.studentNumber ?? '').isNotEmpty) _Chip('N° : ${s.studentNumber}', Icons.tag),
                ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => IncidentFormScreen(initialClass: widget.schoolClass, initialStudentId: s.id)));
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: Text(tr('cs_incident_btn')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.absent, side: const BorderSide(color: AppColors.absent),
                    minimumSize: const Size.fromHeight(42)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Kpi(color: const Color(0xFFFFEBEE), icon: Icons.check_circle_outline, iconColor: AppColors.absent,
                  value: d.line.marks == 0 ? 'N/A' : '${d.line.pct.toStringAsFixed(1)}%', valueColor: AppColors.absent,
                  label: tr('cs_presence'), sub: '')),
              const SizedBox(width: 8),
              Expanded(child: _Kpi(color: const Color(0xFFE3F2FD), icon: Icons.event_available, iconColor: AppColors.primary,
                  value: '${d.line.marks}', label: tr('cs_total_sessions'), sub: '')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Kpi(color: const Color(0xFFECEFF1), icon: Icons.cancel_outlined, iconColor: Colors.grey,
                  value: '${d.line.absences}', label: 'Absences', sub: '')),
              const SizedBox(width: 8),
              Expanded(child: _Kpi(color: const Color(0xFFFFF8E1), icon: Icons.star_border, iconColor: AppColors.orange,
                  value: d.average == null ? 'N/A' : d.average!.toStringAsFixed(1), valueColor: AppColors.orange,
                  label: tr('cs_grade_avg'), sub: '')),
            ]),
            const SizedBox(height: 10),
            _Card(
              title: tr('cs_dist_student'),
              icon: Icons.pie_chart_outline,
              child: _Distribution(items: d.distribution, total: d.line.marks, lang: lang),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _TabBtn(label: '${tr('cs_tab_history')} (${d.history.length})', selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
              Expanded(child: _TabBtn(label: '${tr('cs_tab_grades')} (${d.grades.length})', selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
            ]),
            if (_tab == 1)
              (d.history.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(tr('cs_no_history'))))
                  : Column(children: [
                      for (final h in d.history)
                        ListTile(
                          dense: true,
                          title: Text('${_dateFr(h.date)} • ${h.start} - ${h.end}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          subtitle: (h.observation ?? '').isEmpty ? null : Text(h.observation!),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: hexColor(h.status.colorHex).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text(h.status.label(lang), style: TextStyle(fontSize: 11, color: hexColor(h.status.colorHex), fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ]))
            else
              (d.grades.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(tr('cs_no_grades'))))
                  : Column(children: [
                      for (final g in d.grades)
                        ListTile(
                          dense: true,
                          title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(g.date),
                          trailing: Text(g.score == null ? '--' : '${g.score!.toStringAsFixed(1)} / ${g.max.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                    ])),
          ],
        );
      },
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 10),
          Row(children: [
            InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(s.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${widget.schoolClass.name} • ${s.studentNumber == null ? '' : 'N° ${s.studentNumber}'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ]),
            const SizedBox(width: 10),
            _Avatar(student: s),
          ]),
          const Divider(height: 22),
          async,
        ],
      ),
    );
  }

  static String _dateFr(String y) {
    final d = parseYmd(y);
    const months = ['Jan.', 'Fév.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];
    const days = ['Dim.', 'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.'];
    return '${days[d.weekday % 7]} ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Chip(this.text, this.icon);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Icon(icon, size: 13, color: Colors.grey.shade600),
        ]),
      );
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.grey.shade300, width: 2))),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? AppColors.primary : Colors.grey)),
        ),
      );
}
