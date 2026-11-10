import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../themes/app_colors.dart';
import '../utils/file_saver.dart';
import 'app_bottom_sheet.dart' show showSuccessSnack;

/// Feuille d'export (style de l'original) : aperçu/impression, choisir le dossier,
/// enregistrer dans le téléphone, partager.
Future<void> showExportSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String fileName,
  required Future<Uint8List> Function() buildPdf,
  Future<Uint8List> Function()? buildSpreadsheet, // CSV/Excel (optionnel)
  String spreadsheetName = 'export.xlsx',
  required Map<String, String> labels, // clés : preview, previewSub, folder, folderSub, phone, phoneSub, share, shareSub, sheet, sheetSub, saved
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            _Option(
              icon: Icons.print, color: AppColors.primary,
              title: labels['preview']!, subtitle: labels['previewSub']!,
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await buildPdf();
                await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
              },
            ),
            _Option(
              icon: Icons.drive_folder_upload, color: const Color(0xFF6A1B9A),
              title: labels['folder']!, subtitle: labels['folderSub']!,
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await buildPdf();
                final path = await FileSaver.saveToPickedFolder(fileName, bytes);
                if (path != null && context.mounted) showSuccessSnack(context, '${labels['saved']} : $path');
              },
            ),
            _Option(
              icon: Icons.download_for_offline, color: AppColors.present,
              title: labels['phone']!, subtitle: labels['phoneSub']!,
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await buildPdf();
                final path = await FileSaver.saveToDownloads(fileName, bytes);
                if (context.mounted) showSuccessSnack(context, '${labels['saved']} : $path');
              },
            ),
            _Option(
              icon: Icons.picture_as_pdf, color: AppColors.absent,
              title: labels['share']!, subtitle: labels['shareSub']!,
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await buildPdf();
                await FileSaver.share(fileName, bytes);
              },
            ),
            if (buildSpreadsheet != null)
              _Option(
                icon: Icons.table_chart, color: const Color(0xFF2E7D32),
                title: labels['sheet']!, subtitle: labels['sheetSub']!,
                onTap: () async {
                  Navigator.pop(ctx);
                  final bytes = await buildSpreadsheet();
                  final path = await FileSaver.saveToDownloads(spreadsheetName, bytes);
                  if (context.mounted) showSuccessSnack(context, '${labels['saved']} : $path');
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Option({required this.icon, required this.color, required this.title,
      required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.chevron_left, color: Colors.grey.shade400),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(subtitle, textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Libellés de la feuille d'export à partir de la fonction de traduction.
Map<String, String> exportLabels(String Function(String) tr) => {
      'preview': tr('ex_preview'), 'previewSub': tr('ex_preview_sub'),
      'folder': tr('ex_folder'), 'folderSub': tr('ex_folder_sub'),
      'phone': tr('ex_phone'), 'phoneSub': tr('ex_phone_sub'),
      'share': tr('ex_share'), 'shareSub': tr('ex_share_sub'),
      'sheet': tr('ex_sheet'), 'sheetSub': tr('ex_sheet_sub'),
      'saved': tr('ex_saved'),
    };
