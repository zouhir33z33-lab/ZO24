import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/disciplines.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/timetable_providers.dart';
import '../themes/app_colors.dart';
import 'sheet_detail_screen.dart';
import 'sheet_form_screen.dart';

/// Onglet « الجذاذات » : bibliothèque de fiches pédagogiques.
class SheetsScreen extends ConsumerStatefulWidget {
  const SheetsScreen({super.key});
  @override
  ConsumerState<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends ConsumerState<SheetsScreen> {
  final _search = TextEditingController();
  String? _discipline; // null = tout

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _create() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SheetFormScreen()))
      .then((_) => ref.invalidate(sheetsProvider));

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final all = ref.watch(sheetsProvider).valueOrNull ?? const <PedagogicalSheet>[];
    final q = _search.text.trim().toLowerCase();
    final shown = all.where((s) {
      if (_discipline != null && s.sportDiscipline != _discipline) return false;
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          (s.textContent ?? '').toLowerCase().contains(q) ||
          (s.sportDiscipline ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('nav_sheets')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(sheetsProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(tr('sh_new')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: tr('sh_search'),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                suffixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _Chip(label: tr('filter_all'), color: AppColors.primary,
                    selected: _discipline == null, onTap: () => setState(() => _discipline = null)),
                for (final d in kDisciplines)
                  _Chip(
                    label: lang == 'ar' ? d.ar : d.fr,
                    color: d.color,
                    selected: _discipline == d.fr,
                    onTap: () => setState(() => _discipline = d.fr),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(tr('sh_none'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(tr('sh_none_hint'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add),
                            label: Text(tr('sh_create_btn')),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = shown[i];
                      final d = disciplineByFr(s.sportDiscipline);
                      final color = d?.color ?? AppColors.primary;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SheetDetailScreen(sheet: s)),
                        ).then((_) => ref.invalidate(sheetsProvider)),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.chevron_left, color: Colors.grey.shade400),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(s.title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        _Tag(text: s.fileType, color: const Color(0xFFF9A825)),
                                        if (d != null) _Tag(text: lang == 'ar' ? d.ar : d.fr, color: color),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade600),
                                          const SizedBox(width: 3),
                                          Text(_dateOf(s.createdAt),
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        ]),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                    color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: Icon(d?.icon ?? Icons.description, color: color),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _dateOf(String? created) {
    if (created == null || created.length < 10) return '';
    final p = created.substring(0, 10).split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : color)),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
