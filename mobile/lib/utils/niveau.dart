import 'dart:math';

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
}
