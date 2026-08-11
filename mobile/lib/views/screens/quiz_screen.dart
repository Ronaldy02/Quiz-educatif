import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/quiz_controller.dart';
import '../../models/parametre_partie.dart';
import '../../models/quiz.dart';
import '../../services/database_helper.dart';
import '../../services/haptic_service.dart';
import '../../services/realisation_service.dart';
import '../../services/sound_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/milestone_overlay.dart';
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

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
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

  // Série (Rush/Révision uniquement — spec §18 résumé)
  int _serie = 0;
  int _serieMax = 0; // plus longue série atteinte dans ce quiz (pour réalisations)
  final Set<int> _paliersSerie = {};
  bool _questionsCorrecteCourante = false;
  int _seriesPieces = 0; // total coins reçus pendant le quiz (jalons de série)
  OverlayEntry? _overlayEntry;

  // Animations de feedback réponse (Bloc 7)
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _melangerChoix();
    _demarrerTimer();
    _chargerPortefeuille();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: -3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 0.98), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0), weight: 3),
    ]).animate(_pulseCtrl);
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
      if (correcte) {
        quiz.retirerDerniereErreur(question);
        _questionsCorrecteCourante = true;
        unawaited(HapticService.reponseCorrecte());
        unawaited(SoundService.reponseCorrecte());
      } else {
        unawaited(HapticService.reponseIncorrecte());
        unawaited(SoundService.reponseIncorrecte());
      }
      _estDeuxiemeTentative = false;
      if (widget.mode.feedbackImmediat) {
        setState(() {
          _repondu = true;
          _reponseChoisie = reponse;
          _correcte = correcte;
        });
        if (correcte) { _pulseCtrl.forward(from: 0); }
        else if (reponse != null) { _shakeCtrl.forward(from: 0); }
      } else {
        _passerQuestionSuivante();
      }
      return;
    }

    final tempsRestantAuClic = quiz.tempsRestant;
    final correcte = controller.repondre(quiz, question, reponse ?? '', tempsRestantAuClic);

    if (correcte) {
      _questionsCorrecteCourante = true;
      unawaited(HapticService.reponseCorrecte());
      unawaited(SoundService.reponseCorrecte());
    } else if (reponse != null) {
      unawaited(HapticService.reponseIncorrecte());
      unawaited(SoundService.reponseIncorrecte());
    }

    if (widget.mode.feedbackImmediat) {
      setState(() {
        _repondu = true;
        _reponseChoisie = reponse;
        _correcte = correcte;
      });
      if (correcte) { _pulseCtrl.forward(from: 0); }
      else if (reponse != null) { _shakeCtrl.forward(from: 0); }
    } else {
      // Deuxième chance : proposer un 2e essai si acheté et pas encore utilisé
      if (!correcte && _deuxiemeChanceActif && !_estDeuxiemeTentative && reponse != null) {
        setState(() {
          _enDeuxiemeChance = true;
          _reponseChoisie = reponse;
          _correcte = false;
        });
        _shakeCtrl.forward(from: 0);
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
    final estBombardement = widget.mode.dureeTotale != null;

    // Mise à jour de la série avant de réinitialiser l'état de la question.
    if (!estBombardement) {
      if (_questionsCorrecteCourante) {
        _serie++;
        if (_serie > _serieMax) _serieMax = _serie;
        unawaited(_verifierMilestoneSerie());
      } else {
        _serie = 0;
      }
    }

    _shakeCtrl.reset();
    _pulseCtrl.reset();
    controller.questionSuivante(quiz);
    _melangerChoix();
    setState(() {
      _repondu = false;
      _reponseChoisie = null;
      _correcte = null;
      _enDeuxiemeChance = false;
      _estDeuxiemeTentative = false;
      _questionsCorrecteCourante = false;
    });
    if (quiz.termine) _finir();
  }

  Future<void> _finir() async {
    if (_termine) return;
    _termine = true;
    _timer?.cancel();
    final controller = context.read<QuizController>();
    final resultat = await controller.terminerQuiz(widget.quiz);

    final estBombardement = widget.mode.dureeTotale != null;

    // Pièces de fin de quiz (spec §13 et §18 résumé).
    // Bombardement : tier basé sur le nombre de bonnes réponses.
    // Rush/Révision : formule score ÷ 10.
    final int palierBombardement;
    final int piecesGagnees;
    if (estBombardement) {
      palierBombardement = _palierBombardement(resultat.reponsesCorrectes.length);
      final piecesBrutes = _piecesPalierBombardement(palierBombardement);
      piecesGagnees = piecesBrutes * (_doublePiecesActif ? 2 : 1);
      if (palierBombardement > 0) {
        unawaited(SoundService.bombardement(palierBombardement));
        unawaited(HapticService.serie(palierBombardement));
      }
    } else {
      palierBombardement = 0;
      piecesGagnees = (resultat.score / 10).floor() * (_doublePiecesActif ? 2 : 1);
    }

    final xpGagne = (resultat.xpQuiz * (_doubleXpActif ? 2.0 : 1.0)).round();
    if (xpGagne > 0 || piecesGagnees > 0) {
      await controller.ajouterXpPieces(xpGagne, piecesGagnees);
    }

    // Perfect quiz : toutes les réponses correctes (spec §7).
    final estPerfect = !estBombardement &&
        resultat.total > 0 &&
        resultat.reponsesCorrectes.length == resultat.total;
    if (estPerfect) {
      unawaited(HapticService.perfect());
      unawaited(SoundService.perfect());
    }

    // Vérification et déblocage des réalisations.
    final xpPieces = await controller.getXpPieces();
    final db = await DatabaseHelper.instance.database;
    final realisationsDebloquees = await RealisationService.verifierApresQuiz(
      db: db,
      modeNom: widget.mode.nom,
      nbCorrectesCettePartie: resultat.reponsesCorrectes.length,
      estPerfect: estPerfect,
      scoreBombardement: estBombardement ? resultat.reponsesCorrectes.length : 0,
      serieMax: _serieMax,
      xpTotal: xpPieces['xp'] ?? 0,
      piecesTotal: xpPieces['pieces'] ?? 0,
      subjectId: widget.quiz.chapitre.questions.isNotEmpty
          ? null // le subjectId viendra via le mapping quand nécessaire
          : null,
    );

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
          palierBombardement: palierBombardement,
          estPerfect: estPerfect,
          seriesPieces: _seriesPieces,
          realisationsDebloquees: realisationsDebloquees,
          xpApres: xpPieces['xp'] ?? 0,
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
    _overlayEntry?.remove();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Chrono critique ──────────────────────────────────────────────────────

  // Rush : seuil 3 s (spec §4), Révision : 5 s, Bombardement : géré globalement.
  bool _estCritique(int tempsRestant) {
    if (widget.mode.dureeTotale != null) return false;
    return tempsRestant <= (widget.mode.nom == 'Rush' ? 3 : 5);
  }

  // ─── Jalons de série ──────────────────────────────────────────────────────

  static int _palierBombardement(int nbCorrectes) {
    if (nbCorrectes >= 20) return 20;
    if (nbCorrectes >= 15) return 15;
    if (nbCorrectes >= 10) return 10;
    if (nbCorrectes >= 6) return 6;
    return 0;
  }

  static int _piecesPalierBombardement(int palier) {
    switch (palier) {
      case 6:  return 5;
      case 10: return 12;
      case 15: return 18;
      case 20: return 25;
      default: return 0;
    }
  }

  static int _coinsSerieParPalier(int palier) {
    switch (palier) {
      case 5:  return 5;
      case 10: return 10;
      case 15: return 18;
      case 20: return 25;
      default: return 0;
    }
  }

  void _mostrerOverlay(int palier, {bool estBombardement = false}) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: MilestoneOverlay(
          palier: palier,
          estBombardement: estBombardement,
          onDismissed: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _verifierMilestoneSerie() async {
    const paliers = [5, 10, 15, 20];
    for (final palier in paliers) {
      if (_serie == palier && !_paliersSerie.contains(palier)) {
        _paliersSerie.add(palier);
        final coins = _coinsSerieParPalier(palier);
        _seriesPieces += coins;
        if (mounted) setState(() => _piecesDisponibles += coins);
        await context.read<QuizController>().ajouterXpPieces(0, coins);
        unawaited(HapticService.serie(palier));
        unawaited(SoundService.serie(palier));
        if (mounted) _mostrerOverlay(palier);
        break;
      }
    }
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

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (!peutRepondre) return KeyEventResult.ignored;
        int? index;
        if (event.logicalKey == LogicalKeyboardKey.digit1) { index = 0; }
        else if (event.logicalKey == LogicalKeyboardKey.digit2) { index = 1; }
        else if (event.logicalKey == LogicalKeyboardKey.digit3) { index = 2; }
        else if (event.logicalKey == LogicalKeyboardKey.digit4) { index = 3; }
        if (index != null && index < _choixMelanges.length) {
          _traiterReponse(_choixMelanges[index]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
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
                          color: (_estCritique(quiz.tempsRestant)
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
                            color: _estCritique(quiz.tempsRestant)
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
                      if (_serie >= 2 && widget.mode.dureeTotale == null)
                        Text(
                          '🔥 $_serie',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
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
                child: AnimatedBuilder(
                  animation: Listenable.merge([_shakeCtrl, _pulseCtrl]),
                  builder: (_, __) => ListView.separated(
                    itemCount: _choixMelanges.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final choix = _choixMelanges[index];
                      final montrerCorr = _repondu || _enDeuxiemeChance;
                      final estSelectionneWrong =
                          choix == _reponseChoisie && _correcte == false && montrerCorr;
                      final estSelectionneOk =
                          choix == _reponseChoisie && _correcte == true && _repondu;
                      return _BoutonChoix(
                        lettre: lettres[index % lettres.length],
                        texte: choix,
                        selectionne: _reponseChoisie == choix,
                        estBonneReponse: choix == question.bonneReponse,
                        montrerCorrection: montrerCorr,
                        onPressed: peutRepondre ? () => _traiterReponse(choix) : null,
                        shakeOffset: estSelectionneWrong ? _shakeAnim.value : 0,
                        pulseScale: estSelectionneOk ? _pulseAnim.value : 1.0,
                      );
                    },
                  ),
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
    ),  // Scaffold
    );  // Focus
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
  final double shakeOffset;
  final double pulseScale;

  const _BoutonChoix({
    required this.lettre,
    required this.texte,
    required this.selectionne,
    required this.estBonneReponse,
    required this.montrerCorrection,
    required this.onPressed,
    this.shakeOffset = 0,
    this.pulseScale = 1.0,
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

    return Transform.translate(
      offset: Offset(shakeOffset, 0),
      child: Transform.scale(
        scale: pulseScale,
        child: Material(
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
    ),    // Material
    ),    // Transform.scale
    );    // Transform.translate
  }
}
