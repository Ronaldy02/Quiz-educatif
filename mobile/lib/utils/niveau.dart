import 'dart:math';
import 'package:flutter/material.dart';

/// Huit rangs débloqués aux niveaux 1 / 5 / 10 / 20 / 30 / 50 / 75 / 100.
enum Rang {
  debutant,    // niveau  1
  apprenti,    // niveau  5
  explorateur, // niveau 10
  confirme,    // niveau 20
  avance,      // niveau 30
  expert,      // niveau 50
  maitre,      // niveau 75
  grandMaitre, // niveau 100
}

/// Utilitaires pour le systeme de niveaux du joueur.
///
/// Formule officielle :
///   XP cumule pour le niveau N = 100 * N * (N-1) / 2
///   XP necessaire pour passer N -> N+1  = N * 100
class NiveauHelper {
  NiveauHelper._();

  /// Niveau actuel du joueur en fonction de son XP total.
  ///
  /// Resout 100*N*(N-1)/2 <= xpTotal < 100*N*(N+1)/2.
  /// Equivalent a : N = floor((1 + sqrt(1 + 8*xpTotal/100)) / 2).
  static int niveauDepuisXp(int xpTotal) {
    if (xpTotal <= 0) return 1;
    return ((1.0 + sqrt(1.0 + 8.0 * xpTotal / 100.0)) / 2.0).floor();
  }

  /// XP cumule minimum pour atteindre [niveau].
  static int xpCumulePourNiveau(int niveau) {
    if (niveau <= 1) return 0;
    return 100 * niveau * (niveau - 1) ~/ 2;
  }

  /// XP necessaire pour passer de [niveau] a [niveau]+1.
  static int xpPourNiveauSuivant(int niveau) => niveau * 100;

  /// XP deja acquis dans le niveau actuel.
  static int xpDansNiveauActuel(int xpTotal) {
    final n = niveauDepuisXp(xpTotal);
    return xpTotal - xpCumulePourNiveau(n);
  }

  /// Progression (0.0 a 1.0) dans le niveau actuel.
  static double progressionNiveau(int xpTotal) {
    final n = niveauDepuisXp(xpTotal);
    final xpDans = xpDansNiveauActuel(xpTotal);
    final xpNecessaire = xpPourNiveauSuivant(n);
    if (xpNecessaire == 0) return 1.0;
    return (xpDans / xpNecessaire).clamp(0.0, 1.0);
  }

  /// Rang correspondant au [niveau] donné.
  static Rang rangDepuisNiveau(int niveau) {
    if (niveau >= 100) return Rang.grandMaitre;
    if (niveau >= 75)  return Rang.maitre;
    if (niveau >= 50)  return Rang.expert;
    if (niveau >= 30)  return Rang.avance;
    if (niveau >= 20)  return Rang.confirme;
    if (niveau >= 10)  return Rang.explorateur;
    if (niveau >= 5)   return Rang.apprenti;
    return Rang.debutant;
  }

  /// Emoji associé au rang.
  static String rangEmoji(Rang r) {
    const emojis = ['🌱', '📘', '🔎', '🧠', '🎓', '🏆', '💎', '👑'];
    return emojis[r.index];
  }

  /// Libellé français du rang.
  static String rangNom(Rang r) {
    const noms = [
      'Débutant', 'Apprenti', 'Explorateur', 'Confirmé',
      'Avancé', 'Expert', 'Maître', 'Grand Maître',
    ];
    return noms[r.index];
  }

  /// Couleur associée au rang.
  static Color rangCouleur(Rang r) {
    switch (r) {
      case Rang.debutant:    return const Color(0xFF6B7280);
      case Rang.apprenti:    return const Color(0xFF2563EB);
      case Rang.explorateur: return const Color(0xFF0891B2);
      case Rang.confirme:    return const Color(0xFF059669);
      case Rang.avance:      return const Color(0xFF7C3AED);
      case Rang.expert:      return const Color(0xFFB45309);
      case Rang.maitre:      return const Color(0xFF0284C7);
      case Rang.grandMaitre: return const Color(0xFFDC2626);
    }
  }
}
