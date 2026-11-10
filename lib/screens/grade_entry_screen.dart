import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/students_provider.dart';
import '../themes/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';

/// Saisie des notes d'une évaluation (statut + note + remarque par élève).
class GradeEntryScreen extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  final Evaluation evaluation;
  final bool locked;
  const GradeEntryScreen({
    super.key,
    required this.schoolClass,
    required this.evaluation,
    this.locked = false,
  });

  @override
  ConsumerState<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends ConsumerState<GradeEntryScreen> {
  bool _loading = true;
  double _step = 0.5; // pas du bouton « 0.5+ » (bascule 0.5 / 1)
  List<Student> _students = [];
  final Map<int, double?> _score = {};
  final Map<int, String> _status = {}; // PRESENT | ABSENT | EXEMPT
  final Map<int, String> _remark = {};

  // Libellés FR codés en dur comme dans l'original (« Présent » visible en UI arabe).
  static const _statusLabels = {
    'PRESENT': 'Présent',
    'ABSENT': 'Absent',
    'EXEMPT': 'Dispensé',
  };

  double get _max => widget.evaluation.maxScore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final students = await ref.read(studentsProvider(widget.schoolClass.id!).future);
    final grades = await ref.read(evaluationRepositoryProvider).gradesOf(widget.evaluation.id!);
    for (final s in students) {
      final g = grades[s.id];
      _score[s.id!] = g?.score;
      _status[s.id!] = g?.statusCode ?? (s.isExempt ? 'EXEMPT' : 'PRESENT');
      if ((g?.remarks ?? '').isNotEmpty) _remark[s.id!] = g!.remarks!;
    }
    _students = students;
    if (mounted) setState(() => _loading = false);
  }

  double _clamp(double v) => v < 0 ? 0 : (v > _max ? _max : v);

  void _bump(int id, double delta) {
    setState(() {
      final cur = _score[id];
      _score[id] = _clamp((cur ?? (delta > 0 ? 0 : _max)) + delta);
    });
  }

  Future<void> _typeScore(Student s) async {
    final ctrl = TextEditingController(text: _score[s.id!]?.toString() ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.fullName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: '/ ${_max.toStringAsFixed(0)}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ref.read(trProvider)('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    if (res != null) {
      final v = double.tryParse(res.replaceAll(',', '.'));
      setState(() => _score[s.id!] = res.trim().isEmpty ? null : (v == null ? _score[s.id!] : _clamp(v)));
    }
  }

  Future<void> _save() async {
    if (widget.locked) return;
    final tr = ref.read(trProvider);
    final grades = [
      for (final s in _students)
        StudentGrade(
          evaluationId: widget.evaluation.id!,
          studentId: s.id!,
          termId: widget.evaluation.termId,
          score: _status[s.id!] == 'PRESENT' ? _score[s.id!] : null,
          isExempt: _status[s.id!] == 'EXEMPT',
          statusCode: _status[s.id!] ?? 'PRESENT',
          remarks: (_remark[s.id!] ?? '').trim().isEmpty ? null : _remark[s.id!]!.trim(),
        ),
    ];
    final nav = Navigator.of(context);
    final ctx = context;
    await ref.read(evaluationRepositoryProvider)
        .saveGrades(widget.evaluation.id!, widget.evaluation.termId, grades);
    nav.pop();
    if (ctx.mounted) showSuccessSnack(ctx, tr('ev_saved_grades'));
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final e = widget.evaluation;
    final scored = _students
        .where((s) => _status[s.id!] == 'PRESENT' && _score[s.id!] != null)
        .toList();
    final avg = scored.isEmpty
        ? null
        : scored.map((s) => _score[s.id!]!).reduce((a, b) => a + b) / scored.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 11, color: Colors.white70),
                const SizedBox(width: 4),
                Text(e.evaluationDate, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.schoolClass.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!widget.locked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 16),
                label: Text(tr('ev_valid')),
                style: FilledButton.styleFrom(backgroundColor: Colors.white24),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.bar_chart, size: 18, color: AppColors.orange),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${tr('ev_average')} :',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          Text(
                              avg == null
                                  ? 'N/A / ${_max.toStringAsFixed(0)}'
                                  : '${avg.toStringAsFixed(2)} / ${_max.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      Text('${scored.length} / ${_students.length} ${tr('ev_graded')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    itemCount: _students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _row(_students[i], tr),
                  ),
                ),
                if (!widget.locked)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: Text(tr('ev_save_grades')),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(54),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _row(Student s, String Function(String) tr) {
    final id = s.id!;
    final status = _status[id] ?? 'PRESENT';
    final present = status == 'PRESENT';
    final girl = s.gender == 'F';
    final tint = girl ? const Color(0xFFD81B60) : AppColors.primary;
    final score = _score[id];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PopupMenuButton<String>(
                enabled: !widget.locked,
                onSelected: (v) => setState(() {
                  _status[id] = v;
                  if (v != 'PRESENT') _score[id] = null;
                }),
                itemBuilder: (_) => [
                  for (final e in _statusLabels.entries)
                    PopupMenuItem(value: e.key, child: Text(e.value)),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (present ? AppColors.present : AppColors.absent).withOpacity(0.1),
                    border: Border.all(color: (present ? AppColors.present : AppColors.absent).withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                      Text(_statusLabels[status] ?? status,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold,
                              color: present ? AppColors.present : AppColors.absent)),
                      const SizedBox(width: 4),
                      Icon(Icons.circle, size: 7, color: present ? AppColors.present : AppColors.absent),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if ((s.studentNumber ?? '').isNotEmpty)
                    Text('N° ${s.studentNumber}',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: tint.withOpacity(0.12),
                child: Text(girl ? 'F' : 'G',
                    style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: present ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !present || widget.locked,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _score[id] = null),
                    child: Icon(Icons.backspace_outlined, size: 20, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() => _step = _step == 0.5 ? 1.0 : 0.5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_step == 1.0 ? '1' : '0.5'}+',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                    child: Text('/ ${_max.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: AppColors.primary),
                          onPressed: () => _bump(id, _step),
                        ),
                        InkWell(
                          onTap: () => _typeScore(s),
                          child: SizedBox(
                            width: 48,
                            child: Text(
                              score == null ? '--' : (score % 1 == 0 ? score.toStringAsFixed(0) : score.toString()),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove, color: AppColors.primary),
                          onPressed: () => _bump(id, -_step),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('remark_$id'),
            initialValue: _remark[id] ?? '',
            enabled: !widget.locked,
            onChanged: (v) => _remark[id] = v,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              hintText: tr('ev_note_hint'),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF4F7FB),
              suffixIcon: const Icon(Icons.edit_note, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
