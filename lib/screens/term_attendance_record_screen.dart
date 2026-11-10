import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/academic_providers.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../services/stats_repository.dart';
import '../themes/app_colors.dart';
import '../utils/xlsx_writer.dart';
import '../utils/day_utils.dart';
import '../utils/file_saver.dart';
import '../utils/labels.dart';
import '../utils/status_utils.dart';
import 'attendance_screen.dart';

typedef _RKey = ({int classId, int termId});

final _recordProvider = FutureProvider.autoDispose.family<RecordMatrix, _RKey>((ref, k) {
  return ref.read(statsRepositoryProvider).recordMatrix(k.classId, k.termId);
});

/// « السجل الفصلي » : matrice élèves × séances avec la lettre de chaque statut.
class TermAttendanceRecordScreen extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  const TermAttendanceRecordScreen({super.key, required this.schoolClass});
  @override
  ConsumerState<TermAttendanceRecordScreen> createState() => _TermAttendanceRecordScreenState();
}

class _TermAttendanceRecordScreenState extends ConsumerState<TermAttendanceRecordScreen> {
  int? _termId;

  Future<void> _share(RecordMatrix m, Term term, List<AttendanceStatus> sts) async {
    final rows = <List<String>>[
      ['Matricule/N°', 'Élève', 'Présence %', 'Abs', ...m.sessions.map((s) => '${s.date} ${s.start}')],
      for (final l in m.students)
        [
          l.student.studentNumber ?? '', l.student.fullName, l.pct.toStringAsFixed(0), '${l.absences}',
          for (final s in m.sessions)
            m.cell[l.student.id]?[s.id] == null
                ? ''
                : statusLetter(m.cell[l.student.id]![s.id]!.code, m.cell[l.student.id]![s.id]!.labelFr),
        ],
    ];
    await FileSaver.share('Registre_${widget.schoolClass.name}_T${term.termNumber}.xlsx', toXlsxBytes(rows));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.schoolClass;
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final terms = ref.watch(termsProvider).valueOrNull ?? const <Term>[];
    final current = terms.where((t) => t.isCurrent).firstOrNull ?? (terms.isNotEmpty ? terms.first : null);
    final termId = _termId ?? current?.id;
    final term = terms.where((t) => t.id == termId).firstOrNull;
    final statuses = ref.watch(_statusesLocal).valueOrNull ?? const <AttendanceStatus>[];
    final async = termId == null ? null : ref.watch(_recordProvider((classId: c.id!, termId: termId)));
    final m = async?.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${tr('rec_title')} • ${c.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text(tr('rec_sub'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          if (m != null && m.sessions.isNotEmpty && term != null)
            IconButton(icon: const Icon(Icons.share), onPressed: () => _share(m, term, statuses)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(_recordProvider)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(children: [
              for (final t in terms)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _termId = t.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: termId == t.id ? AppColors.primary : Colors.white,
                          border: Border.all(color: Colors.black54),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text(kTermNamesAr[(t.termNumber - 1).clamp(0, 2)],
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5,
                                color: termId == t.id ? Colors.white : Colors.black87)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final s in statuses.where((s) => s.code != 'EMERGENCY'))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Row(children: [
                      _Letter(status: s, size: 22),
                      const SizedBox(width: 4),
                      Text(s.label(lang), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ],
            ),
          ),
          if (m != null && m.sessions.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFE3F2FD),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'séance ${m.sessions.length} ${tr('rec_total')}   ${tr('rec_avg')} : ${m.avgPresence == null ? 'N/A' : m.avgPresence!.toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          Expanded(
            child: async == null || async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (m == null || m.sessions.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.event_busy, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('${tr('rec_none')} ${term == null ? '' : kTermNamesAr[(term.termNumber - 1).clamp(0, 2)]}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(tr('rec_none_sub'), textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => AttendanceScreen(schoolClass: c))),
                              icon: const Icon(Icons.how_to_reg),
                              label: Text(tr('rec_now')),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 48)),
                            ),
                          ]),
                        ),
                      )
                    : _Table(matrix: m),
          ),
        ],
      ),
    );
  }
}

final _statusesLocal = FutureProvider.autoDispose<List<AttendanceStatus>>((ref) {
  return ref.read(statusRepositoryProvider).all();
});

class _Letter extends StatelessWidget {
  final AttendanceStatus status;
  final double size;
  const _Letter({required this.status, this.size = 26});
  @override
  Widget build(BuildContext context) {
    final c = hexColor(status.colorHex);
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withOpacity(0.18), border: Border.all(color: c), borderRadius: BorderRadius.circular(6)),
      child: Text(statusLetter(status.code, status.labelFr),
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold, color: c)),
    );
  }
}

class _Table extends StatelessWidget {
  final RecordMatrix matrix;
  const _Table({required this.matrix});

  @override
  Widget build(BuildContext context) {
    final sess = matrix.sessions;
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const FixedColumnWidth(170),
              1: const FixedColumnWidth(50),
              2: const FixedColumnWidth(40),
              for (var i = 0; i < sess.length; i++) 3 + i: const FixedColumnWidth(58),
            },
            border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFECEFF1)),
                children: [
                  const Padding(padding: EdgeInsets.all(8), child: Text('التلميذ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Center(child: Text('%', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange))),
                  const Center(child: Text('Abs', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange, fontSize: 11))),
                  for (final s in sess)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        Text('${s.date.substring(8, 10)}/${s.date.substring(5, 7)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(s.start, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      ]),
                    ),
                ],
              ),
              for (final l in matrix.students)
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(l.student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Center(child: Text('${l.pct.toStringAsFixed(0)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                          color: l.pct >= 50 ? AppColors.present : AppColors.orange))),
                  Center(child: Text('${l.absences}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: l.absences > 0 ? AppColors.absent : Colors.black87))),
                  for (final s in sess)
                    Center(
                      child: matrix.cell[l.student.id]?[s.id] == null
                          ? const Text('-')
                          : Padding(padding: const EdgeInsets.all(4), child: _Letter(status: matrix.cell[l.student.id]![s.id]!)),
                    ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
