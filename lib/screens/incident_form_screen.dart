import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/incident_constants.dart';
import '../models/models.dart';
import '../providers/classes_provider.dart';
import '../providers/core_providers.dart';
import '../providers/incident_providers.dart';
import '../providers/students_provider.dart';
import '../providers/pdf_context.dart';
import '../services/pdf_export_service.dart';
import '../themes/app_colors.dart';
import '../utils/day_utils.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/export_sheet.dart';

/// « استمارة حادث تربية بدنية » : déclaration officielle d'un accident corporel.
class IncidentFormScreen extends ConsumerStatefulWidget {
  final IncidentReport? existing;
  final SchoolClass? initialClass;
  final int? initialStudentId;
  const IncidentFormScreen({super.key, this.existing, this.initialClass, this.initialStudentId});
  @override
  ConsumerState<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends ConsumerState<IncidentFormScreen> {
  int? _classId;
  int? _studentId;
  late DateTime _date;
  late TimeOfDay _time;
  final _location = TextEditingController();
  final _activity = TextEditingController();
  String? _injury;
  final _bodyPart = TextEditingController();
  final _circumstances = TextEditingController();
  final _firstAid = TextEditingController();
  String _evac = 'Infirmerie scolaire';
  bool _parent = false;
  final _witnesses = TextEditingController();
  final _notes = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _date = e == null ? now : parseYmd(e.incidentDate);
    final t = (e?.incidentTime ?? '').split(':');
    _time = t.length == 2
        ? TimeOfDay(hour: int.tryParse(t[0]) ?? now.hour, minute: int.tryParse(t[1]) ?? now.minute)
        : TimeOfDay.fromDateTime(now);
    _classId = e?.classId ?? widget.initialClass?.id;
    _studentId = e?.studentId ?? widget.initialStudentId;
    if (e != null) {
      _location.text = e.location;
      _activity.text = e.activity ?? '';
      _injury = e.injuryType;
      _bodyPart.text = e.injuryLocation ?? '';
      _circumstances.text = e.circumstances == kDefaultCircumstances ? '' : e.circumstances;
      _firstAid.text = e.firstAidGiven ?? '';
      _evac = e.evacuationType;
      _parent = e.parentContacted;
      _witnesses.text = e.witnessStudents ?? '';
      _notes.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_location, _activity, _bodyPart, _circumstances, _firstAid, _witnesses, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _timeStr =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  bool get _valid =>
      _classId != null && _studentId != null && _location.text.trim().isNotEmpty &&
      _injury != null;

  IncidentReport _build() => IncidentReport(
        id: widget.existing?.id,
        studentId: _studentId!,
        classId: _classId!,
        incidentDate: ymd(_date),
        incidentTime: _timeStr,
        location: _location.text.trim(),
        activity: _activity.text.trim().isEmpty ? null : _activity.text.trim(),
        injuryType: _injury!,
        injuryLocation: _bodyPart.text.trim().isEmpty ? null : _bodyPart.text.trim(),
        circumstances: _circumstances.text.trim().isEmpty ? kDefaultCircumstances : _circumstances.text.trim(),
        firstAidGiven: _firstAid.text.trim().isEmpty ? null : _firstAid.text.trim(),
        evacuationType: _evac,
        witnessStudents: _witnesses.text.trim().isEmpty ? null : _witnesses.text.trim(),
        parentContacted: _parent,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_valid) return;
    final tr = ref.read(trProvider);
    final repo = ref.read(incidentRepositoryProvider);
    final nav = Navigator.of(context);
    final ctx = context;
    if (widget.existing == null) {
      await repo.insert(_build());
    } else {
      await repo.update(_build());
    }
    ref.invalidate(incidentsProvider);
    nav.pop();
    if (ctx.mounted) showSuccessSnack(ctx, tr('inc_saved'));
  }

  Future<void> _preview() async {
    setState(() => _submitted = true);
    if (!_valid) return;
    final tr = ref.read(trProvider);
    final report = _build();
    final classes = ref.read(classesProvider).valueOrNull ?? const <SchoolClass>[];
    final cls = classes.firstWhere((c) => c.id == _classId);
    final students = ref.read(studentsProvider(_classId!)).valueOrNull ?? const <Student>[];
    final st = students.firstWhere((s) => s.id == _studentId);
    final pc = await loadPdfContext(ref);
    if (!mounted) return;
    await showExportSheet(
      context,
      title: '${tr('inc_export_title')} : ${st.fullName}',
      subtitle: tr('export_official_sub'),
      fileName: 'Accident_${st.lastName}_${ymd(_date)}.pdf',
      buildPdf: () => PdfExportService.incidentPdf(
        report: report, studentName: st.fullName, gender: st.gender ?? '',
        className: cls.name, level: cls.level, ctx: pc),
      labels: _exportLabels(tr),
    );
  }

  static Map<String, String> _exportLabels(String Function(String) tr) => {
        'preview': tr('ex_preview'), 'previewSub': tr('ex_preview_sub'),
        'folder': tr('ex_folder'), 'folderSub': tr('ex_folder_sub'),
        'phone': tr('ex_phone'), 'phoneSub': tr('ex_phone_sub'),
        'share': tr('ex_share'), 'shareSub': tr('ex_share_sub'),
        'sheet': tr('ex_sheet'), 'sheetSub': tr('ex_sheet_sub'),
        'saved': tr('ex_saved'),
      };

  InputDecoration _dec(String label, {IconData? icon, String? error}) => InputDecoration(
        labelText: label,
        suffixIcon: icon == null ? null : Icon(icon, size: 20),
        errorText: error,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final classes = ref.watch(classesProvider).valueOrNull ?? const <SchoolClass>[];
    final students = _classId == null
        ? const <Student>[]
        : (ref.watch(studentsProvider(_classId!)).valueOrNull ?? const <Student>[]);
    final req = tr('required_field');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('inc_form_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(tr('inc_form_sub'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFFFC107)), onPressed: _preview),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _Section(
            number: 1, title: tr('inc_s1'), icon: Icons.person, color: const Color(0xFF0277BD),
            child: Column(children: [
              DropdownButtonFormField<int>(
                value: _classId,
                isExpanded: true,
                decoration: _dec(tr('inc_class'), icon: Icons.school,
                    error: _submitted && _classId == null ? req : null),
                items: [for (final c in classes) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setState(() { _classId = v; _studentId = null; }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: students.any((s) => s.id == _studentId) ? _studentId : null,
                isExpanded: true,
                decoration: _dec(tr('inc_student'), icon: Icons.person_search,
                    error: _submitted && _studentId == null ? req : null),
                items: [for (final s in students) DropdownMenuItem(value: s.id, child: Text(s.fullName))],
                onChanged: (v) => setState(() => _studentId = v),
              ),
            ]),
          ),
          _Section(
            number: 2, title: tr('inc_s2'), icon: Icons.schedule, color: const Color(0xFF2E7D32),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context, initialDate: _date,
                        firstDate: DateTime(DateTime.now().year - 2), lastDate: DateTime.now().add(const Duration(days: 1)));
                      if (p != null) setState(() => _date = p);
                    },
                    child: InputDecorator(
                      decoration: _dec(tr('inc_date'), icon: Icons.calendar_today),
                      child: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _time);
                      if (t != null) setState(() => _time = t);
                    },
                    child: InputDecorator(
                      decoration: _dec(tr('inc_time'), icon: Icons.access_time),
                      child: Text(_timeStr),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                onChanged: (_) => setState(() {}),
                decoration: _dec(tr('inc_location'), icon: Icons.place_outlined,
                    error: _submitted && _location.text.trim().isEmpty ? req : null),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in kLocations)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(lang == 'ar' ? c.ar : c.fr, style: const TextStyle(fontSize: 11.5)),
                        selected: _location.text == c.code,
                        onSelected: (_) => setState(() => _location.text = c.code),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              TextField(controller: _activity, decoration: _dec(tr('inc_activity'), icon: Icons.sports)),
            ]),
          ),
          _Section(
            number: 3, title: tr('inc_s3'), icon: Icons.healing, color: AppColors.absent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('inc_nature'), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in kInjuryTypes)
                  ChoiceChip(
                    label: Text(c.label(lang), style: const TextStyle(fontSize: 12)),
                    selected: _injury == c.code,
                    selectedColor: const Color(0xFFFFCDD2),
                    onSelected: (_) => setState(() => _injury = c.code),
                  ),
              ]),
              if (_submitted && _injury == null)
                Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text(req, style: const TextStyle(color: AppColors.absent, fontSize: 12))),
              const SizedBox(height: 12),
              TextField(controller: _bodyPart, decoration: _dec(tr('inc_body'), icon: Icons.accessibility_new)),
              const SizedBox(height: 12),
              TextField(
                controller: _circumstances,
                minLines: 3, maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: _dec(tr('inc_circ')),
              ),
            ]),
          ),
          _Section(
            number: 4, title: tr('inc_s4'), icon: Icons.medical_services, color: const Color(0xFF2E7D32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _firstAid, minLines: 1, maxLines: 3,
                  decoration: _dec(tr('inc_first_aid'), icon: Icons.healing)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in kFirstAid)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 14, color: AppColors.present),
                    label: Text(lang == 'ar' ? c.ar : c.fr, style: const TextStyle(fontSize: 11.5)),
                    onPressed: () => setState(() {
                      final cur = _firstAid.text.trim();
                      _firstAid.text = cur.isEmpty ? c.code : '$cur, ${c.code}';
                    }),
                  ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _evac,
                isExpanded: true,
                decoration: _dec(tr('inc_evac'), icon: Icons.local_hospital),
                items: [
                  for (final c in kEvacuations)
                    DropdownMenuItem(value: c.code, child: Text(c.label(lang), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _evac = v ?? _evac),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  border: Border.all(color: const Color(0xFFFFCA28)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('inc_parent'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(tr('inc_parent_sub'), style: const TextStyle(fontSize: 11.5)),
                    ]),
                  ),
                  Switch(value: _parent, onChanged: (v) => setState(() => _parent = v)),
                ]),
              ),
            ]),
          ),
          _Section(
            number: 5, title: tr('inc_s5'), icon: Icons.groups, color: Colors.blueGrey,
            child: Column(children: [
              TextField(controller: _witnesses, decoration: _dec(tr('inc_witnesses'), icon: Icons.groups_2)),
              const SizedBox(height: 12),
              TextField(controller: _notes, minLines: 2, maxLines: 5,
                  decoration: _dec(tr('inc_notes'), icon: Icons.notes)),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _preview,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(tr('inc_preview')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.absent,
                  side: const BorderSide(color: AppColors.absent),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle, size: 18),
                label: Text(tr('inc_save')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.absent,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final int number;
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  const _Section({required this.number, required this.title, required this.icon,
      required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text('$number. $title',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color))),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}
