import 'package:flutter/material.dart';
import '../utils/niveau.dart';

/// Overlay animé affiché en fin de quiz lorsque le joueur monte de niveau.
///
/// Si le rang change également, l'animation est plus spectaculaire.
/// L'overlay se ferme automatiquement et appelle [onDismissed].
class NiveauUpOverlay extends StatefulWidget {
  final int niveauAvant;
  final int niveauApres;
  final int xpAvant;
  final int xpApres;
  final VoidCallback onDismissed;

  const NiveauUpOverlay({
    super.key,
    required this.niveauAvant,
    required this.niveauApres,
    required this.xpAvant,
    required this.xpApres,
    required this.onDismissed,
  });

  @override
  State<NiveauUpOverlay> createState() => _NiveauUpOverlayState();
}

class _NiveauUpOverlayState extends State<NiveauUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final bool _estRangUp;
  late final Rang _rangAvant;
  late final Rang _rangApres;

  bool _showNouveauNiveau = false;
  bool _showRangBadge = false;

  @override
  void initState() {
    super.initState();
    _rangAvant = NiveauHelper.rangDepuisNiveau(widget.niveauAvant);
    _rangApres = NiveauHelper.rangDepuisNiveau(widget.niveauApres);
    _estRangUp = _rangApres != _rangAvant;

    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _estRangUp ? 4200 : 3200),
    );

    _ctrl.addListener(() {
      if (!_showNouveauNiveau && _ctrl.value > 0.28) {
        if (mounted) setState(() => _showNouveauNiveau = true);
      }
      if (_estRangUp && !_showRangBadge && _ctrl.value > 0.48) {
        if (mounted) setState(() => _showRangBadge = true);
      }
    });

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDismissed();
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ─── Animations globales ─────────────────────────────────────────────────

  Animation<double> get _opacity => TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
        TweenSequenceItem(
          tween: ConstantTween(1.0),
          weight: _estRangUp ? 74 : 70,
        ),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 18),
      ]).animate(_ctrl);

  Animation<double> get _scale => TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.82, end: 1.06)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 8,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.06, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 4,
        ),
        TweenSequenceItem(
          tween: ConstantTween(1.0),
          weight: _estRangUp ? 70 : 66,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.94)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 18,
        ),
      ]).animate(_ctrl);

  // Barre XP : remonte de progAvant → 1.0 entre 10 % et 35 % de l'animation.
  double _xpBarValue(double progAvant, double progApres) {
    const fillStart = 0.10;
    const fillEnd = 0.35;
    if (!_showNouveauNiveau) {
      if (_ctrl.value < fillStart) return progAvant;
      if (_ctrl.value < fillEnd) {
        final t = (_ctrl.value - fillStart) / (fillEnd - fillStart);
        return progAvant + (1.0 - progAvant) * t;
      }
      return 1.0; // barre pleine avant l'affichage du nouveau niveau
    }
    return progApres; // après la montée, afficher la progression dans le nouveau niveau
  }

  @override
  Widget build(BuildContext context) {
    final progAvant = NiveauHelper.progressionNiveau(widget.xpAvant);
    final progApres = NiveauHelper.progressionNiveau(widget.xpApres);
    final couleurRang = NiveauHelper.rangCouleur(_rangApres);
    final couleurAccent = _estRangUp ? couleurRang : const Color(0xFFB45309);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Center(
            child: Transform.scale(
              scale: _scale.value,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: couleurAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: couleurAccent.withValues(alpha: 0.28),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── Titre ──────────────────────────────────────────
                      Text(
                        '🎉 NIVEAU SUPÉRIEUR !',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: couleurAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Niveaux avant → après ───────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _NiveauBadge(
                            niveau: widget.niveauAvant,
                            estPasse: _showNouveauNiveau,
                            couleur: couleurAccent,
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            child: AnimatedOpacity(
                              opacity: _showNouveauNiveau ? 1.0 : 0.25,
                              duration: const Duration(milliseconds: 350),
                              child: Text(
                                '→',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: couleurAccent,
                                ),
                              ),
                            ),
                          ),
                          _NiveauBadge(
                            niveau: widget.niveauApres,
                            estActif: _showNouveauNiveau,
                            couleur: couleurAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // ─── Barre XP ────────────────────────────────────────
                      _BarreXp(
                        valeur:
                            _xpBarValue(progAvant, progApres),
                        pleine: !_showNouveauNiveau && _ctrl.value >= 0.35,
                        niveauApres: widget.niveauApres,
                        xpApres: widget.xpApres,
                        showNew: _showNouveauNiveau,
                        couleur: couleurAccent,
                      ),

                      // ─── Badge de rang (rang-up seulement) ───────────────
                      if (_estRangUp) ...[
                        const SizedBox(height: 20),
                        AnimatedOpacity(
                          opacity: _showRangBadge ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: AnimatedScale(
                            scale: _showRangBadge ? 1.0 : 0.7,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            child: _RangBadge(
                              rangAvant: _rangAvant,
                              rangApres: _rangApres,
                              couleur: couleurRang,
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
      },
    );
  }
}

// ─── Sous-widgets ─────────────────────────────────────────────────────────────

class _NiveauBadge extends StatelessWidget {
  final int niveau;
  final bool estPasse;
  final bool estActif;
  final Color couleur;

  const _NiveauBadge({
    required this.niveau,
    this.estPasse = false,
    this.estActif = false,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: estActif
            ? couleur
            : estPasse
                ? const Color(0xFFF3F4F6)
                : couleur.withValues(alpha: 0.12),
        border: Border.all(
          color: estPasse ? const Color(0xFFD1D5DB) : couleur,
          width: estActif ? 3 : 1.5,
        ),
        boxShadow: estActif
            ? [
                BoxShadow(
                  color: couleur.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '$niveau',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: estActif
                ? Colors.white
                : estPasse
                    ? const Color(0xFF9CA3AF)
                    : couleur,
          ),
        ),
      ),
    );
  }
}

class _BarreXp extends StatelessWidget {
  final double valeur;
  final bool pleine;
  final int niveauApres;
  final int xpApres;
  final bool showNew;
  final Color couleur;

  const _BarreXp({
    required this.valeur,
    required this.pleine,
    required this.niveauApres,
    required this.xpApres,
    required this.showNew,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final xpDans = NiveauHelper.xpDansNiveauActuel(xpApres);
    final xpNecessaire = NiveauHelper.xpPourNiveauSuivant(niveauApres);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: valeur.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(
              pleine ? const Color(0xFFEAB308) : couleur,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          showNew
              ? '$xpDans / $xpNecessaire XP  ·  Niveau $niveauApres'
              : pleine
                  ? 'Niveau atteint !'
                  : '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RangBadge extends StatelessWidget {
  final Rang rangAvant;
  final Rang rangApres;
  final Color couleur;

  const _RangBadge({
    required this.rangAvant,
    required this.rangApres,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            couleur.withValues(alpha: 0.14),
            couleur.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            '✨ NOUVEAU RANG !',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: couleur,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${NiveauHelper.rangEmoji(rangApres)} ${NiveauHelper.rangNom(rangApres)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: couleur,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Précédent : ${NiveauHelper.rangEmoji(rangAvant)} ${NiveauHelper.rangNom(rangAvant)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: couleur.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
