
enum VoiceRole {
  male,
  female,
  youthful,
}

class VoiceProfile {
  final String id;
  final String language;
  final VoiceRole role;
  final String description;
  final String? modelId;

  const VoiceProfile({
    required this.id,
    required this.language,
    required this.role,
    required this.description,
    this.modelId,
  });

  bool get hasAssignedModel => modelId != null;
}

class VoiceCatalog {
  static final List<VoiceProfile> profiles = [
    for (final language in ['hi', 'en']) ...[
      for (final name in [
        'hero',
        'young_male',
        'deep_male',
        'mature_male',
        'villain',
        'rough_male',
      ])
        VoiceProfile(
          id: '${language}_$name',
          language: language,
          role: VoiceRole.male,
          description: name.replaceAll('_', ' '),
        ),
      for (final name in [
        'heroine',
        'young_female',
        'mature_female',
        'strong_female',
      ])
        VoiceProfile(
          id: '${language}_$name',
          language: language,
          role: VoiceRole.female,
          description: name.replaceAll('_', ' '),
        ),
      for (final name in [
        'youthful_soft',
        'youthful_bright',
      ])
        VoiceProfile(
          id: '${language}_$name',
          language: language,
          role: VoiceRole.youthful,
          description: name.replaceAll('_', ' '),
        ),
    ],
  ];

  static List<VoiceProfile> forLanguage(String language) =>
      profiles
          .where((profile) => profile.language == language)
          .toList(growable: false);

  static VoiceProfile byId(String id) =>
      profiles.firstWhere(
        (profile) => profile.id == id,
        orElse: () => throw ArgumentError('Unknown voice: $id'),
      );

  static List<VoiceProfile> available(String language) =>
      profiles
          .where(
            (profile) =>
                profile.language == language &&
                profile.hasAssignedModel,
          )
          .toList(growable: false);
}
