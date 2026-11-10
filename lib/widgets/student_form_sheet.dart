import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/students_provider.dart';
import '../themes/app_colors.dart';
import 'app_bottom_sheet.dart';

/// Ajout (existing == null) ou modification d'un élève.
Future<void> showStudentFormSheet(
  BuildContext context,
  WidgetRef ref, {
  required SchoolClass schoolClass,
  Student? existing,
}) {
  final tr = ref.read(trProvider);
  return showAppSheet(
    context,
    icon: existing == null ? Icons.person_add_alt_1 : Icons.edit_note,
    title: tr(existing == null ? 'add_student' : 'edit_student'),
    subtitle: schoolClass.name,
    builder: (_) => _StudentForm(schoolClass: schoolClass, existing: existing),
  );
}

class _StudentForm extends ConsumerStatefulWidget {
  final SchoolClass schoolClass;
  final Student? existing;
  const _StudentForm({required this.schoolClass, this.existing});
  @override
  ConsumerState<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<_StudentForm> {
  late final _last = TextEditingController(text: widget.existing?.lastName ?? '');
  late final _first = TextEditingController(text: widget.existing?.firstName ?? '');
  late final _num = TextEditingController(text: widget.existing?.studentNumber ?? '');
  late final _pai = TextEditingController(text: widget.existing?.paiConditions ?? '');
  late final _paiInstr = TextEditingController(text: widget.existing?.paiInstructions ?? '');
  late final _medical = TextEditingController(text: widget.existing?.medicalReason ?? '');
  late String _gender = widget.existing?.gender ?? 'M';
  late bool _exempt = widget.existing?.isExempt ?? false;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_last, _first, _num, _pai, _paiInstr, _medical]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon, {String? error}) => InputDecoration(
        labelText: label,
        suffixIcon: Icon(icon, size: 20),
        errorText: error,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_last.text.trim().isEmpty || _first.text.trim().isEmpty) return;
    final tr = ref.read(trProvider);
    final notifier = ref.read(studentsProvider(widget.schoolClass.id!).notifier);
    final nav = Navigator.of(context);
    final ctx = context;
    final regNo = _num.text.trim();
    final e = widget.existing;
    if (e == null) {
      await notifier.add(Student(
        classId: widget.schoolClass.id!,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        gender: _gender,
        studentNumber: regNo.isEmpty ? null : regNo,
      ));
    } else {
      await notifier.edit(Student(
        id: e.id,
        classId: e.classId,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        gender: _gender,
        studentNumber: regNo.isEmpty ? null : regNo,
        isExempt: _exempt,
        medicalReason: _medical.text.trim().isEmpty ? null : _medical.text.trim(),
        paiConditions: _pai.text.trim(),
        paiInstructions: _paiInstr.text.trim(),
        sortOrder: e.sortOrder,
        isActive: e.isActive,
      ));
    }
    nav.pop();
    if (ctx.mounted) {
      showSuccessSnack(ctx, tr(e == null ? 'student_added' : 'student_updated'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final editing = widget.existing != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('identity_section'),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _last,
                textInputAction: TextInputAction.next,
                decoration: _dec(tr('last_name'), Icons.person_outline,
                    error: _submitted && _last.text.trim().isEmpty ? tr('required_field') : null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _first,
                textInputAction: TextInputAction.next,
                decoration: _dec(tr('first_name'), Icons.badge_outlined,
                    error: _submitted && _first.text.trim().isEmpty ? tr('required_field') : null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _num,
          decoration: _dec(tr('matricule'), Icons.tag),
        ),
        const SizedBox(height: 14),
        Text(tr('gender'), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _GenderBox(
              label: tr('boy'), icon: Icons.male, color: AppColors.primary,
              selected: _gender == 'M', onTap: () => setState(() => _gender = 'M'))),
            const SizedBox(width: 10),
            Expanded(child: _GenderBox(
              label: tr('girl'), icon: Icons.female, color: const Color(0xFFD81B60),
              selected: _gender == 'F', onTap: () => setState(() => _gender = 'F'))),
          ],
        ),
        if (editing) ...[
          const SizedBox(height: 14),
          // NB : ces deux blocs (PAI, dispense) existent dans la base d'origine
          // (colonnes pai_*, is_exempt) ; leur mise en page exacte dans la feuille
          // de modification n'est que partiellement visible dans la vidéo.
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.health_and_safety, color: Color(0xFFC62828)),
            title: Text(tr('pai_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [
              TextField(controller: _pai, maxLines: 2, decoration: _dec(tr('pai_conditions'), Icons.medical_information_outlined)),
              const SizedBox(height: 10),
              TextField(controller: _paiInstr, maxLines: 2, decoration: _dec(tr('pai_instructions'), Icons.notes)),
              const SizedBox(height: 10),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('exempt_switch')),
            value: _exempt,
            onChanged: (v) => setState(() => _exempt = v),
          ),
          if (_exempt)
            TextField(controller: _medical, decoration: _dec(tr('medical_reason'), Icons.healing)),
        ],
        const SizedBox(height: 16),
        SheetButtons(
          cancelLabel: tr('cancel'),
          confirmLabel: tr(editing ? 'save' : 'add'),
          confirmIcon: editing ? Icons.check : Icons.add,
          onConfirm: _submit,
        ),
      ],
    );
  }
}

class _GenderBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _GenderBox({
    required this.label, required this.icon, required this.color,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : Colors.grey.shade50,
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold,
                color: selected ? color : Colors.black54)),
          ],
        ),
      ),
    );
  }
}
