import 'question.dart';

/// Trace une réponse donnée par l'utilisateur pour une question, dans
/// l'ordre du quiz. Sert à l'écran "Révision de tes réponses".
class ReponseEnregistree {
  final Question question;
  final String reponseUtilisateur;
  final bool correcte;
  final int tempsUtilise; // secondes utilisées pour répondre
  final String? bonusUtilise; // ex: 'second_chance', null si aucun

  ReponseEnregistree({
    required this.question,
    required this.reponseUtilisateur,
    required this.correcte,
    this.tempsUtilise = 0,
    this.bonusUtilise,
  });
}
