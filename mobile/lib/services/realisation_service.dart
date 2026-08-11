import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/realisation.dart';
import '../utils/niveau.dart';

/// Clés de la table realisation_stats.
class _Stat {
  static const totalCorrectes = 'total_correctes';
  static const serieMaxGlobal = 'serie_max_global';
  static const bombMeilleur = 'bomb_meilleur';
  static const joursConsecutifs = 'jours_consecutifs';
  static const joursConsecutifsMax = 'jours_consecutifs_max';
  static const dernierQuizDate = 'dernier_quiz_date'; // YYYY-MM-DD in valeur_text
  static const premierQuizFait = 'premier_quiz_fait';
  static const premierRushFait = 'premier_rush_fait';
  static const premiereRevisionFaite = 'premiere_revision_faite';
  static const premierBombardementFait = 'premier_bombardement_fait';
  // ignore: unused_field — déclencheurs futurs (boutique / bonus)
  static const premierBonusUtilise = 'premier_bonus_utilise';
  // ignore: unused_field — déclencheurs futurs (boutique / bonus)
  static const typesBonusUtilises = 'types_bonus_utilises';
  static const matiereJouees = 'matieres_jouees'; // JSON list in valeur_text
}

class RealisationService {
  RealisationService._();

  // ─── Définitions statiques (sans maîtrise par matière) ───────────────────

  static List<Realisation> _definitionsStatiques() => [
    // Apprentissage
    Realisation(id: 'app_premier_pas', nom: 'Premier pas', description: 'Réussir sa première question.', categorie: RealisationCategorie.apprentissage, rarete: RealisationRarete.commune, objectif: 1, recompensePieces: 0),
    Realisation(id: 'app_curieux', nom: 'Curieux', description: 'Réussir 100 questions.', categorie: RealisationCategorie.apprentissage, rarete: RealisationRarete.peuCommune, objectif: 100, recompensePieces: 5),
    Realisation(id: 'app_apprenant', nom: 'Apprenant', description: 'Réussir 500 questions.', categorie: RealisationCategorie.apprentissage, rarete: RealisationRarete.rare, objectif: 500, recompensePieces: 15),
    Realisation(id: 'app_assidu', nom: 'Étudiant assidu', description: 'Réussir 1 000 questions.', categorie: RealisationCategorie.apprentissage, rarete: RealisationRarete.epique, objectif: 1000, recompensePieces: 30),
    Realisation(id: 'app_grand', nom: 'Grand apprenant', description: 'Réussir 5 000 questions.', categorie: RealisationCategorie.apprentissage, rarete: RealisationRarete.epique, objectif: 5000, recompensePieces: 75),
    Realisation(id: 'app_maitre', nom: 'Maître de l\'apprentissage', description: 'Réussir 10 000 questions.', categorie: RealisationCategorie.apprentissage, rarete: RealisationRarete.legendaire, objectif: 10000, recompensePieces: 150),

    // Séries (Rush/Révision uniquement, spec §3)
    Realisation(id: 'serie_5', nom: 'Série de 5', description: 'Réussir 5 questions consécutives en Rush ou Révision.', categorie: RealisationCategorie.series, rarete: RealisationRarete.commune, objectif: 5, recompensePieces: 5),
    Realisation(id: 'serie_10', nom: 'Série de 10', description: 'Réussir 10 questions consécutives en Rush ou Révision.', categorie: RealisationCategorie.series, rarete: RealisationRarete.peuCommune, objectif: 10, recompensePieces: 10),
    Realisation(id: 'serie_15', nom: 'Série de 15', description: 'Réussir 15 questions consécutives en Rush ou Révision.', categorie: RealisationCategorie.series, rarete: RealisationRarete.rare, objectif: 15, recompensePieces: 18),
    Realisation(id: 'serie_20', nom: 'Série de 20', description: 'Réussir 20 questions consécutives en Rush ou Révision.', categorie: RealisationCategorie.series, rarete: RealisationRarete.epique, objectif: 20, recompensePieces: 25),

    // Performance (spec §4)
    Realisation(id: 'perf_parfait', nom: 'Quiz sans faute', description: 'Terminer un quiz avec 100 % de réussite.', categorie: RealisationCategorie.performance, rarete: RealisationRarete.peuCommune, objectif: 0, recompensePieces: 10),
    Realisation(id: 'perf_rapide', nom: 'Rapide', description: 'Réussir un quiz en respectant un temps moyen de réponse rapide.', categorie: RealisationCategorie.performance, rarete: RealisationRarete.rare, objectif: 0, recompensePieces: 15),
    Realisation(id: 'perf_record', nom: 'Nouveau record', description: 'Battre son meilleur score en Bombardement.', categorie: RealisationCategorie.performance, rarete: RealisationRarete.rare, objectif: 0, recompensePieces: 20),

    // Bombardement (spec §5 — paliers 6/10/15)
    Realisation(id: 'bomb_premier', nom: 'Premier bombardement', description: 'Terminer son premier Bombardement.', categorie: RealisationCategorie.bombardement, rarete: RealisationRarete.commune, objectif: 0, recompensePieces: 5),
    Realisation(id: 'bomb_6', nom: 'Bombardier', description: 'Obtenir au moins 6 bonnes réponses en Bombardement.', categorie: RealisationCategorie.bombardement, rarete: RealisationRarete.peuCommune, objectif: 6, recompensePieces: 10),
    Realisation(id: 'bomb_10', nom: 'Bombardier expert', description: 'Obtenir au moins 10 bonnes réponses en Bombardement.', categorie: RealisationCategorie.bombardement, rarete: RealisationRarete.rare, objectif: 10, recompensePieces: 20),
    Realisation(id: 'bomb_15', nom: 'Bombardier légendaire', description: 'Obtenir au moins 15 bonnes réponses en Bombardement.', categorie: RealisationCategorie.bombardement, rarete: RealisationRarete.epique, objectif: 15, recompensePieces: 35),

    // Maîtrise globale (spec §6 — seuils provisoires 50 %/75 %)
    Realisation(id: 'mait_competent', nom: 'Élève compétent', description: 'Atteindre 50 % de maîtrise globale.', categorie: RealisationCategorie.maitrise, rarete: RealisationRarete.peuCommune, objectif: 50, recompensePieces: 15),
    Realisation(id: 'mait_expert', nom: 'Élève expert', description: 'Atteindre 75 % de maîtrise globale.', categorie: RealisationCategorie.maitrise, rarete: RealisationRarete.rare, objectif: 75, recompensePieces: 30),

    // Maîtrise par difficulté (spec §7)
    Realisation(id: 'mait_facile', nom: 'Maître du facile', description: 'Maîtriser les questions faciles à 80 %.', categorie: RealisationCategorie.maitrise, rarete: RealisationRarete.peuCommune, objectif: 80, recompensePieces: 10),
    Realisation(id: 'mait_moyen', nom: 'Maître du moyen', description: 'Maîtriser les questions moyennes à 65 %.', categorie: RealisationCategorie.maitrise, rarete: RealisationRarete.rare, objectif: 65, recompensePieces: 20),
    Realisation(id: 'mait_difficile', nom: 'Maître du difficile', description: 'Maîtriser les questions difficiles à 50 %.', categorie: RealisationCategorie.maitrise, rarete: RealisationRarete.epique, objectif: 50, recompensePieces: 30),

    // Régularité (spec §8)
    Realisation(id: 'reg_3j', nom: '3 jours', description: '3 jours consécutifs.', categorie: RealisationCategorie.regularite, rarete: RealisationRarete.commune, objectif: 3, recompensePieces: 5),
    Realisation(id: 'reg_7j', nom: '7 jours', description: '7 jours consécutifs.', categorie: RealisationCategorie.regularite, rarete: RealisationRarete.commune, objectif: 7, recompensePieces: 10),
    Realisation(id: 'reg_14j', nom: '14 jours', description: '14 jours consécutifs.', categorie: RealisationCategorie.regularite, rarete: RealisationRarete.peuCommune, objectif: 14, recompensePieces: 20),
    Realisation(id: 'reg_30j', nom: '30 jours', description: '30 jours consécutifs.', categorie: RealisationCategorie.regularite, rarete: RealisationRarete.peuCommune, objectif: 30, recompensePieces: 35),
    Realisation(id: 'reg_60j', nom: '60 jours', description: '60 jours consécutifs.', categorie: RealisationCategorie.regularite, rarete: RealisationRarete.rare, objectif: 60, recompensePieces: 60),
    Realisation(id: 'reg_100j', nom: '100 jours', description: '100 jours consécutifs.', categorie: RealisationCategorie.regularite, rarete: RealisationRarete.epique, objectif: 100, recompensePieces: 100),
    Realisation(id: 'reg_365j', nom: '365 jours', description: '365 jours consécutifs.', categorie: RealisationCategorie.regularite, rarete: RealisationRarete.legendaire, objectif: 365, recompensePieces: 250),

    // Progression / niveaux (spec §9)
    Realisation(id: 'niv_5', nom: 'Niveau 5', description: 'Atteindre le niveau 5.', categorie: RealisationCategorie.progression, rarete: RealisationRarete.commune, objectif: 5, recompensePieces: 10),
    Realisation(id: 'niv_10', nom: 'Niveau 10', description: 'Atteindre le niveau 10.', categorie: RealisationCategorie.progression, rarete: RealisationRarete.peuCommune, objectif: 10, recompensePieces: 20),
    Realisation(id: 'niv_20', nom: 'Niveau 20', description: 'Atteindre le niveau 20.', categorie: RealisationCategorie.progression, rarete: RealisationRarete.rare, objectif: 20, recompensePieces: 40),
    Realisation(id: 'niv_50', nom: 'Niveau 50', description: 'Atteindre le niveau 50.', categorie: RealisationCategorie.progression, rarete: RealisationRarete.epique, objectif: 50, recompensePieces: 80),
    Realisation(id: 'niv_100', nom: 'Niveau 100', description: 'Atteindre le niveau 100.', categorie: RealisationCategorie.progression, rarete: RealisationRarete.legendaire, objectif: 100, recompensePieces: 200),

    // Défis (stubs — système non encore disponible, spec §10)
    Realisation(id: 'defi_premier', nom: 'Premier défi', description: 'Terminer son premier défi.', categorie: RealisationCategorie.defis, rarete: RealisationRarete.commune, objectif: 0, recompensePieces: 5),
    Realisation(id: 'defi_quotidien', nom: 'Défi quotidien', description: 'Terminer plusieurs défis quotidiens.', categorie: RealisationCategorie.defis, rarete: RealisationRarete.peuCommune, objectif: 0, recompensePieces: 15),
    Realisation(id: 'defi_hebdo', nom: 'Défi hebdomadaire', description: 'Terminer plusieurs défis hebdomadaires.', categorie: RealisationCategorie.defis, rarete: RealisationRarete.rare, objectif: 0, recompensePieces: 30),
    Realisation(id: 'defi_serie', nom: 'Série de défis', description: 'Terminer plusieurs défis consécutifs.', categorie: RealisationCategorie.defis, rarete: RealisationRarete.rare, objectif: 0, recompensePieces: 25),

    // Collection / économie (spec §11)
    Realisation(id: 'coll_premier_bonus', nom: 'Premier bonus', description: 'Utiliser son premier bonus.', categorie: RealisationCategorie.collection, rarete: RealisationRarete.commune, objectif: 0, recompensePieces: 5),
    Realisation(id: 'coll_stratege', nom: 'Stratège', description: 'Utiliser 2 types de bonus différents.', categorie: RealisationCategorie.collection, rarete: RealisationRarete.peuCommune, objectif: 0, recompensePieces: 15),
    Realisation(id: 'coll_collectionneur', nom: 'Collectionneur', description: 'Accumuler 100 pièces.', categorie: RealisationCategorie.collection, rarete: RealisationRarete.rare, objectif: 0, recompensePieces: 25),

    // Exploration (spec §12)
    Realisation(id: 'expl_premier_quiz', nom: 'Premier quiz', description: 'Terminer son premier quiz.', categorie: RealisationCategorie.exploration, rarete: RealisationRarete.commune, objectif: 0, recompensePieces: 5),
    Realisation(id: 'expl_premier_rush', nom: 'Premier Rush', description: 'Terminer son premier Rush.', categorie: RealisationCategorie.exploration, rarete: RealisationRarete.commune, objectif: 0, recompensePieces: 5),
    Realisation(id: 'expl_premiere_revision', nom: 'Première Révision', description: 'Terminer sa première session Révision.', categorie: RealisationCategorie.exploration, rarete: RealisationRarete.commune, objectif: 0, recompensePieces: 5),
    Realisation(id: 'expl_premier_bombardement', nom: 'Premier Bombardement', description: 'Terminer son premier Bombardement.', categorie: RealisationCategorie.exploration, rarete: RealisationRarete.commune, objectif: 0, recompensePieces: 5),
    Realisation(id: 'expl_premier_bonus', nom: 'Premier bonus', description: 'Utiliser un bonus pour la première fois.', categorie: RealisationCategorie.exploration, rarete: RealisationRarete.commune, objectif: 0, recompensePieces: 5),
    Realisation(id: 'expl_adaptive', nom: 'Première session adaptative', description: 'Terminer une session avec sélection adaptative.', categorie: RealisationCategorie.exploration, rarete: RealisationRarete.peuCommune, objectif: 0, recompensePieces: 10),
    Realisation(id: 'expl_explorateur', nom: 'Explorateur', description: 'Jouer dans 3 matières différentes.', categorie: RealisationCategorie.exploration, rarete: RealisationRarete.peuCommune, objectif: 3, recompensePieces: 15),
  ];

  // ─── Initialisation ──────────────────────────────────────────────────────

  /// Insère les réalisations statiques et génère les réalisations par matière.
  /// Utilise INSERT OR IGNORE pour être idempotent.
  static Future<void> initialiser(Database db) async {
    final defs = _definitionsStatiques();
    for (final r in defs) {
      await db.insert(
        'realisations',
        r.toInsertMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Réalisations dynamiques : une par matière présente en DB
    final matieres = await db.query('matieres', columns: ['id', 'nom']);
    for (final m in matieres) {
      final mid = m['id'] as int;
      final mnom = m['nom'] as String;
      final r = Realisation(
        id: 'mait_matiere_$mid',
        nom: 'Expert en $mnom',
        description: 'Atteindre 60 % de maîtrise en $mnom.',
        categorie: RealisationCategorie.maitrise,
        rarete: RealisationRarete.rare,
        objectif: 60,
        recompensePieces: 20,
      );
      await db.insert(
        'realisations',
        r.toInsertMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ─── Lecture ─────────────────────────────────────────────────────────────

  static Future<List<Realisation>> charger(Database db) async {
    final rows = await db.query(
      'realisations',
      orderBy: 'categorie ASC, rarete ASC',
    );
    return rows.map(Realisation.fromMap).toList();
  }

  // ─── Stats helpers ────────────────────────────────────────────────────────

  static Future<int> _statInt(Database db, String cle) async {
    final row = await db.query(
      'realisation_stats',
      columns: ['valeur_int'],
      where: 'cle = ?',
      whereArgs: [cle],
    );
    return row.isEmpty ? 0 : (row.first['valeur_int'] as int? ?? 0);
  }

  static Future<String?> _statText(Database db, String cle) async {
    final row = await db.query(
      'realisation_stats',
      columns: ['valeur_text'],
      where: 'cle = ?',
      whereArgs: [cle],
    );
    return row.isEmpty ? null : row.first['valeur_text'] as String?;
  }

  static Future<void> _setStatInt(Database db, String cle, int v) async {
    await db.insert(
      'realisation_stats',
      {'cle': cle, 'valeur_int': v, 'valeur_text': null},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _setStatText(Database db, String cle, String v) async {
    await db.insert(
      'realisation_stats',
      {'cle': cle, 'valeur_int': 0, 'valeur_text': v},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Mise à jour des stats après quiz ────────────────────────────────────

  static Future<bool> _mettreAJourStats({
    required Database db,
    required String modeNom,
    required int nbCorrectesCettePartie,
    required int scoreBombardement,
    required int serieMax,
    required int? subjectId,
    required int piecesTotal,
  }) async {
    // Total correctes
    final ancien = await _statInt(db, _Stat.totalCorrectes);
    await _setStatInt(db, _Stat.totalCorrectes, ancien + nbCorrectesCettePartie);

    // Série max globale (Rush/Révision uniquement, spec §3)
    if (modeNom != 'Bombardement' && serieMax > 0) {
      final ancienMax = await _statInt(db, _Stat.serieMaxGlobal);
      if (serieMax > ancienMax) {
        await _setStatInt(db, _Stat.serieMaxGlobal, serieMax);
      }
    }

    // Meilleur score Bombardement + détection nouveau record
    bool nouveauRecord = false;
    if (modeNom == 'Bombardement') {
      final meilleur = await _statInt(db, _Stat.bombMeilleur);
      if (scoreBombardement > meilleur) {
        await _setStatInt(db, _Stat.bombMeilleur, scoreBombardement);
        // Premier quiz Bombardement ne compte pas comme record
        nouveauRecord = meilleur > 0;
      }
    }

    // Régularité : série quotidienne
    final aujourd = DateTime.now();
    final dateStr = '${aujourd.year.toString().padLeft(4, '0')}-'
        '${aujourd.month.toString().padLeft(2, '0')}-'
        '${aujourd.day.toString().padLeft(2, '0')}';
    final ancienDateStr = await _statText(db, _Stat.dernierQuizDate);
    if (ancienDateStr != dateStr) {
      int jours = await _statInt(db, _Stat.joursConsecutifs);
      if (ancienDateStr != null) {
        final ancienDate = DateTime.tryParse(ancienDateStr);
        if (ancienDate != null) {
          final diff = aujourd.difference(ancienDate).inDays;
          jours = diff == 1 ? jours + 1 : 1;
        } else {
          jours = 1;
        }
      } else {
        jours = 1;
      }
      await _setStatInt(db, _Stat.joursConsecutifs, jours);
      final maxJ = await _statInt(db, _Stat.joursConsecutifsMax);
      if (jours > maxJ) await _setStatInt(db, _Stat.joursConsecutifsMax, jours);
      await _setStatText(db, _Stat.dernierQuizDate, dateStr);
    }

    // Premiers modes
    await _setStatInt(db, _Stat.premierQuizFait, 1);
    if (modeNom == 'Rush') await _setStatInt(db, _Stat.premierRushFait, 1);
    if (modeNom == 'Révision') await _setStatInt(db, _Stat.premiereRevisionFaite, 1);
    if (modeNom == 'Bombardement') await _setStatInt(db, _Stat.premierBombardementFait, 1);

    // Matières jouées
    if (subjectId != null) {
      final raw = await _statText(db, _Stat.matiereJouees);
      final liste = raw != null
          ? (jsonDecode(raw) as List).cast<int>()
          : <int>[];
      if (!liste.contains(subjectId)) {
        liste.add(subjectId);
        await _setStatText(db, _Stat.matiereJouees, jsonEncode(liste));
      }
    }

    return nouveauRecord;
  }

  // ─── Calcul de maîtrise depuis la DB ─────────────────────────────────────

  /// Retourne la maîtrise globale en pourcentage (0-100) depuis la table statistiques_questions.
  static Future<int> _maitriseGlobale(Database db) async {
    final rows = await db.query(
      'statistiques_questions',
      columns: ['historique'],
      where: 'historique IS NOT NULL AND historique != \'[]\'',
    );
    if (rows.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (final row in rows) {
      final hist = _parseHistorique(row['historique'] as String?);
      if (hist.isNotEmpty) {
        total += hist.reduce((a, b) => a + b) / hist.length;
        count++;
      }
    }
    return count == 0 ? 0 : (total / count * 100).round();
  }

  /// Maîtrise par difficulté. Retourne un map {difficulte: pourcentage}.
  static Future<Map<String, int>> _maitriseParDifficulte(Database db) async {
    try {
      final rows = await db.rawQuery('''
        SELECT q.difficulte, sq.historique
        FROM statistiques_questions sq
        JOIN questions q ON q.id = sq.question_id
        WHERE sq.historique IS NOT NULL AND sq.historique != '[]'
      ''');
      final sums = <String, double>{};
      final counts = <String, int>{};
      for (final row in rows) {
        final diff = row['difficulte'] as String? ?? 'moyen';
        final hist = _parseHistorique(row['historique'] as String?);
        if (hist.isNotEmpty) {
          sums[diff] = (sums[diff] ?? 0) + hist.reduce((a, b) => a + b) / hist.length;
          counts[diff] = (counts[diff] ?? 0) + 1;
        }
      }
      return {
        for (final k in sums.keys)
          k: (sums[k]! / counts[k]! * 100).round(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Maîtrise par matière. Retourne un map {matiere_id: pourcentage}.
  static Future<Map<int, int>> _maitriseParMatiere(Database db) async {
    try {
      final rows = await db.rawQuery('''
        SELECT q.matiere_id, sq.historique
        FROM statistiques_questions sq
        JOIN questions q ON q.id = sq.question_id
        WHERE sq.historique IS NOT NULL AND sq.historique != '[]'
      ''');
      final sums = <int, double>{};
      final counts = <int, int>{};
      for (final row in rows) {
        final mid = row['matiere_id'] as int;
        final hist = _parseHistorique(row['historique'] as String?);
        if (hist.isNotEmpty) {
          sums[mid] = (sums[mid] ?? 0) + hist.reduce((a, b) => a + b) / hist.length;
          counts[mid] = (counts[mid] ?? 0) + 1;
        }
      }
      return {for (final k in sums.keys) k: (sums[k]! / counts[k]! * 100).round()};
    } catch (_) {
      return {};
    }
  }

  static List<double> _parseHistorique(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Déblocage d'une réalisation ─────────────────────────────────────────

  static Future<void> _debloquer(Database db, Realisation r) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'realisations',
      {
        'debloquee': 1,
        'debloquee_at': now,
        'progres': r.objectif > 0 ? r.objectif : 1,
      },
      where: 'id = ?',
      whereArgs: [r.id],
    );
    if (r.recompensePieces > 0) {
      await db.rawUpdate(
        'UPDATE user_preferences SET pieces_total = pieces_total + ? WHERE id = 1',
        [r.recompensePieces],
      );
    }
  }

  static Future<void> _updateProgres(Database db, String id, int p) async {
    await db.update(
      'realisations',
      {'progres': p},
      where: 'id = ? AND debloquee = 0',
      whereArgs: [id],
    );
  }

  // ─── Point d'entrée principal ─────────────────────────────────────────────

  /// Vérifie et débloque les réalisations après la fin d'un quiz.
  ///
  /// [modeNom] : 'Rush', 'Révision' ou 'Bombardement'.
  /// [nbCorrectesCettePartie] : bonnes réponses dans ce quiz.
  /// [estPerfect] : toutes les réponses correctes (hors Bombardement).
  /// [scoreBombardement] : nombre de bonnes réponses en Bombardement.
  /// [serieMax] : plus longue série atteinte dans ce quiz (Rush/Révision).
  /// [xpTotal] : XP total de l'utilisateur après ce quiz.
  /// [piecesTotal] : pièces totales de l'utilisateur après ce quiz.
  /// [subjectId] : matière du quiz (pour suivi d'exploration).
  ///
  /// Retourne la liste des réalisations nouvellement débloquées.
  static Future<List<Realisation>> verifierApresQuiz({
    required Database db,
    required String modeNom,
    required int nbCorrectesCettePartie,
    required bool estPerfect,
    required int scoreBombardement,
    required int serieMax,
    required int xpTotal,
    required int piecesTotal,
    int? subjectId,
  }) async {
    final estBombardement = modeNom == 'Bombardement';

    // 1. Mettre à jour les stats agrégées
    final nouveauRecord = await _mettreAJourStats(
      db: db,
      modeNom: modeNom,
      nbCorrectesCettePartie: nbCorrectesCettePartie,
      scoreBombardement: scoreBombardement,
      serieMax: serieMax,
      subjectId: subjectId,
      piecesTotal: piecesTotal,
    );

    // 2. Lire les stats actuelles
    final totalCorrectes = await _statInt(db, _Stat.totalCorrectes);
    final serieMaxGlobal = await _statInt(db, _Stat.serieMaxGlobal);
    final joursConsecutifs = await _statInt(db, _Stat.joursConsecutifs);
    final niveau = NiveauHelper.niveauDepuisXp(xpTotal);
    final matiereJoueesRaw = await _statText(db, _Stat.matiereJouees);
    final nbMatieres = matiereJoueesRaw != null
        ? (jsonDecode(matiereJoueesRaw) as List).length
        : 0;

    // 3. Maîtrise (calcul différé, fait une seule fois)
    final maitriseGlobale = await _maitriseGlobale(db);
    final maitriseParDiff = await _maitriseParDifficulte(db);
    final maitriseParMatiere = await _maitriseParMatiere(db);

    // 4. Charger toutes les réalisations non encore débloquées
    final toutes = await db.query(
      'realisations',
      where: 'debloquee = 0',
    );

    final nouvelles = <Realisation>[];

    for (final row in toutes) {
      final r = Realisation.fromMap(row);
      bool debloquer = false;
      int nouveauProgres = r.progres;

      switch (r.id) {
        // Apprentissage
        case 'app_premier_pas':
          nouveauProgres = min(totalCorrectes, 1);
          debloquer = totalCorrectes >= 1;
        case 'app_curieux':
          nouveauProgres = min(totalCorrectes, 100);
          debloquer = totalCorrectes >= 100;
        case 'app_apprenant':
          nouveauProgres = min(totalCorrectes, 500);
          debloquer = totalCorrectes >= 500;
        case 'app_assidu':
          nouveauProgres = min(totalCorrectes, 1000);
          debloquer = totalCorrectes >= 1000;
        case 'app_grand':
          nouveauProgres = min(totalCorrectes, 5000);
          debloquer = totalCorrectes >= 5000;
        case 'app_maitre':
          nouveauProgres = min(totalCorrectes, 10000);
          debloquer = totalCorrectes >= 10000;

        // Séries
        case 'serie_5':
          nouveauProgres = min(serieMaxGlobal, 5);
          debloquer = serieMaxGlobal >= 5;
        case 'serie_10':
          nouveauProgres = min(serieMaxGlobal, 10);
          debloquer = serieMaxGlobal >= 10;
        case 'serie_15':
          nouveauProgres = min(serieMaxGlobal, 15);
          debloquer = serieMaxGlobal >= 15;
        case 'serie_20':
          nouveauProgres = min(serieMaxGlobal, 20);
          debloquer = serieMaxGlobal >= 20;

        // Performance
        case 'perf_parfait':
          debloquer = estPerfect;
        case 'perf_rapide':
          // TODO : mesurer temps moyen par réponse (non disponible actuellement)
          debloquer = false;
        case 'perf_record':
          debloquer = nouveauRecord;

        // Bombardement
        case 'bomb_premier':
          debloquer = estBombardement;
        case 'bomb_6':
          if (estBombardement) {
            nouveauProgres = min(scoreBombardement, 6);
            debloquer = scoreBombardement >= 6;
          }
        case 'bomb_10':
          if (estBombardement) {
            nouveauProgres = min(scoreBombardement, 10);
            debloquer = scoreBombardement >= 10;
          }
        case 'bomb_15':
          if (estBombardement) {
            nouveauProgres = min(scoreBombardement, 15);
            debloquer = scoreBombardement >= 15;
          }

        // Maîtrise globale
        case 'mait_competent':
          nouveauProgres = min(maitriseGlobale, 50);
          debloquer = maitriseGlobale >= 50;
        case 'mait_expert':
          nouveauProgres = min(maitriseGlobale, 75);
          debloquer = maitriseGlobale >= 75;

        // Maîtrise par difficulté
        case 'mait_facile':
          final v = maitriseParDiff['facile'] ?? 0;
          nouveauProgres = min(v, 80);
          debloquer = v >= 80;
        case 'mait_moyen':
          final v = maitriseParDiff['moyen'] ?? 0;
          nouveauProgres = min(v, 65);
          debloquer = v >= 65;
        case 'mait_difficile':
          final v = maitriseParDiff['difficile'] ?? 0;
          nouveauProgres = min(v, 50);
          debloquer = v >= 50;

        // Régularité
        case 'reg_3j':
          nouveauProgres = min(joursConsecutifs, 3);
          debloquer = joursConsecutifs >= 3;
        case 'reg_7j':
          nouveauProgres = min(joursConsecutifs, 7);
          debloquer = joursConsecutifs >= 7;
        case 'reg_14j':
          nouveauProgres = min(joursConsecutifs, 14);
          debloquer = joursConsecutifs >= 14;
        case 'reg_30j':
          nouveauProgres = min(joursConsecutifs, 30);
          debloquer = joursConsecutifs >= 30;
        case 'reg_60j':
          nouveauProgres = min(joursConsecutifs, 60);
          debloquer = joursConsecutifs >= 60;
        case 'reg_100j':
          nouveauProgres = min(joursConsecutifs, 100);
          debloquer = joursConsecutifs >= 100;
        case 'reg_365j':
          nouveauProgres = min(joursConsecutifs, 365);
          debloquer = joursConsecutifs >= 365;

        // Progression
        case 'niv_5':
          nouveauProgres = min(niveau, 5);
          debloquer = niveau >= 5;
        case 'niv_10':
          nouveauProgres = min(niveau, 10);
          debloquer = niveau >= 10;
        case 'niv_20':
          nouveauProgres = min(niveau, 20);
          debloquer = niveau >= 20;
        case 'niv_50':
          nouveauProgres = min(niveau, 50);
          debloquer = niveau >= 50;
        case 'niv_100':
          nouveauProgres = min(niveau, 100);
          debloquer = niveau >= 100;

        // Défis (non disponibles)
        case 'defi_premier':
        case 'defi_quotidien':
        case 'defi_hebdo':
        case 'defi_serie':
          debloquer = false;

        // Collection (bonus non encore suivi)
        case 'coll_premier_bonus':
        case 'coll_stratege':
          debloquer = false;
        case 'coll_collectionneur':
          debloquer = piecesTotal >= 100;

        // Exploration
        case 'expl_premier_quiz':
          debloquer = true;
        case 'expl_premier_rush':
          debloquer = modeNom == 'Rush';
        case 'expl_premiere_revision':
          debloquer = modeNom == 'Révision';
        case 'expl_premier_bombardement':
          debloquer = estBombardement;
        case 'expl_premier_bonus':
          debloquer = false; // TODO : déclencher depuis l'écran boutique
        case 'expl_adaptive':
          // La sélection adaptative est toujours active
          debloquer = true;
        case 'expl_explorateur':
          nouveauProgres = min(nbMatieres, 3);
          debloquer = nbMatieres >= 3;

        default:
          // Réalisations dynamiques : maîtrise par matière
          if (r.id.startsWith('mait_matiere_')) {
            final mid = int.tryParse(r.id.replaceFirst('mait_matiere_', ''));
            if (mid != null) {
              final v = maitriseParMatiere[mid] ?? 0;
              nouveauProgres = min(v, 60);
              debloquer = v >= 60;
            }
          }
      }

      if (debloquer) {
        r.debloquee = true;
        r.debloqueeAt = DateTime.now();
        r.progres = r.objectif > 0 ? r.objectif : 1;
        nouvelles.add(r);
        await _debloquer(db, r);
      } else if (nouveauProgres != r.progres) {
        await _updateProgres(db, r.id, nouveauProgres);
      }
    }

    return nouvelles;
  }
}
