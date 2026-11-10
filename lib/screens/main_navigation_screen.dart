import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/periods.dart';
import '../providers/core_providers.dart';
import '../providers/timetable_providers.dart';
import '../utils/day_utils.dart';
import 'attendance_screen.dart';
import 'classes_screen.dart';
import 'settings_screen.dart';
import 'sheets_screen.dart';
import 'timetable_screen.dart';

/// Coque de navigation : 4 onglets (ordre dans la vidéo, de droite à gauche en
/// arabe : Emploi du temps, Classes, Fiches, Paramètres).
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  static const _tabs = <({String key, IconData icon, IconData selected})>[
    (key: 'nav_timetable', icon: Icons.schedule_outlined, selected: Icons.schedule),
    (key: 'nav_classes', icon: Icons.groups_outlined, selected: Icons.groups),
    (key: 'nav_sheets', icon: Icons.folder_outlined, selected: Icons.folder),
    (key: 'nav_settings', icon: Icons.settings_outlined, selected: Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoDetect());
  }

  /// Si l'option est activée et qu'une séance est en cours, propose d'ouvrir l'appel.
  Future<void> _autoDetect() async {
    if (!ref.read(autoDetectProvider)) return;
    final d = await ref.read(todayDataProvider.future);
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    for (final s in d.slots) {
      if (minutesOf(s.startTime) <= nowMin && nowMin < minutesOf(s.endTime)) {
        final cls = d.classes[s.classId];
        if (cls == null || !mounted) return;
        final tr = ref.read(trProvider);
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('tl_live_session')),
            content: Text('${cls.name} • ${s.startTime} - ${s.endTime}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('tl_start_roll'))),
            ],
          ),
        );
        if (go == true && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(schoolClass: cls)));
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navIndexProvider);
    final tr = ref.watch(trProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          TimetableScreen(),
          ClassesScreen(),
          SheetsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(navIndexProvider.notifier).state = i,
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selected),
              label: tr(t.key),
            ),
        ],
      ),
    );
  }
}
