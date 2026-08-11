import 'dart:math';

import '../models/question.dart';

/// Statistiques de maitrise d'une question (fenetre glissante de 10 tentatives).
class QuestionStats {
  final int nbAffichee;
  final int nbCorrecte;
  final DateTime? derniereTentative;

  const QuestionStats({
    required this.nbAffichee,
    required this.nbCorrecte,
    this.derniereTentative,
  });

  double get tauxReussite =>
      nbAffichee == 0 ? 0.0 : nbCorrecte / nbAffichee;

  bool get jamaisTentee => nbAffichee == 0;
}

/// Moteur de selection adaptative.
///
/// Regle fondamentale (spec) :
///   Les parametres de l'eleve definissent le perimetre.
///   L'adaptation choisit les questions a l'interieur de ce perimetre
///   SANS modifier la representation des matieres, chapitres ou difficultes.
///
/// Algorithme en deux etapes :
///   1. Distribution equilibree : repartir [nbVoulu] slots entre les
///      matieres -> chapitres -> difficultes disponibles (approximativement
///      equidistribues).
///   2. Tirage pondere : dans chaque slot, selectionner la question selon
///      un score multicritere (nouveaute, maitrise, anciennete).
class AdaptiveSelector {
  // Coefficients de ponderation
  static const double _kBase = 10.0;      // toute question reste eligible
  static const double _kNouveaute = 40.0; // jamais tentee
  static const double _kMaitrise = 30.0;  // maitrise faible -> priorite haute
  static const double _kAnciennete = 20.0; // longtemps non vue -> priorite haute

  /// Selectionne au plus [nbVoulu] questions depuis [pool].
  ///
  /// [chapitreIdVersMatiere] : chapitreId -> matiereId.
  ///   Non-vide uniquement quand plusieurs matieres sont dans le pool
  ///   (choisirTout / choisirThemeSVT). Vide = toutes les questions
  ///   appartiennent a la meme matiere.
  ///
  /// [stats] : questionId -> QuestionStats.
  ///   Les questions absentes sont traitees comme "jamais tentees".
  static List<Question> selectionner({
    required List<Question> pool,
    required Map<int, int> chapitreIdVersMatiere,
    required Map<int, QuestionStats> stats,
    required int nbVoulu,
    Random? rng,
  }) {
    final random = rng ?? Random();
    if (pool.isEmpty) return [];
    nbVoulu = nbVoulu.clamp(1, pool.length);

    final toutMatieres = chapitreIdVersMatiere.isNotEmpty;

    // Construire la hierarchie : matiereId -> chapitreId -> difficulte -> questions
    final hier = <int, Map<int, Map<String, List<Question>>>>{};
    for (final q in pool) {
      final mId = toutMatieres ? (chapitreIdVersMatiere[q.chapitreId] ?? -1) : -1;
      final cId = q.chapitreId;
      final diff = q.niveauComplexite;
      (hier[mId] ??= {})[cId] ??= {};
      (hier[mId]![cId]!)[diff] ??= [];
      hier[mId]![cId]![diff]!.add(q);
    }

    final maintenant = DateTime.now();
    final usedIds = <int>{};
    final resultat = <Question>[];

    // Etape 1 : distribution equilibree matiere -> chapitre -> difficulte
    final matiereIds = hier.keys.toList()..shuffle(random);
    final nbParMatiere = _distribuer(nbVoulu, matiereIds.length);

    for (int m = 0; m < matiereIds.length; m++) {
      final mId = matiereIds[m];
      final chapMap = hier[mId]!;
      final nbM = nbParMatiere[m];
      if (nbM == 0) continue;

      final chapIds = chapMap.keys.toList()..shuffle(random);
      final nbParChap = _distribuer(nbM, chapIds.length);

      for (int c = 0; c < chapIds.length; c++) {
        final cId = chapIds[c];
        final diffMap = chapMap[cId]!;
        final nbC = nbParChap[c];
        if (nbC == 0) continue;

        final choisis = _selectionnerSlot(
          diffMap, nbC, usedIds, stats, maintenant, random,
        );
        for (final q in choisis) {
          usedIds.add(q.id);
        }
        resultat.addAll(choisis);
      }
    }

    // Etape 2 : backfill si certains slots n'avaient pas assez de questions
    if (resultat.length < nbVoulu) {
      final restantes = pool.where((q) => !usedIds.contains(q.id)).toList();
      final supplements = _tiragePondere(
        restantes, stats, nbVoulu - resultat.length, maintenant, random,
      );
      resultat.addAll(supplements);
    }

    // Melanger pour que l'ordre ne revele pas la structure hierarchique.
    resultat.shuffle(random);
    return resultat;
  }

  // Selection dans un slot (chapitre x difficulte)

  static List<Question> _selectionnerSlot(
    Map<String, List<Question>> diffMap,
    int nbVoulu,
    Set<int> usedIds,
    Map<int, QuestionStats> stats,
    DateTime maintenant,
    Random random,
  ) {
    final diffs = diffMap.keys.toList()..shuffle(random);
    final diffsDispo = diffs
        .where((d) => diffMap[d]!.any((q) => !usedIds.contains(q.id)))
        .toList();

    if (diffsDispo.isEmpty) return [];

    // Distribution equilibree entre les niveaux de difficulte disponibles.
    final nbParDiff = _distribuer(nbVoulu, diffsDispo.length);
    final slot = <Question>[];

    for (int i = 0; i < diffsDispo.length; i++) {
      final diff = diffsDispo[i];
      final candidats = diffMap[diff]!
          .where((q) => !usedIds.contains(q.id))
          .toList();
      final nb = nbParDiff[i].clamp(0, candidats.length);
      if (nb == 0) continue;
      final choisis = _tiragePondere(candidats, stats, nb, maintenant, random);
      for (final q in choisis) {
        usedIds.add(q.id);
      }
      slot.addAll(choisis);
    }

    // Micro-backfill intra-slot si un niveau de difficulte etait insuffisant.
    if (slot.length < nbVoulu) {
      final encore = diffMap.values
          .expand((qs) => qs)
          .where((q) => !usedIds.contains(q.id))
          .toList();
      final compl = _tiragePondere(
        encore, stats, nbVoulu - slot.length, maintenant, random,
      );
      slot.addAll(compl);
    }

    return slot;
  }

  // Tirage pondere sans remise

  static List<Question> _tiragePondere(
    List<Question> candidats,
    Map<int, QuestionStats> stats,
    int n,
    DateTime maintenant,
    Random random,
  ) {
    if (candidats.isEmpty || n <= 0) return [];
    final pool = List.of(candidats);
    final res = <Question>[];

    for (int i = 0; i < n && pool.isNotEmpty; i++) {
      final scores = pool.map((q) => _score(stats[q.id], maintenant)).toList();
      final total = scores.fold(0.0, (a, b) => a + b);

      double seuil = random.nextDouble() * total;
      int choisi = pool.length - 1;
      for (int j = 0; j < scores.length; j++) {
        seuil -= scores[j];
        if (seuil <= 0) {
          choisi = j;
          break;
        }
      }
      res.add(pool[choisi]);
      pool.removeAt(choisi);
    }
    return res;
  }

  // Score multicritere : plage 10 (maitrisee, recente) -> 100 (nouvelle)

  static double _score(QuestionStats? st, DateTime maintenant) {
    if (st == null || st.jamaisTentee) {
      return _kBase + _kNouveaute; // 50
    }
    double s = _kBase;
    // Maitrise faible -> score eleve
    s += _kMaitrise * (1.0 - st.tauxReussite);
    // Anciennete : longtemps non vue -> score eleve (plafond 30 jours)
    if (st.derniereTentative != null) {
      final jours =
          maintenant.difference(st.derniereTentative!).inDays.clamp(0, 30);
      s += _kAnciennete * (jours / 30.0);
    }
    return s;
  }

  // Distribution equitable de n elements en k seaux

  static List<int> _distribuer(int n, int k) {
    if (k <= 0) return [];
    final base = n ~/ k;
    final reste = n % k;
    return List.generate(k, (i) => i < reste ? base + 1 : base);
  }
}
