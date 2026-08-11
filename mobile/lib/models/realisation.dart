import 'package:flutter/material.dart';

enum RealisationCategorie {
  apprentissage,
  series,
  performance,
  bombardement,
  maitrise,
  regularite,
  progression,
  defis,
  collection,
  exploration,
  secrets,
}

enum RealisationRarete {
  commune,
  peuCommune,
  rare,
  epique,
  legendaire,
}

class Realisation {
  final String id;
  final String nom;
  final String description;
  final RealisationCategorie categorie;
  final RealisationRarete rarete;
  final int recompensePieces;
  final bool secret;
  // objectif == 0 => binaire (pas de barre de progression)
  final int objectif;

  int progres;
  bool debloquee;
  DateTime? debloqueeAt;

  Realisation({
    required this.id,
    required this.nom,
    required this.description,
    required this.categorie,
    required this.rarete,
    required this.objectif,
    required this.recompensePieces,
    this.progres = 0,
    this.debloquee = false,
    this.debloqueeAt,
    this.secret = false,
  });

  factory Realisation.fromMap(Map<String, dynamic> map) => Realisation(
    id: map['id'] as String,
    nom: map['nom'] as String,
    description: map['description'] as String,
    categorie: RealisationCategorie.values[map['categorie'] as int],
    rarete: RealisationRarete.values[map['rarete'] as int],
    objectif: map['objectif'] as int,
    recompensePieces: map['recompense_pieces'] as int? ?? 0,
    secret: (map['secret'] as int? ?? 0) == 1,
    progres: map['progres'] as int? ?? 0,
    debloquee: (map['debloquee'] as int? ?? 0) == 1,
    debloqueeAt: map['debloquee_at'] != null
        ? DateTime.tryParse(map['debloquee_at'] as String)
        : null,
  );

  Map<String, dynamic> toInsertMap() => {
    'id': id,
    'nom': nom,
    'description': description,
    'categorie': categorie.index,
    'rarete': rarete.index,
    'objectif': objectif,
    'recompense_pieces': recompensePieces,
    'secret': secret ? 1 : 0,
    'progres': progres,
    'debloquee': debloquee ? 1 : 0,
    'debloquee_at': debloqueeAt?.toIso8601String(),
  };

  static String rareteEmoji(RealisationRarete r) {
    const e = ['⚪', '🟢', '🔵', '🟣', '🟡'];
    return e[r.index];
  }

  static String rareteLibelle(RealisationRarete r) {
    const l = ['Commune', 'Peu commune', 'Rare', 'Épique', 'Légendaire'];
    return l[r.index];
  }

  static Color rareteColor(RealisationRarete r) {
    const colors = [
      Color(0xFF9CA3AF),
      Color(0xFF22C55E),
      Color(0xFF3B82F6),
      Color(0xFFA855F7),
      Color(0xFFEAB308),
    ];
    return colors[r.index];
  }

  static String categorieLibelle(RealisationCategorie c) {
    const labels = [
      'Apprentissage', 'Séries', 'Performance', 'Bombardement',
      'Maîtrise', 'Régularité', 'Progression', 'Défis',
      'Collection', 'Exploration', 'Secrets',
    ];
    return labels[c.index];
  }

  static String categorieEmoji(RealisationCategorie c) {
    const emojis = [
      '📚', '🔥', '💯', '💥', '🧠', '📅', '📈', '🎯', '🪙', '🧭', '❓',
    ];
    return emojis[c.index];
  }
}
