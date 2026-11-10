import 'package:flutter/material.dart';
import '../services/brightness_service.dart';
import '../models/models.dart';
import '../utils/status_utils.dart';

/// Résultat du mode terrain.
class FieldResult {
  final Map<int, int> statusOf; // studentId -> statusId
  final Map<int, String> obsOf;
  final bool save; // « حفظ وخروج »
  final String? emergencyReason; // non null : toute la classe en « طارئ »
  const FieldResult(this.statusOf, this.obsOf, this.save, this.emergencyReason);
}

/// « بدء النداء الميداني » : appel plein écran sombre (carte 1 par 1 ou liste agrandie),
/// pensé pour le plein soleil. Reconstitué d'après la vidéo.
class FieldAttendanceScreen extends StatefulWidget {
  final SchoolClass schoolClass;
  final String dateLine; // « اليوم، الاثنين 2 نوفمبر • 08:00 - 10:00 »
  final List<Student> students;
  final List<AttendanceStatus> statuses;
  final Map<int, int> statusOf;
  final Map<int, String> obsOf;
  final String lang;
  const FieldAttendanceScreen({
    super.key,
    required this.schoolClass,
    required this.dateLine,
    required this.students,
    required this.statuses,
    required this.statusOf,
    required this.obsOf,
    required this.lang,
  });

  @override
  State<FieldAttendanceScreen> createState() => _FieldAttendanceScreenState();
}

class _FieldAttendanceScreenState extends State<FieldAttendanceScreen> {
  late final Map<int, int> _status = {...widget.statusOf};
  late final Map<int, String> _obs = {...widget.obsOf};
  int _index = 0;
  bool _cardMode = true;
  bool _sun = false;

  @override
  void dispose() {
    BrightnessService.reset();
    super.dispose();
  }
  String? _emergencyReason;
  final Set<int> _seen = {};

  AttendanceStatus? _by(String code) {
    for (final s in widget.statuses) {
      if (s.code == code) return s;
    }
    return null;
  }

  Color get _bg => _sun ? const Color(0xFFF4F6F8) : const Color(0xFF0B1220);
  Color get _panel => _sun ? Colors.white : const Color(0xFF111A2C);
  Color get _fg => _sun ? Colors.black87 : Colors.white;

  AttendanceStatus? _statusOfStudent(Student s) {
    final id = _status[s.id!];
    for (final st in widget.statuses) {
      if (st.id == id) return st;
    }
    return null;
  }

  void _set(Student s, AttendanceStatus st, {bool advance = true}) {
    setState(() {
      _status[s.id!] = st.id!;
      _seen.add(s.id!);
      if (advance && _cardMode) {
        if (_index < widget.students.length - 1) {
          _index++;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => _finishDialog());
        }
      }
    });
  }

  Map<String, int> get _counts {
    var p = 0, a = 0, l = 0;
    final present = _by('PRESENT')?.id, absent = _by('ABSENT')?.id, late = _by('LATE')?.id;
    for (final s in widget.students) {
      final id = _status[s.id!];
      if (id == present) {
        p++;
      } else if (id == absent) {
        a++;
      } else if (id == late) {
        l++;
      }
    }
    return {'p': p, 'a': a, 'l': l, 'o': widget.students.length - p - a - l};
  }

  Future<void> _finishDialog() async {
    final c = _counts;
    final res = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF1F7A5A))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircleAvatar(radius: 30, backgroundColor: Color(0x331F7A5A), child: Icon(Icons.done_all, size: 32, color: Color(0xFF2ECC9A))),
            const SizedBox(height: 12),
            Text('اكمل النداء !', style: TextStyle(color: _fg, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('تم تفقد جميع تلاميذ القسم.', style: TextStyle(color: _fg.withOpacity(0.6), fontSize: 12)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _bg, border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _line('حاضر', c['p']!, const Color(0xFF2ECC9A)),
                _line('غائب', c['a']!, const Color(0xFFFF5252)),
                _line('تأخر', c['l']!, const Color(0xFFFFA000)),
                _line('أخرى', c['o']!, const Color(0xFF4FC3F7)),
              ]),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), minimumSize: const Size.fromHeight(50)),
              child: const Text('حفظ وخروج', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'review'),
              child: Text('مراجعة القائمة', style: TextStyle(color: _fg.withOpacity(0.7))),
            ),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    if (res == 'save') {
      Navigator.pop(context, FieldResult(_status, _obs, true, _emergencyReason));
    } else {
      setState(() => _cardMode = false);
    }
  }

  Widget _line(String label, int n, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text('$n', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
      );

  Future<void> _others(Student s) async {
    final skip = {'PRESENT', 'ABSENT', 'LATE'};
    final list = widget.statuses.where((x) => !skip.contains(x.code)).toList();
    final picked = await showModalBottomSheet<AttendanceStatus>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              InkWell(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, color: _fg)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('حالات تكميلية', style: TextStyle(color: _fg, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(s.fullName, style: TextStyle(color: _fg.withOpacity(0.6), fontSize: 11)),
              ]),
            ]),
            const SizedBox(height: 10),
            for (final st in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, st),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _bg, border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.circle, size: 14, color: hexColor(st.colorHex)),
                      const Spacer(),
                      Text(st.label(widget.lang), style: TextStyle(color: _fg, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.code == 'EMERGENCY') {
      await _emergency(s, picked);
    } else {
      _set(s, picked);
    }
  }

  Future<void> _emergency(Student s, AttendanceStatus st) async {
    final ctrl = TextEditingController();
    const chips = ['سوء الأحوال الجوية', 'غياب الأستاذ', 'المنشآت غير متوفرة', 'مناسبة مدرسية'];
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  InkWell(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Colors.grey)),
                  const Spacer(),
                  const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('حالة « طارئ »', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('تسيير حدث استثنائي', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                  const SizedBox(width: 10),
                  const CircleAvatar(backgroundColor: Color(0xFFECEFF1), child: Icon(Icons.event_busy, color: Colors.black54)),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFECEFF1), borderRadius: BorderRadius.circular(12)),
                  child: Text('هل ترغب في تطبيق هذه الحالة فقط على ${s.fullName} أم على كامل القسم؟'),
                ),
                const SizedBox(height: 12),
                const Text('طبيعة الحدث (اختياري) :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: 'مثال: سوء الأحوال الجوية، غياب أستاذ...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in chips)
                    ActionChip(label: Text(c, style: const TextStyle(fontSize: 11)), onPressed: () => setD(() => ctrl.text = c)),
                ]),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'class'),
                  icon: const Icon(Icons.groups),
                  label: const Text('كامل القسم'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF455A64), minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'one'),
                  icon: const Icon(Icons.person),
                  label: const Text('هذا التلميذ فقط'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ]),
            ),
          ),
        ),
      ),
    );
    if (res == null || !mounted) return;
    final reason = ctrl.text.trim();
    setState(() {
      if (res == 'class') {
        for (final x in widget.students) {
          _status[x.id!] = st.id!;
          if (reason.isNotEmpty) _obs[x.id!] = reason;
          _seen.add(x.id!);
        }
        _emergencyReason = reason.isEmpty ? 'طارئ' : reason;
      } else {
        _status[s.id!] = st.id!;
        if (reason.isNotEmpty) _obs[s.id!] = reason;
        _seen.add(s.id!);
        if (_index < widget.students.length - 1) _index++;
      }
    });
    if (res == 'class') _finishDialog();
  }

  Widget _bigButton(String label, IconData icon, Color color, VoidCallback onTap, {double h = 64, double fs = 22}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: fs + 2),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final n = widget.students.length;
    final done = _seen.length;
    final pct = n == 0 ? 0 : (done * 100 ~/ n);
    final present = _by('PRESENT'), absent = _by('ABSENT'), late = _by('LATE');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, FieldResult(_status, _obs, false, _emergencyReason));
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(children: [
                  InkWell(
                    onTap: () {
                      setState(() => _sun = !_sun);
                      _sun ? BrightnessService.max() : BrightnessService.reset();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFFA000)), borderRadius: BorderRadius.circular(10)),
                      child: const Row(children: [
                        Text('شمس', style: TextStyle(color: Color(0xFFFFA000), fontSize: 11, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.wb_sunny, size: 14, color: Color(0xFFFFA000)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  Column(children: [
                    Text(widget.schoolClass.name, style: TextStyle(color: _fg, fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(widget.dateLine, style: TextStyle(color: _fg.withOpacity(0.6), fontSize: 10.5)),
                  ]),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.pop(context, FieldResult(_status, _obs, false, _emergencyReason)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: _panel, border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Text('خروج', style: TextStyle(color: _fg, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 14, color: _fg),
                      ]),
                    ),
                  ),
                ]),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: _panel, border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: _tab('بطاقة 1 بـ 1', Icons.style, _cardMode, () => setState(() => _cardMode = true))),
                  Expanded(child: _tab('قائمة مكبرة', Icons.list, !_cardMode, () => setState(() => _cardMode = false))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Text('$pct%', style: TextStyle(color: _fg.withOpacity(0.6), fontSize: 10)),
                  const Spacer(),
                  Text('التقييد ${_cardMode ? _index + 1 : done} / $n',
                      style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: n == 0 ? 0 : done / n, minHeight: 4, backgroundColor: Colors.white12, color: const Color(0xFF16A34A)),
                ),
              ),
              Expanded(child: _cardMode ? _card(present, absent, late) : _list(present, absent, late)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, IconData icon, bool sel, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 38,
          decoration: BoxDecoration(color: sel ? const Color(0xFF2563EB) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: TextStyle(color: sel ? Colors.white : _fg.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 5),
            Icon(icon, size: 14, color: sel ? Colors.white : _fg.withOpacity(0.7)),
          ]),
        ),
      );

  Widget _card(AttendanceStatus? present, AttendanceStatus? absent, AttendanceStatus? late) {
    if (widget.students.isEmpty) return const SizedBox();
    final s = widget.students[_index];
    final cur = _statusOfStudent(s);
    final recorded = _seen.contains(s.id!);
    final girl = s.gender == 'F';
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        // glisser vers la droite = précédent (arabe), vers la gauche = suivant
        if (v > 200 && _index > 0) setState(() => _index--);
        if (v < -200 && _index < widget.students.length - 1) setState(() => _index++);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: _panel, border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(24)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if ((s.studentNumber ?? '').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x222563EB), border: Border.all(color: const Color(0xFF3B82F6)), borderRadius: BorderRadius.circular(12)),
                        child: Text('${s.studentNumber} #', style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 8),
                    Text('${widget.schoolClass.name} • ${girl ? 'FILLE' : 'GARÇON'}',
                        style: TextStyle(color: _fg.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        child: Text(s.lastName, style: TextStyle(color: _fg, fontSize: 36, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Text(s.firstName, style: const TextStyle(color: Color(0xFFFFC107), fontSize: 38, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (cur != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: (cur.code == 'PRESENT' ? const Color(0xFF16A34A) : (cur.code == 'ABSENT' ? const Color(0xFFDC2626) : hexColor(cur.colorHex))),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text('${recorded ? '✓ تم التسجيل' : 'لم التسجيل'} : ${cur.label(widget.lang)}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (present != null) _bigButton('حاضر', Icons.check_circle, const Color(0xFF16A34A), () => _set(s, present)),
            const SizedBox(height: 8),
            if (absent != null) _bigButton('غائب', Icons.cancel, const Color(0xFFDC2626), () => _set(s, absent), h: 56),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _bigButton('أخرى', Icons.more_horiz, const Color(0xFF0288D1), () => _others(s), h: 50, fs: 16)),
              const SizedBox(width: 8),
              Expanded(child: late == null ? const SizedBox() : _bigButton('متأخر', Icons.timer, const Color(0xFFD97706), () => _set(s, late), h: 50, fs: 16)),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                InkWell(
                  onTap: _index < widget.students.length - 1 ? () => setState(() => _index++) : _finishDialog,
                  child: Text(_index < widget.students.length - 1 ? '← التالي' : '← إنهاء',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const Spacer(),
                Text('اسحب أو اضغط', style: TextStyle(color: _fg.withOpacity(0.4), fontSize: 10)),
                const Spacer(),
                InkWell(
                  onTap: _index > 0 ? () => setState(() => _index--) : null,
                  child: Text('السابق →', style: TextStyle(color: _fg.withOpacity(_index > 0 ? 0.7 : 0.25), fontSize: 12)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(AttendanceStatus? present, AttendanceStatus? absent, AttendanceStatus? late) {
    Widget btn(String label, bool sel, Color c, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Container(
            width: 44, height: 44,
            margin: const EdgeInsetsDirectional.only(start: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? c : _bg,
              border: Border.all(color: sel ? Colors.white54 : Colors.white12),
              borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: TextStyle(color: sel ? Colors.white : _fg.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        );
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            itemCount: widget.students.length,
            itemBuilder: (_, i) {
              final s = widget.students[i];
              final cur = _statusOfStudent(s);
              final isP = cur?.id == present?.id, isA = cur?.id == absent?.id, isR = cur?.id == late?.id;
              final other = cur != null && !isP && !isA && !isR;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _panel, border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  if ((s.studentNumber ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0x33FFC107), border: Border.all(color: const Color(0xFFFFC107)), borderRadius: BorderRadius.circular(8)),
                      child: Text(s.studentNumber!, style: const TextStyle(color: Color(0xFFFFC107), fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.fullName, overflow: TextOverflow.ellipsis, style: TextStyle(color: _fg, fontWeight: FontWeight.bold, fontSize: 14))),
                  btn('P', isP, const Color(0xFF16A34A), () { if (present != null) _set(s, present, advance: false); }),
                  btn('A', isA, const Color(0xFFDC2626), () { if (absent != null) _set(s, absent, advance: false); }),
                  btn('R', isR, const Color(0xFFD97706), () { if (late != null) _set(s, late, advance: false); }),
                  btn(other ? statusLetter(cur.code, cur.labelFr) : '...', other, other ? hexColor(cur.colorHex) : Colors.grey, () => _others(s)),
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: InkWell(
            onTap: _finishDialog,
            child: Container(
              height: 54,
              decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('تأكيد وإتمام النداء', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.check_circle_outline, color: Colors.white),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
