
import '../models/dub_project.dart';
import 'voice_catalog.dart';

class CharacterVoiceCaster {
  const CharacterVoiceCaster();

  void assign(
    DubProject project, {
    Map<String, VoiceRole> preferredRoles = const {},
  }) {
    // One style represents one independent voice. Piper installation state
    // must never decide whether a bundled Supertonic preset can be cast.
    final uniqueStyles = <String>{};
    final distinct = VoiceCatalog.available(project.targetLanguage)
        .where((profile) {
          final style = VoiceCatalog.supertonicStyle(profile.id);
          return style != null && uniqueStyles.add(style);
        }).toList();

    if (distinct.isEmpty) {
      throw StateError(
        'No bundled Supertonic styles are available for '
        '${project.targetLanguage}.',
      );
    }

    // Evidence-derived preferences are usable only after independent visual
    // and reference speaker links have been verified by their producers.
    // An OtakuMind suggestion or scene match alone must not force a role.
    final verifiedPreferences = <String, VoiceRole>{};
    for (final entry in project.speakerIdentityEvidence.entries) {
      final evidence = entry.value;
      if (evidence is! Map ||
          evidence['visual_speaker_link_verified'] != true ||
          evidence['reference_speaker_link_verified'] != true ||
          evidence['identity_status'] != 'verified_character') continue;
      final role = evidence['verified_voice_role'];
      if (role == 'male') verifiedPreferences[entry.key] = VoiceRole.male;
      if (role == 'female') verifiedPreferences[entry.key] = VoiceRole.female;
      if (role == 'youthful') verifiedPreferences[entry.key] = VoiceRole.youthful;
    }
    final roles = <String, VoiceRole>{...verifiedPreferences, ...preferredRoles};

    final speakers = <String>{};
    final existingRoles = <String, VoiceRole>{};
    for (final entry in project.characterVoices.entries) {
      final profile = VoiceCatalog.profiles.where((p) => p.id == entry.value);
      if (profile.isNotEmpty) existingRoles[entry.key] = profile.first.role;
    }

    for (final segment in project.segments) {
      final speaker = segment.speakerId.trim();

      if (speaker.isEmpty || speaker == 'unknown') {
        continue;
      }

      speakers.add(speaker);
    }

    final validIds = distinct.map((voice) => voice.id).toSet();

    project.characterVoices.removeWhere(
      (speaker, voice) =>
          !speakers.contains(speaker) ||
          !validIds.contains(voice) ||
          (roles.containsKey(speaker) &&
              VoiceCatalog.byId(voice).role != roles[speaker]),
    );

    final usedStyles = project.characterVoices.values
        .map(VoiceCatalog.supertonicStyle).whereType<String>().toSet();

    for (final speaker in speakers) {
      if (project.characterVoices.containsKey(speaker)) {
        continue;
      }

      final preferredRole = roles[speaker] ?? existingRoles[speaker];

      // Acoustic clustering does not establish gender, age, or character role.
      // Unclassified voices are provisional style choices, not predictions.
      final candidates = distinct.where((voice) {
        return preferredRole == null || voice.role == preferredRole;
      }).toList();

      if (candidates.isEmpty) {
        throw StateError(
          'No compatible voice for speaker $speaker.',
        );
      }

      final unused = candidates.where(
        (voice) => !usedStyles.contains(VoiceCatalog.supertonicStyle(voice.id)),
      );

      final selected = unused.isNotEmpty
          ? unused.first
          : candidates.first;

      project.characterVoices[speaker] = selected.id;
      usedStyles.add(VoiceCatalog.supertonicStyle(selected.id)!);
    }

    for (final segment in project.segments) {
      final assigned = project.characterVoices[
        segment.speakerId
      ];

      if (assigned != null) {
        segment.voiceId = assigned;
      } else {
        segment.voiceId = '';
      }
    }
  }
}
