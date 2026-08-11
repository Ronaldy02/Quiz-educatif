import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/quiz_controller.dart';
import '../../models/chapitre.dart';
import '../../models/parametre_partie.dart';
import '../../models/resultat.dart';
import '../../theme/app_theme.dart';
import '../widgets/educle_logo.dart';
import 'home_screen.dart';
import 'quiz_screen.dart';
import 'revision_reponses_screen.dart';

class ResultatScreen extends StatelessWidget {
  final Resultat resultat;
  final Chapitre? chapitre;
  final ParametrePartie? mode;
  final int xpGagne;
  final int piecesGagnees;
  final bool doubleXpActif;
  final bool doublePiecesActif;

  const ResultatScreen({
    super.key,
    required this.resultat,
    this.chapitre,
    this.mode,
    this.xpGagne = 0,
    this.piecesGagnees = 0,
    this.doubleXpActif = false,
    this.doublePiecesActif = false,
  });

  String _messageSelonScore() {
    if (mode?.nom == 'Bombardement') {
      final nb = resultat.historique.length;
      if (nb >= 10) return 'Incroyable, tu voles !';
      if (nb >= 7) return 'Excellent score sous pression !';
      if (nb >= 4) return 'Bien joué, continue à t\'entraîner.';
      return 'La prochaine fois, tu iras plus vite !';
    }
    if (resultat.total == 0) return 'Quiz terminé !';
    final ratio = resultat.reponsesCorrectes.length / resultat.total;
    if (mode?.nom == 'Rush') {
      if (ratio >= 0.8) return 'Excellent ! Tu es rapide et précis.';
      if (ratio >= 0.6) return 'Bien joué ! Encore un peu de vitesse.';
      if (ratio >= 0.4) return 'Pas mal, continue à t\'entraîner.';
      return 'Ne lâche pas, la pratique paie.';
    }
    // Révision
    if (ratio >= 0.8) return 'Bravo ! Tu maîtrises bien ces notions.';
    if (ratio >= 0.6) return 'Bien ! Relis les explications des erreurs.';
    if (ratio >= 0.4) return 'Continue, les explications t\'aideront.';
    return 'Prends le temps de revoir tes cartes mentales.';
  }

  @override
  Widget build(BuildContext context) {
    final matiereNom = context
        .read<QuizController>()
        .utilisateur
        .matiereSelectionnee
        ?.nom;
    final sousTitreParties = [
      if (matiereNom != null) matiereNom,
      if (mode != null) mode!.nom,
    ].join(' · ');

    final isBombardement = mode?.nom == 'Bombardement';
    final nbReponses = resultat.historique.length;
    final nbCorrectes = resultat.reponsesCorrectes.length;
    final ratio = (!isBombardement && resultat.total > 0)
        ? nbCorrectes / resultat.total
        : 0.0;
    final ringValue = isBombardement
        ? (nbReponses / 10.0).clamp(0.0, 1.0)
        : ratio;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const Center(child: EduCleLogo()),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: ringValue,
                        strokeWidth: 10,
                        backgroundColor: EduCleColors.border,
                        color: EduCleColors.primary,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${resultat.score}',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'pts',
                          style: TextStyle(
                            color: EduCleColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _messageSelonScore(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isBombardement
                  ? '$nbReponses question${nbReponses > 1 ? 's' : ''} répondues'
                  : '$nbCorrectes / ${resultat.total} bonnes réponses · ${(ratio * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EduCleColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (sousTitreParties.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sousTitreParties,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EduCleColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            // ─── Récompenses XP / pièces ─────────────────────────────────
            if (xpGagne > 0 || piecesGagnees > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: EduCleColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: EduCleColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (xpGagne > 0) ...[
                      Text(
                        '⭐ +$xpGagne XP',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      if (doubleXpActif)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            '×2',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                    ],
                    if (xpGagne > 0 && piecesGagnees > 0)
                      const SizedBox(width: 20),
                    if (piecesGagnees > 0) ...[
                      Text(
                        '🪙 +$piecesGagnees',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      if (doublePiecesActif)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            '×2',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: resultat.historique.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RevisionReponsesScreen(
                            resultat: resultat,
                            matiereNom: matiereNom,
                          ),
                        ),
                      );
                    },
              child: const Text('Revoir mes réponses'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (chapitre == null || mode == null)
                        ? null
                        : () => _rejouer(context),
                    child: const Text('Rejouer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EduCleColors.textSecondary,
                      side: const BorderSide(color: EduCleColors.border),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text("Retour à l'accueil"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: EduCleColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: EduCleColors.border),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sauvegarde ton score',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Crée un compte pour suivre tes progrès.',
                          style: TextStyle(
                            color: EduCleColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bientôt disponible !')),
                      );
                    },
                    child: const Text('Créer un compte'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _rejouer(BuildContext context) {
    final controller = context.read<QuizController>();
    final quiz = controller.lancerQuiz(mode!);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz, mode: mode!)),
    );
  }
}
