/// Modèle "Question" du diagramme de classes.
class Question {
  final int id;
  final int chapitreId;
  final String enonce;
  final List<String> choix;
  final String bonneReponse;
  final String explication;
  final String niveauComplexite; // "Facile", "Moyen", "Difficile"

  Question({
    required this.id,
    required this.chapitreId,
    required this.enonce,
    required this.choix,
    required this.bonneReponse,
    required this.explication,
    required this.niveauComplexite,
  });

  /// + vérifierRéponse(réponse : string) : bool
  bool verifierReponse(String reponse) => reponse == bonneReponse;

  factory Question.fromMap(Map<String, dynamic> map, List<String> choix) {
    return Question(
      id: map['id'] as int,
      chapitreId: map['chapitre_id'] as int? ?? -1,
      enonce: map['enonce'] as String,
      choix: choix,
      bonneReponse: map['bonne_reponse'] as String,
      explication: map['explication'] as String,
      niveauComplexite: map['niveau_complexite'] as String,
    );
  }
}
