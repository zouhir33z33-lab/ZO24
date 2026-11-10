import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/levels.dart';
import '../models/models.dart';
import '../providers/classes_provider.dart';
import '../providers/core_providers.dart';
import '../themes/app_colors.dart';
import 'app_bottom_sheet.dart';

/// Feuille « Nouveau groupe pédagogique » (création) ou modification d'une classe.
Future<void> showClassFormSheet(BuildContext context, WidgetRef ref, {SchoolClass? existing}) {
  final tr = ref.read(trProvider);
  return showAppSheet(
    context,
    icon: Icons.school,
    title: tr(existing == null ? 'create_class_title' : 'edit_class'),
    subtitle: tr('new_group'),
    builder: (_) => _ClassForm(existing: existing),
  );
}

class _ClassForm extends ConsumerStatefulWidget {
  final SchoolClass? existing;
  const _ClassForm({this.existing});
  @override
  ConsumerState<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends ConsumerState<_ClassForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  String? _level;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _level = widget.existing?.level;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final name = _name.text.trim();
    if (name.isEmpty || _level == null) return;
    final tr = ref.read(trProvider);
    final notifier = ref.read(classesProvider.notifier);
    final messenger = Navigator.of(context);
    final ctx = context;
    if (widget.existing == null) {
      final count = ref.read(classesProvider).valueOrNull?.length ?? 0;
      await notifier.add(
        name: name,
        level: _level!,
        colorCode: kClassColors[count % kClassColors.length],
      );
    } else {
      await notifier.edit(widget.existing!, name: name, level: _level!);
    }
    messenger.pop();
    if (ctx.mounted) {
      showSuccessSnack(
          ctx, tr(widget.existing == null ? 'class_created' : 'class_updated'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final cycle = ref.watch(cycleProvider);
    final levels = cycle == null ? kLevels.values.toList() : levelsOf(cycle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('class_info'),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: .5)),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          autofocus: widget.existing == null,
          decoration: InputDecoration(
            labelText: tr('class_name'),
            hintText: '1م1 ، 2م3 ...',
            suffixIcon: const Icon(Icons.menu_book_outlined),
            errorText: _submitted && _name.text.trim().isEmpty ? tr('required_field') : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(tr('class_level'), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: [
            for (final l in levels)
              _LevelBox(
                info: l,
                selected: _level == l.code,
                onTap: () => setState(() => _level = l.code),
              ),
          ],
        ),
        if (_submitted && _level == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tr('required_field'),
                style: const TextStyle(color: AppColors.absent, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        SheetButtons(
          cancelLabel: tr('cancel'),
          confirmLabel: tr(widget.existing == null ? 'create_class' : 'save'),
          confirmIcon: widget.existing == null ? Icons.add : Icons.check,
          onConfirm: _submit,
        ),
      ],
    );
  }
}

class _LevelBox extends StatelessWidget {
  final LevelInfo info;
  final bool selected;
  final VoidCallback onTap;
  const _LevelBox({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? info.color.withOpacity(0.08) : Colors.grey.shade50,
          border: Border.all(
              color: selected ? info.color : Colors.grey.shade300, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(info.code,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: selected ? info.color : Colors.black87)),
            Text(info.ar,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: selected ? info.color : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
