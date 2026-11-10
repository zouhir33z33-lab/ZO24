import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Écriture / partage de fichiers exportés (PDF, CSV, sauvegardes).
class FileSaver {
  /// « Enregistrer dans le téléphone » : Téléchargements/EPS_Assistant.
  /// Retourne le chemin réellement utilisé (repli sur le dossier de l'appli si refusé).
  static Future<String> saveToDownloads(String fileName, List<int> bytes) async {
    try {
      final dir = Directory('/storage/emulated/0/Download/EPS_Assistant');
      if (!await dir.exists()) await dir.create(recursive: true);
      final f = File(p.join(dir.path, fileName));
      await f.writeAsBytes(bytes);
      return f.path;
    } catch (_) {
      final base = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
      final f = File(p.join(base.path, fileName));
      await f.writeAsBytes(bytes);
      return f.path;
    }
  }

  /// « Choisir le dossier » : sélecteur de dossier du système. null si annulé.
  static Future<String?> saveToPickedFolder(String fileName, List<int> bytes) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return null;
    final f = File(p.join(dir, fileName));
    await f.writeAsBytes(bytes);
    return f.path;
  }

  static Future<void> share(String fileName, List<int> bytes, {String? text}) async {
    final tmp = await getTemporaryDirectory();
    final f = File(p.join(tmp.path, fileName));
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path)], text: text);
  }
}
