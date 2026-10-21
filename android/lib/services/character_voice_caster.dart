
import '../models/dub_project.dart';
import 'voice_catalog.dart';

class CharacterVoiceCaster {
  const CharacterVoiceCaster();

  void assign(
    DubProject project, {
    Map<String, VoiceRole> preferredRoles = const {},
    Set<String>? installedModelIds,
  }) {
    final available = VoiceCatalog.forLanguage(
      project.targetLanguage,
    ).where((profile) {
      final modelId = profile.modelId;

      return modelId != null &&
          (installedModelIds == null ||
              installedModelIds.contains(modelId));
    }).toList();

    if (available.isEmpty) {
      throw StateError(
        'No installed character voices are available for '
        '${project.targetLanguage}.',
      );
    }

    final speakers = <String>[];

    for (final segment in project.segments) {
      final speaker = segment.speakerId.trim();

      if (speaker.isEmpty || speaker == 'unknown') {
        continue;
      }

      if (!speakers.contains(speaker)) {
        speakers.add(speaker);
      }
    }

    final validIds = available.map((voice) => voice.id).toSet();

    project.characterVoices.removeWhere(
      (speaker, voice) =>
          !speakers.contains(speaker) ||
          !validIds.contains(voice),
    );

    final used = project.characterVoices.values.toSet();

    for (final speaker in speakers) {
      if (project.characterVoices.containsKey(speaker)) {
        continue;
      }

      final preferredRole = preferredRoles[speaker];

      final candidates = available.where((voice) {
        return preferredRole == null ||
            voice.role == preferredRole;
      }).toList();

      if (candidates.isEmpty) {
        throw StateError(
          'No compatible voice for speaker $speaker.',
        );
      }

      final unused = candidates.where(
        (voice) => !used.contains(voice.id),
      );

      final selected = unused.isNotEmpty
          ? unused.first
          : candidates.first;

      project.characterVoices[speaker] = selected.id;
      used.add(selected.id);
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
