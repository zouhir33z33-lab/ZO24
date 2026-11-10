import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'database_helper.dart';

class SheetRepository {
  Future<List<PedagogicalSheet>> all() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('pedagogical_sheets', orderBy: 'created_at DESC, id DESC');
    return rows.map(PedagogicalSheet.fromMap).toList();
  }

  Future<int> insert(PedagogicalSheet s) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('pedagogical_sheets', s.toMap());
  }

  Future<void> update(PedagogicalSheet s) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('pedagogical_sheets', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> delete(PedagogicalSheet s) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('pedagogical_sheets', where: 'id = ?', whereArgs: [s.id]);
    final path = s.filePath;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  /// Copie un fichier choisi (PDF / image) dans le dossier privé de l'application.
  Future<String> importFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(dir.path, 'sheets'));
    if (!await target.exists()) await target.create(recursive: true);
    final name = '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final dest = p.join(target.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  }
}
