import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/levels.dart';
import '../constants/periods.dart';
import '../models/models.dart';
import '../providers/academic_providers.dart';
import '../providers/classes_provider.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/timetable_providers.dart';
import '../themes/app_colors.dart';
import '../utils/day_utils.dart';
import '../widgets/app_bottom_sheet.dart';

/// « تعيين حصة » : affecte une classe à un jour + période (1 séance/semaine max par classe).
class AssignSlotScreen extends ConsumerStatefulWidget {
  final int dayOfWeek;
  final Period period;
  final TimetableSlot? existing; // modification d'une affectation
  const AssignSlotScreen({super.key, required this.dayOfWeek, required this.period, this.existing});

  @override
  ConsumerState<AssignSlotScreen> createState() => _AssignSlotScreenState();
}

class _AssignSlotScreenState extends ConsumerState<AssignSlotScreen> {
  int? _classId;
  int? _sheetId;
  late final TextEditingController _field =
      TextEditingController(text: widget.existing?.fieldName ?? kFacilities.first);

  @override
  void initState() {
    super.initState();
    _classId = widget.existing?.classId;
    _sheetId = widget.existing?.defaultSheetId;
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tr = ref.read(trProvider);
    final year = await ref.read(activeYearProvider.future);
    if (year == null || _classId == null) return;
    final repo = ref.read(timetableRepositoryProvider);
    final slot = TimetableSlot(
      id: widget.existing?.id,
      academicYearId: year.id!,
      classId: _classId!,
      dayOfWeek: widget.dayOfWeek,
      startTime: widget.period.start,
      endTime: widget.period.end,
      defaultSheetId: _sheetId,
      fieldName: _field.text.trim().isEmpty ? null : _field.text.trim(),
    );
    if (widget.existing == null) {
      await repo.insertSlot(slot);
    } else {
      await repo.updateSlot(slot);
    }
    ref.invalidate(slotsProvider);
    ref.invalidate(todayDataProvider);
    if (!mounted) return;
    final ctx = context;
    Navigator.pop(ctx);
    showSuccessSnack(ctx, tr('slot_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final classes = ref.watch(classesProvider).valueOrNull ?? const <SchoolClass>[];
    final slots = ref.watch(slotsProvider).valueOrNull ?? const <TimetableSlot>[];
    final sheets = ref.watch(sheetsProvider).valueOrNull ?? const <PedagogicalSheet>[];
    final p = widget.period;

    // Classe → créneau existant (hors celui qu'on modifie)
    TimetableSlot? scheduledOf(int classId) {
      for (final s in slots) {
        if (s.classId == classId && s.id != widget.existing?.id) return s;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('assign_title'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _Section(
            tint: const Color(0xFFE3F2FD),
            border: const Color(0xFF90CAF9),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${dayName(lang, widget.dayOfWeek)} • ${tr(p.longKey)}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0277BD))),
                          Text(tr(p.morning ? 'session_morning' : 'session_afternoon'),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    Icon(p.morning ? Icons.wb_sunny : Icons.nights_stay,
                        color: const Color(0xFF0277BD)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _TimePill(label: '${tr('start_time')}: ${p.start}', icon: Icons.schedule)),
                    const SizedBox(width: 10),
                    Expanded(child: _TimePill(label: '${tr('end_time')}: ${p.end}', icon: Icons.timer_outlined)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                      child: Text(tr('max_week'),
                          style: const TextStyle(fontSize: 10, color: Color(0xFFEF6C00))),
                    ),
                    const Spacer(),
                    Text(tr('pick_class'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.groups, size: 18, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 10),
                for (final c in classes) _classTile(c, scheduledOf(c.id!), lang, tr),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Text(tr('facility'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.stadium, size: 18, color: Color(0xFF0277BD)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _field,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    suffixIcon: const Icon(Icons.place_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in kFacilities)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(f, style: const TextStyle(fontSize: 12)),
                            selected: _field.text.trim() == f,
                            onSelected: (_) => setState(() => _field.text = f),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Text(tr('linked_sheet'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.description_outlined, size: 18, color: Color(0xFF0277BD)),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: _sheetId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  hint: Text(sheets.isEmpty ? tr('no_sheet') : tr('linked_sheet')),
                  items: [
                    for (final s in sheets)
                      DropdownMenuItem(value: s.id, child: Text(s.title, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: sheets.isEmpty ? null : (v) => setState(() => _sheetId = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _classId == null ? null : _submit,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(tr('validate_assign')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final nav = Navigator.of(context);
                final ctx = context;
                final tr2 = ref.read(trProvider);
                await ref.read(timetableRepositoryProvider).deleteSlot(widget.existing!.id!);
                ref.invalidate(slotsProvider);
                ref.invalidate(todayDataProvider);
                nav.pop();
                if (ctx.mounted) showSuccessSnack(ctx, tr2('slot_removed'));
              },
              icon: const Icon(Icons.delete_outline, color: AppColors.absent),
              label: Text(tr('remove_slot'), style: const TextStyle(color: AppColors.absent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _classTile(SchoolClass c, TimetableSlot? taken, String lang, String Function(String) tr) {
    final locked = taken != null;
    final color = colorFromHex(c.colorCode);
    final selected = _classId == c.id;
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: InkWell(
        onTap: locked ? null : () => setState(() => _classId = c.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.07) : Colors.grey.shade50,
            border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(locked ? Icons.lock_outline : Icons.circle_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (locked)
                      Text(
                        '${tr('already_scheduled')} ${dayName(lang, taken.dayOfWeek)} (${taken.startTime}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.absent),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(c.level,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final Widget child;
  final Color? tint, border;
  const _Section({required this.child, this.tint, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint ?? Theme.of(context).colorScheme.surface,
        border: Border.all(color: border ?? Colors.transparent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _TimePill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _TimePill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0277BD)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        ],
      ),
    );
  }
}
