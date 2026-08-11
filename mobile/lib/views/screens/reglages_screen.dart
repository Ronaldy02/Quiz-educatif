import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/quiz_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/educle_app_bar.dart';
import 'admin_screen.dart';

const List<String> _kPays = [
  'Haïti',
  'Rép. Dominicaine',
  'États-Unis',
  'Canada',
  'France',
  'Belgique',
];

const Map<String, List<String>> _kRegions = {
  'Haïti': [
    'Artibonite', 'Centre', 'Grand\'Anse', 'Nippes',
    'Nord', 'Nord-Est', 'Nord-Ouest', 'Ouest', 'Sud', 'Sud-Est',
  ],
  'Rép. Dominicaine': [
    'Cibao Norte', 'Cibao Sur', 'Cibao Nordeste', 'Cibao Noroeste',
    'Valdesia', 'Enriquillo', 'El Valle', 'Yuma', 'Higuamo', 'Ozama',
  ],
  'États-Unis': [
    'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'Californie', 'Caroline du Nord',
    'Caroline du Sud', 'Colorado', 'Connecticut', 'Dakota du Nord', 'Dakota du Sud',
    'Delaware', 'Floride', 'Géorgie', 'Hawaï', 'Idaho', 'Illinois', 'Indiana',
    'Iowa', 'Kansas', 'Kentucky', 'Louisiane', 'Maine', 'Maryland', 'Massachusetts',
    'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska',
    'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico', 'New York', 'Ohio',
    'Oklahoma', 'Oregon', 'Pennsylvanie', 'Rhode Island', 'Tennessee', 'Texas',
    'Utah', 'Vermont', 'Virginie', 'Washington', 'Virginie-Occidentale', 'Wisconsin',
    'Wyoming',
  ],
  'Canada': [
    'Alberta', 'Colombie-Britannique', 'Manitoba', 'Nouveau-Brunswick',
    'Terre-Neuve-et-Labrador', 'Nouvelle-Écosse', 'Ontario',
    'Île-du-Prince-Édouard', 'Québec', 'Saskatchewan',
    'Territoires du Nord-Ouest', 'Nunavut', 'Yukon',
  ],
  'France': [
    'Auvergne-Rhône-Alpes', 'Bourgogne-Franche-Comté', 'Bretagne',
    'Centre-Val de Loire', 'Corse', 'Grand Est', 'Hauts-de-France',
    'Île-de-France', 'Normandie', 'Nouvelle-Aquitaine', 'Occitanie',
    'Pays de la Loire', "Provence-Alpes-Côte d'Azur",
    'Guadeloupe', 'Martinique', 'Guyane', 'La Réunion', 'Mayotte',
  ],
  'Belgique': [
    'Anvers', 'Brabant flamand', 'Brabant wallon', 'Bruxelles-Capitale',
    'Flandre occidentale', 'Flandre orientale', 'Hainaut',
    'Liège', 'Limbourg', 'Luxembourg', 'Namur',
  ],
};

String _labelRegion(String pays) {
  switch (pays) {
    case 'Haïti':
      return 'Département';
    case 'États-Unis':
      return 'État';
    case 'Canada':
      return 'Province / Territoire';
    default:
      return 'Région';
  }
}

class ReglagesScreen extends StatelessWidget {
  const ReglagesScreen({super.key});

  static const List<int> _options = [5, 10, 15, 20];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuizController>();
    final annees = controller.niveauScolaire == 'Secondaire'
        ? ['NS1', 'NS2', 'NS3', 'NS4']
        : ['7e AF', '8e AF', '9e AF'];
    final regions = _kRegions[controller.pays] ?? [];

    return Scaffold(
      appBar: const EduCleAppBar(labelRetour: 'Retour'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Text(
              'Réglages',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 28),

            // ── Nombre de questions ──────────────────────────────────────
            const _SectionTitre(titre: 'Nombre de questions'),
            const SizedBox(height: 12),
            _CarteReglage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    value: controller.nombreQuestions,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: EduCleColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: EduCleColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: EduCleColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: EduCleColors.primary),
                      ),
                    ),
                    items: _options
                        .map((nb) => DropdownMenuItem(
                              value: nb,
                              child: Text('$nb questions'),
                            ))
                        .toList(),
                    onChanged: (nb) {
                      if (nb != null) {
                        context
                            .read<QuizController>()
                            .changerNombreQuestions(nb);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const _NoteInfo(
                    texte:
                        'Mode Bombardement : jusqu\'à 30 questions aléatoires, indépendamment de ce réglage.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Cycle d'études ───────────────────────────────────────────
            _SectionTitre(titre: 'Cycle d\'études'),
            const SizedBox(height: 12),
            _CarteReglage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sélectionne ton niveau pour n\'afficher que les matières correspondantes.',
                    style: TextStyle(
                      color: EduCleColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _BoutonCycle(
                          label: 'Fondamental',
                          sousTitre: '7e à 9e AF',
                          selectionne:
                              controller.niveauScolaire == 'Fondamental',
                          onTap: () => context
                              .read<QuizController>()
                              .changerNiveauScolaire('Fondamental'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BoutonCycle(
                          label: 'Secondaire',
                          sousTitre: 'NS1 à NS4',
                          selectionne:
                              controller.niveauScolaire == 'Secondaire',
                          onTap: () => context
                              .read<QuizController>()
                              .changerNiveauScolaire('Secondaire'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Niveau / Année ───────────────────────────────────────────
            const _SectionTitre(titre: 'Niveau / Année'),
            const SizedBox(height: 12),
            _CarteReglage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sélectionne ton année scolaire pour un suivi plus précis.',
                    style: TextStyle(
                      color: EduCleColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: annees
                        .map((annee) => _BoutonAnnee(
                              label: annee,
                              selectionne: controller.annee == annee,
                              onTap: () => context
                                  .read<QuizController>()
                                  .changerAnnee(annee),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Difficulté ───────────────────────────────────────────────
            const _SectionTitre(titre: 'Difficulté'),
            const SizedBox(height: 12),
            _CarteReglage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtre les questions selon leur niveau de difficulté.',
                    style: TextStyle(
                      color: EduCleColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Toutes', 'Facile', 'Moyen', 'Difficile']
                        .map((d) => _BoutonAnnee(
                              label: d,
                              selectionne: controller.difficulte == d,
                              onTap: () => context
                                  .read<QuizController>()
                                  .changerDifficulte(d),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Localisation ─────────────────────────────────────────────
            const _SectionTitre(titre: 'Localisation'),
            const SizedBox(height: 12),
            _CarteReglage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choisis ton pays puis ta région pour le classement par zone.',
                    style: TextStyle(
                      color: EduCleColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kPays
                        .map((p) => _BoutonAnnee(
                              label: p,
                              selectionne: controller.pays == p,
                              onTap: () => context
                                  .read<QuizController>()
                                  .changerPays(p),
                            ))
                        .toList(),
                  ),
                  if (regions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _MiniTitre(texte: _labelRegion(controller.pays)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: regions
                          .map((r) => _BoutonAnnee(
                                label: r,
                                selectionne: controller.ville == r,
                                onTap: () => context
                                    .read<QuizController>()
                                    .changerVille(r),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Portefeuille ─────────────────────────────────────────────
            const _SectionTitre(titre: 'Mon portefeuille'),
            const SizedBox(height: 12),
            const _PortefeuilleCard(),
            const SizedBox(height: 28),

            // ── À propos ─────────────────────────────────────────────────
            const _SectionTitre(titre: 'À propos'),
            const SizedBox(height: 12),
            _CarteReglage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LigneInfo(libelle: 'Application', valeur: 'EduClé'),
                  const Divider(height: 20),
                  GestureDetector(
                    onLongPress: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AdminScreen()),
                      );
                    },
                    child: const _LigneInfo(libelle: 'Version', valeur: '1.0.0'),
                  ),
                  const Divider(height: 20),
                  const _LigneInfo(
                      libelle: 'Créé par', valeur: 'Coding Club ISTEAH'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Portefeuille XP / pièces ─────────────────────────────────────────────────

class _PortefeuilleCard extends StatefulWidget {
  const _PortefeuilleCard();

  @override
  State<_PortefeuilleCard> createState() => _PortefeuilleCardState();
}

class _PortefeuilleCardState extends State<_PortefeuilleCard> {
  int _xp = 0;
  int _pieces = 0;
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final data = await context.read<QuizController>().getXpPieces();
    if (mounted) {
      setState(() {
        _xp = data['xp'] ?? 0;
        _pieces = data['pieces'] ?? 0;
        _charge = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_charge) {
      return const _CarteReglage(
        child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return _CarteReglage(
      child: Row(
        children: [
          Expanded(
            child: _StatPortefeuille(
              emoji: '⭐',
              label: 'XP total',
              valeur: _xp,
              couleur: const Color(0xFFB45309),
            ),
          ),
          Container(width: 1, height: 48, color: EduCleColors.border),
          Expanded(
            child: _StatPortefeuille(
              emoji: '🪙',
              label: 'Pièces',
              valeur: _pieces,
              couleur: const Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPortefeuille extends StatelessWidget {
  final String emoji;
  final String label;
  final int valeur;
  final Color couleur;

  const _StatPortefeuille({
    required this.emoji,
    required this.label,
    required this.valeur,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          valeur.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: couleur,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: EduCleColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionTitre extends StatelessWidget {
  final String titre;
  const _SectionTitre({required this.titre});

  @override
  Widget build(BuildContext context) {
    return Text(
      titre.toUpperCase(),
      style: const TextStyle(
        color: EduCleColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _MiniTitre extends StatelessWidget {
  final String texte;
  const _MiniTitre({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      style: const TextStyle(
        color: EduCleColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _CarteReglage extends StatelessWidget {
  final Widget child;
  const _CarteReglage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EduCleColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EduCleColors.border),
      ),
      child: child,
    );
  }
}


class _NoteInfo extends StatelessWidget {
  final String texte;
  const _NoteInfo({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EduCleColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: EduCleColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                fontSize: 13,
                color: EduCleColors.primary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneInfo extends StatelessWidget {
  final String libelle;
  final String valeur;
  const _LigneInfo({required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(libelle, style: const TextStyle(color: EduCleColors.textSecondary)),
        Text(valeur, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _BoutonAnnee extends StatelessWidget {
  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  const _BoutonAnnee({
    required this.label,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        decoration: BoxDecoration(
          color: selectionne ? EduCleColors.primary : EduCleColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selectionne ? EduCleColors.primary : EduCleColors.border,
            width: selectionne ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selectionne ? Colors.white : EduCleColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _BoutonCycle extends StatelessWidget {
  final String label;
  final String sousTitre;
  final bool selectionne;
  final VoidCallback onTap;

  const _BoutonCycle({
    required this.label,
    required this.sousTitre,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selectionne ? EduCleColors.primary : EduCleColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectionne ? EduCleColors.primary : EduCleColors.border,
            width: selectionne ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: selectionne ? Colors.white : EduCleColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sousTitre,
              style: TextStyle(
                fontSize: 11,
                color: selectionne ? Colors.white70 : EduCleColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
