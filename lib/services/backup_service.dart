import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

/// Sauvegarde complète = base SQLite + fichiers des fiches (PDF/images), en ZIP.
/// Restauration : remplace la base et les fichiers. Format propre à cette
/// reconstruction (le format du ZIP de l'original n'est pas connu).
class BackupService {
  static const String _dbEntry = 'eps_assistant.db';
  static const String _sheetsPrefix = 'sheets/';

  Future<List<int>> createBackup() async {
    final dbFile = File(await DatabaseHelper.instance.dbPath);
    final archive = Archive();
    // forcer l'écriture du journal avant la copie
    final db = await DatabaseHelper.instance.database;
    await db.execute('PRAGMA wal_checkpoint(FULL)').catchError((_) {});
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile(_dbEntry, dbBytes.length, dbBytes));

    final docs = await getApplicationDocumentsDirectory();
    final sheets = Directory(p.join(docs.path, 'sheets'));
    if (await sheets.exists()) {
      await for (final e in sheets.list()) {
        if (e is File) {
          final b = await e.readAsBytes();
          archive.addFile(ArchiveFile('$_sheetsPrefix${p.basename(e.path)}', b.length, b));
        }
      }
    }
    return ZipEncoder().encode(archive)!;
  }

  /// Retourne false si le fichier n'est pas une sauvegarde valide.
  Future<bool> restore(List<int> zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      return false;
    }
    final dbEntry = archive.files.where((f) => f.isFile && f.name == _dbEntry).firstOrNull;
    if (dbEntry == null) return false;

    final dbPath = await DatabaseHelper.instance.dbPath;
    await DatabaseHelper.instance.close();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('$dbPath$suffix');
      if (await f.exists()) await f.delete();
    }
    await File(dbPath).writeAsBytes(dbEntry.content as List<int>);

    final docs = await getApplicationDocumentsDirectory();
    final sheets = Directory(p.join(docs.path, 'sheets'));
    if (!await sheets.exists()) await sheets.create(recursive: true);
    for (final f in archive.files) {
      if (f.isFile && f.name.startsWith(_sheetsPrefix)) {
        await File(p.join(sheets.path, p.basename(f.name))).writeAsBytes(f.content as List<int>);
      }
    }
    final db = await DatabaseHelper.instance.database; // rouvre
    final rows = await db.query('pedagogical_sheets', columns: ['id', 'file_path']);
    for (final r in rows) {
      final old = r['file_path'] as String?;
      if (old != null && old.isNotEmpty) {
        await db.update('pedagogical_sheets', {'file_path': p.join(sheets.path, p.basename(old))},
            where: 'id = ?', whereArgs: [r['id']]);
      }
    }
    return true;
  }
}
