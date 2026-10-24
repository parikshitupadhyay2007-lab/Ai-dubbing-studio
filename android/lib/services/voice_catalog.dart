import 'voice_model_config.dart';

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

  final String? _defaultModelId;

  const VoiceProfile({
    required this.id,
    required this.language,
    required this.role,
    required this.description,
    String? modelId,
  }) : _defaultModelId = modelId;

  String? get modelId =>
      VoiceCatalog._installedModels[id]?.modelId ?? _defaultModelId;

  bool get hasAssignedModel => modelId != null || VoiceCatalog.supertonicStyle(id) != null;
}

class InstalledVoiceModel {
  final String modelId;
  final String profileId;
  final VoiceModelConfig config;

  const InstalledVoiceModel({
    required this.modelId,
    required this.profileId,
    required this.config,
  });

  String get modelPath => config.modelPath;
  String get configPath => config.configPath;
}

class VoiceCatalog {
  VoiceCatalog._();

  static final Map<String, InstalledVoiceModel> _installedModels = {};

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
          role: language == 'en' && name == 'hero'
              ? VoiceRole.female
              : VoiceRole.male,
          description: language == 'en' && name == 'hero'
              ? 'Lessac female voice (legacy en_hero model ID)'
              : name.replaceAll('_', ' '),
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

  static VoiceProfile byId(String id) => profiles.firstWhere(
        (profile) => profile.id == id,
        orElse: () => throw ArgumentError('Unknown voice: $id'),
      );

  /// Supertonic voice styles are bundled with the application, not individually
  /// installed Piper checkpoints. Keep role-consistent choices available.
  static String? supertonicStyle(String id) {
    final profile = profiles.where((p) => p.id == id);
    if (profile.isEmpty) return null;
    const styles = <String, String>{
      'hero': 'M1', 'young_male': 'M2', 'deep_male': 'M3',
      'mature_male': 'M4', 'villain': 'M5', 'rough_male': 'M5',
      'heroine': 'F1', 'young_female': 'F2', 'mature_female': 'F3',
      'strong_female': 'F4', 'youthful_soft': 'F5',
      'youthful_bright': 'F5',
    };
    if (id == 'en_hero') return 'F1'; // Legacy Lessac profile is female.
    if (id.endsWith('_youthful_soft') || id.endsWith('_youthful_bright')) return 'F5';
    final suffix = id.substring(3);
    return styles[suffix];
  }

  static List<VoiceProfile> available(String language) =>
      profiles.where((p) => p.language == language &&
          supertonicStyle(p.id) != null).toList(growable: false);

  static InstalledVoiceModel? installedModel(String profileId) =>
      _installedModels[profileId];

  static List<InstalledVoiceModel> get installedModels =>
      List.unmodifiable(_installedModels.values);

  /// Register a voice only after its model/configuration pair is installed.
  ///
  /// This checks file presence and Piper metadata. Actual ONNX inference
  /// must still be tested separately by the native speech engine.
  static Future<InstalledVoiceModel> registerInstalled({
    required String profileId,
    required String modelId,
    required String modelPath,
    required String configPath,
  }) async {
    if (modelId.trim().isEmpty) {
      throw ArgumentError('Model ID cannot be empty.');
    }

    final profile = byId(profileId);

    final config = await VoiceModelConfig.load(
      modelPath: modelPath,
      configPath: configPath,
      expectedLanguage: profile.language,
    );

    final installed = InstalledVoiceModel(
      modelId: modelId,
      profileId: profileId,
      config: config,
    );

    _installedModels[profileId] = installed;

    return installed;
  }

  static void unregister(String profileId) {
    _installedModels.remove(profileId);
  }

  static void clearInstalled() {
    _installedModels.clear();
  }
}
