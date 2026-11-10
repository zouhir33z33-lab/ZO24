import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/levels.dart';
import '../constants/periods.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/timetable_providers.dart';
import '../themes/app_colors.dart';
import '../utils/day_utils.dart';
import '../providers/academic_providers.dart';
import '../providers/classes_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/pdf_context.dart';
import '../services/pdf_export_service.dart';
import '../utils/xlsx_writer.dart';
import '../widgets/export_sheet.dart';
import 'assign_slot_screen.dart';
import 'attendance_screen.dart';

/// Onglet « التوقيت » : vue du jour (terrain) et vue de la semaine.
class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    return DefaultTabController(
      length: 2,
      initialIndex: 0, // « اليوم والملعب » = 1er onglet (à droite en RTL)
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('tl_title')),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () async {
                final slots = ref.read(slotsProvider).valueOrNull ?? const <TimetableSlot>[];
                final classes = {
                  for (final c in ref.read(classesProvider).valueOrNull ?? const <SchoolClass>[]) c.id!: c
                };
                final sheets = {
                  for (final x in ref.read(sheetsProvider).valueOrNull ?? const <PedagogicalSheet>[]) x.id!: x
                };
                final pc = await loadPdfContext(ref);
                if (!context.mounted) return;
                await showExportSheet(
                  context,
                  title: tr('ex_tt_title'),
                  subtitle: tr('export_official_sub'),
                  fileName: 'Emploi_du_temps_EPS.pdf',
                  buildPdf: () => PdfExportService.timetablePdf(
                      slots: slots, classes: classes, sheets: sheets, ctx: pc),
                  buildSpreadsheet: () async =>
                      Uint8List.fromList(toXlsxBytes(PdfExportService.timetableCsv(slots, classes))),
                  spreadsheetName: 'Emploi_du_temps_EPS.xlsx',
                  labels: exportLabels(tr),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(slotsProvider);
                ref.invalidate(todayDataProvider);
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                final year = await ref.read(activeYearProvider.future);
                if (year == null || !context.mounted) return;
                final isClear = v == 'clear';
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    icon: Icon(isClear ? Icons.delete_sweep : Icons.history, color: isClear ? AppColors.absent : AppColors.orange),
                    title: Text(tr(isClear ? 'tl_clear' : 'tl_default')),
                    content: Text(isClear
                        ? 'Voulez-vous libérer tous les créneaux ? Votre emploi du temps sera entièrement vierge pour vous permettre de le configurer à votre convenance.'
                        : "Voulez-vous restaurer l'emploi du temps type par défaut ? Vos créneaux personnalisés actuels seront remplacés."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: isClear ? AppColors.absent : AppColors.orange),
                        child: Text(tr('tl_confirm')),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                final repo = ref.read(timetableRepositoryProvider);
                if (isClear) {
                  await repo.clearAll(year.id!);
                } else {
                  await repo.applyDefault(
                    year.id!,
                    ref.read(classesProvider).valueOrNull ?? const <SchoolClass>[],
                    ref.read(sheetsProvider).valueOrNull ?? const <PedagogicalSheet>[],
                  );
                }
                ref.invalidate(slotsProvider);
                ref.invalidate(todayDataProvider);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'clear', child: Row(children: [
                  const Icon(Icons.delete_sweep, size: 18, color: AppColors.absent),
                  const SizedBox(width: 10),
                  Text(tr('tl_clear')),
                ])),
                PopupMenuItem(value: 'default', child: Row(children: [
                  const Icon(Icons.history, size: 18, color: AppColors.orange),
                  const SizedBox(width: 10),
                  Text(tr('tl_default')),
                ])),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => ref.read(navIndexProvider.notifier).state = 3,
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: const Icon(Icons.today, size: 20), text: tr('tl_today')),
              Tab(icon: const Icon(Icons.view_week_outlined, size: 20), text: tr('tl_week')),
            ],
          ),
        ),
        body: const TabBarView(children: [_TodayView(), _WeekView()]),
      ),
    );
  }
}

// ───────────────────────── Vue du jour ─────────────────────────

class _TodayView extends ConsumerWidget {
  const _TodayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final async = ref.watch(todayDataProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (d) {
        final now = DateTime.now();
        final nowMin = now.hour * 60 + now.minute;
        TimetableSlot? live, next;
        for (final s in d.slots) {
          if (minutesOf(s.startTime) <= nowMin && nowMin < minutesOf(s.endTime)) live = s;
        }
        if (live == null) {
          for (final s in d.slots) {
            if (minutesOf(s.startTime) > nowMin) {
              next = s;
              break;
            }
          }
        }
        final focus = live ?? next;
        final today = appDayOf(now);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(todayDataProvider),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (focus != null && d.classes[focus.classId] != null)
                _FocusCard(
                  slot: focus,
                  cls: d.classes[focus.classId]!,
                  sheet: d.sheets[focus.defaultSheetId],
                  live: live != null,
                  nowMin: nowMin,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatTile(
                    icon: Icons.flag, color: AppColors.primary,
                    value: '${d.slots.length} / ${kPeriods.length}', label: tr('tl_stat_sessions'))),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(
                    icon: Icons.groups, color: const Color(0xFF6A1B9A),
                    value: '${d.expectedStudents}', label: tr('tl_stat_students'))),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(
                    icon: Icons.pie_chart_outline, color: AppColors.absent,
                    value: d.presenceRate == null ? 'N/A' : '${d.presenceRate!.toStringAsFixed(1)}%',
                    label: tr('tl_stat_rate'))),
                ],
              ),
              const SizedBox(height: 12),
              _Card(
                title: '${tr('tl_today_schedule')} • ${dayName(lang, today)}',
                icon: Icons.event_note,
                color: AppColors.primary,
                child: Column(
                  children: [
                    for (final p in kPeriods) _periodRow(context, ref, d, p, today, tr),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AlertCard(
                icon: Icons.warning_amber_rounded, color: AppColors.absent,
                title: tr('tl_alert_abs'), emptyText: tr('tl_alert_abs_none'),
                lines: [for (final r in d.absenceAlerts)
                  _line(r, '${r['class_name']} • ${r['n']}')],
              ),
              const SizedBox(height: 10),
              _AlertCard(
                icon: Icons.checkroom, color: const Color(0xFF6A1B9A),
                title: tr('tl_alert_kit'), emptyText: tr('tl_alert_kit_none'),
                lines: [for (final r in d.noKitAlerts)
                  _line(r, '${r['class_name']} • ${r['n']}')],
              ),
              const SizedBox(height: 10),
              _AlertCard(
                icon: Icons.history, color: AppColors.orange,
                title: tr('tl_alert_recent'), emptyText: tr('tl_alert_recent_none'),
                lines: [for (final r in d.recentAbsences)
                  _line(r, '${r['class_name']} • ${r['session_date']}')],
              ),
              const SizedBox(height: 10),
              _AlertCard(
                icon: Icons.medical_services_outlined, color: const Color(0xFF00838F),
                title: tr('tl_alert_exempt'), emptyText: tr('tl_alert_exempt_none'),
                lines: [for (final r in d.exemptToday)
                  _line(r, '${r['class_name']}')],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  static String _line(Map<String, Object?> r, String trailing) =>
      '${r['last_name']} ${r['first_name']}|$trailing';

  Widget _periodRow(BuildContext context, WidgetRef ref, TodayData d, Period p, int today,
      String Function(String) tr) {
    TimetableSlot? slot;
    for (final s in d.slots) {
      if (s.startTime == p.start && s.endTime == p.end) slot = s;
    }
    final cls = slot == null ? null : d.classes[slot.classId];
    final dot = cls == null ? Colors.grey : colorFromHex(cls.colorCode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (cls != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(schoolClass: cls)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AssignSlotScreen(dayOfWeek: today, period: p)));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: cls == null ? Colors.transparent : const Color(0xFFF1F4F8),
            border: Border.all(color: cls == null ? Colors.grey.shade300 : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: Text('${p.start} - ${p.end}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cls?.name ?? tr('tl_free_slot'),
                  style: TextStyle(
                    fontWeight: cls == null ? FontWeight.normal : FontWeight.bold,
                    fontStyle: cls == null ? FontStyle.italic : FontStyle.normal,
                    color: cls == null ? Colors.grey : null,
                  ),
                ),
              ),
              Icon(cls == null ? Icons.add_circle_outline : Icons.chevron_left, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends ConsumerWidget {
  final TimetableSlot slot;
  final SchoolClass cls;
  final PedagogicalSheet? sheet;
  final bool live;
  final int nowMin;
  const _FocusCard({required this.slot, required this.cls, required this.sheet, required this.live, required this.nowMin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final color = live ? AppColors.present : AppColors.orange;
    final remaining = live
        ? 'Fin dans ${durationLabel(minutesOf(slot.endTime) - nowMin)}'
        : 'Dans ${durationLabel(minutesOf(slot.startTime) - nowMin)} (${slot.startTime})';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: Text('${slot.startTime} - ${slot.endTime}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(tr(live ? 'tl_live_session' : 'tl_next_session'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                      child: Text(cls.level, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(cls.name,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: live ? AppColors.present : AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(remaining,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                if (sheet != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.present.withOpacity(0.08),
                      border: Border.all(color: AppColors.present.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${tr('tl_sheet')} : ${sheet!.title}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.present, fontWeight: FontWeight.bold)),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => AttendanceScreen(schoolClass: cls))),
                  icon: const Icon(Icons.how_to_reg, size: 18),
                  label: Text(tr('tl_start_roll')),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  const _Card({required this.title, required this.icon, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, emptyText;
  final List<String> lines; // « nom|détail »
  const _AlertCard({required this.icon, required this.color, required this.title,
      required this.emptyText, required this.lines});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: title,
      icon: icon,
      color: color,
      child: lines.isEmpty
          ? Row(children: [
              const Icon(Icons.check_circle, size: 16, color: AppColors.present),
              const SizedBox(width: 6),
              Expanded(child: Text(emptyText, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
            ])
          : Column(
              children: [
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(l.split('|').first,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        Text(l.split('|').last, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ───────────────────────── Vue de la semaine ─────────────────────────

final _selectedDayProvider = StateProvider<int>((ref) => appDayOf(DateTime.now()).clamp(1, 5).toInt());

class _WeekView extends ConsumerWidget {
  const _WeekView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final slots = ref.watch(slotsProvider).valueOrNull ?? const <TimetableSlot>[];
    final classes = {for (final c in ref.watch(classesProviderForTimetable)) c.id!: c};
    final sheets = {for (final s in ref.watch(sheetsProvider).valueOrNull ?? const <PedagogicalSheet>[]) s.id!: s};
    final selected = ref.watch(_selectedDayProvider);
    final todayDay = appDayOf(DateTime.now());

    List<TimetableSlot> ofDay(int day) => slots.where((s) => s.dayOfWeek == day).toList();

    Widget periodCard(Period p) {
      TimetableSlot? slot;
      for (final s in ofDay(selected)) {
        if (s.startTime == p.start && s.endTime == p.end) slot = s;
      }
      final cls = slot == null ? null : classes[slot.classId];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssignSlotScreen(dayOfWeek: selected, period: p, existing: slot),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cls == null ? Colors.white : const Color(0xFFFFF8E1),
              border: Border.all(color: cls == null ? Colors.grey.shade300 : const Color(0xFFFFB300), width: 1.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: cls == null
                ? Row(
                    children: [
                      const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${tr(p.key)} (${p.start} - ${p.end})\n${tr('free_period')}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFFE0B2), borderRadius: BorderRadius.circular(8)),
                            child: Text('${tr(p.key)} (${p.start} - ${p.end})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          Text(cls.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text(cls.level,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      if ((slot!.fieldName ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            const Icon(Icons.place_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(slot.fieldName!, style: const TextStyle(fontSize: 12)),
                          ]),
                        ),
                      if (sheets[slot.defaultSheetId] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            const Icon(Icons.description_outlined, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(sheets[slot.defaultSheetId]!.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.primary)),
                            ),
                          ]),
                        ),
                    ],
                  ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final day in kSchoolDaysList)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => ref.read(_selectedDayProvider.notifier).state = day,
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected == day ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: day == todayDay ? AppColors.orange : Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dayName(lang, day),
                                style: TextStyle(
                                    fontSize: 10.5, fontWeight: FontWeight.bold,
                                    color: selected == day ? Colors.white : Colors.black87)),
                            const SizedBox(height: 2),
                            Text('${ofDay(day).length}/${kPeriods.length}',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: selected == day ? Colors.white70 : Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Banner(text: tr('morning_period'), color: const Color(0xFFFFB300), bg: const Color(0xFFFFF8E1)),
        const SizedBox(height: 8),
        periodCard(kPeriods[0]),
        periodCard(kPeriods[1]),
        _Banner(text: '${tr('lunch_break')} • $kLunchStart - $kLunchEnd',
            color: AppColors.orange, bg: const Color(0xFFFFF3E0)),
        const SizedBox(height: 8),
        _Banner(text: tr('evening_period'), color: const Color(0xFF0288D1), bg: const Color(0xFFE1F5FE)),
        const SizedBox(height: 8),
        periodCard(kPeriods[2]),
        periodCard(kPeriods[3]),
      ],
    );
  }
}

const List<int> kSchoolDaysList = [1, 2, 3, 4, 5];

class _Banner extends StatelessWidget {
  final String text;
  final Color color, bg;
  const _Banner({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
