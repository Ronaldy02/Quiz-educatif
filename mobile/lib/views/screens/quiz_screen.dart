import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/quiz_controller.dart';
import '../../models/parametre_partie.dart';
import '../../models/quiz.dart';
import '../../theme/app_theme.dart';
import 'resultat_screen.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final ParametrePartie mode;

  const QuizScreen({super.key, required this.quiz, required this.mode});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Timer? _timer;
  bool _repondu = false;
  String? _reponseChoisie;
  bool? _correcte;
  bool _termine = false;
  List<String> _choixMelanges = [];

  // Bonus availability (une fois par quiz)
  bool _eliminationDispo = true;
  bool _cinqCinquanteDispo = true;
  bool _tempsDispo = true;
  bool _deuxiemeChanceDispo = true;
  bool _doubleXpActif = false;
  bool _doublePiecesActif = false;

  // État deuxième chance
  bool _enDeuxiemeChance = false;
  bool _estDeuxiemeTentative = false;

  @override
  void initState() {
    super.initState();
    _melangerChoix();
    _demarrerTimer();
  }

  void _melangerChoix() {
    final question = widget.quiz.questionCourante;
    if (question == null) return;
    _choixMelanges = List.of(question.choix)..shuffle(Random());
  }

  void _demarrerTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final quiz = widget.quiz;
      if (quiz.tempsRestant > 0) {
        setState(() => quiz.tempsRestant--);
        if (quiz.tempsRestant == 0) {
          _surTempsEcoule();
        }
      }
    });
  }

  void _surTempsEcoule() {
    final modeGlobal = widget.mode.dureeTotale != null;
    if (modeGlobal) {
      widget.quiz.forcerFin();
      _finir();
    } else if (_enDeuxiemeChance) {
      // Temps écoulé pendant la proposition de deuxième chance → passer
      setState(() => _enDeuxiemeChance = false);
      _passerQuestionSuivante();
    } else if (!_repondu) {
      _traiterReponse(null);
    }
  }

  void _traiterReponse(String? reponse) {
    if (_repondu && !_estDeuxiemeTentative) return;
    if (_enDeuxiemeChance) return; // Boutons overlay gèrent ça

    final controller = context.read<QuizController>();
    final quiz = widget.quiz;
    final question = quiz.questionCourante;
    if (question == null) return;

    if (_estDeuxiemeTentative) {
      // Deuxième tentative : tempsRestant = 0 (pas de bonus vitesse)
      final correcte = controller.repondre(
        quiz, question, reponse ?? '', 0,
        bonusUtilise: 'second_chance',
      );
      if (correcte) {
        quiz.retirerDerniereErreur(question);
      }
      _estDeuxiemeTentative = false;
      if (widget.mode.feedbackImmediat) {
        setState(() {
          _repondu = true;
          _reponseChoisie = reponse;
          _correcte = correcte;
        });
      } else {
        _passerQuestionSuivante();
      }
      return;
    }

    final tempsRestantAuClic = quiz.tempsRestant;
    final correcte = controller.repondre(quiz, question, reponse ?? '', tempsRestantAuClic);

    if (widget.mode.feedbackImmediat) {
      setState(() {
        _repondu = true;
        _reponseChoisie = reponse;
        _correcte = correcte;
      });
    } else {
      // En mode Rush/Bombardement, offrir deuxième chance après une erreur
      if (!correcte && _deuxiemeChanceDispo && reponse != null) {
        setState(() {
          _enDeuxiemeChance = true;
          _deuxiemeChanceDispo = false;
          _reponseChoisie = reponse;
          _correcte = false;
        });
      } else {
        _passerQuestionSuivante();
      }
    }
  }

  void _accepterDeuxiemeChance() {
    setState(() {
      _enDeuxiemeChance = false;
      _estDeuxiemeTentative = true;
      _reponseChoisie = null;
      _correcte = null;
    });
  }

  void _refuserDeuxiemeChance() {
    setState(() => _enDeuxiemeChance = false);
    _passerQuestionSuivante();
  }

  void _passerQuestionSuivante() {
    final controller = context.read<QuizController>();
    final quiz = widget.quiz;
    controller.questionSuivante(quiz);
    _melangerChoix();
    setState(() {
      _repondu = false;
      _reponseChoisie = null;
      _correcte = null;
      _enDeuxiemeChance = false;
      _estDeuxiemeTentative = false;
    });
    if (quiz.termine) {
      _finir();
    }
  }

  Future<void> _finir() async {
    if (_termine) return;
    _termine = true;
    _timer?.cancel();
    final controller = context.read<QuizController>();
    final resultat = await controller.terminerQuiz(widget.quiz);

    final nbCorrectes = resultat.reponsesCorrectes.length;
    final xpGagne = nbCorrectes * 10 * (_doubleXpActif ? 2 : 1);
    final piecesGagnees = nbCorrectes * 5 * (_doublePiecesActif ? 2 : 1);
    if (xpGagne > 0 || piecesGagnees > 0) {
      await controller.ajouterXpPieces(xpGagne, piecesGagnees);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultatScreen(
          resultat: resultat,
          chapitre: widget.quiz.chapitre,
          mode: widget.mode,
          xpGagne: xpGagne,
          piecesGagnees: piecesGagnees,
          doubleXpActif: _doubleXpActif,
          doublePiecesActif: _doublePiecesActif,
        ),
      ),
    );
  }

  Future<void> _confirmerQuitter() async {
    final quitter = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le quiz ?'),
        content: const Text('Ta progression sur cette question sera perdue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (quitter == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ─── Bonus actions ───────────────────────────────────────────────────────────

  void _utiliserElimination() {
    final bonneReponse = widget.quiz.questionCourante?.bonneReponse;
    if (bonneReponse == null) return;
    final mauvaises = _choixMelanges.where((c) => c != bonneReponse).toList()..shuffle();
    if (mauvaises.isEmpty) return;
    setState(() {
      _choixMelanges.remove(mauvaises.first);
      _eliminationDispo = false;
      // 50/50 inutile s'il ne reste qu'un mauvais choix
      if (_choixMelanges.length <= 2) _cinqCinquanteDispo = false;
    });
  }

  void _utiliserCinqCinquante() {
    final bonneReponse = widget.quiz.questionCourante?.bonneReponse;
    if (bonneReponse == null) return;
    final mauvaises = _choixMelanges.where((c) => c != bonneReponse).toList()..shuffle();
    if (mauvaises.isEmpty) return;
    setState(() {
      _choixMelanges = [bonneReponse, mauvaises.first]..shuffle();
      _cinqCinquanteDispo = false;
      _eliminationDispo = false;
    });
  }

  void _utiliserTemps() {
    setState(() {
      widget.quiz.tempsRestant += 10;
      _tempsDispo = false;
    });
  }

  void _activerDoubleXp() {
    setState(() => _doubleXpActif = !_doubleXpActif);
  }

  void _activerDoublePieces() {
    setState(() => _doublePiecesActif = !_doublePiecesActif);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final question = quiz.questionCourante;
    final utilisateur = context.read<QuizController>().utilisateur;

    if (question == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final estModeGlobal = widget.mode.dureeTotale != null;
    final progression = estModeGlobal
        ? null
        : (quiz.indexCourant + 1) / quiz.questions.length;
    final lettres = ['A', 'B', 'C', 'D', 'E', 'F'];
    final peutRepondre = !_repondu && !_enDeuxiemeChance;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── En-tête ────────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: _confirmerQuitter,
                    style: TextButton.styleFrom(
                      foregroundColor: EduCleColors.textSecondary,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Quitter'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          estModeGlobal
                              ? 'Question ${quiz.indexCourant + 1}'
                              : 'Question ${quiz.indexCourant + 1} / '
                                    '${quiz.questions.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progression,
                            minHeight: 6,
                            backgroundColor: EduCleColors.border,
                            color: EduCleColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.mode.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (quiz.tempsRestant <= 5
                                  ? EduCleColors.error
                                  : EduCleColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${quiz.tempsRestant}s',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: quiz.tempsRestant <= 5
                                ? EduCleColors.error
                                : EduCleColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  _Badge(texte: utilisateur.matiereSelectionnee?.nom ?? quiz.chapitre.titre),
                  if (utilisateur.niveau != null)
                    _Badge(texte: utilisateur.niveau!, claire: true),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                question.enonce,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              // ─── Choix ──────────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: _choixMelanges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final choix = _choixMelanges[index];
                    // En état deuxième chance, montrer la mauvaise sélection
                    final montrerErreur = _enDeuxiemeChance;
                    return _BoutonChoix(
                      lettre: lettres[index % lettres.length],
                      texte: choix,
                      selectionne: _reponseChoisie == choix,
                      estBonneReponse: choix == question.bonneReponse,
                      montrerCorrection: _repondu || montrerErreur,
                      onPressed: peutRepondre ? () => _traiterReponse(choix) : null,
                    );
                  },
                ),
              ),
              // ─── Barre bonus ─────────────────────────────────────────────
              _BonusBarre(
                eliminationDispo: _eliminationDispo && peutRepondre && _choixMelanges.length > 2,
                cinqCinquanteDispo: _cinqCinquanteDispo && peutRepondre && _choixMelanges.length > 2,
                tempsDispo: _tempsDispo && peutRepondre,
                deuxiemeChanceDispo: _deuxiemeChanceDispo,
                doubleXpActif: _doubleXpActif,
                doublePiecesActif: _doublePiecesActif,
                onElimination: peutRepondre ? _utiliserElimination : null,
                onCinqCinquante: peutRepondre ? _utiliserCinqCinquante : null,
                onTemps: peutRepondre ? _utiliserTemps : null,
                onDoubleXp: _activerDoubleXp,
                onDoublePieces: _activerDoublePieces,
              ),
              // ─── Deuxième chance overlay (Rush / Bombardement) ────────────
              if (_enDeuxiemeChance) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFC107)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔄 Deuxième chance !',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mauvaise réponse. Tu peux réessayer une fois.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _accepterDeuxiemeChance,
                              child: const Text('Réessayer'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: EduCleColors.textSecondary,
                                side: const BorderSide(color: EduCleColors.border),
                              ),
                              onPressed: _refuserDeuxiemeChance,
                              child: const Text('Passer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              // ─── Feedback Révision ────────────────────────────────────────
              if (_repondu && widget.mode.feedbackImmediat) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_correcte ?? false)
                        ? EduCleColors.successBg
                        : EduCleColors.errorBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_correcte ?? false)
                          ? EduCleColors.success
                          : EduCleColors.error,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_correcte ?? false)
                            ? 'Bonne réponse !'
                            : 'Réponse incorrecte',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: (_correcte ?? false)
                              ? EduCleColors.success
                              : EduCleColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(question.explication),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Deuxième chance disponible après erreur en Révision
                    if (!(_correcte ?? false) && _deuxiemeChanceDispo) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFFFC107)),
                          ),
                          onPressed: () {
                            setState(() {
                              _deuxiemeChanceDispo = false;
                              _estDeuxiemeTentative = true;
                              _repondu = false;
                              _reponseChoisie = null;
                              _correcte = null;
                            });
                          },
                          child: const Text('🔄 Réessayer'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _passerQuestionSuivante,
                        child: const Text('Suivant'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bonus barre ─────────────────────────────────────────────────────────────

class _BonusBarre extends StatelessWidget {
  final bool eliminationDispo;
  final bool cinqCinquanteDispo;
  final bool tempsDispo;
  final bool deuxiemeChanceDispo;
  final bool doubleXpActif;
  final bool doublePiecesActif;
  final VoidCallback? onElimination;
  final VoidCallback? onCinqCinquante;
  final VoidCallback? onTemps;
  final VoidCallback onDoubleXp;
  final VoidCallback onDoublePieces;

  const _BonusBarre({
    required this.eliminationDispo,
    required this.cinqCinquanteDispo,
    required this.tempsDispo,
    required this.deuxiemeChanceDispo,
    required this.doubleXpActif,
    required this.doublePiecesActif,
    required this.onElimination,
    required this.onCinqCinquante,
    required this.onTemps,
    required this.onDoubleXp,
    required this.onDoublePieces,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _BonusChip(
              emoji: '🧹',
              label: 'Éliminer',
              disponible: eliminationDispo,
              onTap: onElimination,
            ),
            const SizedBox(width: 8),
            _BonusChip(
              emoji: '✂️',
              label: '50/50',
              disponible: cinqCinquanteDispo,
              onTap: onCinqCinquante,
            ),
            const SizedBox(width: 8),
            _BonusChip(
              emoji: '⏱️',
              label: '+10s',
              disponible: tempsDispo,
              onTap: onTemps,
            ),
            const SizedBox(width: 8),
            _BonusChip(
              emoji: '🔄',
              label: '2e chance',
              disponible: deuxiemeChanceDispo,
              onTap: null, // déclenchement automatique après erreur
            ),
            const SizedBox(width: 8),
            _BonusChip(
              emoji: '⭐',
              label: '2× XP',
              disponible: true,
              actif: doubleXpActif,
              onTap: onDoubleXp,
            ),
            const SizedBox(width: 8),
            _BonusChip(
              emoji: '🪙',
              label: '2× 🪙',
              disponible: true,
              actif: doublePiecesActif,
              onTap: onDoublePieces,
            ),
          ],
        ),
      ),
    );
  }
}

class _BonusChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool disponible;
  final bool actif;
  final VoidCallback? onTap;

  const _BonusChip({
    required this.emoji,
    required this.label,
    required this.disponible,
    this.actif = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = disponible
        ? EduCleColors.primary
        : EduCleColors.textSecondary;
    final bgColor = actif
        ? EduCleColors.primary.withValues(alpha: 0.18)
        : disponible
            ? EduCleColors.primary.withValues(alpha: 0.08)
            : EduCleColors.border.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: disponible ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: actif
              ? Border.all(color: EduCleColors.primary, width: 1.2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets communs ─────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String texte;
  final bool claire;

  const _Badge({required this.texte, this.claire = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: claire
            ? EduCleColors.border.withValues(alpha: 0.5)
            : EduCleColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: claire ? EduCleColors.textSecondary : EduCleColors.primary,
        ),
      ),
    );
  }
}

class _BoutonChoix extends StatelessWidget {
  final String lettre;
  final String texte;
  final bool selectionne;
  final bool estBonneReponse;
  final bool montrerCorrection;
  final VoidCallback? onPressed;

  const _BoutonChoix({
    required this.lettre,
    required this.texte,
    required this.selectionne,
    required this.estBonneReponse,
    required this.montrerCorrection,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    Color fond = EduCleColors.surface;
    Color bordure = EduCleColors.border;
    Color couleurLettre = EduCleColors.textSecondary;

    if (montrerCorrection) {
      if (estBonneReponse) {
        fond = EduCleColors.successBg;
        bordure = EduCleColors.success;
        couleurLettre = EduCleColors.success;
      } else if (selectionne) {
        fond = EduCleColors.errorBg;
        bordure = EduCleColors.error;
        couleurLettre = EduCleColors.error;
      }
    } else if (selectionne) {
      bordure = EduCleColors.primary;
      couleurLettre = EduCleColors.primary;
    }

    return Material(
      color: fond,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bordure, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: couleurLettre, width: 1.4),
                ),
                child: Text(
                  lettre,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: couleurLettre,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texte,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
