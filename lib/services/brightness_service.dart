import 'package:flutter/services.dart';

/// Luminosité de l'écran (bouton « شمس » du mode terrain). Implémentée par un petit
/// canal natif Android (voir scripts/MainActivity.kt) : sans aucune dépendance tierce.
class BrightnessService {
  static const MethodChannel _channel = MethodChannel('eps/brightness');

  /// Luminosité maximale pour la fenêtre de l'application.
  static Future<void> max() async {
    try {
      await _channel.invokeMethod('max');
    } catch (_) {}
  }

  /// Rend le contrôle de la luminosité au système.
  static Future<void> reset() async {
    try {
      await _channel.invokeMethod('reset');
    } catch (_) {}
  }
}
