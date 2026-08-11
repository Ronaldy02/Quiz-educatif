import 'question.dart';
import 'reponse_enregistree.dart';

/// Modèle "Résultat" du diagramme de classes.
class Resultat {
  final int score;        // score effectif (après multiplicateur si actif)
  final int? scoreBase;   // score avant multiplicateur, null si pas de multiplicateur
  // XP brut du quiz (somme pondérée par maîtrise avant tentative).
  // Ne comprend PAS encore le facteur ×2 du bonus Double XP.
  final double xpQuiz;
  final int total;
  final List<Question> reponsesCorrectes;
  final List<Question> reponsesIncorrectes;
  final List<ReponseEnregistree> historique;

  Resultat({
    required this.score,
    this.scoreBase,
    this.xpQuiz = 0.0,
    required this.total,
    required this.reponsesCorrectes,
    required this.reponsesIncorrectes,
    this.historique = const [],
  });

  /// + afficherRésumé() : void
  /// Construit un résumé textuel (la vue se charge de l'affichage réel).
  String afficherResume() {
    return '$score / $total bonnes réponses';
  }
}
