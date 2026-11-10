import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/evaluation_providers.dart';
import '../providers/repository_providers.dart';
import '../themes/app_colors.dart';
import '../utils/day_utils.dart';
import 'app_bottom_sheet.dart';

const List<String> kActivitySuggestions = [
  'سباق السرعة', 'القفز الطويل', 'رمي الجلة', 'سباق نصف الطويل',
  'كرة السلة', 'الكرة الطائرة', 'كرة اليد',
];

Future<void> showEvaluationFormSheet(
  BuildContext context,
  WidgetRef ref, {
  required SchoolClass schoolClass,
  required int termId,
  Evaluation? existing,
}) {
  final tr = ref.read(trProvider);
  return showAppSheet(
    context,
    icon: Icons.flag,
    title: tr(existing == null ? 'ev_form_title' : 'ev_edit_title'),
    subtitle: schoolClass.level,
    builder: (_) => _EvalForm(schoolClass: schoolClass, termId: termId, existing: existing),
  );
}

class _EvalForm extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  final int termId;
  final Evaluation? existing;
  const _EvalForm({required this.schoolClass, required this.termId, this.existing});
  @override
  ConsumerState<_EvalForm> createState() => _EvalFormState();
}

class _EvalFormState extends ConsumerState<_EvalForm> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late DateTime _date = widget.existing == null
      ? DateTime.now()
      : parseYmd(widget.existing!.evaluationDate);
  late final _coef = TextEditingController(
      text: (widget.existing?.coefficient ?? 1.0).toString());
  late final _scale = TextEditingController(
      text: (widget.existing?.maxScore ?? 20).toStringAsFixed(0));
  bool _submitted = false;

  @override
  void dispose() {
    _title.dispose();
    _coef.dispose();
    _scale.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1, 9, 1),
      lastDate: DateTime(DateTime.now().year + 1, 8, 31),
    );
    if (p != null) setState(() => _date = p);
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final coef = double.tryParse(_coef.text.replaceAll(',', '.')) ?? 1.0;
    final scale = double.tryParse(_scale.text.replaceAll(',', '.')) ?? 20.0;
    final tr = ref.read(trProvider);
    final repo = ref.read(evaluationRepositoryProvider);
    final nav = Navigator.of(context);
    final ctx = context;
    final e = Evaluation(
      id: widget.existing?.id,
      classId: widget.schoolClass.id!,
      termId: widget.termId,
      title: title,
      evaluationDate: ymd(_date),
      maxScore: scale <= 0 ? 20 : scale,
      coefficient: coef <= 0 ? 1 : coef,
    );
    if (widget.existing == null) {
      await repo.insert(e);
    } else {
      await repo.update(e);
    }
    ref.invalidate(evaluationRowsProvider);
    nav.pop();
    if (ctx.mounted) {
      showSuccessSnack(ctx, tr(widget.existing == null ? 'ev_created' : 'ev_updated'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(Icons.visibility_outlined, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(tr('ev_suggestions'), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final s in kActivitySuggestions)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    selected: _title.text == s,
                    onSelected: (_) => setState(() => _title.text = s),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: tr('ev_test_title'),
            suffixIcon: const Icon(Icons.flag_outlined),
            errorText: _submitted && _title.text.trim().isEmpty ? tr('required_field') : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.edit_calendar, size: 16),
                label: Text(tr('ev_edit_btn')),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tr('ev_date'), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(_fmt(_date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 10),
              const Icon(Icons.calendar_month, color: AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _coef,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: tr('ev_coef'),
                  prefixText: 'x ',
                  suffixIcon: const Icon(Icons.tune),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _scale,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: tr('ev_scale'),
                  prefixText: '/ ',
                  suffixIcon: const Icon(Icons.star_outline, color: AppColors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_task),
          label: Text(widget.existing == null ? tr('ev_create') : tr('save')),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}
