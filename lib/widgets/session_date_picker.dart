import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../utils/day_utils.dart';

const List<String> _shortDays = ['dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.'];
const List<String> _shortMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
];
const List<String> _longMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
const List<String> _initials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Sélecteur de date de séance (reproduit la boîte de la vidéo) : seuls les jours
/// du planning sont sélectionnables ; légende « jour d'évaluation » / « séance ».
Future<DateTime?> showSessionDatePicker(
  BuildContext context, {
  required DateTime initial,
  required Set<int> allowedAppDays, // jours de la semaine (dimanche = 1) ; vide = tous
  required Set<String> sessionDates, // yyyy-MM-dd
  required Set<String> evalDates,
  required String planningText, // ex. « Dimanche »
  required String title,
  required String planningLabel,
  required String onlyDaysText,
  required String evalLegend,
  required String sessionLegend,
  required String okLabel,
  required String cancelLabel,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      var selected = DateTime(initial.year, initial.month, initial.day);
      var shown = DateTime(initial.year, initial.month);
      return StatefulBuilder(
        builder: (ctx, setState) {
          final first = DateTime(shown.year, shown.month, 1);
          final lead = first.weekday - 1; // lundi = 0
          final days = DateUtils.getDaysInMonth(shown.year, shown.month);
          final cells = <Widget>[
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++) _cell(DateTime(shown.year, shown.month, d), selected,
                allowedAppDays, sessionDates, evalDates, (v) => setState(() => selected = v)),
          ];
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                        const SizedBox(height: 6),
                        Text(
                          '${_shortDays[selected.weekday % 7]} ${selected.day} ${_shortMonths[selected.month - 1]}',
                          style: const TextStyle(fontSize: 30),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (allowedAppDays.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        border: Border.all(color: const Color(0xFF90CAF9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('$planningLabel : $planningText ($onlyDaysText)',
                                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setState(() => shown = DateTime(shown.year, shown.month - 1)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setState(() => shown = DateTime(shown.year, shown.month + 1)),
                        ),
                        const Spacer(),
                        Text('${_longMonths[shown.month - 1]} ${shown.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (final l in _initials)
                          Expanded(
                            child: Center(
                              child: Text(l, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1,
                      children: cells,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Text(evalLegend, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, size: 12, color: Color(0xFF6A1B9A)),
                        ]),
                        Row(children: [
                          Text(sessionLegend, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.circle, size: 9, color: AppColors.present),
                        ]),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, selected),
                          child: Text(okLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(cancelLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _cell(
  DateTime d,
  DateTime selected,
  Set<int> allowed,
  Set<String> sessionDates,
  Set<String> evalDates,
  ValueChanged<DateTime> onTap,
) {
  final ok = allowed.isEmpty || allowed.contains(appDayOf(d));
  final isSel = DateUtils.isSameDay(d, selected);
  final key = ymd(d);
  final hasSession = sessionDates.contains(key);
  final hasEval = evalDates.contains(key);
  return Padding(
    padding: const EdgeInsets.all(2),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: ok ? () => onTap(d) : null,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSel ? AppColors.primary : (ok ? null : const Color(0xFFEFEFEF)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('${d.day}',
                style: TextStyle(
                  fontSize: 13,
                  color: isSel ? Colors.white : (ok ? Colors.black87 : Colors.grey.shade400),
                )),
            if (hasSession)
              const Positioned(bottom: 3, child: Icon(Icons.circle, size: 5, color: AppColors.present)),
            if (hasEval)
              const Positioned(top: 1, right: 1, child: Icon(Icons.star, size: 9, color: Color(0xFF6A1B9A))),
          ],
        ),
      ),
    ),
  );
}
