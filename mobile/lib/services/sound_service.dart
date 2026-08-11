// Stub — remplacer par audioplayers + assets quand les fichiers audio seront disponibles.
// Les identifiants correspondent aux noms de la spec §15.

/// Identifiants des effets sonores.
enum SoundId {
  answerCorrect,  // SFX_ANSWER_CORRECT
  answerWrong,    // SFX_ANSWER_WRONG
  streak5,        // SFX_STREAK_5
  streak10,       // SFX_STREAK_10
  streak15,       // SFX_STREAK_15
  streak20,       // SFX_STREAK_20
  perfect,        // SFX_PERFECT
  bombard6,       // SFX_BOMBARD_6
  bombard10,      // SFX_BOMBARD_10
  bombard15,      // SFX_BOMBARD_15
  bombard20,      // SFX_BOMBARD_20
  levelUp,        // SFX_LEVEL_UP
  badgeUnlock,    // SFX_BADGE_UNLOCK
  newRecord,      // SFX_NEW_RECORD
}

/// Identifiants des voix préenregistrées (spec §15 — ne pas utiliser de TTS).
enum VoiceId {
  amazing,     // VOICE_AMAZING
  excellent,   // VOICE_EXCELLENT
  perfect,     // VOICE_PERFECT
  incredible,  // VOICE_INCREDIBLE
}

class SoundService {
  SoundService._();

  static Future<void> _sfx(SoundId _) async {
    // TODO : audioplayers — await _player.play(AssetSource('sfx/<id>.mp3'));
  }

  static Future<void> _voix(VoiceId _) async {
    // TODO : audioplayers — await _voicePlayer.play(AssetSource('voices/<id>.mp3'));
  }

  static Future<void> reponseCorrecte() => _sfx(SoundId.answerCorrect);
  static Future<void> reponseIncorrecte() => _sfx(SoundId.answerWrong);

  /// Joue le SFX et la voix associés au palier de série (spec §4-6).
  static Future<void> serie(int palier) {
    switch (palier) {
      case 5:
        return _sfx(SoundId.streak5);
      case 10:
        return Future.wait([_sfx(SoundId.streak10), _voix(VoiceId.amazing)]);
      case 15:
        return _sfx(SoundId.streak15);
      case 20:
        return Future.wait([_sfx(SoundId.streak20), _voix(VoiceId.incredible)]);
      default:
        return Future.value();
    }
  }

  /// Son + voix pour le Quiz parfait (spec §7).
  static Future<void> perfect() =>
      Future.wait([_sfx(SoundId.perfect), _voix(VoiceId.perfect)]);

  /// Son + voix pour les paliers Bombardement (spec §9-12).
  static Future<void> bombardement(int palier) {
    switch (palier) {
      case 6:
        return _sfx(SoundId.bombard6);
      case 10:
        return Future.wait([_sfx(SoundId.bombard10), _voix(VoiceId.excellent)]);
      case 15:
        return Future.wait([_sfx(SoundId.bombard15), _voix(VoiceId.amazing)]);
      case 20:
        return Future.wait([_sfx(SoundId.bombard20), _voix(VoiceId.amazing)]);
      default:
        return Future.value();
    }
  }
}
