
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

    // Different catalog profiles backed by the same ONNX model are not
    // independent character voices. Collapse duplicates before casting.
    final uniqueModels = <String>{};
    final distinct = available.where((profile) =>
        uniqueModels.add(profile.modelId!)).toList();

    if (distinct.isEmpty) {
      throw StateError(
        'No installed character voices are available for '
        '${project.targetLanguage}.',
      );
    }

    final speakers = <String>[];
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

      if (!speakers.contains(speaker)) {
        speakers.add(speaker);
      }
    }

    final validIds = distinct.map((voice) => voice.id).toSet();

    project.characterVoices.removeWhere(
      (speaker, voice) =>
          !speakers.contains(speaker) ||
          !validIds.contains(voice) ||
          (preferredRoles.containsKey(speaker) &&
              VoiceCatalog.byId(voice).role != preferredRoles[speaker]),
    );

    final used = project.characterVoices.values.toSet();

    for (final speaker in speakers) {
      if (project.characterVoices.containsKey(speaker)) {
        continue;
      }

      final preferredRole = preferredRoles[speaker] ?? existingRoles[speaker];

      // Acoustic speaker clustering identifies identities, not gender or age.
      // Never silently infer a role from catalog ordering when different
      // voice roles are installed. An explicit role or saved casting is needed.
      if (preferredRole == null &&
          distinct.map((voice) => voice.role).toSet().length > 1) {
        throw StateError(
          'Speaker $speaker has no verified voice role. '
          'Select a character voice before dubbing; automatic speaker '
          'clustering cannot determine gender or age reliably.',
        );
      }

      final candidates = distinct.where((voice) {
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
