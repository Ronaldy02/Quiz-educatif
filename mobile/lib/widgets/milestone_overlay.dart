import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Overlay non-bloquant affiché lors d'un jalon de série ou de Bombardement.
///
/// S'insère via Overlay.of(context).insert() ; se supprime automatiquement
/// à la fin de l'animation via [onDismissed].  L'appelant doit entourer
/// l'instance d'un [IgnorePointer] pour que les interactions passent au travers.
class MilestoneOverlay extends StatefulWidget {
  final int palier;
  final bool estBombardement;
  final VoidCallback onDismissed;

  const MilestoneOverlay({
    super.key,
    required this.palier,
    this.estBombardement = false,
    required this.onDismissed,
  });

  /// Durée totale de l'animation selon le palier (spec §1, tableau durées).
  static Duration dureePourPalier(int palier) {
    if (palier >= 20) return const Duration(milliseconds: 2200);
    if (palier >= 15) return const Duration(milliseconds: 1650);
    if (palier >= 10) return const Duration(milliseconds: 1400);
    return const Duration(milliseconds: 1050);
  }

  @override
  State<MilestoneOverlay> createState() => _MilestoneOverlayState();
}

class _MilestoneOverlayState extends State<MilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MilestoneOverlay.dureePourPalier(widget.palier),
    );

    // Scale : 0.80 → 1.15 (spring) → 1.0 (stable) → 0.85 (disparition)
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.80, end: 1.15), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.00), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.00), weight: 62),
      TweenSequenceItem(tween: Tween(begin: 1.00, end: 0.85), weight: 18),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Opacity : fade-in rapide → stable → fade-out
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 72),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 18),
    ]).animate(_ctrl);

    _ctrl.forward().whenComplete(widget.onDismissed);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _emoji {
    if (widget.estBombardement) {
      if (widget.palier >= 20) return '💥🏆';
      if (widget.palier >= 15) return '💥⚡';
      return '💥';
    }
    // Spec : 🔥 ×(palier÷5) pour les séries
    return '🔥' * (widget.palier ~/ 5).clamp(1, 4);
  }

  String get _titre {
    if (widget.estBombardement) {
      return '${widget.palier} BONNES\nRÉPONSES !';
    }
    return 'SÉRIE DE ${widget.palier} !';
  }

  int get _coins {
    if (widget.estBombardement) {
      switch (widget.palier) {
        case 20: return 25;
        case 15: return 18;
        case 10: return 12;
        case 6:  return 5;
        default: return 0;
      }
    }
    switch (widget.palier) {
      case 20: return 25;
      case 15: return 18;
      case 10: return 10;
      case 5:  return 5;
      default: return 0;
    }
  }

  Color get _couleur {
    if (widget.palier >= 20) return const Color(0xFF7C3AED); // violet
    if (widget.palier >= 15) return const Color(0xFFDC2626); // rouge
    if (widget.palier >= 10) return const Color(0xFFEA580C); // orange
    return const Color(0xFFF59E0B);                          // ambre
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _opacity,
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 48),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: EduCleColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _couleur, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: _couleur.withValues(alpha: 0.3),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _emoji,
                    style: TextStyle(
                      fontSize: widget.palier >= 15 ? 40 : 34,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _titre,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _couleur,
                      height: 1.2,
                    ),
                  ),
                  if (_coins > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _couleur.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+$_coins 🪙',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _couleur,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
