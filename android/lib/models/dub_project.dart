import 'dart:convert';

enum ProjectStage {
  imported,
  transcribing,
  casting,
  translating,
  refining,
  synthesizing,
  exporting,
  completed,
  failed,
}

class DubSegment {
  final int id;
  final double start;
  final double end;

  String original;
  String translation;
  String speakerId;
  String voiceId;
  double speakerConfidence;

  DubSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.original,
    this.translation = '',
    this.speakerId = 'unknown',
    this.voiceId = '',
    this.speakerConfidence = 0,
  });

  factory DubSegment.fromJson(Map<String, dynamic> json) {
    return DubSegment(
      id: (json['id'] as num).toInt(),
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      original: json['original'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      speakerId: json['speaker_id'] as String? ?? 'unknown',
      voiceId: json['voice_id'] as String? ?? '',
      speakerConfidence:
          (json['speaker_confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        'original': original,
        'translation': translation,
        'speaker_id': speakerId,
        'voice_id': voiceId,
        'speaker_confidence': speakerConfidence,
      };
}

class DubProject {
  final String id;
  final String title;
  final String sourcePath;
  final String targetLanguage;

  String sourceLanguage;
  String? outputPath;
  String? error;
  ProjectStage stage;

  final List<DubSegment> segments;
  final Map<String, String> characterVoices;

  DubProject({
    required this.id,
    required this.title,
    required this.sourcePath,
    required this.targetLanguage,
    this.sourceLanguage = 'auto',
    this.outputPath,
    this.error,
    this.stage = ProjectStage.imported,
    List<DubSegment>? segments,
    Map<String, String>? characterVoices,
  })  : segments = segments ?? [],
        characterVoices = characterVoices ?? {};

  Map<String, dynamic> toJson() => {
        'schema': 'otakudub.offline.v5',
        'id': id,
        'title': title,
        'source_path': sourcePath,
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
        'output_path': outputPath,
        'error': error,
        'stage': stage.name,
        'segments': segments.map((s) => s.toJson()).toList(),
        'character_voices': characterVoices,
      };

  factory DubProject.fromJson(Map<String, dynamic> json) {
    return DubProject(
      id: json['id'] as String,
      title: json['title'] as String,
      sourcePath: json['source_path'] as String,
      targetLanguage: json['target_language'] as String,
      sourceLanguage: json['source_language'] as String? ?? 'auto',
      outputPath: json['output_path'] as String?,
      error: json['error'] as String?,
      stage: ProjectStage.values.firstWhere(
        (s) => s.name == json['stage'],
        orElse: () => ProjectStage.imported,
      ),
      segments: [
        for (final item in json['segments'] as List? ?? [])
          DubSegment.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      characterVoices: Map<String, String>.from(
        json['character_voices'] as Map? ?? {},
      ),
    );
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static DubProject decode(String text) =>
      DubProject.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
