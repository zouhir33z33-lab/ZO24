import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/stats_providers.dart';
import '../providers/timetable_providers.dart';
import '../services/attendance_repository.dart';
import '../themes/app_colors.dart';
import '../utils/day_utils.dart';
import '../widgets/app_bottom_sheet.dart';
import 'attendance_screen.dart';

/// « سجل الحصص » : séances déjà enregistrées de la classe (aperçu / modification / suppression).
class SessionHistoryScreen extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  const SessionHistoryScreen({super.key, required this.schoolClass});
  @override
  ConsumerState<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  List<SessionSummary>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(attendanceRepositoryProvider).sessionsOfClass(widget.schoolClass.id!);
    if (mounted) setState(() => _items = r);
  }

  static const _fr = ['Dim.', 'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.'];

  String _title(String ymdStr) {
    final d = parseYmd(ymdStr);
    return '${_fr[d.weekday % 7]} ${d.day} ${kMonthsAr[d.month - 1]} ${d.year}';
  }

  Future<void> _open(SessionSummary s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttendanceScreen(schoolClass: widget.schoolClass, initialDate: parseYmd(s.date))),
    );
    ref.invalidate(todayDataProvider);
    ref.invalidate(lastMarksProvider);
    _load();
  }

  Future<void> _delete(SessionSummary s) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.absent),
        title: Text(tr('att_del_title')),
        content: Text('${tr('att_del_msg1')} (${_title(s.date)} • ${s.start} - ${s.end}) ?\n\n${tr('att_del_msg2')}'),
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
    if (ok != true) return;
    await ref.read(attendanceRepositoryProvider).deleteSessionById(s.id);
    ref.invalidate(todayDataProvider);
    ref.invalidate(lastMarksProvider);
    await _load();
    if (mounted) showSuccessSnack(context, tr('sess_deleted'));
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('sess_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(widget.schoolClass.name, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.access_time, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(tr('sess_none'), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _open(SessionSummary(
                            id: 0, date: ymd(DateTime.now()), start: '', end: '', cancelled: false,
                            termName: '', total: 0, present: 0, absent: 0)),
                        icon: const Icon(Icons.add),
                        label: Text(tr('sess_first')),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 48)),
                      ),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final s = items[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _open(s),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (v) => v == 'open' ? _open(s) : _delete(s),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Row(children: [
                                    const Icon(Icons.edit, size: 17, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(tr('sess_open'), style: const TextStyle(fontSize: 13)),
                                  ]),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    const Icon(Icons.delete, size: 17, color: AppColors.absent),
                                    const SizedBox(width: 8),
                                    Text(tr('delete'), style: const TextStyle(fontSize: 13, color: AppColors.absent)),
                                  ]),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Flexible(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_title(s.date), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _Pill(text: s.termName, color: AppColors.primary, bg: const Color(0xFFE3EAF3)),
                                      Row(mainAxisSize: MainAxisSize.min, children: [
                                        Text('${s.start} - ${s.end}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        const SizedBox(width: 3),
                                        Icon(Icons.access_time, size: 11, color: Colors.grey.shade600),
                                      ]),
                                      _Pill(text: 'présent ${s.present}/${s.total}', color: AppColors.present, bg: const Color(0xFFE8F5E9)),
                                      if (s.absent > 0)
                                        _Pill(text: '${s.absent} ${tr('sess_absents')}', color: AppColors.absent, bg: const Color(0xFFFFEBEE)),
                                      if (s.cancelled)
                                        _Pill(text: tr('sess_cancelled'), color: AppColors.orange, bg: const Color(0xFFFFF3E0)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFFE3EAF3),
                              child: Icon(Icons.event_available, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color, bg;
  const _Pill({required this.text, required this.color, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
      );
}
