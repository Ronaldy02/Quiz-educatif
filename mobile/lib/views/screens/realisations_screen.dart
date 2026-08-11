import 'package:flutter/material.dart';
import '../../models/realisation.dart';
import '../../services/database_helper.dart';
import '../../services/realisation_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/educle_logo.dart';

class RealisationsScreen extends StatefulWidget {
  const RealisationsScreen({super.key});

  @override
  State<RealisationsScreen> createState() => _RealisationsScreenState();
}

class _RealisationsScreenState extends State<RealisationsScreen> {
  List<Realisation> _toutes = [];
  RealisationCategorie? _filtreCategorie;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final db = await DatabaseHelper.instance.database;
    final liste = await RealisationService.charger(db);
    if (mounted) setState(() { _toutes = liste; _chargement = false; });
  }

  List<Realisation> get _filtrees {
    if (_filtreCategorie == null) return _toutes;
    return _toutes.where((r) => r.categorie == _filtreCategorie).toList();
  }

  int get _nbDebloquees => _toutes.where((r) => r.debloquee).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const EduCleLogo(),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🏅 RÉALISATIONS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (!_chargement) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$_nbDebloquees / ${_toutes.length} débloquées',
                      style: const TextStyle(
                        color: EduCleColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _toutes.isEmpty
                            ? 0
                            : _nbDebloquees / _toutes.length,
                        minHeight: 6,
                        backgroundColor: EduCleColors.border,
                        color: EduCleColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Filtres catégories
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ChipFiltre(
                    label: 'Toutes',
                    selectionne: _filtreCategorie == null,
                    onTap: () => setState(() => _filtreCategorie = null),
                  ),
                  ...RealisationCategorie.values.map((c) => _ChipFiltre(
                    label: '${Realisation.categorieEmoji(c)} ${Realisation.categorieLibelle(c)}',
                    selectionne: _filtreCategorie == c,
                    onTap: () => setState(
                      () => _filtreCategorie = _filtreCategorie == c ? null : c,
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Liste
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator())
                  : _filtrees.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucune réalisation dans cette catégorie.',
                            style: TextStyle(color: EduCleColors.textSecondary),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.88,
                          ),
                          itemCount: _filtrees.length,
                          itemBuilder: (ctx, i) => _CarteRealisation(
                            realisation: _filtrees[i],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipFiltre extends StatelessWidget {
  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  const _ChipFiltre({
    required this.label,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selectionne ? EduCleColors.primary : EduCleColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selectionne ? EduCleColors.primary : EduCleColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selectionne ? Colors.white : EduCleColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteRealisation extends StatelessWidget {
  final Realisation realisation;

  const _CarteRealisation({required this.realisation});

  @override
  Widget build(BuildContext context) {
    final r = realisation;
    final couleur = Realisation.rareteColor(r.rarete);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EduCleColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: r.debloquee ? couleur : EduCleColors.border,
          width: r.debloquee ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône / état
          Text(
            r.debloquee
                ? '🏅'
                : r.secret
                    ? '❓'
                    : Realisation.categorieEmoji(r.categorie),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 8),
          // Nom
          Text(
            r.secret && !r.debloquee ? 'Réalisation secrète' : r.nom,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: r.debloquee ? couleur : null,
            ),
          ),
          const SizedBox(height: 4),
          // Description
          Expanded(
            child: Text(
              r.secret && !r.debloquee ? '???' : r.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: EduCleColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Barre de progression ou statut
          if (r.debloquee) ...[
            Row(
              children: [
                const Text('✓ ', style: TextStyle(fontSize: 11, color: Color(0xFF22C55E), fontWeight: FontWeight.w700)),
                Text(
                  'Débloquée',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF22C55E),
                  ),
                ),
                if (r.recompensePieces > 0) ...[
                  const Spacer(),
                  Text(
                    '+${r.recompensePieces} 🪙',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (r.objectif > 0 && !r.secret) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: r.objectif > 0 ? r.progres / r.objectif : 0,
                minHeight: 4,
                backgroundColor: EduCleColors.border,
                color: couleur,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${r.progres} / ${r.objectif}',
              style: const TextStyle(
                fontSize: 10,
                color: EduCleColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
