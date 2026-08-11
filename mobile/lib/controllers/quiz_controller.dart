import 'package:flutter/foundation.dart';

import '../models/carte_mentale.dart';
import '../models/chapitre.dart';
import '../models/matiere.dart';
import '../models/parametre_partie.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../models/resultat.dart';
import '../models/utilisateur.dart';
import '../services/adaptive_selector.dart';
import '../services/database_helper.dart';
import '../services/realisation_service.dart';

/// Couche "Contrôleur" (MVC) : fait le lien entre les vues et le modèle
/// (Utilisateur, Quiz...), orchestre les actions utilisateur (sélection,
/// lancement de quiz, réponses) et la persistance locale. Le décompte du
/// temps à l'écran (UI) est géré par la vue ; le contrôleur expose les
/// opérations métier (répondre, passer, terminer, sauvegarder).
class QuizController extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Utilisateur utilisateur = Utilisateur(id: 1, nom: 'Élève');

  List<String> niveaux = [];
  List<Matiere> matieres = [];
  List<Chapitre> chapitres = [];
  Chapitre? dernierChapitre;

  // Mapping chapitreId → matiereId, peuplé quand plusieurs matières sont
  // dans le pool (choisirTout / choisirThemeSVT).
  Map<int, int> _chapitreIdVersMatiere = {};

  int nombreQuestions = 10;
  static const int _nbQuestionsBombardement = 30;

  bool chargement = false;
  bool quizEnCoursDisponible = false;
  bool profilConfigure = false;
  String _niveauScolaire = 'Fondamental';
  String _annee = '7e AF';
  String _pays = 'Haïti';
  String _ville = '';
  String _difficulte = 'Toutes';

  String get niveauScolaire => _niveauScolaire;
  String get annee => _annee;
  String get pays => _pays;
  String get ville => _ville;
  String get difficulte => _difficulte;
  String get zone {
    if (_pays.isEmpty) return '';
    return _ville.isEmpty ? _pays : '$_pays / $_ville';
  }

  Future<void> initialiser() async {
    chargement = true;
    notifyListeners();
    try {
      if (kIsWeb) {
        matieres = _matieresWeb;
      } else {
        niveaux = await _db.getNiveaux();
        _niveauScolaire = await _db.getNiveauScolaire();
        _annee = await _db.getAnnee();
        _pays = await _db.getPays();
        _ville = await _db.getVille();
        _difficulte = await _db.getDifficulte();
        profilConfigure = await _db.getProfilConfigure();
        utilisateur.zone = zone;
        matieres = await _db.getMatieresByCycle(_niveauScolaire);
        final quizSauvegarde = await _db.getQuizEnCours();
        quizEnCoursDisponible = quizSauvegarde != null;
        final db = await _db.database;
        await RealisationService.initialiser(db);
      }
    } catch (_) {}
    chargement = false;
    notifyListeners();
  }

  Future<void> changerNiveauScolaire(String niveau) async {
    _niveauScolaire = niveau;
    final anneeDefaut = niveau == 'Secondaire' ? 'NS1' : '7e AF';
    _annee = anneeDefaut;
    if (!kIsWeb) {
      await _db.setNiveauScolaire(niveau);
      await _db.setAnnee(anneeDefaut);
      matieres = await _db.getMatieresByCycle(niveau);
    }
    notifyListeners();
  }

  Future<void> changerAnnee(String annee) async {
    _annee = annee;
    if (!kIsWeb) await _db.setAnnee(annee);
    notifyListeners();
  }

  Future<void> changerPays(String pays) async {
    _pays = pays;
    utilisateur.zone = zone;
    if (!kIsWeb) await _db.setPays(pays);
    notifyListeners();
  }

  Future<void> changerVille(String ville) async {
    _ville = ville;
    utilisateur.zone = zone;
    if (!kIsWeb) await _db.setVille(ville);
    notifyListeners();
  }

  Future<void> changerDifficulte(String difficulte) async {
    _difficulte = difficulte;
    if (!kIsWeb) await _db.setDifficulte(difficulte);
    notifyListeners();
  }

  Future<void> marquerProfilConfigure() async {
    profilConfigure = true;
    if (!kIsWeb) await _db.setProfilConfigure();
    notifyListeners();
  }

  static final List<Matiere> _matieresWeb = [
    Matiere(id: 1, nom: 'Mathématiques'),
    Matiere(id: 2, nom: 'Français'),
    Matiere(id: 3, nom: 'Sciences expérimentales'),
    Matiere(id: 4, nom: 'Histoire'),
    Matiere(id: 5, nom: 'Géographie'),
    Matiere(id: 6, nom: 'Connaissances générales'),
  ];

  Future<void> choisirNiveau(String niveau) async {
    utilisateur.choisirNiveau(niveau);
    matieres = await _db.getMatieres(niveau);
    chapitres = [];
    notifyListeners();
  }

  Future<void> choisirMatiere(Matiere matiere) async {
    utilisateur.choisirMatiere(matiere);
    chapitres = await _db.getChapitres(matiere.id);
    notifyListeners();
  }

  Future<Chapitre> choisirChapitre(Chapitre chapitre) async {
    final chapitreComplet = await _db.getChapitreComplet(chapitre.id, difficulte: _difficulte);
    utilisateur.choisirChapitre(chapitreComplet);
    dernierChapitre = chapitreComplet;
    _chapitreIdVersMatiere = {}; // un seul chapitre, pas de multi-matière
    notifyListeners();
    return chapitreComplet;
  }

  /// Regroupe tous les chapitres de la matière courante en un chapitre
  /// virtuel, pour l'option "Tout — tous les chapitres" du sélecteur.
  Future<Chapitre> choisirTousLesChapitres() async {
    final toutesQuestions = <Question>[];
    final toutesCartes = <CarteMentale>[];
    for (final chapitre in chapitres) {
      final complet = await _db.getChapitreComplet(chapitre.id, difficulte: _difficulte);
      toutesQuestions.addAll(complet.questions);
      toutesCartes.addAll(complet.cartesMentales);
    }
    final chapitreTout = Chapitre(
      id: -1,
      titre: 'Tout',
      cartesMentales: toutesCartes,
      questions: toutesQuestions,
    );
    utilisateur.choisirChapitre(chapitreTout);
    dernierChapitre = chapitreTout;
    // Même matière → pas de mapping inter-matières nécessaire.
    // L'équiprobabilité entre chapitres vient de Question.chapitreId.
    _chapitreIdVersMatiere = {};
    notifyListeners();
    return chapitreTout;
  }

  /// Combine Biologie + Géologie + Astronomie en un chapitre virtuel SVT.
  Future<Chapitre> choisirThemeSVT() async {
    const nomsVises = {'Biologie', 'Géologie', 'Astronomie'};
    final toutesQuestions = <Question>[];
    final toutesCartes = <CarteMentale>[];
    final mapping = <int, int>{};
    for (final matiere in matieres) {
      if (!nomsVises.contains(matiere.nom)) continue;
      final chapitresDeLaMatiere = await _db.getChapitres(matiere.id);
      for (final chapitre in chapitresDeLaMatiere) {
        final complet = await _db.getChapitreComplet(chapitre.id, difficulte: _difficulte);
        toutesQuestions.addAll(complet.questions);
        toutesCartes.addAll(complet.cartesMentales);
        mapping[chapitre.id] = matiere.id;
      }
    }
    final chapitreVirtuel = Chapitre(
      id: -3,
      titre: 'SVT',
      cartesMentales: toutesCartes,
      questions: toutesQuestions,
    );
    utilisateur.choisirChapitre(chapitreVirtuel);
    dernierChapitre = chapitreVirtuel;
    _chapitreIdVersMatiere = mapping;
    notifyListeners();
    return chapitreVirtuel;
  }

  /// Charge toutes les questions de toutes les matières → chapitre virtuel "Tout"
  /// utilisé par le bouton "Jouer (Tout)" de l'accueil.
  Future<Chapitre> choisirTout() async {
    if (kIsWeb) {
      final chapitreTout = Chapitre(id: -1, titre: 'Toutes les matières');
      utilisateur.choisirChapitre(chapitreTout);
      dernierChapitre = chapitreTout;
      _chapitreIdVersMatiere = {};
      notifyListeners();
      return chapitreTout;
    }
    final toutesQuestions = <Question>[];
    final toutesCartes = <CarteMentale>[];
    final mapping = <int, int>{};
    for (final matiere in matieres) {
      final chapitresDeLaMatiere = await _db.getChapitres(matiere.id);
      for (final chapitre in chapitresDeLaMatiere) {
        final complet = await _db.getChapitreComplet(chapitre.id, difficulte: _difficulte);
        toutesQuestions.addAll(complet.questions);
        toutesCartes.addAll(complet.cartesMentales);
        mapping[chapitre.id] = matiere.id;
      }
    }
    final chapitreTout = Chapitre(
      id: -1,
      titre: 'Toutes les matières',
      cartesMentales: toutesCartes,
      questions: toutesQuestions,
    );
    utilisateur.choisirChapitre(chapitreTout);
    dernierChapitre = chapitreTout;
    _chapitreIdVersMatiere = mapping;
    notifyListeners();
    return chapitreTout;
  }

  /// + consulterCartes(chapitre : Chapitre) : List&lt;CarteMentale&gt;
  List<CarteMentale> consulterCartes(Chapitre chapitre) {
    return utilisateur.consulterCartes(chapitre);
  }

  /// + lancerQuiz(mode : ModeJeu) : Quiz
  Future<Quiz> lancerQuiz(ParametrePartie mode) async {
    final estBombardement = mode.dureeTotale != null;
    final nbCible = estBombardement ? _nbQuestionsBombardement : nombreQuestions;

    final chapitre = utilisateur.chapitreSelectionne;
    if (chapitre == null || chapitre.questions.isEmpty) {
      // Fallback minimal (ne devrait pas arriver en usage normal).
      final quiz = utilisateur.lancerQuiz(mode);
      _sauvegarderEtat(quiz);
      return quiz;
    }

    // Charger les stats depuis la DB pour la sélection adaptative.
    Map<int, QuestionStats> stats = {};
    if (!kIsWeb) {
      final ids = chapitre.questions.map((q) => q.id).toList();
      stats = await _db.getStatsParQuestions(ids);
    }

    final nbVoulu = nbCible.clamp(1, chapitre.questions.length);
    final questions = AdaptiveSelector.selectionner(
      pool: chapitre.questions,
      chapitreIdVersMatiere: _chapitreIdVersMatiere,
      stats: stats,
      nbVoulu: nbVoulu,
    );

    // Snapshot de maitrise avant le quiz, utilise pour calculer l'XP par question.
    final maitriseAvant = {
      for (final q in questions)
        q.id: stats[q.id]?.tauxReussite ?? 0.0,
    };

    final quiz = Quiz(
      id: DateTime.now().millisecondsSinceEpoch,
      chapitre: chapitre,
      mode: mode,
      questions: questions,
      maitriseAvant: maitriseAvant,
    );
    quiz.demarrer();
    utilisateur.quizEnCours = quiz;
    _sauvegarderEtat(quiz);
    return quiz;
  }

  void changerNombreQuestions(int nb) {
    nombreQuestions = nb;
    notifyListeners();
  }

  /// + reprendreQuiz() : Quiz
  Future<Quiz?> reprendreQuizSauvegarde() async {
    final sauvegarde = await _db.getQuizEnCours();
    if (sauvegarde == null) return null;

    final chapitreId = sauvegarde['chapitre_id'] as int;
    final chapitreComplet = await _db.getChapitreComplet(chapitreId);
    final modeNom = sauvegarde['mode_nom'] as String;
    final mode = ParametrePartie.modes.firstWhere((m) => m.nom == modeNom);

    final quiz = Quiz(
      id: DateTime.now().millisecondsSinceEpoch,
      chapitre: chapitreComplet,
      mode: mode,
      questions: chapitreComplet.questions,
      score: sauvegarde['score'] as int,
      tempsRestant: sauvegarde['temps_restant'] as int,
      indexCourant: sauvegarde['index_courant'] as int,
    );
    utilisateur.choisirChapitre(chapitreComplet);
    utilisateur.quizEnCours = quiz;
    quizEnCoursDisponible = false;
    notifyListeners();
    return quiz;
  }

  /// + répondre(question : Question, réponse : string) : bool
  bool repondre(Quiz quiz, Question question, String reponse, int tempsRestantAuClic, {String? bonusUtilise}) {
    final correcte = quiz.repondre(question, reponse, tempsRestantAuClic, bonusUtilise: bonusUtilise);
    _sauvegarderEtat(quiz);
    return correcte;
  }

  /// Passe à la question suivante (réinitialise le temps par question si
  /// le mode en a un, comme Rush ou Révision).
  void questionSuivante(Quiz quiz) {
    quiz.passerQuestionSuivante();
    if (!quiz.termine) {
      _sauvegarderEtat(quiz);
    }
  }

  Future<Resultat> terminerQuiz(Quiz quiz) async {
    final resultat = quiz.afficherResultat();
    utilisateur.enregistrerResultat(quiz.chapitre, resultat);
    if (!kIsWeb && quiz.chapitre.id >= 0) {
      await _db.enregistrerProgression(
        quiz.chapitre.id,
        resultat.score,
        resultat.total,
      );
      await _db.enregistrerStatistiquesQuestions(quiz.historique);
      await _db.enregistrerScore(
        matiereId: utilisateur.matiereSelectionnee?.id,
        score: resultat.score,
        nbCorrectes: resultat.reponsesCorrectes.length,
        nbTotal: resultat.total,
        modeNom: quiz.mode.nom,
      );
    }
    await _db.effacerQuizEnCours();
    quizEnCoursDisponible = false;
    notifyListeners();
    return resultat;
  }

  Future<Map<String, dynamic>> getStatsGlobales() => _db.getStatsGlobales();

  Future<List<Map<String, dynamic>>> getStatsByMatiere() =>
      _db.getStatsByMatiere();

  Future<List<Map<String, dynamic>>> getMaitriseParMatiere() =>
      _db.getMaitriseParMatiere();

  Future<Map<String, dynamic>> getMaitriseGlobale() =>
      _db.getMaitriseGlobale();

  Future<List<Map<String, dynamic>>> getScores({int? matiereId}) async {
    if (kIsWeb) return [];
    return _db.getScores(matiereId: matiereId);
  }

  Future<Map<String, int>> getXpPieces() async {
    if (kIsWeb) return {'xp': 0, 'pieces': 0};
    return _db.getXpPieces();
  }

  Future<void> ajouterXpPieces(int xp, int pieces) async {
    if (kIsWeb) return;
    await _db.ajouterXpPieces(xp, pieces);
  }

  Future<void> _sauvegarderEtat(Quiz quiz) async {
    if (quiz.chapitre.id < 0) return; // chapitre virtuel "Tout", pas de sauvegarde
    await _db.sauvegarderQuizEnCours(
      chapitreId: quiz.chapitre.id,
      modeNom: quiz.mode.nom,
      indexCourant: quiz.indexCourant,
      score: quiz.score,
      tempsRestant: quiz.tempsRestant,
      reponsesCorrectesIds: quiz.reponsesCorrectes.map((q) => q.id).toList(),
      reponsesIncorrectesIds: quiz.reponsesIncorrectes
          .map((q) => q.id)
          .toList(),
    );
  }
}
