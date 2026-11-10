import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/academic_providers.dart';
import '../providers/core_providers.dart';
import '../providers/incident_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/stats_providers.dart';
import '../providers/students_provider.dart';
import '../providers/timetable_providers.dart';
import '../services/attendance_repository.dart';
import '../themes/app_colors.dart';
import '../utils/day_utils.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/session_date_picker.dart';
import 'field_attendance_screen.dart';
import 'session_history_screen.dart';

/// Écran d'appel (feuille de présence) d'une classe pour une date donnée.
class AttendanceScreen extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  final DateTime? initialDate;
  const AttendanceScreen({super.key, required this.schoolClass, this.initialDate});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late DateTime _date;
  bool _loading = true;
  bool _dirty = false;
  bool _savedOnce = false; // une séance existe déjà pour cette date
  bool _locked = false;
  String? _emergencyReason; // non null : séance annulée (« طارئ »)
  int _termId = 0;
  List<Student> _students = [];
  List<AttendanceStatus> _statuses = [];
  final Map<int, int> _statusOf = {}; // studentId -> statusId
  final Map<int, String> _obsOf = {};
  Set<int> _incidentIds = {}; // élèves ayant une déclaration d'accident (icône cloche)

  AttendanceStatus? _byCode(String code) {
    for (final s in _statuses) {
      if (s.code == code) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<TimetableSlot> get _mySlots =>
      (ref.read(slotsProvider).valueOrNull ?? const <TimetableSlot>[])
          .where((s) => s.classId == widget.schoolClass.id)
          .toList();

  TimetableSlot? get _slotForDate {
    final d = appDayOf(_date);
    for (final s in _mySlots) {
      if (s.dayOfWeek == d) return s;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final statuses = await ref.read(statusesProvider.future);
    final students = await ref.read(studentsProvider(widget.schoolClass.id!).future);
    final terms = await ref.read(termsProvider.future);
    final term = terms.where((t) => t.isCurrent).firstOrNull ??
        (terms.isNotEmpty ? terms.first : null);
    final repo = ref.read(attendanceRepositoryProvider);
    final session = await repo.findSession(widget.schoolClass.id!, ymd(_date));
    final saved = session == null ? <int, Attendance>{} : await repo.attendanceOf(session.id!);

    final incidents = await ref.read(incidentRepositoryProvider).all(classId: widget.schoolClass.id!);
    _incidentIds = {for (final i in incidents) i.report.studentId};
    _statuses = statuses;
    _students = students;
    _termId = term?.id ?? 0;
    _locked = term?.isLocked ?? false;
    _savedOnce = session != null;
    _emergencyReason = session?.status == 'CANCELLED' ? (session?.cancellationReason ?? '') : null;
    _statusOf.clear();
    _obsOf.clear();
    final present = _byCode('PRESENT');
    final exempt = _byCode('EXEMPT');
    for (final s in students) {
      final a = saved[s.id];
      if (a != null) {
        _statusOf[s.id!] = a.statusId;
        if ((a.observation ?? '').isNotEmpty) _obsOf[s.id!] = a.observation!;
      } else if (s.isExempt && exempt != null) {
        _statusOf[s.id!] = exempt.id!;
      } else if (present != null) {
        _statusOf[s.id!] = present.id!;
      }
    }
    _dirty = false;
    if (mounted) setState(() => _loading = false);
  }

  void _setStatus(int studentId, int statusId) {
    setState(() {
      _statusOf[studentId] = statusId;
      _dirty = true;
    });
  }

  void _bulk(String code) {
    final st = _byCode(code);
    if (st == null) return;
    setState(() {
      for (final s in _students) {
        _statusOf[s.id!] = st.id!;
      }
      _dirty = true;
    });
  }

  Future<void> _pickDate() async {
    final tr = ref.read(trProvider);
    final lang = ref.read(localeProvider).languageCode;
    final days = _mySlots.map((s) => s.dayOfWeek).toSet();
    final repo = ref.read(attendanceRepositoryProvider);
    final sessions = await repo.sessionDates(widget.schoolClass.id!);
    final evals = await repo.evaluationDates(widget.schoolClass.id!);
    if (!mounted) return;
    final picked = await showSessionDatePicker(
      context,
      initial: _date,
      allowedAppDays: days,
      sessionDates: sessions,
      evalDates: evals,
      planningText: (days.toList()..sort()).map((d) => dayName(lang, d)).join('، '),
      title: tr('att_pick_date'),
      planningLabel: tr('att_planning'),
      onlyDaysText: tr('dp_only_days'),
      evalLegend: tr('dp_eval_day'),
      sessionLegend: tr('dp_session'),
      okLabel: tr('att_validate'),
      cancelLabel: tr('cancel'),
    );
    if (picked != null && ymd(picked) != ymd(_date)) {
      _date = picked;
      await _load();
    }
  }

  Future<void> _editComment(Student s) async {
    final tr = ref.read(trProvider);
    final ctrl = TextEditingController(text: _obsOf[s.id!] ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.fullName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: tr('att_comment'), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(tr('save'))),
        ],
      ),
    );
    if (res != null) {
      setState(() {
        if (res.isEmpty) {
          _obsOf.remove(s.id!);
        } else {
          _obsOf[s.id!] = res;
        }
        _dirty = true;
      });
    }
  }

  Future<bool> _save() async {
    if (_locked || _students.isEmpty) return false;
    final slot = _slotForDate;
    final now = TimeOfDay.now();
    final nowStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await ref.read(attendanceRepositoryProvider).saveSession(
          classId: widget.schoolClass.id!,
          termId: _termId,
          date: ymd(_date),
          startTime: slot?.startTime ?? nowStr,
          endTime: slot?.endTime ?? nowStr,
          sheetId: slot?.defaultSheetId,
          cancelReason: _emergencyReason,
          entries: {
            for (final s in _students)
              if (_statusOf[s.id!] != null)
                s.id!: AttendanceEntry(_statusOf[s.id!]!, _obsOf[s.id!]),
          },
        );
    // Un élève marqué « معفى » devient dispensé (liste des élèves dispensés, carte bleue).
    final exempt = _byCode('EXEMPT');
    if (exempt != null) {
      final ids = [for (final s in _students) if (_statusOf[s.id!] == exempt.id) s.id!];
      if (ids.isNotEmpty) {
        await ref.read(studentRepositoryProvider).markExempt(ids);
        ref.invalidate(studentsProvider(widget.schoolClass.id!));
      }
    }
    ref.invalidate(todayDataProvider);
    ref.invalidate(lastMarksProvider);
    return true;
  }


  /// « بدء النداء الميداني » : mode plein écran sombre.
  Future<void> _openField() async {
    final lang = ref.read(localeProvider).languageCode;
    final slot = _slotForDate;
    final line = '${_dateLabel(lang)}${slot == null ? '' : ' • ${slot.startTime} - ${slot.endTime}'}';
    final res = await Navigator.push<FieldResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FieldAttendanceScreen(
          schoolClass: widget.schoolClass,
          dateLine: line,
          students: _students,
          statuses: _statuses,
          statusOf: _statusOf,
          obsOf: _obsOf,
          lang: lang,
        ),
      ),
    );
    if (res == null || !mounted) return;
    setState(() {
      _statusOf
        ..clear()
        ..addAll(res.statusOf);
      _obsOf
        ..clear()
        ..addAll(res.obsOf);
      if (res.emergencyReason != null) _emergencyReason = res.emergencyReason;
      _dirty = true;
    });
    if (res.save) await _saveAndClose();
  }

  /// Astérisque rouge : événement exceptionnel pour toute la classe (« طارئ »).
  Future<void> _emergencyAll() async {
    final tr = ref.read(trProvider);
    final em = _byCode('EMERGENCY');
    if (em == null) return;
    final ctrl = TextEditingController(text: _emergencyReason ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.event_busy, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('att_em_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(tr('att_em_sub'), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ]),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('att_em_msg')),
              const SizedBox(height: 10),
              TextField(controller: ctrl, decoration: InputDecoration(labelText: tr('att_em_reason'), hintText: tr('att_em_hint'), border: const OutlineInputBorder())),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in const ['att_em_c1', 'att_em_c2', 'att_em_c3', 'att_em_c4'])
                  ActionChip(label: Text(tr(k), style: const TextStyle(fontSize: 11)), onPressed: () => setD(() => ctrl.text = tr(k))),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF455A64)),
              child: Text(tr('att_em_all')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      for (final s in _students) {
        _statusOf[s.id!] = em.id!;
      }
      _emergencyReason = ctrl.text.trim();
      _dirty = true;
    });
  }

  /// Corbeille : supprime la séance de cette date.
  Future<void> _deleteSession() async {
    final tr = ref.read(trProvider);
    final lang = ref.read(localeProvider).languageCode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.absent),
        title: Text(tr('att_del_title')),
        content: Text('${tr('att_del_msg1')} (${_dateLabel(lang)}) ?\n\n${tr('att_del_msg2')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(attendanceRepositoryProvider).deleteSession(widget.schoolClass.id!, ymd(_date));
    ref.invalidate(todayDataProvider);
    ref.invalidate(lastMarksProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveAndClose() async {
    final tr = ref.read(trProvider);
    final nav = Navigator.of(context);
    final ctx = context;
    if (await _save()) {
      nav.pop();
      if (ctx.mounted) showSuccessSnack(ctx, tr('att_saved'));
    }
  }

  Future<void> _onBack() async {
    if (_locked || (_savedOnce && !_dirty)) {
      Navigator.of(context).pop();
      return;
    }
    final tr = ref.read(trProvider);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.help_outline, color: AppColors.primary),
        title: Text(tr('att_save_q')),
        content: Text(tr('att_exit_msg')),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'exit'),
            child: Text(tr('att_exit_nosave'), style: const TextStyle(color: AppColors.absent)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'exit') {
      Navigator.of(context).pop();
    } else if (choice == 'save') {
      await _saveAndClose();
    }
  }

  String _dateLabel(String lang) {
    final day = dayName(lang, appDayOf(_date));
    final month = lang == 'ar' ? kMonthsAr[_date.month - 1] : '${_date.month}';
    final isToday = ymd(_date) == ymd(DateTime.now());
    final core = lang == 'ar' ? '$day ${_date.day} $month' : '$day ${_date.day}/${_date.month}';
    return isToday ? '${ref.read(trProvider)('att_today')}، $core' : core;
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final present = _byCode('PRESENT');
    final absent = _byCode('ABSENT');
    var nPresent = 0, nAbsent = 0;
    for (final s in _students) {
      final id = _statusOf[s.id!];
      if (id == present?.id) nPresent++;
      if (id == absent?.id) nAbsent++;
    }
    final nOther = _students.length - nPresent - nAbsent;
    final slot = _slotForDate;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _onBack),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.schoolClass.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('${widget.schoolClass.name} • ${slot?.startTime ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SessionHistoryScreen(schoolClass: widget.schoolClass))),
            ),
            // Astérisque rouge = événement exceptionnel (« طارئ ») pour toute la classe ;
            // soleil = mode terrain ; corbeille = supprimer la séance. (Rôles déduits de la vidéo.)
            IconButton(
              icon: const Icon(Icons.emergency, color: Color(0xFFFF5252)),
              onPressed: _locked ? null : _emergencyAll,
            ),
            IconButton(
              icon: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFFFC107)),
              onPressed: _openField,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: (_locked || !_savedOnce) ? null : _deleteSession,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)]),
                        border: Border.all(color: const Color(0xFFFFCA28)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                                color: AppColors.orange, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.calendar_month, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_dateLabel(lang),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF5D4037))),
                                Text(tr('att_change_date'),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_mySlots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      child: Text(tr('att_not_scheduled'),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Counter(label: tr('att_present'), value: nPresent, color: AppColors.present),
                        _Counter(label: tr('att_absent'), value: nAbsent, color: AppColors.absent),
                        _Counter(label: tr('att_other'), value: nOther, color: const Color(0xFF6A1B9A)),
                        _Counter(label: tr('att_total'), value: _students.length, color: Colors.black87),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _students.isEmpty
                        ? Center(child: Text(tr('att_no_students')))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            itemCount: _students.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _StudentRow(
                              index: i + 1,
                              student: _students[i],
                              statuses: _statuses,
                              lang: lang,
                              statusId: _statusOf[_students[i].id!],
                              hasNote: (_obsOf[_students[i].id!] ?? '').isNotEmpty,
                              hasIncident: _incidentIds.contains(_students[i].id),
                              locked: _locked,
                              onStatus: (id) => _setStatus(_students[i].id!, id),
                              onComment: () => _editComment(_students[i]),
                              presentId: present?.id,
                              absentId: absent?.id,
                              presentLabel: tr('att_present'),
                              absentLabel: tr('att_absent'),
                              otherLabel: tr('att_other'),
                            ),
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: FilledButton.icon(
                        onPressed: _locked || _students.isEmpty ? null : _saveAndClose,
                        icon: Icon(_locked ? Icons.lock : Icons.save_outlined),
                        label: Text(_locked ? tr('att_locked') : tr('att_save_close')),
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
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Counter({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
        Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  final int index;
  final Student student;
  final List<AttendanceStatus> statuses;
  final String lang;
  final int? statusId;
  final bool hasNote, locked, hasIncident;
  final ValueChanged<int> onStatus;
  final VoidCallback onComment;
  final int? presentId, absentId;
  final String presentLabel, absentLabel, otherLabel;
  const _StudentRow({
    required this.index,
    required this.student,
    required this.statuses,
    required this.lang,
    required this.statusId,
    required this.hasNote,
    required this.hasIncident,
    required this.locked,
    required this.onStatus,
    required this.onComment,
    required this.presentId,
    required this.absentId,
    required this.presentLabel,
    required this.absentLabel,
    required this.otherLabel,
  });

  static const _grey = Color(0xFFE6E6E6);

  @override
  Widget build(BuildContext context) {
    final others = statuses.where((s) => s.id != presentId && s.id != absentId).toList();
    AttendanceStatus? current;
    for (final s in others) {
      if (s.id == statusId) current = s;
    }
    final isPresent = statusId == presentId;
    final isAbsent = statusId == absentId;
    final curColor = current == null ? null : _hex(current.colorHex);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: (curColor ?? AppColors.present).withOpacity(0.15),
                child: Text('$index',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: curColor ?? AppColors.present)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(children: [
                  Flexible(
                    child: Text(student.fullName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  if (student.hasPai) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.health_and_safety, size: 17, color: AppColors.absent),
                  ],
                ]),
              ),
              if (hasIncident) ...[
                const Icon(Icons.notifications_active, size: 18, color: AppColors.absent),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: onComment,
                child: Icon(hasNote ? Icons.comment : Icons.comment_outlined,
                    size: 22, color: hasNote ? AppColors.primary : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _StatusButton(
                  label: presentLabel,
                  selected: isPresent,
                  color: AppColors.present,
                  onTap: locked || presentId == null ? null : () => onStatus(presentId!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _StatusButton(
                  label: absentLabel,
                  selected: isAbsent,
                  color: AppColors.absent,
                  onTap: locked || absentId == null ? null : () => onStatus(absentId!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: PopupMenuButton<int>(
                  enabled: !locked,
                  onSelected: onStatus,
                  itemBuilder: (_) => [
                    for (final s in others)
                      PopupMenuItem(
                        value: s.id!,
                        child: Row(children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(color: _hex(s.colorHex), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Text(s.label(lang)),
                        ]),
                      ),
                  ],
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: current == null ? _grey : curColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_drop_down, size: 18),
                        Flexible(
                          child: Text(
                            current == null ? otherLabel : current.label(lang),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: current == null ? Colors.black87 : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;
  const _StatusButton({required this.label, required this.selected, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFE6E6E6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.black87,
            )),
      ),
    );
  }
}
