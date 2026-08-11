import 'package:flutter/services.dart';

/// Wrapper autour de HapticFeedback (Flutter natif, pas de package externe).
/// Les méthodes sont des no-ops sur les plateformes sans retour haptique.
class HapticService {
  HapticService._();

  static Future<void> reponseCorrecte() => HapticFeedback.lightImpact();
  static Future<void> reponseIncorrecte() => HapticFeedback.mediumImpact();

  /// Intensité proportionnelle au palier de série (spec §16).
  static Future<void> serie(int palier) {
    if (palier >= 20) return HapticFeedback.heavyImpact();
    if (palier >= 10) return HapticFeedback.mediumImpact();
    return HapticFeedback.lightImpact();
  }

  /// Pattern distinct pour le Quiz parfait (spec §16) : court → court → long.
  static Future<void> perfect() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }
}
