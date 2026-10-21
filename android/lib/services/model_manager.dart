
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'models/dub_project.dart';
import 'services/dubbing_pipeline.dart';
import 'services/model_manager.dart';
import 'services/offline_engine.dart';
import 'services/project_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OtakuDubApp());
}

class OtakuDubApp extends StatelessWidget {
  const OtakuDubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'オタクダブ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080811),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9955FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const OtakuDubHome(),
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

  bool initializingModels = true;
  String modelStatus = 'Preparing bundled AI models...';

  DubProject? current;
  List<DubProject> projects = [];

  final messageController = TextEditingController();
  final history = <Map<String, String>>[];

  String personality = 'spirit';
  String chatResponse = '';

  @override
  void initState() {
    super.initState();
    initializeModels();
    refreshProjects();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> initializeModels() async {
    try {
      final results = await models.installBundledModels();

      final ready = results.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (!mounted) return;

      setState(() {
        initializingModels = false;
        modelStatus =
            '${ready.length}/${AiModel.values.length} model files installed.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        initializingModels = false;
        modelStatus = 'Model initialization failed: $e';
      });
    }
  }

  Future<void> refreshProjects() async {
    final loaded = await repository.all();

    if (mounted) {
      setState(() => projects = loaded);
    }
  }

  Future<void> importMedia() async {
    if (busy || initializingModels) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4',
        'mkv',
        'mov',
        'webm',
        'mp3',
        'wav',
        'm4a',
      ],
    );

    if (picked == null || picked.files.single.path == null) {
      return;
    }

    setState(() => busy = true);

    try {
      final selected = picked.files.single;
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final dir = await repository.folder(id);

      final extension =
          selected.extension?.toLowerCase() ?? 'mp4';

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

      if (!mounted) return;

      setState(() {
        current = project;
        status = 'Imported locally: ${selected.name}';
      });

      await refreshProjects();
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Import failed: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> generate() async {
    final project = current;

    if (project == null || busy || initializingModels) {
      return;
    }

    setState(() {
      busy = true;
      status = 'Checking native offline AI runtime...';
    });

    try {
      await pipeline.process(
        project,
        onProgress: (stage) {
          if (mounted) {
            setState(() {
              status = 'Processing: ${stage.name}';
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        status = 'Dubbed media created successfully.';
      });

      await refreshProjects();
    } catch (e) {
      if (mounted) {
        setState(() {
          status = 'Processing stopped: $e';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendMessage() async {
    final message = messageController.text.trim();

    if (message.isEmpty || busy || initializingModels) {
      return;
    }

    setState(() {
      busy = true;
      chatResponse = 'Generating locally...';
    });

    try {
      final reply = await engine.chat(
        message: message,
        personality: personality,
        language: language,
        history: history,
      );

      history.add({
        'role': 'user',
        'content': message,
      });

      history.add({
        'role': 'assistant',
        'content': reply,
      });

      messageController.clear();

      if (mounted) {
        setState(() => chatResponse = reply);
      }
    } catch (e) {
      if (mounted) {
        setState(() => chatResponse = e.toString());
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget studio() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Your Anime. Your Language.',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Import your media and process it using local AI models.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: language,
          decoration: const InputDecoration(
            labelText: 'Target language',
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
          onChanged: busy || initializingModels
              ? null
              : (value) {
                  setState(() {
                    language = value ?? 'hi';
                  });
                },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy || initializingModels
              ? null
              : importMedia,
          icon: const Icon(Icons.folder_open),
          label: const Text('Import anime / movie'),
        ),
        if (current != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text(current!.title),
              subtitle: Text(
                'Target: ${current!.targetLanguage.toUpperCase()}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  OpenFilex.open(current!.sourcePath);
                },
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: busy || initializingModels
                ? null
                : generate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Start offline dubbing'),
          ),
        ],
        const SizedBox(height: 16),
        if (busy || initializingModels)
          const LinearProgressIndicator(),
        const SizedBox(height: 10),
        Text(initializingModels ? modelStatus : status),
        const SizedBox(height: 20),
        const Text(
          'Automatic dubbing requires compatible native '
          'inference engines as well as installed model files.',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget projectLibrary() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Local Projects',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        for (final project in projects)
          Card(
            child: ListTile(
              title: Text(project.title),
              subtitle: Text(
                '${project.stage.name} • '
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
                      icon: const Icon(Icons.play_circle),
                      onPressed: () {
                        OpenFilex.open(project.outputPath!);
                      },
                    ),
            ),
          ),
      ],
    );
  }

  Widget mind() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'OtakuMind',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: personality,
          decoration: const InputDecoration(
            labelText: 'Original anime-inspired personality',
          ),
          items: const [
            DropdownMenuItem(
              value: 'spirit',
              child: Text('Unbreakable Spirit'),
            ),
            DropdownMenuItem(
              value: 'shadow',
              child: Text('Shadow Strategist'),
            ),
            DropdownMenuItem(
              value: 'mentor',
              child: Text('Limitless Mentor'),
            ),
            DropdownMenuItem(
              value: 'companion',
              child: Text('Future Companion'),
            ),
            DropdownMenuItem(
              value: 'guardian',
              child: Text('Gentle Guardian'),
            ),
            DropdownMenuItem(
              value: 'genius',
              child: Text('Mastermind'),
            ),
          ],
          onChanged: busy || initializingModels
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => personality = value);
                  }
                },
        ),
        const SizedBox(height: 15),
        TextField(
          controller: messageController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Message',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy || initializingModels
              ? null
              : sendMessage,
          child: const Text('Send to local OtakuMind'),
        ),
        const SizedBox(height: 18),
        SelectableText(chatResponse),
      ],
    );
  }

  Widget modelSetup() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Local AI Models',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(modelStatus),
        const SizedBox(height: 8),
        if (initializingModels)
          const LinearProgressIndicator(),
        const Text(
          'Bundled models are extracted automatically. '
          'Manual import remains available as a fallback.',
        ),
        const SizedBox(height: 16),
        for (final model in AiModel.values)
          FutureBuilder<bool>(
            future: models.installed(model),
            builder: (context, snapshot) {
              final installed = snapshot.data == true;

              return Card(
                child: ListTile(
                  title: Text(model.displayName),
                  subtitle: Text(
                    snapshot.hasError
                        ? 'Installation error'
                        : installed
                            ? 'File present'
                            : 'File missing',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.file_upload),
                    tooltip: 'Import compatible model',
                    onPressed: initializingModels
                        ? null
                        : () async {
                            try {
                              final imported =
                                  await models.importModel(model);

                              if (!mounted) return;

                              if (imported) {
                                setState(() {});
                              }
                            } catch (e) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                ),
                              );
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      studio(),
      projectLibrary(),
      mind(),
      modelSetup(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'オタクダブ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'powered by parikshit.co',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);

          if (value == 1) {
            refreshProjects();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.movie),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology),
            label: 'Mind',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory),
            label: 'Models',
          ),
        ],
      ),
    );
  }
}
