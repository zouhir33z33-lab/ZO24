import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

enum SortMode { original, lastAsc, lastDesc, firstAsc, firstDesc, femaleFirst, maleFirst, numberAsc, numberDesc }

/// Feuille « ترتيب التلاميذ » (9 options relevées dans la vidéo).
Future<SortMode?> showSortSheet(
  BuildContext context, {
  required SortMode current,
  required String title,
  required Map<SortMode, (String, String)> labels, // mode -> (titre, sous-titre)
}) {
  const icons = {
    SortMode.original: Icons.format_list_bulleted,
    SortMode.lastAsc: Icons.check,
    SortMode.lastDesc: Icons.sort_by_alpha,
    SortMode.firstAsc: Icons.text_fields,
    SortMode.firstDesc: Icons.text_fields,
    SortMode.femaleFirst: Icons.female,
    SortMode.maleFirst: Icons.male,
    SortMode.numberAsc: Icons.format_list_numbered,
    SortMode.numberDesc: Icons.format_list_numbered_rtl,
  };
  return showModalBottomSheet<SortMode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                const Icon(Icons.sort, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ]),
            ),
            const Divider(height: 18),
            for (final m in SortMode.values)
              ListTile(
                dense: true,
                leading: current == m
                    ? const CircleAvatar(radius: 14, backgroundColor: AppColors.primary, child: Icon(Icons.check, size: 16, color: Colors.white))
                    : CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade200, child: Icon(icons[m], size: 15, color: Colors.grey.shade700)),
                title: Text(labels[m]!.$1,
                    style: TextStyle(fontWeight: FontWeight.bold, color: current == m ? AppColors.primary : Colors.black87)),
                subtitle: Text(labels[m]!.$2, style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    ),
  );
}
