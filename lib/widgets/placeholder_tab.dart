import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';

/// Contenu temporaire d'un onglet (remplacé en phase 5).
class PlaceholderTab extends ConsumerWidget {
  final String titleKey;
  const PlaceholderTab({super.key, required this.titleKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(titleKey))),
      body: Center(child: Text(tr('coming_soon'))),
    );
  }
}
