import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'models/dub_project.dart';
import 'services/dubbing_pipeline.dart';
import 'services/model_manager.dart';
import 'services/offline_engine.dart';
import 'services/project_repository.dart';
import 'services/voice_installation_registry.dart';

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

      Navigator.of(context).pushReplacement(
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
      );
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

  Future<void> generate() async {
    final project = current;
    if (project == null || busy) return;

    setState(() {
      busy = true;
      status = 'Checking offline AI runtime...';
      dubPercent = 0;
    });

    try {
      await pipeline.process(
        project,
        onProgress: (stage) {
          if (mounted) {
            setState(() { status = stage == ProjectStage.transcribing ? 'Transcribing audio locally with Whisper. This stage can take time; 10% is its starting milestone.' : 'Processing: ${stage.name}'; dubPercent = stage == ProjectStage.completed ? 100 : stage == ProjectStage.exporting ? 85 : stage == ProjectStage.synthesizing ? 70 : stage == ProjectStage.refining ? 55 : stage == ProjectStage.translating ? 40 : stage == ProjectStage.casting ? 25 : stage == ProjectStage.transcribing ? 10 : dubPercent; });
          }
        },
      );

      if (mounted) {
        setState(() => status = 'Dubbed media created successfully!');
      }

      await refreshProjects();
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Processing stopped: $e');
      }
    } finally {
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
            label: const Text('CREATE MY DUB'),
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
              leading: const Icon(
                Icons.video_library_outlined,
                color: cyan,
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
              'OtakuMind runs internally for dialogue refinement. '
              'Translation uses OtakuMind and speaker identification runs in the native engine. Voice synthesis requires compatible installed voice models.',
            ),
          ),
        ),
        const SizedBox(height: 12),
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

