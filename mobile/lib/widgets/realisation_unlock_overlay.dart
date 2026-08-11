import 'package:flutter/material.dart';

import '../models/realisation.dart';
import '../theme/app_theme.dart';

/// Popup centrée non-bloquante affichée lors du déblocage d'une réalisation.
/// Utilise OverlayEntry ; le parent doit insérer via [insereDans] et le supprimer
/// via [onDismissed].
class RealisationUnlockOverlay extends StatefulWidget {
  final Realisation realisation;
  final VoidCallback onDismissed;

  const RealisationUnlockOverlay({
    super.key,
    required this.realisation,
    required this.onDismissed,
  });

  @override
  State<RealisationUnlockOverlay> createState() =>
      _RealisationUnlockOverlayState();
}

class _RealisationUnlockOverlayState extends State<RealisationUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  static const _duree = Duration(milliseconds: 2800);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _duree);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.08), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.00), weight: 6),
      TweenSequenceItem(tween: ConstantTween(1.00), weight: 66),
      TweenSequenceItem(tween: Tween(begin: 1.00, end: 0.90), weight: 18),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 74),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 18),
    ]).animate(_ctrl);

    _ctrl.forward().whenComplete(widget.onDismissed);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.realisation;
    final couleur = Realisation.rareteColor(r.rarete);

    return Positioned.fill(
      child: FadeTransition(
        opacity: _opacity,
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 36),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: EduCleColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: couleur, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: couleur.withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✨ RÉALISATION DÉBLOQUÉE !',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: couleur,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '🏅',
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.nom,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: couleur,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: EduCleColors.textSecondary,
                    ),
                  ),
                  if (r.recompensePieces > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: couleur.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${r.recompensePieces} 🪙',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: couleur,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${Realisation.rareteEmoji(r.rarete)} ${Realisation.rareteLibelle(r.rarete)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: couleur,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
