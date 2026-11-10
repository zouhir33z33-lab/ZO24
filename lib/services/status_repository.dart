import '../constants/default_statuses.dart';
import '../models/models.dart';
import 'database_helper.dart';

class StatusRepository {
  Future<List<AttendanceStatus>> all() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('attendance_statuses', orderBy: 'sort_order, id');
    return rows.map(AttendanceStatus.fromMap).toList();
  }

  Future<int> insert(AttendanceStatus s) async {
    final db = await DatabaseHelper.instance.database;
    final n = (await db.rawQuery('SELECT COALESCE(MAX(sort_order),0)+1 AS n FROM attendance_statuses')).first['n'] as int;
    final m = s.toMap()..['sort_order'] = n;
    return db.insert('attendance_statuses', m);
  }

  Future<void> update(AttendanceStatus s) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('attendance_statuses', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  /// Supprime un statut personnalisé non utilisé. Retourne false s'il est utilisé.
  Future<bool> deleteIfUnused(int id) async {
    final db = await DatabaseHelper.instance.database;
    final used = await db.rawQuery('SELECT COUNT(*) AS n FROM attendances WHERE status_id = ?', [id]);
    if ((used.first['n'] as int) > 0) return false;
    await db.delete('attendance_statuses', where: 'id = ? AND is_system = 0', whereArgs: [id]);
    return true;
  }

  /// Restaure les libellés/couleurs des statuts par défaut ; recrée ceux qui manquent.
  Future<void> resetDefaults() async {
    final db = await DatabaseHelper.instance.database;
    var order = 0;
    for (final d in kDefaultStatuses) {
      final values = {
        'label_fr': d.labelFr,
        'label_ar': d.labelAr,
        'label_en': d.labelEn,
        'color_hex': d.colorHex,
        'icon_name': d.icon,
        'counts_as_absence': d.countsAsAbsence ? 1 : 0,
        'sort_order': order++,
      };
      final n = await db.update('attendance_statuses', values, where: 'code = ?', whereArgs: [d.code]);
      if (n == 0) {
        await db.insert('attendance_statuses', {
          'code': d.code,
          ...values,
          'is_system': 1,
        });
      }
    }
  }
}
