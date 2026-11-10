import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../constants/incident_constants.dart';
import '../constants/periods.dart';
import '../models/models.dart';
import '../providers/teacher_provider.dart';
import '../utils/day_utils.dart';
import '../utils/labels.dart';
import 'evaluation_repository.dart';

/// Contexte administratif commun à tous les PDF.
class PdfContext {
  final TeacherProfile teacher;
  final String yearName;
  final String directorLabel; // « مدير المتوسطة » …
  final String cycleWord; // « متوسطة » …
  const PdfContext({
    required this.teacher,
    required this.yearName,
    required this.directorLabel,
    required this.cycleWord,
  });

  String get school => teacher.school.isEmpty ? 'Lycée / Collège' : teacher.school;
  String get teacherName => teacher.fullName.isEmpty ? "Professeur d'EPS" : teacher.fullName;
}

/// PDF générés via HTML (le moteur de la plateforme assure la forme des lettres
/// arabes et le sens RTL). Mises en page calquées sur les PDF réels de l'application
/// d'origine (accident, bilan trimestriel, emploi du temps).
class PdfExportService {
  static String _e(String? s) => (s ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\n', '<br/>');

  static const String _appName = 'مساعد التربية البدنية والرياضية';

  static const String _baseCss = """
  body { font-family: sans-serif; color:#111; margin:0; }
  .top { display:flex; justify-content:space-between; align-items:flex-start; }
  .top .r { text-align:right; line-height:1.5; font-weight:bold; font-size:10pt; }
  .top .r .sub { font-weight:normal; color:#555; font-size:8.5pt; }
  .top .l { text-align:left; line-height:1.6; font-size:9.5pt; }
  .top .l span.k { font-weight:normal; color:#444; }
  hr.rule { border:0; border-top:2px solid #263238; margin:10px 0 14px; }
  .sig { border:1px solid #777; border-radius:8px; padding:6px 8px; height:78px; position:relative; font-size:9.5pt; }
  .sig b { display:block; }
  .sig .bot { position:absolute; bottom:5px; right:8px; left:8px; font-size:8pt; color:#777; }
  """;

  // ─────────────────────── Déclaration d'accident ───────────────────────

  static String _injuryLabel(IncidentReport r) {
    if (r.injuryType == 'ENTORSE') return 'التواء';
    return choiceOf(kInjuryTypes, r.injuryType)?.ar ?? r.injuryType;
  }

  static Future<Uint8List> incidentPdf({
    required IncidentReport report,
    required String studentName,
    required String gender, // 'M' | 'F' | ''
    required String className,
    required String level,
    required PdfContext ctx,
  }) {
    String or(String? v, String d) => (v == null || v.trim().isEmpty) ? d : v.trim();
    final evac = choiceOf(kEvacuations, report.evacuationType)?.ar ?? report.evacuationType;
    final parent = report.parentContacted
        ? '<span style="color:#2E7D32;font-weight:bold">نعم</span>'
        : '<span style="color:#EF6C00;font-weight:bold">لا / في الانتظار</span>';
    final sex = gender == 'F' ? 'أنثى' : (gender == 'M' ? 'ذكر' : '—');
    final locChoice = choiceOf(kLocations, report.location);

    final html = '''
<html dir="rtl" lang="ar"><head><meta charset="utf-8"/><style>
@page { size: A4; margin: 12mm; }
$_baseCss
.badge { display:inline-block; border:1.5px solid #C62828; color:#C62828; background:#FFEBEE; border-radius:10px; padding:1px 8px; font-size:8pt; font-weight:bold; margin-top:3px; }
.title { text-align:center; margin:4px 0 12px; }
.title div { display:inline-block; border:2px solid #607D8B; border-radius:10px; background:#ECEFF1; padding:6px 26px; }
.title h1 { margin:0; font-size:15pt; } .title small { color:#666; font-size:8.5pt; }
.box { border:1px solid #607D8B; border-radius:8px; margin-bottom:10px; overflow:hidden; }
.box h3 { margin:0; padding:4px 10px; font-size:9.5pt; background:#CFD8DC; }
.box .in { padding:8px 12px; font-size:9.5pt; }
.box.red { border-color:#E57373; } .box.red h3 { background:#FFEBEE; color:#B71C1C; }
.box.grey { border-color:#BDBDBD; } .box.grey h3 { background:#EEEEEE; }
.box.green { border-color:#66BB6A; } .box.green h3 { background:#E8F5E9; color:#1B5E20; }
table.kv { width:100%; border-collapse:collapse; } table.kv td { padding:3px 2px; width:33%; }
table.kv b { font-size:9pt; }
</style></head><body>
<div class="top">
  <div class="r">الجمهورية الجزائرية الديمقراطية الشعبية<br/>وزارة التربية الوطنية<br/>المؤسسة : ${_e(ctx.teacher.school.isEmpty ? 'Établissement Scolaire' : ctx.teacher.school)}
    <div class="sub">المادة : التربية البدنية والرياضية</div></div>
  <div class="l"><b>السنة الدراسية :</b> ${_e(ctx.yearName)}<br/><span class="badge">تصريح إداري عاجل بحادث</span></div>
</div>
<hr class="rule"/>
<div class="title"><div><h1>تصريح بحادث مدرسي بدني</h1><small>استمارة حادث خلال حصة التربية البدنية والرياضية</small></div></div>

<div class="box"><h3>1. هوية التلميذ المصاب وإطار الحصة</h3><div class="in"><table class="kv">
<tr><td><b>اللقب والاسم :</b> <span style="color:#1A237E;font-weight:bold">${_e(studentName)}</span></td><td><b>القسم :</b> ${_e(className)} (${_e(level)})</td><td><b>الجنس :</b> $sex</td></tr>
<tr><td><b>تاريخ الحادث :</b> ${_e(report.incidentDate)}</td><td><b>التوقيت الدقيق :</b> ${_e(report.incidentTime)}</td><td><b>مكان الحادث :</b> ${_e(locChoice?.ar ?? report.location)}</td></tr>
<tr><td><b>النشاط الرياضي الممارس :</b> ${_e(or(report.activity, 'غير محدد'))}</td><td><b>الأستاذ المسؤول :</b> ${_e(ctx.teacherName)}</td><td></td></tr>
</table></div></div>

<div class="box red"><h3>2. طبيعة الإصابة وموقع الضرر الجسدي</h3><div class="in"><table class="kv">
<tr><td style="width:50%"><b>طبيعة الإصابة :</b> <span style="color:#C62828;font-weight:bold">${_e(_injuryLabel(report))}</span></td>
<td style="width:50%"><b>موضع الإصابة في الجسم :</b> <span style="color:#C62828;font-weight:bold">${_e(or(report.injuryLocation, 'غير محدد'))}</span></td></tr>
</table></div></div>

<div class="box grey"><h3>3. الظروف المفصلة للحادث (وقائع موضوعية)</h3><div class="in" style="min-height:60px;padding-top:18px">${_e(or(report.circumstances, "Blessure survenue pendant la pratique d'activités physiques en séance d'EPS."))}</div></div>

<div class="box green"><h3>4. الإسعافات الأولية وتدابير التوجيه والإجلاء</h3><div class="in">
<div style="margin-bottom:5px"><b>الإسعافات الأولية الفورية :</b> ${_e(or(report.firstAidGiven, 'إجراءات الحماية والراحة'))}</div>
<table class="kv"><tr><td style="width:60%"><b>التكفل / التوجيه :</b> ${_e(evac)}</td><td><b>إشعار الأولياء :</b> $parent</td></tr></table>
</div></div>

<div class="box grey"><h3>5. شهود الحادث وملاحظات تكميلية</h3><div class="in">
<div><b>التلاميذ الشهود :</b> ${_e(or(report.witnessStudents, 'لا يوجد شهود مسجلون'))}</div>
${(report.notes ?? '').trim().isEmpty ? '' : '<div style="margin-top:4px"><b>ملاحظات :</b> ${_e(report.notes)}</div>'}
</div></div>

<div style="position:fixed;bottom:16mm;left:0;right:0">
<table style="width:100%;border-collapse:separate;border-spacing:8px 0"><tr>
<td class="sig" style="width:33%"><b>أستاذ(ة) التربية البدنية والرياضية المصرح :</b>${_e(ctx.teacherName)}<span class="bot">التاريخ والإمضاء :</span></td>
<td class="sig" style="width:33%"><b>قاعة التمريض / وحدة الكشف (UDS) :</b><span class="bot">الختم والتأشيرة الطبية :</span></td>
<td class="sig" style="width:33%"><b>مدير المؤسسة :</b><span class="bot">الإمضاء والختم الرسمي :</span></td>
</tr></table>
<div style="text-align:center;font-size:7.5pt;color:#999;margin-top:6px">تم استخراج الوثيقة بواسطة $_appName • حرر في 3 نسخ أصلية (الإدارة، الأستاذ، الملف الطبي)</div>
</div>
</body></html>''';
    return Printing.convertHtml(html: html);
  }

  // ─────────────────────── Emploi du temps hebdomadaire ───────────────────────

  static const List<int> _days = [1, 2, 3, 4, 5];

  static Future<Uint8List> timetablePdf({
    required List<TimetableSlot> slots,
    required Map<int, SchoolClass> classes,
    required Map<int, PedagogicalSheet> sheets,
    required PdfContext ctx,
  }) {
    final used = <int>{};
    for (final s in slots) {
      used.add(s.classId);
    }
    final names = [for (final id in used) if (classes[id] != null) classes[id]!.name];
    final hours = slots.length * 2;

    String cell(int day, Period p) {
      for (final s in slots) {
        if (s.dayOfWeek == day && s.startTime == p.start && s.endTime == p.end) {
          final c = classes[s.classId];
          if (c == null) break;
          final sheet = sheets[s.defaultSheetId];
          return '<div style="font-size:13pt;font-weight:bold;color:#0D47A1">${_e(c.name)}</div>'
              '<div style="font-weight:bold;color:#37474F">${_e(c.level)}</div>'
              '${(s.fieldName ?? '').isEmpty ? '' : '<div style="color:#555;font-size:8pt">${_e(s.fieldName)}</div>'}'
              '${sheet == null ? '' : '<div style="color:#00695C;font-size:7.5pt">${_e(sheet.title)}</div>'}';
        }
      }
      return '<span style="color:#999">-</span>';
    }

    final rows = StringBuffer();
    void periodRow(Period p) {
      rows.write('<tr style="height:60px"><td class="time"><b>${tr(p)}</b><br/><span>${p.start} - ${p.end}</span></td>');
      for (final d in _days) {
        final filled = slots.any((s) => s.dayOfWeek == d && s.startTime == p.start && s.endTime == p.end);
        rows.write('<td${filled ? ' class="hit"' : ''}>${cell(d, p)}</td>');
      }
      rows.write('</tr>');
    }

    periodRow(kPeriods[0]);
    periodRow(kPeriods[1]);
    rows.write('<tr class="lunch"><td><b>$kLunchStart - $kLunchEnd</b></td>${_days.map((_) => '<td>فترة الاستراحة</td>').join()}</tr>');
    periodRow(kPeriods[2]);
    periodRow(kPeriods[3]);

    final headDays = _days
        .map((d) => '<th>${kDayNamesAr[d - 1]}<br/><span>${kDayNamesFr[d - 1].toUpperCase()}</span></th>')
        .join();

    final html = '''
<html dir="rtl" lang="ar"><head><meta charset="utf-8"/><style>
@page { size: A4 landscape; margin: 10mm; }
$_baseCss
.bar { background:#F3F3F3; border:1px solid #ddd; border-radius:6px; padding:6px 10px; display:flex; justify-content:space-between; font-size:8.5pt; margin:10px 0; }
h1 { text-align:center; font-size:13pt; margin:14px 0 8px; }
table.tt { width:100%; border-collapse:collapse; font-size:8.5pt; }
table.tt th { background:#37474F; color:#fff; padding:6px; border:1px solid #37474F; }
table.tt th span { font-weight:normal; font-size:7.5pt; }
table.tt td { border:1px solid #78909C; text-align:center; padding:4px; }
td.time { background:#ECEFF1; width:90px; } td.time span { color:#555; }
td.hit { background:#E3F2FD; }
tr.lunch td { background:#FFF8E1; color:#EF6C00; font-size:8pt; font-weight:bold; }
</style></head><body>
<div class="top">
  <div class="r">الجمهورية الجزائرية الديمقراطية الشعبية<br/>وزارة التربية الوطنية<div class="sub">مديرية التربية • مادة التربية البدنية والرياضية</div></div>
  <div class="l"><b>السنة الدراسية :</b> ${_e(ctx.yearName)}<br/><b>المؤسسة :</b> ${_e(ctx.school)}<br/><span class="k">تاريخ الإصدار :</span> ${stampNow()}</div>
</div>
<hr class="rule"/>
<h1>جدول التوقيت الأسبوعي الرسمي لأستاذ التربية البدنية والرياضية</h1>
<div class="bar"><span><b>المادة :</b> التربية البدنية والرياضية</span>
<span style="color:#0D47A1"><b>الأقسام المبرمجة :</b> ${names.length} (${_e(names.join('، '))})</span>
<span style="color:#2E7D32"><b>الحجم الساعي :</b> ${slots.length} حصص ($hours سا / أسبوع)</span></div>
<table class="tt"><tr><th>التوقيت</th>$headDays</tr>$rows</table>
<table style="width:100%;margin-top:14px;border-collapse:separate;border-spacing:8px 0"><tr>
<td class="sig" style="width:34%"><b>أستاذ(ة) التربية البدنية والرياضية :</b><span class="bot">الإمضاء والتاريخ</span></td>
<td style="text-align:center;font-size:8pt;color:#777;width:32%">وثيقة مطابقة للتوقيت الرسمي لوزارة التربية الوطنية<br/><b style="color:#444">${_e(ctx.cycleWord)} • $_appName</b></td>
<td class="sig" style="width:34%"><b>تأشيرة مدير المؤسسة :</b><span class="bot">(الختم والإمضاء) ${_e(ctx.directorLabel)}</span></td>
</tr></table>
</body></html>''';
    return Printing.convertHtml(html: html);
  }

  static String tr(Period p) => switch (p.id) {
        'M1' => 'الفترة الصباحية 1',
        'M2' => 'الفترة الصباحية 2',
        'E1' => 'الفترة المسائية 1',
        _ => 'الفترة المسائية 2',
      };

  static List<List<String>> timetableCsv(List<TimetableSlot> slots, Map<int, SchoolClass> classes) => [
        ['Jour', 'Début', 'Fin', 'Classe', 'Niveau', 'Terrain'],
        for (final s in slots)
          [
            kDayNamesFr[s.dayOfWeek - 1], s.startTime, s.endTime,
            classes[s.classId]?.name ?? '', classes[s.classId]?.level ?? '', s.fieldName ?? '',
          ],
      ];

  // ─────────────────────── Bilan trimestriel ───────────────────────

  static Future<Uint8List> termReportPdf({
    required SchoolClass cls,
    required Term term,
    required TermSummary summary,
    required PdfContext ctx,
  }) {
    final body = StringBuffer();
    for (final st in summary.students) {
      final sex = st.student.gender == 'F' ? 'أ' : 'ذ';
      body.write('<tr><td>${_e(st.student.studentNumber ?? '')}</td><td style="text-align:right;font-weight:bold">${_e(st.student.fullName)}</td>'
          '<td>$sex</td><td style="color:${st.absences > 0 ? '#C62828' : '#111'}">${st.absences}</td>'
          '<td>${(st.presencePct ?? 100).toStringAsFixed(0)}%</td><td>${st.gradedEvals}</td>'
          '<td>${st.average == null ? '-' : st.average!.toStringAsFixed(2)}</td>'
          '<td><b>${st.average == null ? 'N/A' : _appr(st.average!)}</b></td></tr>');
    }
    final termAr = kTermNamesAr[(term.termNumber - 1).clamp(0, 2)];
    final avgTxt = summary.classAverage == null ? 'N/A' : summary.classAverage!.toStringAsFixed(2);
    final passTxt = summary.passRate == null ? 'N/A' : '${summary.passRate!.toStringAsFixed(1)}%';
    final html = '''
<html dir="rtl" lang="ar"><head><meta charset="utf-8"/><style>
@page { size: A4; margin: 12mm; }
$_baseCss
h1 { text-align:center; font-size:14pt; margin:16px 0 10px; }
.info { background:#F3F3F3; border:1px solid #ddd; border-radius:6px; padding:7px 10px; display:flex; justify-content:space-between; font-size:10pt; font-weight:bold; margin-bottom:10px; }
.kpi { display:flex; background:#ECEFF1; border:1px solid #B0BEC5; border-radius:10px; padding:10px 0; margin-bottom:12px; text-align:center; }
.kpi div { flex:1; border-left:1px solid #B0BEC5; } .kpi div:last-child { border-left:0; }
.kpi b { display:block; font-size:15pt; } .kpi span { font-size:8.5pt; color:#444; }
table.g { width:100%; border-collapse:collapse; font-size:9pt; }
table.g th { background:#ECEFF1; border:1px solid #777; padding:5px; }
table.g td { border:1px solid #999; padding:5px; text-align:center; }
</style></head><body>
<div class="top">
  <div class="r">الجمهورية الجزائرية الديمقراطية الشعبية<br/>وزارة التربية الوطنية - التربية البدنية والرياضية</div>
  <div class="l"><b>السنة الدراسية :</b> ${_e(ctx.yearName)}<br/><b>المؤسسة :</b> ${_e(ctx.school)}<br/><span class="k">التاريخ :</span> ${stampNow()}</div>
</div>
<hr class="rule"/>
<h1>الحصيلة الرسمية لاختتام الفصل الدراسي • $termAr</h1>
<div class="info"><span>القسم : ${_e(cls.name)} (${_e(cls.level)})</span><span>التعداد : ${summary.students.length} تلميذ</span></div>
<div class="kpi">
<div><b>${summary.sessions}</b><span>الحصص المنجزة</span></div>
<div><b>${summary.evaluations}</b><span>التقييمات المنجزة</span></div>
<div><b style="color:#0D47A1">$avgTxt</b><span>معدل القسم</span></div>
<div><b style="color:#2E7D32">$passTxt</b><span>نسبة النجاح</span></div></div>
<table class="g"><tr><th>الرقم</th><th>اللقب والاسم</th><th>ج</th><th>الغياب</th><th>المواظبة</th><th>التقييم</th><th>المعدل</th><th>التقدير</th></tr>$body</table>
<div style="position:fixed;bottom:14mm;left:0;right:0">
<table style="width:100%;border-collapse:separate;border-spacing:8px 0"><tr>
<td class="sig" style="width:50%"><b>أستاذ(ة) التربية البدنية والرياضية :</b><span class="bot">الإمضاء والختم</span></td>
<td class="sig" style="width:50%"><b>${_e(ctx.directorLabel)} :</b><span class="bot">التأشيرة، الختم والتاريخ</span></td>
</tr></table>
<div style="display:flex;justify-content:space-between;font-size:7.5pt;color:#777;margin-top:6px"><span>الصفحة 1 / 1</span><span>تطبيق $_appName • الحصيلة الرسمية لاختتام الفصل</span></div>
</div>
</body></html>''';
    return Printing.convertHtml(html: html);
  }

  static String _appr(double a) =>
      a >= 16 ? 'Très Bien' : a >= 14 ? 'Bien' : a >= 12 ? 'Assez Bien' : a >= 10 ? 'Passable' : 'Insuffisant';

  static List<List<String>> termCsv(SchoolClass cls, Term term, TermSummary summary) => [
        ['Classe', 'Trimestre', 'Matricule', 'Élève', 'Sexe', 'Absences', 'Présence %', 'Évaluations', 'Moyenne /20', 'Appréciation'],
        for (final st in summary.students)
          [
            cls.name, term.name, st.student.studentNumber ?? '', st.student.fullName,
            st.student.gender ?? '', '${st.absences}',
            (st.presencePct ?? 100).toStringAsFixed(0), '${st.gradedEvals}',
            st.average?.toStringAsFixed(2) ?? '', st.average == null ? '' : _appr(st.average!),
          ],
      ];

  // ─────────────────────── Relevé de notes ───────────────────────

  static Future<Uint8List> gradeSheetPdf({
    required SchoolClass cls,
    required Term term,
    required List<EvaluationRow> evals,
    required Map<int, Map<int, double?>> matrix,
    required TermSummary summary,
    required PdfContext ctx,
  }) {
    final head = evals
        .map((r) => '<th>${_e(r.evaluation.title)}<br/><span style="font-weight:normal;font-size:7.5pt">/${r.evaluation.maxScore.toStringAsFixed(0)} • x${r.evaluation.coefficient}</span></th>')
        .join();
    final body = StringBuffer();
    for (final st in summary.students) {
      body.write('<tr><td>${_e(st.student.studentNumber ?? '')}</td><td style="text-align:right;font-weight:bold">${_e(st.student.fullName)}</td>');
      for (final r in evals) {
        final v = matrix[r.evaluation.id]?[st.student.id];
        body.write('<td>${v == null ? '-' : v.toStringAsFixed(2)}</td>');
      }
      body.write('<td><b>${st.average == null ? '-' : st.average!.toStringAsFixed(2)}</b></td></tr>');
    }
    final termAr = kTermNamesAr[(term.termNumber - 1).clamp(0, 2)];
    final html = '''
<html dir="rtl" lang="ar"><head><meta charset="utf-8"/><style>
@page { size: A4; margin: 12mm; }
$_baseCss
h1 { text-align:center; font-size:14pt; margin:16px 0 10px; }
.info { background:#F3F3F3; border:1px solid #ddd; border-radius:6px; padding:7px 10px; display:flex; justify-content:space-between; font-size:10pt; font-weight:bold; margin-bottom:10px; }
table.g { width:100%; border-collapse:collapse; font-size:9pt; }
table.g th { background:#ECEFF1; border:1px solid #777; padding:5px; }
table.g td { border:1px solid #999; padding:5px; text-align:center; }
</style></head><body>
<div class="top">
  <div class="r">الجمهورية الجزائرية الديمقراطية الشعبية<br/>وزارة التربية الوطنية - التربية البدنية والرياضية</div>
  <div class="l"><b>السنة الدراسية :</b> ${_e(ctx.yearName)}<br/><b>المؤسسة :</b> ${_e(ctx.school)}<br/><span class="k">التاريخ :</span> ${stampNow()}</div>
</div>
<hr class="rule"/>
<h1>كشف النقاط • $termAr</h1>
<div class="info"><span>القسم : ${_e(cls.name)} (${_e(cls.level)})</span><span>التعداد : ${summary.students.length} تلميذ</span></div>
<table class="g"><tr><th>الرقم</th><th>اللقب والاسم</th>$head<th>المعدل /20</th></tr>$body</table>
<div style="position:fixed;bottom:14mm;left:0;right:0">
<table style="width:100%;border-collapse:separate;border-spacing:8px 0"><tr>
<td class="sig" style="width:50%"><b>أستاذ(ة) التربية البدنية والرياضية :</b><span class="bot">الإمضاء والختم</span></td>
<td class="sig" style="width:50%"><b>${_e(ctx.directorLabel)} :</b><span class="bot">التأشيرة، الختم والتاريخ</span></td>
</tr></table></div>
</body></html>''';
    return Printing.convertHtml(html: html);
  }

  static List<List<String>> gradeSheetCsv(
    SchoolClass cls,
    Term term,
    List<EvaluationRow> evals,
    Map<int, Map<int, double?>> matrix,
    TermSummary summary,
  ) =>
      [
        ['Classe', 'Trimestre', 'Matricule', 'Élève', ...evals.map((r) => r.evaluation.title), 'Moyenne /20'],
        for (final st in summary.students)
          [
            cls.name, term.name, st.student.studentNumber ?? '', st.student.fullName,
            for (final r in evals) matrix[r.evaluation.id]?[st.student.id]?.toStringAsFixed(2) ?? '',
            st.average?.toStringAsFixed(2) ?? '',
          ],
      ];

  // ─────────────────────── Registre des élèves dispensés ───────────────────────

  static Future<Uint8List> exemptListPdf({
    required List<Map<String, Object?>> rows, // students + class_name
    required String levelLabel, // « Tous les niveaux » ou « 1AM »
    required PdfContext ctx,
  }) {
    final males = rows.where((r) => r['gender'] == 'M').length;
    final females = rows.where((r) => r['gender'] == 'F').length;
    final body = StringBuffer();
    var i = 0;
    for (final r in rows) {
      i++;
      final reason = (r['medical_reason'] as String?) ?? '';
      body.write('<tr><td>$i</td><td style="text-align:right;font-weight:bold">${_e('${r['last_name']} ${r['first_name']}')}</td>'
          '<td>${r['gender'] == 'F' ? 'أ' : 'ذ'}</td><td>${_e('${r['class_name']}')}</td>'
          '<td>${_e((r['student_number'] as String?) ?? '')}</td>'
          '<td>${_e(reason.isEmpty ? "Dispensé(e) d'EPS" : reason)}</td><td></td></tr>');
    }
    final html = '''
<html dir="rtl" lang="ar"><head><meta charset="utf-8"/><style>
@page { size: A4; margin: 12mm; }
$_baseCss
h1 { text-align:center; font-size:14pt; margin:14px 0 2px; }
.sub { text-align:center; color:#555; font-size:9pt; margin-bottom:10px; }
.info { background:#F3F3F3; border:1px solid #ddd; border-radius:6px; padding:7px 10px; display:flex; justify-content:space-between; font-size:9.5pt; font-weight:bold; margin-bottom:10px; }
table.g { width:100%; border-collapse:collapse; font-size:9pt; }
table.g th { background:#ECEFF1; border:1px solid #777; padding:5px; }
table.g td { border:1px solid #999; padding:6px 5px; text-align:center; }
</style></head><body>
<div class="top">
  <div class="r">الجمهورية الجزائرية الديمقراطية الشعبية<br/>وزارة التربية الوطنية<div class="sub" style="text-align:right">المادة : التربية البدنية والرياضية</div></div>
  <div class="l"><b>السنة الدراسية :</b> ${_e(ctx.yearName)}<br/><b>المؤسسة :</b> ${_e(ctx.school)}<br/><span class="k">التاريخ :</span> ${stampNow()}</div>
</div>
<hr class="rule"/>
<h1>السجل الرسمي للتلاميذ المعفيين من ممارسة التربية البدنية والرياضية</h1>
<div class="sub">سجل الإعفاءات الطبية الرسمية - وزارة التربية الوطنية</div>
<div class="info"><span>التصنيف : ${_e(levelLabel)}</span><span>مجموع المعفيين : ${rows.length} تلميذ</span><span>ذكور : $males • إناث : $females</span></div>
<table class="g"><tr><th>الرقم</th><th>اللقب والاسم</th><th>الجنس</th><th>القسم</th><th>رقم التسجيل</th><th>سبب الإعفاء / الشهادة</th><th>التأشيرة الطبية</th></tr>$body</table>
<div style="position:fixed;bottom:14mm;left:0;right:0">
<table style="width:100%;border-collapse:separate;border-spacing:8px 0"><tr>
<td class="sig" style="width:33%"><b>أستاذ(ة) التربية البدنية والرياضية :</b><span class="bot">الإمضاء والتاريخ</span></td>
<td class="sig" style="width:33%"><b>طبيب الصحة المدرسية (وحدة الكشف والمتابعة) :</b><span class="bot">الختم والتأشيرة الطبية</span></td>
<td class="sig" style="width:33%"><b>مدير المؤسسة :</b><span class="bot">الإمضاء والختم الرسمي</span></td>
</tr></table></div>
</body></html>''';
    return Printing.convertHtml(html: html);
  }

  static List<List<String>> exemptCsv(List<Map<String, Object?>> rows) => [
        ['Nom', 'Prénom', 'Sexe', 'Classe', 'Matricule', 'Motif'],
        for (final r in rows)
          [
            '${r['last_name']}', '${r['first_name']}', '${r['gender'] ?? ''}', '${r['class_name']}',
            '${r['student_number'] ?? ''}', '${r['medical_reason'] ?? "Dispensé(e) d'EPS"}',
          ],
      ];
}
