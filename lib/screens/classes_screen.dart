import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/levels.dart';
import '../models/models.dart';
import '../providers/classes_provider.dart';
import '../providers/students_provider.dart';
import '../providers/core_providers.dart';
import '../themes/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/class_form_sheet.dart';
import 'attendance_screen.dart';
import 'class_detail_screen.dart';
import 'evaluations_screen.dart';
import 'exempt_students_screen.dart';
import 'global_student_search_screen.dart';
import 'term_attendance_record_screen.dart';
import 'term_closing_screen.dart';

/// Onglet « الأقسام » : filtres par niveau, cartes de classe, création.
class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});
  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  String? _levelFilter; // null = tous

  /// « حذف / إفراغ القسم » : deux options (vider les élèves / supprimer la classe).
  Future<void> _deleteSheet(SchoolClass c) async {
    final tr = ref.read(trProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                InkWell(onTap: () => Navigator.pop(ctx), child: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFEEEEEE), child: Icon(Icons.close, size: 18))),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(tr('del_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text(c.name, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
                const SizedBox(width: 10),
                const CircleAvatar(radius: 18, backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.warning_amber_rounded, color: AppColors.absent)),
              ]),
              const SizedBox(height: 14),
              _DelOption(
                color: const Color(0xFFF59E0B), bg: const Color(0xFFFFF8E1), icon: Icons.cleaning_services,
                title: tr('del_empty'), sub: tr('del_empty_sub'), onTap: () => Navigator.pop(ctx, 'empty')),
              const SizedBox(height: 10),
              _DelOption(
                color: AppColors.absent, bg: const Color(0xFFFFEBEE), icon: Icons.delete_forever,
                title: tr('del_all'), sub: tr('del_all_sub'), onTap: () => Navigator.pop(ctx, 'all')),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(choice == 'empty' ? 'del_empty' : 'delete_class_q')),
        content: Text(tr(choice == 'empty' ? 'del_empty_confirm' : 'delete_class_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete'), style: const TextStyle(color: AppColors.absent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (choice == 'empty') {
      await ref.read(classesProvider.notifier).emptyClass(c.id!);
      ref.invalidate(studentsProvider);
      if (mounted) showSuccessSnack(context, tr('del_empty_done'));
    } else {
      await ref.read(classesProvider.notifier).remove(c.id!);
      if (mounted) showSuccessSnack(context, tr('class_deleted'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final classesAsync = ref.watch(classesProvider);
    final all = classesAsync.valueOrNull ?? const <SchoolClass>[];
    final levelsPresent = <String>[];
    for (final c in all) {
      if (!levelsPresent.contains(c.level)) levelsPresent.add(c.level);
    }
    final shown = _levelFilter == null
        ? all
        : all.where((c) => c.level == _levelFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('classes_title')),
        // Icônes de la barre (recherche / sac médical) : rôles déduits des icônes de la vidéo.
        actions: [
          IconButton(
            tooltip: tr('ex_students_title'),
            icon: const Icon(Icons.medical_services_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExemptStudentsScreen())),
          ),
          IconButton(
            tooltip: tr('gs_title'),
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GlobalStudentSearchScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showClassFormSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: Text(tr('new_class')),
      ),
      body: Column(
        children: [
          Container(
            height: 52,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FilterChip(
                  label: tr('all_classes'),
                  selected: _levelFilter == null,
                  onTap: () => setState(() => _levelFilter = null),
                ),
                for (final l in levelsPresent)
                  _FilterChip(
                    label: kLevels[l]?.ar ?? l,
                    selected: _levelFilter == l,
                    onTap: () => setState(() => _levelFilter = l),
                  ),
              ],
            ),
          ),
          Expanded(
            child: classesAsync.isLoading && all.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                    ? _EmptyState(
                        text: tr('no_classes_level'),
                        buttonLabel: tr('create_class'),
                        onPressed: () => showClassFormSheet(context, ref),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ClassCard(
                          c: shown[i],
                          onOpen: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ClassDetailScreen(schoolClass: shown[i]))),
                          onEdit: () => showClassFormSheet(context, ref, existing: shown[i]),
                          onDelete: () => _deleteSheet(shown[i]),
                          onRecord: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TermAttendanceRecordScreen(schoolClass: shown[i]))),
                          onGrades: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EvaluationsScreen(schoolClass: shown[i]))),
                          onClosing: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TermClosingScreen(initialClass: shown[i]))),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFFE3EAF3),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.primary,
              )),
        ),
      ),
    );
  }
}

PopupMenuItem<String> _item(String v, IconData i, String label, Color c) => PopupMenuItem(
      value: v,
      child: Row(children: [
        Icon(i, size: 18, color: c),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: v == 'delete' ? AppColors.absent : Colors.black87, fontWeight: FontWeight.bold)),
      ]),
    );

class _DelOption extends StatelessWidget {
  final Color color, bg;
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const _DelOption({required this.color, required this.bg, required this.icon, required this.title, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(Icons.chevron_left, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Text(sub, textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
            ])),
            const SizedBox(width: 10),
            CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
          ]),
        ),
      );
}

class _ClassCard extends ConsumerWidget {
  final SchoolClass c;
  final VoidCallback onOpen, onEdit, onDelete, onRecord, onGrades, onClosing;
  const _ClassCard({required this.c, required this.onOpen, required this.onEdit, required this.onDelete,
      required this.onRecord, required this.onGrades, required this.onClosing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final stripe = colorFromHex(c.colorCode);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: stripe),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (v) {
                            switch (v) {
                              case 'edit':
                                onEdit();
                              case 'record':
                                onRecord();
                              case 'grades':
                                onGrades();
                              case 'closing':
                                onClosing();
                              default:
                                onDelete();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: _MenuRow(Icons.edit, tr('edit'), Colors.black87)),
                            PopupMenuItem(value: 'record', child: _MenuRow(Icons.grid_view, tr('cm_record'), AppColors.primary)),
                            PopupMenuItem(value: 'grades', child: _MenuRow(Icons.assignment_outlined, tr('cm_grades'), AppColors.orange)),
                            PopupMenuItem(value: 'closing', child: _MenuRow(Icons.lock_outline, tr('cm_closing'), AppColors.present)),
                            PopupMenuItem(value: 'delete', child: _MenuRow(Icons.delete, tr('cm_delete'), AppColors.absent)),
                          ],
                        ),
                        Expanded(
                          child: Text(c.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: stripe.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(c.level,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stripe)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        InkWell(
                          onTap: onOpen,
                          child: Row(children: [
                            Text(tr('manage_students'),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            const Icon(Icons.chevron_left, size: 16, color: AppColors.primary),
                          ]),
                        ),
                        const Spacer(),
                        Icon(Icons.groups_2_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${c.studentCount} ${tr('students_count')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => AttendanceScreen(schoolClass: c))),
                      icon: const Icon(Icons.how_to_reg, size: 18),
                      label: Text(tr('call_roll')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.present,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text, buttonLabel;
  final VoidCallback onPressed;
  const _EmptyState({required this.text, required this.buttonLabel, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _MenuRow(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]);
}
