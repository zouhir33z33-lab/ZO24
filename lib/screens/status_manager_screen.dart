import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/timetable_providers.dart';
import '../themes/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';

const List<String> kStatusPalette = [
  '#2E7D32', '#C62828', '#D84315', '#880E4F', '#EF6C00', '#6A1B9A', '#0277BD', '#1565C0',
  '#AD1457', '#37474F', '#4E342E', '#00796B', '#455A64', '#283593', '#F9A825', '#00838F',
];

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

/// « حالات الحضور والغياب » : liste, modification, création, restauration.
class StatusManagerScreen extends ConsumerWidget {
  const StatusManagerScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, AttendanceStatus? s) {
    final tr = ref.read(trProvider);
    return showAppSheet(
      context,
      icon: s == null ? Icons.add : Icons.edit,
      title: tr(s == null ? 'st_new' : 'st_edit'),
      subtitle: s?.labelAr ?? '',
      builder: (_) => _StatusForm(existing: s),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    // L'écran d'origine liste les 9 statuts (« Présent » inclus).
    final list = ref.watch(statusesProvider).valueOrNull ?? const <AttendanceStatus>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('st_title')),
        actions: [
          IconButton(
            tooltip: tr('st_reset'),
            icon: const Icon(Icons.restore),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(tr('st_reset_q')),
                  content: Text(tr('st_reset_msg')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(statusRepositoryProvider).resetDefaults();
                ref.invalidate(statusesProvider);
                if (context.mounted) showSuccessSnack(context, tr('st_updated'));
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(tr('st_add')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = list[i];
          final color = _hex(s.colorHex);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(width: 24, height: 24, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.label(lang)} (${s.labelAr})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (s.countsAsAbsence ? AppColors.absent : AppColors.present).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.countsAsAbsence ? tr('st_counts') : tr('st_not_counts'),
                            style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.bold,
                              color: s.countsAsAbsence ? AppColors.absent : AppColors.present,
                            ),
                          ),
                        ),
                        if (s.isSystem)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('• ${tr('st_system')}', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                          ),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                  onPressed: () => _edit(context, ref, s),
                ),
                if (!s.isSystem)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 22, color: AppColors.absent),
                    onPressed: () async {
                      final ok = await ref.read(statusRepositoryProvider).deleteIfUnused(s.id!);
                      ref.invalidate(statusesProvider);
                      if (context.mounted) {
                        if (ok) {
                          showSuccessSnack(context, tr('st_deleted'));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('st_in_use'))));
                        }
                      }
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusForm extends ConsumerStatefulWidget {
  final AttendanceStatus? existing;
  const _StatusForm({this.existing});
  @override
  ConsumerState<_StatusForm> createState() => _StatusFormState();
}

class _StatusFormState extends ConsumerState<_StatusForm> {
  late final _fr = TextEditingController(text: widget.existing?.labelFr ?? '');
  late final _ar = TextEditingController(text: widget.existing?.labelAr ?? '');
  late final _en = TextEditingController(text: widget.existing?.labelEn ?? '');
  late String _color = widget.existing?.colorHex ?? kStatusPalette[6];
  late bool _counts = widget.existing?.countsAsAbsence ?? false;
  bool _submitted = false;

  @override
  void dispose() {
    _fr.dispose();
    _ar.dispose();
    _en.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_fr.text.trim().isEmpty || _ar.text.trim().isEmpty || _en.text.trim().isEmpty) return;
    final tr = ref.read(trProvider);
    final repo = ref.read(statusRepositoryProvider);
    final e = widget.existing;
    final s = AttendanceStatus(
      id: e?.id,
      code: e?.code ?? 'CUSTOM_${DateTime.now().millisecondsSinceEpoch}',
      labelFr: _fr.text.trim(),
      labelAr: _ar.text.trim(),
      labelEn: _en.text.trim(),
      colorHex: _color,
      iconName: e?.iconName,
      countsAsAbsence: _counts,
      isSystem: e?.isSystem ?? false,
      sortOrder: e?.sortOrder ?? 0,
    );
    if (e == null) {
      await repo.insert(s);
    } else {
      await repo.update(s);
    }
    ref.invalidate(statusesProvider);
    if (!mounted) return;
    final ctx = context;
    Navigator.pop(ctx);
    showSuccessSnack(ctx, tr('st_updated'));
  }

  InputDecoration _dec(String label, IconData icon, TextEditingController c) => InputDecoration(
        labelText: label,
        suffixIcon: Icon(icon, size: 20),
        errorText: _submitted && c.text.trim().isEmpty ? ref.read(trProvider)('required_field') : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('LIBELLÉS DU STATUT',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 10),
        TextField(controller: _fr, decoration: _dec(tr('st_label_fr'), Icons.translate, _fr)),
        const SizedBox(height: 10),
        TextField(controller: _ar, decoration: _dec(tr('st_label_ar'), Icons.language, _ar)),
        const SizedBox(height: 10),
        TextField(controller: _en, decoration: _dec(tr('st_label_en'), Icons.public, _en)),
        const SizedBox(height: 14),
        Text(tr('st_color'), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final c in kStatusPalette)
                InkWell(
                  onTap: () => setState(() => _color = c),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _hex(c), shape: BoxShape.circle),
                    child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          tileColor: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(14)),
          title: Text(tr('st_counts_switch'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(tr('st_counts_hint'), style: const TextStyle(fontSize: 11)),
          value: _counts,
          onChanged: (v) => setState(() => _counts = v),
        ),
        const SizedBox(height: 16),
        SheetButtons(
          cancelLabel: tr('cancel'),
          confirmLabel: tr('save'),
          confirmIcon: Icons.check,
          onConfirm: _save,
        ),
      ],
    );
  }
}
