import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/classes_provider.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../themes/app_colors.dart';
import 'class_detail_screen.dart';

/// Recherche d'élèves dans toutes les classes (nom, prénom ou matricule) ;
/// mode [onlyExempt] = liste des élèves dispensés (certificat médical).
/// NB : l'écran d'origine n'est pas montré dans la vidéo ; disposition simple.
class GlobalStudentSearchScreen extends ConsumerStatefulWidget {
  final bool onlyExempt;
  const GlobalStudentSearchScreen({super.key, this.onlyExempt = false});
  @override
  ConsumerState<GlobalStudentSearchScreen> createState() => _GlobalStudentSearchScreenState();
}

class _GlobalStudentSearchScreenState extends ConsumerState<GlobalStudentSearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, Object?>> _rows = [];

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final r = await ref.read(studentRepositoryProvider).search(_ctrl.text, onlyExempt: widget.onlyExempt);
    if (mounted) setState(() => _rows = r);
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final classes = ref.watch(classesProvider).valueOrNull ?? const <SchoolClass>[];
    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.onlyExempt ? 'ex_students_title' : 'gs_title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              autofocus: !widget.onlyExempt,
              onChanged: (_) => _run(),
              decoration: InputDecoration(
                hintText: tr('search_student'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Expanded(
            child: _rows.isEmpty
                ? Center(child: Text(tr('no_students')))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = _rows[i];
                      final girl = r['gender'] == 'F';
                      final tint = girl ? const Color(0xFFD81B60) : AppColors.primary;
                      final reason = (r['medical_reason'] as String?) ?? '';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tint.withOpacity(0.12),
                            child: Text(girl ? 'F' : 'G',
                                style: TextStyle(color: tint, fontWeight: FontWeight.bold)),
                          ),
                          title: Text('${r['last_name']} ${r['first_name']}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${r['class_name']} (${r['class_level']})${reason.isEmpty ? '' : ' • $reason'}'),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () {
                            final matches = classes.where((c) => c.id == r['class_id']);
                            if (matches.isEmpty) return;
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ClassDetailScreen(schoolClass: matches.first)));
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
