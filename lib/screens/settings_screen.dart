import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/academic_providers.dart';
import '../providers/classes_provider.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/teacher_provider.dart';
import '../providers/timetable_providers.dart';
import '../themes/app_colors.dart';
import '../themes/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../providers/incident_providers.dart';
import '../providers/students_provider.dart';
import '../utils/file_saver.dart';
import 'incidents_screen.dart';
import 'onboarding_screen.dart';
import 'status_manager_screen.dart';
import 'teacher_profile_screen.dart';
import 'term_closing_screen.dart';

/// Onglet « الإعدادات ». (Sécurité PIN, sauvegarde/restauration et journal
/// des incidents seront ajoutés avec leurs écrans respectifs.)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});


  String _stamp() {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${t(n.month)}${t(n.day)}_${t(n.hour)}${t(n.minute)}';
  }

  Future<void> _backupSheet(BuildContext context, WidgetRef ref) {
    final tr = ref.read(trProvider);
    final name = 'EPS_Backup_${_stamp()}.zip';
    Future<List<int>> build() => ref.read(backupServiceProvider).createBackup();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('bk_sheet_title'), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(tr('bk_sheet_sub'), textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.drive_folder_upload, color: Color(0xFF6A1B9A)),
                title: Text(tr('ex_folder')),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await FileSaver.saveToPickedFolder(name, await build());
                  if (path != null && context.mounted) showSuccessSnack(context, '${tr('ex_saved')} : $path');
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline, color: AppColors.present),
                title: Text(tr('bk_to_phone')),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await FileSaver.saveToDownloads(name, await build());
                  if (context.mounted) showSuccessSnack(context, '${tr('ex_saved')} : $path');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppColors.primary),
                title: Text(tr('bk_share')),
                onTap: () async {
                  Navigator.pop(ctx);
                  await FileSaver.share(name, await build());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final tr = ref.read(trProvider);
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    final path = res?.files.single.path;
    if (path == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 34),
        title: Text(tr('bk_restore_q')),
        content: Text(tr('bk_restore_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('bk_restore_btn'))),
        ],
      ),
    );
    if (ok != true) return;
    final good = await ref.read(backupServiceProvider).restore(await File(path).readAsBytes());
    if (!context.mounted) return;
    if (!good) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('bk_invalid'))));
      return;
    }
    ref.invalidate(activeYearProvider);
    ref.invalidate(termsProvider);
    ref.invalidate(classesProvider);
    ref.invalidate(slotsProvider);
    ref.invalidate(statusesProvider);
    ref.invalidate(sheetsProvider);
    ref.invalidate(teacherProvider);
    ref.invalidate(incidentsProvider);
    ref.invalidate(studentsProvider);
    ref.invalidate(todayDataProvider);
    showSuccessSnack(context, tr('bk_restored'));
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.absent, size: 36),
        title: Text(tr('rs_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('rs_confirm_q'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(tr('rs_list')),
              const SizedBox(height: 8),
              Text(tr('rs_kept')),
              const SizedBox(height: 8),
              Text(tr('rs_final'),
                  style: const TextStyle(color: AppColors.absent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(tr('rs_confirm')),
            style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(resetServiceProvider).resetClassesAndStudents();
      await ref.read(classesProvider.notifier).refresh();
      ref.invalidate(slotsProvider);
      ref.invalidate(todayDataProvider);
      if (context.mounted) showSuccessSnack(context, tr('rs_done'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final theme = ref.watch(themeKindProvider);
    final cycle = ref.watch(cycleProvider);
    final teacher = ref.watch(teacherProvider).valueOrNull;
    final year = ref.watch(activeYearProvider).valueOrNull;
    final autoDetect = ref.watch(autoDetectProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('nav_settings'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Profil de l'enseignant
          _Tile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherProfileScreen())),
            leading: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF263238),
              backgroundImage: AssetImage('assets/images/coach_icon.png'),
            ),
            title: tr('tp_role'),
            subtitle: (teacher == null || teacher.isEmpty) ? tr('tp_tap_register') : teacher.fullName,
            subtitleColor: AppColors.primary,
            extra: year == null
                ? null
                : Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.present.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text('● ${tr('active_word')} ${year.name}',
                        style: const TextStyle(fontSize: 11, color: AppColors.present, fontWeight: FontWeight.bold)),
                  ),
          ),
          const SizedBox(height: 10),
          // Cycle
          _Tile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => OnboardingScreen(settingsMode: true, onDone: () => Navigator.pop(ctx)),
              ),
            ),
            leading: _IconBox(icon: Icons.school, color: AppColors.primary),
            title: cycle == null ? '—' : '${tr('cycle_${cycle.name}')} ${cycle == EducationCycle.mixed ? '' : tr('cycle_${cycle.name}_sub')}',
            caption: tr('settings_cycle_title'),
          ),
          const SizedBox(height: 14),
          _Header(tr('settings_lang_display')),
          Row(
            children: [
              for (final l in const ['fr', 'ar', 'en'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => ref.read(localeProvider.notifier).setLanguage(l),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: lang == l ? AppColors.primary.withOpacity(0.12) : Colors.white,
                          border: Border.all(color: lang == l ? AppColors.primary : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          const {'fr': 'Français', 'ar': 'العربية', 'en': 'English'}[l]!,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: lang == l ? AppColors.primary : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Header(tr('settings_appearance')),
          Row(
            children: [
              _ThemeCard(kind: AppThemeKind.national, label: tr('theme_national'), selected: theme == AppThemeKind.national),
              _ThemeCard(kind: AppThemeKind.dark, label: tr('theme_dark'), selected: theme == AppThemeKind.dark),
              _ThemeCard(kind: AppThemeKind.light, label: tr('theme_light'), selected: theme == AppThemeKind.light),
            ],
          ),
          const SizedBox(height: 14),
          _Tile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusManagerScreen())),
            leading: _IconBox(icon: Icons.checklist, color: AppColors.orange),
            title: tr('st_manage_title'),
            subtitle: tr('st_manage_sub'),
            caption: tr('st_roll_states'),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _IconBox(icon: Icons.timer_outlined, color: AppColors.present),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('auto_detect'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(tr('auto_detect_hint'), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Switch(
                  value: autoDetect,
                  onChanged: (v) => ref.read(autoDetectProvider.notifier).set(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Tile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermClosingScreen())),
            leading: _IconBox(icon: Icons.lock_outline, color: const Color(0xFF00897B)),
            title: tr('terms_closing_title'),
            tint: const Color(0xFFE0F2F1),
          ),
          const SizedBox(height: 10),
          _Tile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentsScreen())),
            leading: _IconBox(icon: Icons.emergency, color: AppColors.absent),
            title: tr('inc_title'),
            subtitle: 'Déclarations officielles & fiches d\'incident EPS (PDF)',
            tint: const Color(0xFFFFEBEE),
          ),
          const SizedBox(height: 18),
          _Header(tr('bk_header')),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: const Color(0xFF90CAF9)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('bk_card_title'), textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0277BD), fontSize: 15)),
                const SizedBox(height: 6),
                Text(tr('bk_card_desc'), style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => _backupSheet(context, ref),
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(tr('bk_save_btn')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _restore(context, ref),
                  icon: const Icon(Icons.restore),
                  label: Text(tr('bk_restore_label')),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Header(tr('reset_header')),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              border: Border.all(color: const Color(0xFFEF9A9A)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.absent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tr('reset_title'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.absent)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(tr('reset_desc'), style: const TextStyle(fontSize: 11.5, color: Color(0xFFB71C1C))),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => _reset(context, ref),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(tr('reset_btn')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.absent,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('EPS Assistant • v${AppConstants.appVersion}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      );
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      );
}

class _Tile extends StatelessWidget {
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? subtitle, caption;
  final Color? subtitleColor, tint;
  final Widget? extra;
  const _Tile({
    required this.onTap, required this.leading, required this.title,
    this.subtitle, this.caption, this.subtitleColor, this.tint, this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tint ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption != null)
                    Text(caption!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 12, color: subtitleColor ?? Colors.grey.shade600)),
                  if (extra != null) extra!,
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends ConsumerWidget {
  final AppThemeKind kind;
  final String label;
  final bool selected;
  const _ThemeCard({required this.kind, required this.label, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = switch (kind) {
      AppThemeKind.light => [const Color(0xFF1565C0), Colors.white, const Color(0xFFE3EAF3)],
      AppThemeKind.dark => [const Color(0xFF263238), const Color(0xFF37474F), const Color(0xFF455A64)],
      AppThemeKind.national => [AppColors.nationalGreen, Colors.white, AppColors.nationalRed],
    };
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => ref.read(themeKindProvider.notifier).setKind(kind),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: kind == AppThemeKind.dark ? const Color(0xFF1E2833) : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      for (final c in colors)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
