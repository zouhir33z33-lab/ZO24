import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../constants/levels.dart';
import '../providers/core_providers.dart';
import '../themes/app_colors.dart';

/// Premier lancement : choix de la langue et du cycle d'enseignement.
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  final bool settingsMode; // true : ouvert depuis les paramètres (avec barre d'application)
  const OnboardingScreen({super.key, required this.onDone, this.settingsMode = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  EducationCycle? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.settingsMode) _selected = ref.read(cycleProvider);
  }

  static const _cycleColors = {
    EducationCycle.primary: Color(0xFFEF6C00),
    EducationCycle.middle: Color(0xFF1565C0),
    EducationCycle.secondary: Color(0xFF2E7D32),
    EducationCycle.mixed: Color(0xFF8D6E63),
  };
  static const _cycleIcons = {
    EducationCycle.primary: Icons.child_care,
    EducationCycle.middle: Icons.school,
    EducationCycle.secondary: Icons.account_balance,
    EducationCycle.mixed: Icons.all_inclusive,
  };

  Future<void> _confirm() async {
    final c = _selected;
    if (c == null) return;
    await ref.read(cycleProvider.notifier).setCycle(c);
    await ref.read(sharedPrefsProvider).setBool(SettingsKeys.onboardingDone, true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final lang = ref.watch(localeProvider).languageCode;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.settingsMode
          ? AppBar(title: Text(tr('settings_cycle_title')))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  for (final l in const ['en', 'ar', 'fr']) ...[
                    _LangChip(
                      label: tr('lang_$l'),
                      selected: lang == l,
                      onTap: () => ref.read(localeProvider.notifier).setLanguage(l),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  if (!widget.settingsMode) Center(
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sports_soccer, size: 38, color: AppColors.primary),
                    ),
                  ),
                  if (!widget.settingsMode) const SizedBox(height: 16),
                  if (!widget.settingsMode) Text(tr('welcome_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  if (!widget.settingsMode) const SizedBox(height: 8),
                  Text(tr('onb_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  const SizedBox(height: 20),
                  for (final cd in kCycles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CycleCard(
                        data: cd,
                        color: _cycleColors[cd.cycle]!,
                        icon: _cycleIcons[cd.cycle]!,
                        title: tr('cycle_${cd.code}'),
                        subtitle: tr('cycle_${cd.code}_sub'),
                        selected: _selected == cd.cycle,
                        onTap: () => setState(() => _selected = cd.cycle),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed: _selected == null ? null : _confirm,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(widget.settingsMode ? tr('confirm_btn') : tr('confirm_start')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(tr('onb_hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade100,
          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.primary : Colors.black54,
            )),
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final CycleData data;
  final Color color;
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _CycleCard({
    required this.data,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : Colors.white,
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? color : Colors.grey.shade400, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                for (final l in data.levels.reversed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
