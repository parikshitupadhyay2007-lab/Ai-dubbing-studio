
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
          (preferredRoles.containsKey(speaker) &&
              VoiceCatalog.byId(voice).role != preferredRoles[speaker]),
    );

    final usedStyles = project.characterVoices.values
        .map(VoiceCatalog.supertonicStyle).whereType<String>().toSet();

    for (final speaker in speakers) {
      if (project.characterVoices.containsKey(speaker)) {
        continue;
      }

      final preferredRole = preferredRoles[speaker] ?? existingRoles[speaker];

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
