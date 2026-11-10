import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

/// Feuille modale du style de l'original : poignée, icône + titre/sous-titre,
/// bouton de fermeture rond, coins supérieurs arrondis.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      Text(subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

/// Barre de boutons « Annuler / Valider » (valider = 2/3 de la largeur).
class SheetButtons extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final IconData confirmIcon;
  final VoidCallback onConfirm;
  const SheetButtons({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: onConfirm,
            icon: Icon(confirmIcon, size: 18),
            label: Text(confirmLabel),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.present,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
}
