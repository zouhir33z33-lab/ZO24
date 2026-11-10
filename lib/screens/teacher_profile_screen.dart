import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';
import '../providers/teacher_provider.dart';
import '../themes/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';

/// « المعلومات الشخصية » : identité administrative de l'enseignant.
class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});
  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  final _last = TextEditingController();
  final _first = TextEditingController();
  final _school = TextEditingController();
  final _place = TextEditingController();
  final _rank = TextEditingController();
  final _grade = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    for (final c in [_last, _first, _school, _place, _rank, _grade]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final tr = ref.read(trProvider);
    await ref.read(teacherProvider.notifier).save(TeacherProfile(
          lastName: _last.text.trim(),
          firstName: _first.text.trim(),
          school: _school.text.trim(),
          place: _place.text.trim(),
          rank: _rank.text.trim(),
          grade: _grade.text.trim(),
        ));
    if (!mounted) return;
    final ctx = context;
    Navigator.pop(ctx);
    showSuccessSnack(ctx, tr('tp_saved'));
  }

  Widget _field(TextEditingController c, String label, String hint, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final p = ref.watch(teacherProvider).valueOrNull;
    if (!_init && p != null) {
      _last.text = p.lastName;
      _first.text = p.firstName;
      _school.text = p.school;
      _place.text = p.place;
      _rank.text = p.rank;
      _grade.text = p.grade;
      _init = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('tp_title')),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0277BD), Color(0xFF00838F)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Professeur EPS / Coach',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(tr('tp_role'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  backgroundImage: AssetImage('assets/images/coach_icon.png'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(tr('tp_hint'), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          _field(_last, tr('last_name').replaceAll(' *', ''), tr('tp_ph_last'), Icons.badge_outlined),
          _field(_first, tr('first_name').replaceAll(' *', ''), tr('tp_ph_first'), Icons.person_outline),
          _field(_school, tr('tp_school'), tr('tp_ph_school'), Icons.account_balance_outlined),
          _field(_place, tr('tp_place'), tr('tp_ph_place'), Icons.place_outlined),
          _field(_rank, tr('tp_rank'), '13', Icons.military_tech_outlined),
          _field(_grade, tr('tp_grade'), '05', Icons.stairs_outlined),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(tr('save')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}
