import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/disciplines.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../themes/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';

/// « Nouvelle Fiche EPS » : titre, discipline, format (texte / PDF / image).
class SheetFormScreen extends ConsumerStatefulWidget {
  final PedagogicalSheet? existing;
  const SheetFormScreen({super.key, this.existing});
  @override
  ConsumerState<SheetFormScreen> createState() => _SheetFormScreenState();
}

class _SheetFormScreenState extends ConsumerState<SheetFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _text = TextEditingController(text: widget.existing?.textContent ?? '');
  late String _type = widget.existing?.fileType ?? 'TEXT';
  late String? _discipline = widget.existing?.sportDiscipline;
  String? _filePath;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _filePath = widget.existing?.filePath;
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: _type == 'PDF' ? FileType.custom : FileType.image,
      allowedExtensions: _type == 'PDF' ? ['pdf'] : null,
    );
    final path = res?.files.single.path;
    if (path != null) {
      final stored = await ref.read(sheetRepositoryProvider).importFile(path);
      setState(() => _filePath = stored);
    }
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_title.text.trim().isEmpty || _discipline == null) return;
    final tr = ref.read(trProvider);
    final repo = ref.read(sheetRepositoryProvider);
    final sheet = PedagogicalSheet(
      id: widget.existing?.id,
      title: _title.text.trim(),
      sportDiscipline: _discipline,
      fileType: _type,
      filePath: _type == 'TEXT' ? null : _filePath,
      textContent: _text.text.trim().isEmpty ? null : _text.text.trim(),
    );
    final nav = Navigator.of(context);
    final ctx = context;
    if (widget.existing == null) {
      await repo.insert(sheet);
    } else {
      await repo.update(sheet);
    }
    nav.pop();
    if (ctx.mounted) showSuccessSnack(ctx, tr('sh_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nouvelle Fiche EPS' : 'Modifier la Fiche'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Enregistrer'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.85)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Card(
            icon: Icons.edit_note,
            title: 'Informations générales',
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: tr('sh_title_label'),
                    prefixIcon: const Icon(Icons.title),
                    errorText: _submitted && _title.text.trim().isEmpty ? 'Veuillez renseigner un titre' : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _discipline,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Discipline / APSA *',
                    errorText: _submitted && _discipline == null ? 'Veuillez choisir une discipline' : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    for (final d in kDisciplines)
                      DropdownMenuItem(
                        value: d.fr,
                        child: Row(children: [
                          Icon(d.icon, size: 18, color: d.color),
                          const SizedBox(width: 8),
                          Text(lang == 'ar' ? '${d.fr}' : d.fr),
                        ]),
                      ),
                  ],
                  onChanged: (v) => setState(() => _discipline = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            icon: Icons.description_outlined,
            title: 'Format du document',
            child: Row(
              children: [
                _FormatTile(
                  label: tr('sh_fmt_image'), icon: Icons.image_outlined, color: const Color(0xFF8E24AA),
                  selected: _type == 'IMAGE', onTap: () => setState(() { _type = 'IMAGE'; _filePath = null; }),
                ),
                const SizedBox(width: 8),
                _FormatTile(
                  label: tr('sh_fmt_pdf'), icon: Icons.picture_as_pdf_outlined, color: const Color(0xFFD32F2F),
                  selected: _type == 'PDF', onTap: () => setState(() { _type = 'PDF'; _filePath = null; }),
                ),
                const SizedBox(width: 8),
                _FormatTile(
                  label: tr('sh_fmt_text'), icon: Icons.article_outlined, color: const Color(0xFF1565C0),
                  selected: _type == 'TEXT', onTap: () => setState(() => _type = 'TEXT'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_type == 'TEXT')
            _Card(
              icon: Icons.description,
              title: tr('sh_content'),
              child: TextField(
                controller: _text,
                minLines: 8,
                maxLines: 20,
                decoration: InputDecoration(
                  hintText: tr('sh_content_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else ...[
            _Card(
              icon: _type == 'PDF' ? Icons.picture_as_pdf : Icons.image,
              title: tr(_type == 'PDF' ? 'sh_attached_pdf' : 'sh_attached_image'),
              child: InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_filePath == null ? Icons.upload_file : Icons.check_circle,
                          size: 34, color: _filePath == null ? AppColors.primary : AppColors.present),
                      const SizedBox(height: 6),
                      Text(
                        _filePath == null
                            ? tr(_type == 'PDF' ? 'sh_import_pdf' : 'sh_import_image')
                            : _filePath!.split('/').last,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              icon: Icons.notes,
              title: tr('sh_notes'),
              child: TextField(
                controller: _text,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: tr('sh_notes_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FormatTile({required this.label, required this.icon, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.grey.shade50,
            border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : Colors.grey),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold,
                      color: selected ? color : Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
