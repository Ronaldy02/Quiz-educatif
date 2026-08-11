import 'dart:math';

import '../models/question.dart';

/// Statistiques de maitrise d'une question (fenetre glissante de 10 tentatives).
class QuestionStats {
  final int nbAffichee;
  // Somme ponderee des valeurs de reussite (1.0 / 0.75 / 0.0).
  final double nbCorrecte;
  // Date de la derniere BONNE reponse. NULL = jamais correctement repondue.
  final DateTime? derniereBonneReponse;

  const QuestionStats({
    required this.nbAffichee,
    required this.nbCorrecte,
    this.derniereBonneReponse,
  });

  double get tauxReussite =>
      nbAffichee == 0 ? 0.0 : (nbCorrecte / nbAffichee).clamp(0.0, 1.0);

  /// Vrai si la question n'a jamais ete correctement repondue (tentee ou non).
  /// Spec §14 : inclut « jamais tentee » ET « tentee mais jamais reussie ».
  bool get jamaisReussie => derniereBonneReponse == null;
}

/// Moteur de selection adaptative des questions.
///
/// Architecture a deux niveaux (spec §20-22) :
///
///   1. Equilibrage des categories  [Matiere → Chapitre → Difficulte]
///      Chaque categorie disponible a le meme poids, independamment du
///      nombre de questions qu'elle contient (spec §3-5).
///
///   2. Tirage pondere dans chaque slot  [spec §18-19]
///      Criteres : Maitrise + Nouveaute + Anciennete relative + Historique recent.
class AdaptiveSelector {
  // Coefficients de ponderation (spec §18-19).
  static const double _kBase = 10.0;        // toute question reste eligible
  static const double _kNouveaute = 40.0;   // jamais correctement repondue
  static const double _kMaitrise = 30.0;    // maitrise faible -> priorite haute
  static const double _kAnciennete = 20.0;  // longtemps sans bonne reponse -> priorite haute

  // Facteur applique aux questions deja posees dans la session (spec §17).
  // On ne les exclut pas totalement : si le pool est trop petit elles peuvent reapparaitre.
  static const double _kPenaliteSession = 0.05;

  /// Selectionne au plus [nbVoulu] questions depuis [pool].
  ///
  /// [chapitreIdVersMatiere] chapitreId → matiereId.
  ///   Non-vide uniquement quand plusieurs matieres sont dans le pool.
  ///
  /// [stats] questionId → QuestionStats.
  ///   Les questions absentes sont traitees comme « jamais reussies ».
  ///
  /// [sessionIds] IDs des questions deja posees dans la session courante.
  ///   Recoivent une forte penalite pour eviter les repetitions (spec §17).
  static List<Question> selectionner({
    required List<Question> pool,
    required Map<int, int> chapitreIdVersMatiere,
    required Map<int, QuestionStats> stats,
    required int nbVoulu,
    Set<int>? sessionIds,
    Random? rng,
  }) {
    final random = rng ?? Random();
    if (pool.isEmpty) return [];
    nbVoulu = nbVoulu.clamp(1, pool.length);
    final recent = sessionIds ?? const <int>{};

    final toutMatieres = chapitreIdVersMatiere.isNotEmpty;

    // Construire la hierarchie : matiereId -> chapitreId -> difficulte -> questions
    final hier = <int, Map<int, Map<String, List<Question>>>>{};
    for (final q in pool) {
      final mId = toutMatieres ? (chapitreIdVersMatiere[q.chapitreId] ?? -1) : -1;
      (hier[mId] ??= {})[q.chapitreId] ??= {};
      (hier[mId]![q.chapitreId]!)[q.niveauComplexite] ??= [];
      hier[mId]![q.chapitreId]![q.niveauComplexite]!.add(q);
    }

    final maintenant = DateTime.now();
    final usedIds = <int>{};
    final resultat = <Question>[];

    // ── Etape 1 : distribution equilibree Matiere → Chapitre → Difficulte ──
    final matiereIds = hier.keys.toList()..shuffle(random);
    final nbParMatiere = _distribuer(nbVoulu, matiereIds.length);

    for (int m = 0; m < matiereIds.length; m++) {
      final chapMap = hier[matiereIds[m]]!;
      final nbM = nbParMatiere[m];
      if (nbM == 0) continue;

      final chapIds = chapMap.keys.toList()..shuffle(random);
      final nbParChap = _distribuer(nbM, chapIds.length);

      for (int c = 0; c < chapIds.length; c++) {
        final nbC = nbParChap[c];
        if (nbC == 0) continue;

        final choisis = _selectionnerSlot(
          chapMap[chapIds[c]]!, nbC, usedIds, stats, maintenant, recent, random,
        );
        for (final q in choisis) { usedIds.add(q.id); }
        resultat.addAll(choisis);
      }
    }

    // ── Etape 2 : backfill si certains slots manquaient de questions ──
    if (resultat.length < nbVoulu) {
      final restantes = pool.where((q) => !usedIds.contains(q.id)).toList();
      resultat.addAll(_tiragePondere(
        restantes, stats, nbVoulu - resultat.length, maintenant, recent, random,
      ));
    }

    resultat.shuffle(random);
    return resultat;
  }

  // ── Selection dans un slot (chapitre x difficulte) ────────────────────────

  static List<Question> _selectionnerSlot(
    Map<String, List<Question>> diffMap,
    int nbVoulu,
    Set<int> usedIds,
    Map<int, QuestionStats> stats,
    DateTime maintenant,
    Set<int> recent,
    Random random,
  ) {
    // Ne considerer que les niveaux qui ont au moins une question disponible.
    final diffsDispo = diffMap.keys
        .where((d) => diffMap[d]!.any((q) => !usedIds.contains(q.id)))
        .toList()
      ..shuffle(random);

    if (diffsDispo.isEmpty) return [];

    final nbParDiff = _distribuer(nbVoulu, diffsDispo.length);
    final slot = <Question>[];

    for (int i = 0; i < diffsDispo.length; i++) {
      final candidats = diffMap[diffsDispo[i]]!
          .where((q) => !usedIds.contains(q.id))
          .toList();
      final nb = nbParDiff[i].clamp(0, candidats.length);
      if (nb == 0) continue;
      final choisis = _tiragePondere(candidats, stats, nb, maintenant, recent, random);
      for (final q in choisis) { usedIds.add(q.id); }
      slot.addAll(choisis);
    }

    // Micro-backfill intra-slot si un niveau n'avait pas assez de questions.
    if (slot.length < nbVoulu) {
      final encore = diffMap.values
          .expand((qs) => qs)
          .where((q) => !usedIds.contains(q.id))
          .toList();
      slot.addAll(_tiragePondere(
        encore, stats, nbVoulu - slot.length, maintenant, recent, random,
      ));
    }

    return slot;
  }

  // ── Tirage pondere sans remise ─────────────────────────────────────────────

  static List<Question> _tiragePondere(
    List<Question> candidats,
    Map<int, QuestionStats> stats,
    int n,
    DateTime maintenant,
    Set<int> recent,
    Random random,
  ) {
    if (candidats.isEmpty || n <= 0) return [];
    final pool = List.of(candidats);
    final res = <Question>[];

    // Calcul des bornes d'anciennete relative sur l'ensemble des candidats (spec §16).
    // anciennetePlus  = derniereBonneReponse la plus ancienne (priorite max)
    // ancienneteMoins = derniereBonneReponse la plus recente  (priorite min)
    DateTime? anciennetePlus;
    DateTime? ancienneteMoins;
    for (final q in pool) {
      final d = stats[q.id]?.derniereBonneReponse;
      if (d == null) continue;
      if (anciennetePlus == null || d.isBefore(anciennetePlus)) anciennetePlus = d;
      if (ancienneteMoins == null || d.isAfter(ancienneteMoins)) ancienneteMoins = d;
    }

    for (int i = 0; i < n && pool.isNotEmpty; i++) {
      final scores = pool
          .map((q) => _score(
                stats[q.id],
                maintenant,
                anciennetePlus,
                ancienneteMoins,
                recent.contains(q.id),
              ))
          .toList();
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

  // ── Score multicritere (spec §18-19) ──────────────────────────────────────
  //
  //   jamais reussie → 100  (kBase + kNouveaute + kMaitrise + kAnciennete)
  //   reussie, maitrise faible, ancienne → jusqu'a 60
  //   reussie, maitrise forte, recente   → 10  (kBase seul)
  //
  // La separation « equilibrage/adaptation » (spec §20) est garantie par le
  // fait que _score n'intervient qu'apres la distribution des slots.

  static double _score(
    QuestionStats? st,
    DateTime maintenant,
    DateTime? anciennetePlus,
    DateTime? ancienneteMoins,
    bool estRecente,
  ) {
    // Jamais reussie (tentee ou non) → priorite maximale (spec §14).
    if (st == null || st.jamaisReussie) {
      final raw = _kBase + _kNouveaute + _kMaitrise + _kAnciennete;
      return estRecente ? raw * _kPenaliteSession : raw;
    }

    double s = _kBase;

    // Maitrise faible → score eleve (spec §13.1).
    s += _kMaitrise * (1.0 - st.tauxReussite);

    // Anciennete relative (spec §16) :
    //   la question avec la derniereBonneReponse la plus ancienne recoit _kAnciennete,
    //   la plus recente recoit 0.  Pas de seuil fixe.
    if (anciennetePlus != null && ancienneteMoins != null) {
      final rangeMs =
          ancienneteMoins.difference(anciennetePlus).inMilliseconds.abs();
      if (rangeMs > 0) {
        final ageMs =
            maintenant.difference(st.derniereBonneReponse!).inMilliseconds;
        final ageMoinsMs =
            maintenant.difference(ancienneteMoins).inMilliseconds;
        final anciennete = ((ageMs - ageMoinsMs) / rangeMs).clamp(0.0, 1.0);
        s += _kAnciennete * anciennete;
      }
    }

    return estRecente ? s * _kPenaliteSession : s;
  }

  // ── Distribution equitable de n elements en k seaux ───────────────────────
  //
  // base = n ~/ k ; les (n % k) premiers seaux recoivent base+1.
  // Le shuffle de l'appelant garantit que le « seau superieur » n'avantage
  // pas toujours la meme categorie (spec §5).

  static List<int> _distribuer(int n, int k) {
    if (k <= 0) return [];
    final base = n ~/ k;
    final reste = n % k;
    return List.generate(k, (i) => i < reste ? base + 1 : base);
  }
}
