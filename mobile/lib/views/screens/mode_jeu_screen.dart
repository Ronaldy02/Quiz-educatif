import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/quiz_controller.dart';
import '../../models/chapitre.dart';
import '../../models/parametre_partie.dart';
import '../../theme/app_theme.dart';
import '../widgets/educle_app_bar.dart';
import 'apprentissage_screen.dart';
import 'cartes_mentales_screen.dart';
import 'quiz_screen.dart';

class ModeJeuScreen extends StatelessWidget {
  final Chapitre chapitre;

  const ModeJeuScreen({super.key, required this.chapitre});

  static const _descriptions = {
    'Rush':
        'Aucune correction pendant la partie. La correction complète arrive '
        'à la fin. Teste ta rapidité.',
    'Révision':
        'Correction immédiate après chaque réponse, avec explication. '
        'Comprends chaque notion au fur et à mesure.',
    'Bombardement':
        'Réponds à un maximum de questions avant la fin du temps. '
        'Entraîne-toi sous pression.',
  };

  static const _sousTitres = {
    'Rush': '10 s / question',
    'Révision': '20 s / question',
    'Bombardement': '1 min au total',
  };

  static const _icones = {
    'Rush': Icons.bolt_rounded,
    'Révision': Icons.check_circle_rounded,
    'Bombardement': Icons.timer_rounded,
  };

  static const _couleurs = {
    'Rush': EduCleColors.rush,
    'Révision': EduCleColors.revision,
    'Bombardement': EduCleColors.bombardement,
  };

  @override
  Widget build(BuildContext context) {
    final estGlobalTout = chapitre.id < 0 && chapitre.titre == 'Toutes les matières';
    final matiere = estGlobalTout
        ? null
        : context.read<QuizController>().utilisateur.matiereSelectionnee;
    final emoji = matiere != null ? MatiereStyle.emojiPour(matiere.nom) : '🌐';
    final matiereNom = matiere?.nom;

    return Scaffold(
      appBar: const EduCleAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: EduCleColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: EduCleColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: EduCleColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 14)),
                    ),
                    if (matiereNom != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        matiereNom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: EduCleColors.textSecondary,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '·',
                          style: TextStyle(color: EduCleColors.border),
                        ),
                      ),
                    ] else
                      const SizedBox(width: 6),
                    Text(
                      chapitre.titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: EduCleColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choisis ton mode de jeu',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Le mode détermine le rythme et le moment de la correction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: EduCleColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BoutonMode(
                    icone: Icons.style_rounded,
                    label: 'Cartes mentales',
                    couleur: const Color(0xFF8E24AA),
                    actif: chapitre.cartesMentales.isNotEmpty,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CartesMentalesScreen(chapitre: chapitre),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BoutonMode(
                    icone: Icons.school_rounded,
                    label: 'Apprentissage',
                    couleur: const Color(0xFF0288D1),
                    actif: chapitre.questions.isNotEmpty || chapitre.cartesMentales.isNotEmpty,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ApprentissageScreen(chapitre: chapitre),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...ParametrePartie.modes.map(
              (mode) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CarteMode(
                  mode: mode,
                  couleur: _couleurs[mode.nom] ?? EduCleColors.primary,
                  icone: _icones[mode.nom] ?? Icons.play_arrow_rounded,
                  sousTitre: _sousTitres[mode.nom] ?? '',
                  description: _descriptions[mode.nom] ?? '',
                  onTap: () => _lancer(context, mode),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lancer(BuildContext context, ParametrePartie mode) async {
    final controller = context.read<QuizController>();
    final quiz = await controller.lancerQuiz(mode);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz, mode: mode)),
    );
  }
}

class _BoutonMode extends StatelessWidget {
  final IconData icone;
  final String label;
  final Color couleur;
  final bool actif;
  final VoidCallback onTap;

  const _BoutonMode({
    required this.icone,
    required this.label,
    required this.couleur,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleurEff = actif ? couleur : EduCleColors.textSecondary;
    return Material(
      color: couleurEff.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: actif ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: couleurEff.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, color: couleurEff, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: couleurEff,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteMode extends StatelessWidget {
  final ParametrePartie mode;
  final Color couleur;
  final IconData icone;
  final String sousTitre;
  final String description;
  final VoidCallback onTap;

  const _CarteMode({
    required this.mode,
    required this.couleur,
    required this.icone,
    required this.sousTitre,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EduCleColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EduCleColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: couleur,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icone, color: couleur),
                        const SizedBox(width: 10),
                        Text(
                          mode.nom,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: EduCleColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sousTitre,
                      style: TextStyle(
                        color: couleur,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        color: EduCleColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
