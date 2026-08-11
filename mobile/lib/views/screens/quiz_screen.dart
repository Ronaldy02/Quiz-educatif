import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/quiz_controller.dart';
import '../../models/parametre_partie.dart';
import '../../models/quiz.dart';
import '../../theme/app_theme.dart';
import 'resultat_screen.dart';

// ─── Prix des bonus (en pièces) ──────────────────────────────────────────────
const _prixElimination = 100;
const _prixTemps = 150;
const _prixCinqCinquante = 200;
const _prixDeuxiemeChance = 250;
const _prixDoubleXp = 300;
const _prixDoublePieces = 300;
const _prixMultiplicateur = 500;

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

  // Portefeuille
  int _piecesDisponibles = 0;

  // État bonus : false = pas encore acheté/utilisé, true = acheté/actif
  bool _eliminationActif = false;
  bool _cinqCinquanteActif = false;
  bool _tempsActif = false;
  bool _deuxiemeChanceActif = false; // acheté, sera déclenché sur prochaine erreur
  bool _doubleXpActif = false;
  bool _doublePiecesActif = false;
  bool _multiplicateurActif = false;

  // État deuxième chance
  bool _enDeuxiemeChance = false;
  bool _estDeuxiemeTentative = false;

  @override
  void initState() {
    super.initState();
    _melangerChoix();
    _demarrerTimer();
    _chargerPortefeuille();
  }

  Future<void> _chargerPortefeuille() async {
    final data = await context.read<QuizController>().getXpPieces();
    if (mounted) setState(() => _piecesDisponibles = data['pieces'] ?? 0);
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
        if (quiz.tempsRestant == 0) _surTempsEcoule();
      }
    });
  }

  void _surTempsEcoule() {
    final modeGlobal = widget.mode.dureeTotale != null;
    if (modeGlobal) {
      widget.quiz.forcerFin();
      _finir();
    } else if (_enDeuxiemeChance) {
      setState(() => _enDeuxiemeChance = false);
      _passerQuestionSuivante();
    } else if (!_repondu) {
      _traiterReponse(null);
    }
  }

  void _traiterReponse(String? reponse) {
    if (_repondu && !_estDeuxiemeTentative) return;
    if (_enDeuxiemeChance) return;

    final controller = context.read<QuizController>();
    final quiz = widget.quiz;
    final question = quiz.questionCourante;
    if (question == null) return;

    if (_estDeuxiemeTentative) {
      final correcte = controller.repondre(
        quiz, question, reponse ?? '', 0,
        bonusUtilise: 'second_chance',
      );
      if (correcte) quiz.retirerDerniereErreur(question);
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
      // Deuxième chance : proposer un 2e essai si acheté et pas encore utilisé
      if (!correcte && _deuxiemeChanceActif && !_estDeuxiemeTentative && reponse != null) {
        setState(() {
          _enDeuxiemeChance = true;
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
      _deuxiemeChanceActif = false; // consommé
      _reponseChoisie = null;
      _correcte = null;
    });
  }

  void _refuserDeuxiemeChance() {
    setState(() {
      _enDeuxiemeChance = false;
      _deuxiemeChanceActif = false; // consommé même si refusé
    });
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
    if (quiz.termine) _finir();
  }

  Future<void> _finir() async {
    if (_termine) return;
    _termine = true;
    _timer?.cancel();
    final controller = context.read<QuizController>();
    final resultat = await controller.terminerQuiz(widget.quiz);

    // Pièces = floor(score_effectif / 10), doublées si bonus actif
    final piecesGagnees = (resultat.score / 10).floor() * (_doublePiecesActif ? 2 : 1);
    final xpGagne = resultat.reponsesCorrectes.length * 10 * (_doubleXpActif ? 2 : 1);
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
          multiplicateurActif: _multiplicateurActif,
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

  // ─── Achat de bonus ──────────────────────────────────────────────────────

  Future<bool> _acheterBonus(int prix) async {
    if (_piecesDisponibles < prix) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pas assez de pièces (il faut $prix 🪙, tu en as $_piecesDisponibles)'),
          duration: const Duration(seconds: 2),
        ));
      }
      return false;
    }
    setState(() => _piecesDisponibles -= prix);
    await context.read<QuizController>().ajouterXpPieces(0, -prix);
    return true;
  }

  // ─── Actions bonus ───────────────────────────────────────────────────────

  Future<void> _utiliserElimination() async {
    if (_eliminationActif) return;
    if (!await _acheterBonus(_prixElimination)) return;
    final bonneReponse = widget.quiz.questionCourante?.bonneReponse;
    if (bonneReponse == null) return;
    final mauvaises = _choixMelanges.where((c) => c != bonneReponse).toList()..shuffle();
    if (mauvaises.isEmpty) return;
    setState(() {
      _choixMelanges.remove(mauvaises.first);
      _eliminationActif = true;
      if (_choixMelanges.length <= 2) _cinqCinquanteActif = true; // 50/50 impossible
    });
  }

  Future<void> _utiliserCinqCinquante() async {
    if (_cinqCinquanteActif) return;
    if (!await _acheterBonus(_prixCinqCinquante)) return;
    final bonneReponse = widget.quiz.questionCourante?.bonneReponse;
    if (bonneReponse == null) return;
    final mauvaises = _choixMelanges.where((c) => c != bonneReponse).toList()..shuffle();
    if (mauvaises.isEmpty) return;
    setState(() {
      _choixMelanges = [bonneReponse, mauvaises.first]..shuffle();
      _cinqCinquanteActif = true;
      _eliminationActif = true; // Élimination n'a plus de sens
    });
  }

  Future<void> _utiliserTemps() async {
    if (_tempsActif) return;
    if (!await _acheterBonus(_prixTemps)) return;
    setState(() {
      widget.quiz.tempsRestant += 10;
      _tempsActif = true;
    });
  }

  Future<void> _acheterDeuxiemeChance() async {
    if (_deuxiemeChanceActif) return;
    if (!await _acheterBonus(_prixDeuxiemeChance)) return;
    setState(() => _deuxiemeChanceActif = true);
  }

  Future<void> _activerDoubleXp() async {
    if (_doubleXpActif) return;
    if (!await _acheterBonus(_prixDoubleXp)) return;
    setState(() => _doubleXpActif = true);
  }

  Future<void> _activerDoublePieces() async {
    if (_doublePiecesActif) return;
    if (!await _acheterBonus(_prixDoublePieces)) return;
    setState(() => _doublePiecesActif = true);
  }

  Future<void> _activerMultiplicateur() async {
    if (_multiplicateurActif) return;
    if (!await _acheterBonus(_prixMultiplicateur)) return;
    setState(() {
      _multiplicateurActif = true;
      widget.quiz.multiplicateurScoreActif = true;
    });
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
              // ─── En-tête ─────────────────────────────────────────────────
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
                              : 'Question ${quiz.indexCourant + 1} / ${quiz.questions.length}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                      const SizedBox(height: 2),
                      Text(
                        '🪙 $_piecesDisponibles',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: EduCleColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Badge(texte: utilisateur.matiereSelectionnee?.nom ?? quiz.chapitre.titre),
                  if (utilisateur.niveau != null)
                    _Badge(texte: utilisateur.niveau!, claire: true),
                  if (_multiplicateurActif)
                    const _Badge(texte: '🎯 ×1,5 score', claire: true),
                  if (_doubleXpActif)
                    const _Badge(texte: '⭐ 2× XP', claire: true),
                  if (_doublePiecesActif)
                    const _Badge(texte: '🪙 2× 🪙', claire: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                question.enonce,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              // ─── Choix ───────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: _choixMelanges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final choix = _choixMelanges[index];
                    return _BoutonChoix(
                      lettre: lettres[index % lettres.length],
                      texte: choix,
                      selectionne: _reponseChoisie == choix,
                      estBonneReponse: choix == question.bonneReponse,
                      montrerCorrection: _repondu || _enDeuxiemeChance,
                      onPressed: peutRepondre ? () => _traiterReponse(choix) : null,
                    );
                  },
                ),
              ),
              // ─── Barre bonus ─────────────────────────────────────────────
              _BonusBarre(
                pieces: _piecesDisponibles,
                peutAcheter: peutRepondre,
                nbChoixRestants: _choixMelanges.length,
                eliminationActif: _eliminationActif,
                cinqCinquanteActif: _cinqCinquanteActif,
                tempsActif: _tempsActif,
                deuxiemeChanceActif: _deuxiemeChanceActif,
                doubleXpActif: _doubleXpActif,
                doublePiecesActif: _doublePiecesActif,
                multiplicateurActif: _multiplicateurActif,
                onElimination: _utiliserElimination,
                onCinqCinquante: _utiliserCinqCinquante,
                onTemps: _utiliserTemps,
                onDeuxiemeChance: _acheterDeuxiemeChance,
                onDoubleXp: _activerDoubleXp,
                onDoublePieces: _activerDoublePieces,
                onMultiplicateur: _activerMultiplicateur,
              ),
              // ─── Deuxième chance overlay (Rush / Bombardement) ─────────
              if (_enDeuxiemeChance) ...[
                const SizedBox(height: 8),
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
                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
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
                const SizedBox(height: 8),
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
                        (_correcte ?? false) ? 'Bonne réponse !' : 'Réponse incorrecte',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: (_correcte ?? false) ? EduCleColors.success : EduCleColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(question.explication),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Deuxième chance acheté + réponse incorrecte en mode Révision
                    if (!(_correcte ?? false) && _deuxiemeChanceActif && !_estDeuxiemeTentative) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFFFC107)),
                          ),
                          onPressed: () {
                            setState(() {
                              _deuxiemeChanceActif = false;
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

// ─── Barre bonus ──────────────────────────────────────────────────────────────

class _BonusBarre extends StatelessWidget {
  final int pieces;
  final bool peutAcheter;
  final int nbChoixRestants;
  final bool eliminationActif;
  final bool cinqCinquanteActif;
  final bool tempsActif;
  final bool deuxiemeChanceActif;
  final bool doubleXpActif;
  final bool doublePiecesActif;
  final bool multiplicateurActif;
  final VoidCallback onElimination;
  final VoidCallback onCinqCinquante;
  final VoidCallback onTemps;
  final VoidCallback onDeuxiemeChance;
  final VoidCallback onDoubleXp;
  final VoidCallback onDoublePieces;
  final VoidCallback onMultiplicateur;

  const _BonusBarre({
    required this.pieces,
    required this.peutAcheter,
    required this.nbChoixRestants,
    required this.eliminationActif,
    required this.cinqCinquanteActif,
    required this.tempsActif,
    required this.deuxiemeChanceActif,
    required this.doubleXpActif,
    required this.doublePiecesActif,
    required this.multiplicateurActif,
    required this.onElimination,
    required this.onCinqCinquante,
    required this.onTemps,
    required this.onDeuxiemeChance,
    required this.onDoubleXp,
    required this.onDoublePieces,
    required this.onMultiplicateur,
  });

  bool _peutAcheter(int prix) => peutAcheter && pieces >= prix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _BonusChip(
              emoji: '🧹',
              label: 'Éliminer',
              prix: _prixElimination,
              actif: eliminationActif,
              achetable: !eliminationActif && _peutAcheter(_prixElimination) && nbChoixRestants > 2,
              onTap: eliminationActif ? null : (_peutAcheter(_prixElimination) && nbChoixRestants > 2 ? onElimination : null),
            ),
            const SizedBox(width: 7),
            _BonusChip(
              emoji: '✂️',
              label: '50/50',
              prix: _prixCinqCinquante,
              actif: cinqCinquanteActif,
              achetable: !cinqCinquanteActif && _peutAcheter(_prixCinqCinquante) && nbChoixRestants > 2,
              onTap: cinqCinquanteActif ? null : (_peutAcheter(_prixCinqCinquante) && nbChoixRestants > 2 ? onCinqCinquante : null),
            ),
            const SizedBox(width: 7),
            _BonusChip(
              emoji: '⏱️',
              label: '+10s',
              prix: _prixTemps,
              actif: tempsActif,
              achetable: !tempsActif && _peutAcheter(_prixTemps) && peutAcheter,
              onTap: tempsActif ? null : (_peutAcheter(_prixTemps) && peutAcheter ? onTemps : null),
            ),
            const SizedBox(width: 7),
            _BonusChip(
              emoji: '🔄',
              label: '2e ch.',
              prix: _prixDeuxiemeChance,
              actif: deuxiemeChanceActif,
              achetable: !deuxiemeChanceActif && _peutAcheter(_prixDeuxiemeChance),
              onTap: deuxiemeChanceActif ? null : (_peutAcheter(_prixDeuxiemeChance) ? onDeuxiemeChance : null),
            ),
            const SizedBox(width: 7),
            _BonusChip(
              emoji: '⭐',
              label: '2× XP',
              prix: _prixDoubleXp,
              actif: doubleXpActif,
              achetable: !doubleXpActif && _peutAcheter(_prixDoubleXp),
              onTap: doubleXpActif ? null : (_peutAcheter(_prixDoubleXp) ? onDoubleXp : null),
            ),
            const SizedBox(width: 7),
            _BonusChip(
              emoji: '🪙',
              label: '2× 🪙',
              prix: _prixDoublePieces,
              actif: doublePiecesActif,
              achetable: !doublePiecesActif && _peutAcheter(_prixDoublePieces),
              onTap: doublePiecesActif ? null : (_peutAcheter(_prixDoublePieces) ? onDoublePieces : null),
            ),
            const SizedBox(width: 7),
            _BonusChip(
              emoji: '🎯',
              label: '×1,5',
              prix: _prixMultiplicateur,
              actif: multiplicateurActif,
              achetable: !multiplicateurActif && _peutAcheter(_prixMultiplicateur) && peutAcheter,
              onTap: multiplicateurActif ? null : (_peutAcheter(_prixMultiplicateur) && peutAcheter ? onMultiplicateur : null),
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
  final int prix;
  final bool actif;     // acheté / actif
  final bool achetable; // peut être acheté maintenant
  final VoidCallback? onTap;

  const _BonusChip({
    required this.emoji,
    required this.label,
    required this.prix,
    required this.actif,
    required this.achetable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color couleur;
    final Color fond;
    final String sousTitre;

    if (actif) {
      couleur = EduCleColors.success;
      fond = EduCleColors.successBg;
      sousTitre = 'actif ✓';
    } else if (achetable) {
      couleur = EduCleColors.primary;
      fond = EduCleColors.primary.withValues(alpha: 0.08);
      sousTitre = '$prix🪙';
    } else {
      couleur = EduCleColors.textSecondary;
      fond = EduCleColors.border.withValues(alpha: 0.5);
      sousTitre = '$prix🪙';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(20),
          border: actif ? Border.all(color: EduCleColors.success, width: 1.2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              sousTitre,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: actif
                    ? EduCleColors.success
                    : couleur.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets communs ──────────────────────────────────────────────────────────

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
