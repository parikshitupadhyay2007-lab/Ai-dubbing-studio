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
  // Optional safe synthesis extension; original Whisper boundaries stay immutable.
  double? synthesisEnd;

  String original;
  String translation;
  String speakerId;
  String voiceId;
  double speakerConfidence;
  bool speakerManuallyVerified;
  String delivery;

  DubSegment({
    required this.id,
    required this.start,
    required this.end,
    this.synthesisEnd,
    required this.original,
    this.translation = '',
    this.speakerId = 'unknown',
    this.voiceId = '',
    this.speakerConfidence = 0,
    this.speakerManuallyVerified = false,
    this.delivery = 'natural',
  });

  factory DubSegment.fromJson(Map<String, dynamic> json) {
    return DubSegment(
      id: (json['id'] as num).toInt(),
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      synthesisEnd: (json['synthesis_end'] as num?)?.toDouble(),
      original: json['original'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      speakerId: json['speaker_id'] as String? ?? 'unknown',
      voiceId: json['voice_id'] as String? ?? '',
      speakerConfidence:
          (json['speaker_confidence'] as num?)?.toDouble() ?? 0,
      speakerManuallyVerified: json['speaker_manually_verified'] == true,
      delivery: json['delivery'] as String? ?? 'natural',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        if (synthesisEnd != null) 'synthesis_end': synthesisEnd,
        'original': original,
        'translation': translation,
        'speaker_id': speakerId,
        'voice_id': voiceId,
        'speaker_confidence': speakerConfidence,
        'speaker_manually_verified': speakerManuallyVerified,
        'delivery': delivery,
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
  final Set<int> refinedSegmentIds;
  Map<String, dynamic>? animeSceneContext;
  Map<String, dynamic> speakerIdentityEvidence;

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
    Set<int>? refinedSegmentIds,
    this.animeSceneContext,
    Map<String, dynamic>? speakerIdentityEvidence,
  })  : segments = segments ?? [],
        characterVoices = characterVoices ?? {},
        refinedSegmentIds = refinedSegmentIds ?? <int>{},
        speakerIdentityEvidence = speakerIdentityEvidence ?? <String, dynamic>{};

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
        'refined_segment_ids': refinedSegmentIds.toList()..sort(),
        'anime_scene_context': animeSceneContext,
        'speaker_identity_evidence': speakerIdentityEvidence,
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
      animeSceneContext: json['anime_scene_context'] is Map
          ? Map<String, dynamic>.from(json['anime_scene_context'] as Map) : null,
      speakerIdentityEvidence: json['speaker_identity_evidence'] is Map
          ? Map<String, dynamic>.from(json['speaker_identity_evidence'] as Map)
          : <String, dynamic>{},
      refinedSegmentIds: (json['refined_segment_ids'] as List? ?? [])
          .map((value) => (value as num).toInt()).toSet(),
    );
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static DubProject decode(String text) =>
      DubProject.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
