import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/disciplines.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../themes/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';
import 'sheet_form_screen.dart';

/// Consultation d'une fiche : en-tête (discipline, type, date) puis texte, aperçu PDF ou image.
class SheetDetailScreen extends ConsumerWidget {
  final PedagogicalSheet sheet;
  const SheetDetailScreen({super.key, required this.sheet});

  static String _date(String? created) {
    if (created == null || created.length < 10) return '';
    final p = created.substring(0, 10).split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final d = disciplineByFr(sheet.sportDiscipline);
    final color = d?.color ?? AppColors.primary;
    final path = sheet.filePath;
    final fileOk = path != null && File(path).existsSync();
    final typeKey = switch (sheet.fileType) {
      'PDF' => 'sh_type_pdf',
      'IMAGE' => 'sh_type_image',
      _ => 'sh_type_text',
    };

    final header = Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3EAF3),
        border: Border.all(color: const Color(0xFF9FB6D3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text(tr(typeKey), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text(d?.fr ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 17,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(d?.icon ?? Icons.description, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(_date(sheet.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
        ],
      ),
    );

    Widget textCard(String text) => Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.55)),
        );

    Widget body;
    if (sheet.fileType == 'PDF' && fileOk) {
      body = Column(children: [
        header,
        if ((sheet.textContent ?? '').isNotEmpty) textCard(sheet.textContent!),
        Expanded(
          child: PdfPreview(
            build: (_) => File(path).readAsBytes(),
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
          ),
        ),
      ]);
    } else if (sheet.fileType == 'IMAGE' && fileOk) {
      body = Column(children: [
        header,
        Expanded(child: InteractiveViewer(child: Center(child: Image.file(File(path))))),
        if ((sheet.textContent ?? '').isNotEmpty) textCard(sheet.textContent!),
      ]);
    } else if (sheet.fileType == 'TEXT') {
      body = ListView(children: [header, textCard(sheet.textContent ?? '')]);
    } else {
      body = Column(children: [header, Expanded(child: Center(child: Text(tr('sh_file_missing'))))]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(sheet.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(tr('sh_delete_q')),
                  content: Text(tr('sh_delete_msg')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(tr('delete'), style: const TextStyle(color: AppColors.absent)),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(sheetRepositoryProvider).delete(sheet);
                if (context.mounted) {
                  Navigator.pop(context);
                  showSuccessSnack(context, tr('sh_deleted'));
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => SheetFormScreen(existing: sheet)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              if (sheet.fileType != 'TEXT' && fileOk) {
                await Share.shareXFiles([XFile(path)], text: sheet.title);
              } else {
                await Share.share('${sheet.title}\n\n${sheet.textContent ?? ''}');
              }
            },
          ),
        ],
      ),
      body: body,
    );
  }
}
