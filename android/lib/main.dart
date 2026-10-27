import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import 'models/dub_project.dart';
import 'services/dubbing_pipeline.dart';
import 'services/dialogue_quality_gate.dart';
import 'services/character_identity_fusion.dart';
import 'services/identity_confidence_gate.dart';
import 'services/model_manager.dart';
import 'services/offline_engine.dart';
import 'services/project_repository.dart';
import 'services/voice_installation_registry.dart';
import 'services/voice_catalog.dart';

// Blackheart visual system: warm paper, ink, lavender and sakura.
const bg = Color(0xFFFFFAF5);
const panel = Color(0xFFFFFFFF);
const ink = Color(0xFF202432);
const mutedInk = Color(0xFF687080);
const violet = Color(0xFF9A83D9);
const cyan = Color(0xFF78A9E7);
const pink = Color(0xFFE9A4C2);
const blush = Color(0xFFFFE8E6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await const VoiceInstallationRegistry().restore();
  } catch (error) {
    debugPrint('Voice restoration failed: $error');
  }

  runApp(const OtakuDubApp());
}

class OtakuDubApp extends StatelessWidget {
  const OtakuDubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Otaku Dub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: bg,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: ink, elevation: 0, centerTitle: false),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: ink), bodyLarge: TextStyle(color: ink)),
        colorScheme: ColorScheme.fromSeed(
          seedColor: violet,
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          color: panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: violet.withValues(alpha: 0.15),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: violet,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const OtakuDubLaunch(),
    );
  }
}

// FIVE-SECOND ANIMATED INTRODUCTION

class OtakuDubLaunch extends StatefulWidget {
  const OtakuDubLaunch({super.key});

  @override
  State<OtakuDubLaunch> createState() => _OtakuDubLaunchState();
}

class _OtakuDubLaunchState extends State<OtakuDubLaunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();

    animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    animation.forward().whenComplete(() {
      if (!mounted) return;

      unawaited(Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 650),
          pageBuilder: (_, __, ___) => const OtakuDubHome(),
          transitionsBuilder: (_, transition, __, child) {
            return FadeTransition(
              opacity: transition,
              child: child,
            );
          },
        ),
      ));
    });
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  double progress(double start, double end) {
    return ((animation.value - start) / (end - start))
        .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final left = Curves.easeOutBack.transform(
          progress(0.02, 0.35),
        );

        final right = Curves.easeOutBack.transform(
          progress(0.16, 0.49),
        );

        final reveal = Curves.easeIn.transform(
          progress(0.36, 0.66),
        );

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.3,
                colors: [
                  Color(0xFFFFE1DE),
                  bg,
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 35,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FadeTransition(
                        opacity: animation,
                        child: const Text(
                          'BLACKHEART PRESENTS',
                          style: TextStyle(
                            color: cyan,
                            letterSpacing: 5,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -110 + 115 * left,
                    bottom: 125,
                    child: Transform.rotate(
                      angle: -0.08,
                      child: const AnimeMascot(
                        color: cyan,
                        female: false,
                        size: 175,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -110 + 115 * right,
                    bottom: 125,
                    child: Transform.rotate(
                      angle: 0.08,
                      child: const AnimeMascot(
                        color: pink,
                        female: true,
                        size: 175,
                      ),
                    ),
                  ),
                  Center(
                    child: Opacity(
                      opacity: reveal,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: cyan,
                            size: 40,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'POWERED BY BLACKHEART',
                            style: TextStyle(
                              letterSpacing: 6,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                colors: [ink, cyan, violet],
                              ).createShader(bounds);
                            },
                            child: const Text(
                              'OtakuDub',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ink,
                                fontSize: 43,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'AI DUBBING STUDIO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2.4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 17),
                          const Text(
                            'Same story. A new voice.',
                            style: TextStyle(
                              color: mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 35,
                    left: 40,
                    right: 40,
                    child: LinearProgressIndicator(
                      value: animation.value,
                      color: cyan,
                      backgroundColor: violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ORIGINAL ANIME-INSPIRED CHARACTER AVATARS

class AnimeMascot extends StatelessWidget {
  final Color color;
  final bool female;
  final double size;

  const AnimeMascot({
    super.key,
    required this.color,
    required this.female,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.3,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: size * .88,
            height: size * .85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size * .48),
                topRight: Radius.circular(size * .48),
                bottomLeft: Radius.circular(size * .15),
                bottomRight: Radius.circular(size * .15),
              ),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.35), panel, bg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: color, width: 2),
            ),
          ),
          Positioned(
            top: size * .24,
            child: Container(
              width: size * .69,
              height: size * .76,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDDCB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size * .40),
                  topRight: Radius.circular(size * .38),
                  bottomLeft: Radius.circular(size * .35),
                  bottomRight: Radius.circular(size * .35),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _eye(),
                    _eye(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: size * .13,
            child: Container(
              width: size * .78,
              height: size * .43,
              decoration: BoxDecoration(
                color: female
                    ? const Color(0xFFC2A5FF)
                    : const Color(0xFF17162D),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size * .5),
                  topRight: Radius.circular(size * .46),
                  bottomLeft: Radius.circular(size * .09),
                  bottomRight: Radius.circular(size * .29),
                ),
                border: Border.all(color: color, width: 2),
              ),
            ),
          ),
          Positioned(
            top: size * .26,
            right: size * .03,
            child: Icon(
              female ? Icons.auto_awesome : Icons.headphones,
              color: color,
              size: size * .25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye() {
    return Container(
      width: size * .075,
      height: size * .12,
      decoration: BoxDecoration(
        color: female ? violet : const Color(0xFF235FC8),
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }
}

class OtakuDubHome extends StatefulWidget {
  const OtakuDubHome({super.key});

  @override
  State<OtakuDubHome> createState() => _OtakuDubHomeState();
}

class _OtakuDubHomeState extends State<OtakuDubHome> {
  final models = ModelManager();
  final repository = ProjectRepository();

  late final engine = OfflineEngine(models);
  late final pipeline = DubbingPipeline(engine, repository);
  late Future<Map<String, dynamic>> _speakerCheck = engine.speakerEngineStatus();
  bool _speakerRepairing = false;
  String? _speakerRepairMessage;

  int tab = 0;
  String language = 'hi';
  String status = 'Ready to import media.';
  bool busy = false;
  double? dubPercent;

  DubProject? current;
  List<DubProject> projects = [];
  final Map<AiModel, Future<bool>> _modelChecks = {};

  Future<bool> _modelCheck(AiModel model) => _modelChecks.putIfAbsent(model, () {
    if (model == AiModel.hindiVoice) return const VoiceInstallationRegistry().isInstalled('hi_hero');
    if (model == AiModel.englishVoice) return const VoiceInstallationRegistry().isInstalled('en_hero');
    return models.installed(model);
  });

  void _refreshModelCheck(AiModel model) {
    setState(() => _modelChecks.remove(model));
  }

  @override
  void initState() {
    super.initState();
    refreshProjects();
  }

  Future<void> refreshProjects() async {
    try {
      final loaded = await repository.all();
      if (mounted) setState(() => projects = loaded);
    } catch (e) {
      if (mounted) setState(() => status = 'Library error: $e');
    }
  }

  Future<void> importMedia() async {
    if (busy) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp4',
        'mkv',
        'mov',
        'webm',
      ],
    );

    if (picked == null || picked.files.single.path == null) return;

    setState(() => busy = true);

    try {
      final selected = picked.files.single;
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final dir = await repository.folder(id);
      final extension = selected.extension?.toLowerCase() ?? 'mp4';

      final copied = await File(selected.path!).copy(
        '${dir.path}/source.$extension',
      );

      final project = DubProject(
        id: id,
        title: selected.name,
        sourcePath: copied.path,
        targetLanguage: language,
      );

      await repository.save(project);

      if (mounted) {
        setState(() {
          current = project;
          status = 'Imported: ${selected.name}';
        });
      }

      await refreshProjects();
    } catch (e) {
      if (mounted) setState(() => status = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resolveCharacterVoices(DubProject project) async {
    final speakers = project.segments.map((s) => s.speakerId)
        .where((id) => id.trim().isNotEmpty && id != 'unknown')
        .toSet().toList()..sort();
    final unresolved = const IdentityConfidenceGate().unresolved(project);
    // Uncertain segments require explicit confirmation. Never invent a
    // speaker identity from timeline proximity or silently cast unknown audio.
    final speakerChoices = <int, String?>{
      for (final segment in unresolved) segment.id: null,
    };
    final candidateSpeakers = <String>[
      ...speakers,
      for (var index = 1; index <= unresolved.length; index++)
        'speaker_manual_$index',
    ];
    final voices = VoiceCatalog.available(project.targetLanguage);
    if (voices.isEmpty) {
      setState(() => status = 'No bundled Supertonic voices for this language.');
      return;
    }
    final choices = <String, String?>{
      for (final speaker in candidateSpeakers)
        speaker: voices.any((v) => v.id == project.characterVoices[speaker])
            ? project.characterVoices[speaker]
            : project.segments.any((s) => s.speakerId == speaker &&
                voices.any((v) => v.id == s.voiceId))
                ? project.segments.firstWhere((s) => s.speakerId == speaker &&
                    voices.any((v) => v.id == s.voiceId)).voiceId
                : null,
    };
    // Previously identified speakers are already eligible for provisional
    // automatic casting. Only unknown lines require a manual speaker decision.
    final reservedStyles = <String>{};
    for (final speaker in speakers) {
      final previous = choices[speaker];
      if (previous != null) {
        final style = VoiceCatalog.supertonicStyle(previous);
        if (style != null) reservedStyles.add(style);
      }
    }
    for (final speaker in speakers) {
      if (choices[speaker] != null) continue;
      final preferred = voices.where((v) =>
          !reservedStyles.contains(VoiceCatalog.supertonicStyle(v.id)));
      final voice = preferred.isNotEmpty ? preferred.first : voices.first;
      choices[speaker] = voice.id;
      final style = VoiceCatalog.supertonicStyle(voice.id);
      if (style != null) reservedStyles.add(style);
    }
    void proposeVoice(String speaker) {
      if (choices[speaker] != null) return;
      final used = choices.values.whereType<String>()
          .map(VoiceCatalog.supertonicStyle).whereType<String>().toSet();
      final available = voices.where((v) =>
          !used.contains(VoiceCatalog.supertonicStyle(v.id)));
      choices[speaker] = (available.isNotEmpty ? available.first : voices.first).id;
    }
    List<String> activeSpeakers() => <String>{
      ...speakers,
      ...speakerChoices.values.whereType<String>(),
    }.toList()..sort();

    bool canSaveCasting() =>
        speakerChoices.values.every((value) => value != null) &&
        activeSpeakers().every((speaker) => choices[speaker] != null);

    String castingGuidance() {
      final unresolvedCount = speakerChoices.values.where((v) => v == null).length;
      final missingVoices = activeSpeakers()
          .where((speaker) => choices[speaker] == null).length;
      if (unresolvedCount == 0 && missingVoices == 0) return 'Ready to save casting.';
      return 'To enable Save casting: resolve $unresolvedCount dialogue segment(s) '
          'and assign voices for $missingVoices speaker(s). Scroll to see all speakers.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Assign character voices'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose a voice for each detected speaker. '
                    'Voice identity cannot be inferred reliably from acoustic clustering.'),
                if (unresolved.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('These dialogue segments could not be identified reliably. '
                        'Select an existing speaker or a new identity after checking the source video.'),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(castingGuidance(),
                    key: const ValueKey('casting_requirements')),
                ),
                for (final segment in unresolved)
                  DropdownButtonFormField<String>(
                    key: ValueKey('resolve_speaker_${segment.id}'),
                    initialValue: speakerChoices[segment.id],
                    decoration: InputDecoration(
                      labelText: 'Segment ${segment.id} (${segment.start.toStringAsFixed(1)}–${segment.end.toStringAsFixed(1)} s)',
                      helperText: segment.original.length > 60
                          ? '${segment.original.substring(0, 60)}…' : segment.original,
                    ),
                    items: [
                      for (final speaker in candidateSpeakers)
                        DropdownMenuItem(value: speaker, child: Text(speaker)),
                    ],
                    onChanged: (value) => update(() {
                      speakerChoices[segment.id] = value;
                      if (value != null) proposeVoice(value);
                    }),
                  ),
                for (final speaker in activeSpeakers())
                  DropdownButtonFormField<String>(
                    key: ValueKey('cast_$speaker'),
                    initialValue: choices[speaker],
                    decoration: InputDecoration(labelText: speaker),
                    items: [
                      for (final voice in voices)
                        DropdownMenuItem(
                          value: voice.id,
                          child: Text('${voice.description} (${voice.role.name})'),
                        ),
                    ],
                    onChanged: (value) => update(() => choices[speaker] = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: canSaveCasting()
                  ? () => Navigator.pop(dialogContext, true) : null,
              child: const Text('Save casting'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    for (final segment in unresolved) {
      segment.speakerId = speakerChoices[segment.id]!;
      segment.speakerConfidence = 0; // Explicitly user-resolved, not model confidence.
      segment.speakerManuallyVerified = true;
    }
    final usedSpeakers = project.segments.map((segment) => segment.speakerId).toSet();
    project.characterVoices
      ..clear()
      ..addAll({for (final entry in choices.entries)
        if (usedSpeakers.contains(entry.key)) entry.key: entry.value!});
    for (final segment in project.segments) {
      segment.voiceId = project.characterVoices[segment.speakerId] ?? '';
    }
    const CharacterIdentityFusion().record(project);
    await repository.save(project);
    if (mounted) setState(() {
      current = project;
      status = 'Character voices saved for ${usedSpeakers.length} speaker(s). '
          'Tap RESUME MY DUB to continue.';
    });
  }

  Future<void> generate() async {
    final project = current;
    if (project == null || busy) return;

    setState(() {
      busy = true;
      status = 'Checking offline AI runtime...';
      dubPercent = 0;
    });

    var backgroundStarted = false;
    try {
      await const MethodChannel('co.parikshit.otakudub/offline_engine')
          .invokeMethod<bool>('startBackgroundDubbing');
      backgroundStarted = true;
      await pipeline.process(
        project,
        onProgress: (stage) {
          if (mounted) {
            setState(() { status = stage == ProjectStage.transcribing ? 'Transcribing audio locally with Whisper. This stage can take time; 10% is its starting milestone.' : 'Processing: ${stage.name}'; dubPercent = stage == ProjectStage.completed ? 100 : stage == ProjectStage.exporting ? 85 : stage == ProjectStage.synthesizing ? 70 : stage == ProjectStage.refining ? 55 : stage == ProjectStage.translating ? 40 : stage == ProjectStage.casting ? 25 : stage == ProjectStage.transcribing ? 10 : dubPercent; });
          }
        },
      );

      if (mounted) {
        setState(() => status = project.error ?? 'Dubbed video saved automatically to Movies/OtakuDub and Projects!');
      }

      await refreshProjects();
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Processing stopped: $e');
      }
    } finally {
      if (backgroundStarted) {
        try {
          await const MethodChannel('co.parikshit.otakudub/offline_engine')
              .invokeMethod<bool>('stopBackgroundDubbing');
        } catch (error) {
          debugPrint('Could not stop background notification: $error');
        }
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Widget heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: const TextStyle(color: mutedInk),
        ),
      ],
    );
  }

  Widget studio() {
    return ListView(
      key: const ValueKey('studio'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      children: [
        heading(
          'Every story,\na new voice.',
          'Powered by Blackheart',
        ),
        const SizedBox(height: 24),
        Container(
          height: 170,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFDCEB),
                Color(0xFFDCEEFF),
                Color(0xFFE9DFFF),
              ],
            ),
            border: Border.all(color: violet.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.movie_creation_outlined,
                color: ink,
                size: 55,
              ),
              SizedBox(width: 17),
              Expanded(
                child: Text(
                  'THE STORY STAYS.\nTHE VOICE EVOLVES.',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'CHOOSE A LANGUAGE',
          style: TextStyle(
            color: cyan,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: language,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.translate),
          ),
          items: const [
            DropdownMenuItem(
              value: 'hi',
              child: Text('Hindi'),
            ),
            DropdownMenuItem(
              value: 'en',
              child: Text('English'),
            ),
          ],
          onChanged: busy
              ? null
              : (value) => setState(() {
                    language = value ?? 'hi';
                  }),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : importMedia,
          icon: const Icon(Icons.video_file_outlined),
          label: const Text('CHOOSE YOUR VIDEO'),
        ),
        if (current != null) ...[
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle, color: cyan),
              title: Text(current!.title),
              subtitle: Text(
                'Target: ${current!.targetLanguage.toUpperCase()}',
              ),
              onTap: () => OpenFilex.open(current!.sourcePath),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : generate,
            icon: const Icon(Icons.auto_awesome),
            label: Text(current!.stage == ProjectStage.translating ||
                current!.stage == ProjectStage.refining ||
                current!.stage == ProjectStage.casting ||
                current!.stage == ProjectStage.synthesizing ||
                current!.stage == ProjectStage.exporting ||
                (current!.stage == ProjectStage.failed && current!.segments.isNotEmpty)
                    ? 'RESUME MY DUB'
                    : 'CREATE MY DUB'),
          ),
        ],
        const SizedBox(height: 20),
        if (dubPercent != null) ...[
          Text('Progress: ${dubPercent!.round()}%'),
          LinearProgressIndicator(value: dubPercent! / 100),
          const Text('Stage-based estimate, not elapsed-time progress.'),
        ],
        const SizedBox(height: 12),
        Text(
          status,
          style: const TextStyle(color: cyan),
        ),
        const SizedBox(height: 14),
        const Text(
          'Some dubbing engines are still under development. '
          'The app will show an error if an unfinished stage is reached.',
          style: TextStyle(color: mutedInk, fontSize: 12),
        ),
      ],
    );
  }

  String _stamp(double seconds) {
    final ms = (seconds * 1000).round();
    final minutes = ms ~/ 60000;
    final secs = (ms % 60000) ~/ 1000;
    final fraction = ms % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${fraction.toString().padLeft(3, '0')}';
  }

  Future<void> _editReplacement(DubProject project, DubSegment line) async {
    final controller = TextEditingController(text: line.translation);
    final replacement = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit replacement • Segment ${line.id}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Original: ${line.original}'),
          const SizedBox(height: 8),
          Text('Target: ${_stamp(line.start)} – ${_stamp(line.synthesisEnd ?? line.end)}'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Replacement dialogue',
              hintText: 'Paste a meaning-preserving Hindi or Hindi-English alternative',
            ),
          ),
          const SizedBox(height: 8),
          const Text('Saving changes only this segment. Resume My Dub will synthesize and check its actual duration.',
            style: TextStyle(fontSize: 12, color: mutedInk)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save dialogue')),
        ],
      ),
    );
    controller.dispose();
    if (replacement == null || !mounted) return;
    if (!DialogueQualityGate.acceptableTranslation(
      replacement, line.original, project.sourceLanguage, project.targetLanguage,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Dialogue rejected by language/quality validation. Preserve meaning and use the selected target language.'),
      ));
      return;
    }
    final previous = line.translation;
    final wasRefined = project.refinedSegmentIds.contains(line.id);
    line.translation = replacement;
    project.refinedSegmentIds.add(line.id); // Do not overwrite user edit during optional refinement.
    try {
      await repository.save(project);
      if (!mounted) return;
      setState(() {
        current = current?.id == project.id ? project : current;
        projects = [...projects];
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Replacement saved. Resume My Dub to test the generated voice.'),
      ));
    } catch (error) {
      line.translation = previous;
      if (!wasRefined) project.refinedSegmentIds.remove(line.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    }
  }

  void _inspectDialogue(DubProject project) {
    final segments = [...project.segments]
      ..sort((a, b) => a.start.compareTo(b.start));
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Dialogue Inspector'), actions: [
          IconButton(
            tooltip: 'Copy dialogue report',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              final report = segments.map((s) =>
                'Segment ${s.id} | Speaker ${s.speakerId}\n'
                'Original ${_stamp(s.start)}–${_stamp(s.end)}: ${s.original}\n'
                'Replacement ${_stamp(s.start)}–${_stamp(s.synthesisEnd ?? s.end)}: ${s.translation.isEmpty ? '[Not generated]' : s.translation}\n'
                'Voice: ${s.voiceId.isEmpty ? '[Not assigned]' : s.voiceId}'
              ).join('\n\n');
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dialogue report copied')),
              );
            },
          ),
        ]),
        body: segments.isEmpty
          ? const Center(child: Text('Transcription has not been saved yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: segments.length,
              itemBuilder: (context, index) {
                final line = segments[index];
                final replacementEnd = line.synthesisEnd ?? line.end;
                return Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SEGMENT ${line.id} • ${line.speakerId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: violet)),
                    const SizedBox(height: 12),
                    const Text('ORIGINAL VOICE', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_stamp(line.start)} – ${_stamp(line.end)}'),
                    SelectableText(line.original.isEmpty ? '[Not transcribed]' : line.original),
                    const Divider(height: 28),
                    const Text('REPLACEMENT VOICE', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_stamp(line.start)} – ${_stamp(replacementEnd)} • Target window ${(replacementEnd - line.start).toStringAsFixed(2)}s'),
                    SelectableText(line.translation.isEmpty ? '[Not generated]' : line.translation),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: busy ? null : () => _editReplacement(project, line),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit / Paste replacement'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Assigned voice: ${line.voiceId.isEmpty ? 'Pending' : line.voiceId}',
                      style: const TextStyle(color: mutedInk)),
                    const Text('Actual generated audio duration is not yet saved per segment.',
                      style: TextStyle(color: mutedInk, fontSize: 12)),
                  ]),
                ));
              },
            ),
      ),
    ));
  }

  Widget projectLibrary() {
    return ListView(
      key: const ValueKey('projects'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      children: [
        heading(
          'Your Projects',
          'Your anime dubbing workspace.',
        ),
        const SizedBox(height: 22),
        if (projects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                'No projects yet. Import your first video in Studio.',
              ),
            ),
          ),
        for (final project in projects)
          Card(
            child: ListTile(
              // Keep project selection separate from inspecting its saved script.
              leading: IconButton(
                tooltip: 'Inspect original and replacement dialogue',
                icon: const Icon(Icons.subtitles_outlined, color: cyan),
                onPressed: () => _inspectDialogue(project),
              ),
              title: Text(project.title),
              subtitle: Text(
                '${project.stage.name.toUpperCase()} • '
                '${project.targetLanguage.toUpperCase()}',
              ),
              onTap: () {
                setState(() {
                  current = project;
                  tab = 0;
                  status = 'Selected ${project.title}';
                });
              },
              trailing: project.outputPath == null
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Icons.play_circle_fill,
                        color: pink,
                      ),
                      onPressed: () {
                        OpenFilex.open(project.outputPath!);
                      },
                    ),
            ),
          ),
      ],
    );
  }

  Widget modelSetup() {
    return ListView(
      key: const ValueKey('models'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      children: [
        heading(
          'Engine Library',
          'Manage your local dubbing models.',
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'OtakuMind directs translation, dialogue refinement and engine handoffs offline. '
              'OtakuMind coordinates specialist transcription, speaker tracking, translation and Supertonic voice synthesis. Uncertain acoustic identity is never invented.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: _speakerCheck,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final verified = state?['verified'] == true;
            return Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(
                  leading: Icon(verified ? Icons.check_circle_outline : Icons.warning_amber,
                      color: verified ? cyan : pink),
                  title: const Text('ECAPA Speaker Recognition'),
                  subtitle: Text(_speakerRepairMessage ??
                      (snapshot.connectionState == ConnectionState.waiting
                          ? 'Checking installed speaker pack and SHA-256…'
                          : snapshot.hasError
                              ? 'Speaker diagnostic failed: ${snapshot.error}'
                              : '${state?['status'] ?? 'Status unavailable'}. '
                                  'Verification does not guarantee speaker identification.')),
                ),
                if (_speakerRepairing) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(_speakerRepairing ? Icons.hourglass_top : Icons.build_circle_outlined),
                  label: Text(_speakerRepairing ? 'Repair running — please wait' : 'Check / repair speaker engine'),
                  onPressed: _speakerRepairing ? null : () async {
                    setState(() {
                      _speakerRepairing = true;
                      _speakerRepairMessage = 'Checking and repairing bundled ECAPA files. Please wait…';
                    });
                    try {
                      final result = await engine.speakerEngineStatus(repair: true);
                      if (!mounted) return;
                      setState(() {
                        _speakerRepairMessage = result['status']?.toString() ?? 'Unknown repair result';
                        _speakerRepairing = false;
                        _speakerCheck = Future.value(result);
                      });
                    } catch (error) {
                      if (!mounted) return;
                      setState(() {
                        _speakerRepairMessage = 'Repair failed: $error';
                        _speakerRepairing = false;
                        _speakerCheck = engine.speakerEngineStatus();
                      });
                    }
                  },
                ),
              ]),
            ));
          },
        ),
        for (final model in AiModel.values.where((model) => model != AiModel.translator && model != AiModel.speaker))
          FutureBuilder<bool>(
            future: _modelCheck(model),
            builder: (context, snapshot) {
              final installed = snapshot.data == true;

              return Card(
                child: ListTile(
                  leading: Icon(
                    installed
                        ? Icons.check_circle_outline
                        : Icons.memory,
                    color: installed ? cyan : pink,
                  ),
                  title: Text(model.displayName),
                  subtitle: Text(
                    snapshot.connectionState == ConnectionState.waiting
                        ? 'Checking/installing bundled model...'
                        : snapshot.hasError
                            ? 'Model check failed: ${snapshot.error}'
                            : installed
                                ? 'Model verified'
                                : model == AiModel.whisper
                                    ? 'Whisper installation or validation failed; tap icon to retry'
                                    : 'Model installation or validation failed',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.file_upload_outlined),
                    onPressed: () async {
                      try {
                        if (model.isVoice) {
                          await const VoiceInstallationRegistry().refresh();
                        } else {
                          await models.importModel(model);
                        }
                        if (mounted) _refreshModelCheck(model);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void changeTab(int value) {
    setState(() => tab = value);
    if (value == 1) refreshProjects();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      studio(),
      projectLibrary(),
      modelSetup(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OTAKU DUB',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'POWERED BY BLACKHEART',
              style: TextStyle(
                fontSize: 10,
                color: cyan,
                letterSpacing: 2.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Replay intro',
            icon: const Icon(Icons.auto_awesome, color: pink),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const OtakuDubLaunch(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 550),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.12, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: pages[tab],
          ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 650),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1.6),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  key: ValueKey(tab),
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Transform.translate(
                        offset: const Offset(-17, 12),
                        child: const AnimeMascot(
                          color: cyan,
                          female: false,
                          size: 73,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(17, 12),
                        child: const AnimeMascot(
                          color: pink,
                          female: true,
                          size: 73,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel,
        indicatorColor: violet.withValues(alpha: 0.14),
        selectedIndex: tab,
        onDestinationSelected: changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.movie_creation_outlined),
            selectedIcon: Icon(Icons.movie_creation, color: cyan),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library, color: cyan),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory, color: cyan),
            label: 'Models',
          ),
        ],
      ),
    );
  }
}
