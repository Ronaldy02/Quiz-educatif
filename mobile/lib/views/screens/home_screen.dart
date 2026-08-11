import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/quiz_controller.dart';
import '../../models/chapitre.dart';
import '../../models/matiere.dart';
import '../../theme/app_theme.dart';
import '../widgets/educle_logo.dart';
import 'chapitre_screen.dart';
import 'classement_screen.dart';
import 'mode_jeu_screen.dart';
import 'onboarding_screen.dart';
import 'quiz_screen.dart';
import 'realisations_screen.dart';
import 'reglages_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = context.read<QuizController>();
      await ctrl.initialiser();
      if (!mounted) return;
      if (!ctrl.profilConfigure) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuizController>();
    final matieres = controller.matieres
        .where((m) => m.nom.toLowerCase().contains(_recherche.toLowerCase()))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: controller.chargement
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(
                            onSettings: () => _afficherReglages(context),
                            onStats: () => _afficherStats(context),
                            onClassement: () => _afficherClassement(context),
                            onRealisations: () => _afficherRealisations(context),
                          ),
                          const SizedBox(height: 20),
                          _BanniereHero(
                            onJouerTout: () => _jouerTout(context),
                          ),
                          if (controller.quizEnCoursDisponible) ...[
                            const SizedBox(height: 16),
                            _PilleReprendre(
                              onTap: () => _reprendre(context),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _BadgeContexte(
                            niveauScolaire: controller.niveauScolaire,
                            annee: controller.annee,
                            difficulte: controller.difficulte,
                            onTap: () => _afficherReglages(context),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Thématiques',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (controller.dernierChapitre != null)
                                _BoutonRejouer(
                                  chapitre: controller.dernierChapitre!,
                                  onTap: () => _rejouer(context),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _BarreRecherche(
                            onChanged: (v) =>
                                setState(() => _recherche = v),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (matieres.isEmpty && _recherche.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Aucune matière ne correspond à « $_recherche ».',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: EduCleColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _CarteMatiere(
                            matiere: matieres[index],
                            onTap: () =>
                                _choisirMatiere(context, matieres[index]),
                          ),
                          childCount: matieres.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 28),
                      child: Center(
                        child: Text(
                          'EduClé — Coding Club ISTEAH',
                          style: TextStyle(
                            color: EduCleColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _jouerTout(BuildContext context) async {
    final controller = context.read<QuizController>();
    final chapitre = await controller.choisirTout();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ModeJeuScreen(chapitre: chapitre)),
    );
  }

  void _rejouer(BuildContext context) {
    final chapitre = context.read<QuizController>().dernierChapitre!;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ModeJeuScreen(chapitre: chapitre)),
    );
  }

  Future<void> _choisirMatiere(BuildContext context, Matiere matiere) async {
    await context.read<QuizController>().choisirMatiere(matiere);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChapitreScreen()),
    );
  }

  Future<void> _reprendre(BuildContext context) async {
    final controller = context.read<QuizController>();
    final quiz = await controller.reprendreQuizSauvegarde();
    if (quiz == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(quiz: quiz, mode: quiz.mode),
      ),
    );
  }

  void _afficherReglages(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReglagesScreen()),
    );
  }

  void _afficherStats(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StatsScreen()),
    );
  }

  void _afficherClassement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClassementScreen()),
    );
  }

  void _afficherRealisations(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RealisationsScreen()),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onStats;
  final VoidCallback onClassement;
  final VoidCallback onRealisations;

  const _Header({
    required this.onSettings,
    required this.onStats,
    required this.onClassement,
    required this.onRealisations,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const EduCleLogo(),
        const Spacer(),
        _IconeBouton(
          icone: Icons.query_stats_rounded,
          onTap: onStats,
          tooltip: 'Statistiques',
        ),
        const SizedBox(width: 8),
        _IconeBouton(
          icone: Icons.military_tech_rounded,
          onTap: onRealisations,
          tooltip: 'Réalisations',
        ),
        const SizedBox(width: 8),
        _IconeBouton(
          icone: Icons.emoji_events_rounded,
          onTap: onClassement,
          tooltip: 'Classement',
        ),
        const SizedBox(width: 8),
        _IconeBouton(
          icone: Icons.settings_outlined,
          onTap: onSettings,
          tooltip: 'Réglages',
        ),
      ],
    );
  }
}

class _IconeBouton extends StatelessWidget {
  final IconData icone;
  final VoidCallback onTap;
  final String tooltip;

  const _IconeBouton({
    required this.icone,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: EduCleColors.border),
          color: EduCleColors.surface,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icone, color: EduCleColors.textSecondary, size: 20),
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _BanniereHero extends StatelessWidget {
  final VoidCallback onJouerTout;

  const _BanniereHero({required this.onJouerTout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: EduCleColors.bannerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'SANS COMPTE REQUIS',
              style: TextStyle(
                color: Colors.lightBlueAccent,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lance un quiz, toutes\nmatières confondues',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choisis ta matière et ton chapitre pour démarrer un quiz adapté.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onJouerTout,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Jouer (Tout)'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: EduCleColors.primary,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarreRecherche extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _BarreRecherche({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Rechercher une matière…',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: EduCleColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EduCleColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EduCleColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EduCleColors.primary),
        ),
      ),
    );
  }
}

class _BadgeContexte extends StatelessWidget {
  final String niveauScolaire;
  final String annee;
  final String difficulte;
  final VoidCallback onTap;

  const _BadgeContexte({
    required this.niveauScolaire,
    required this.annee,
    required this.difficulte,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          _Chip(label: '$niveauScolaire · $annee', icone: Icons.school_rounded),
          if (difficulte != 'Toutes') ...[
            const SizedBox(width: 8),
            _Chip(label: difficulte, icone: Icons.tune_rounded),
          ],
          const Spacer(),
          const Icon(
            Icons.edit_rounded,
            size: 13,
            color: EduCleColors.textSecondary,
          ),
          const SizedBox(width: 4),
          const Text(
            'Modifier',
            style: TextStyle(
              fontSize: 12,
              color: EduCleColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icone;

  const _Chip({required this.label, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: EduCleColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: EduCleColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: EduCleColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteMatiere extends StatelessWidget {
  final Matiere matiere;
  final VoidCallback onTap;

  const _CarteMatiere({required this.matiere, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = MatiereStyle.pour(matiere.nom);
    final emoji = MatiereStyle.emojiPour(matiere.nom);
    final imagePath = MatiereStyle.imagePour(matiere.nom);

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
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imagePath != null)
                Image.asset(
                  imagePath,
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) =>
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                )
              else
                Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                matiere.nom,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: style.couleur,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonRejouer extends StatelessWidget {
  final Chapitre chapitre;
  final VoidCallback onTap;

  const _BoutonRejouer({required this.chapitre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: EduCleColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: EduCleColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.replay_rounded,
              size: 14,
              color: EduCleColors.primary,
            ),
            const SizedBox(width: 4),
            const Text(
              'Rejouer',
              style: TextStyle(
                color: EduCleColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PilleReprendre extends StatelessWidget {
  final VoidCallback onTap;

  const _PilleReprendre({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: EduCleColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: EduCleColors.primary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: EduCleColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Reprendre le quiz en cours',
                style: TextStyle(
                  color: EduCleColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
