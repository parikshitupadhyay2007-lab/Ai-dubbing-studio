import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

const server = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://ai-dubbing-studio.onrender.com',
);

void main() => runApp(const Studio());

class Studio extends StatelessWidget {
  const Studio({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Dubbing Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, dynamic>? project;

  bool busy = false;
  String status = 'Select a language and upload your video.';
  String language = 'hi';
  String style = 'natural';

  final Map<int, TextEditingController> translations = {};

  List<Map<String, dynamic>> get segments {
    return ((project?['segments'] ?? []) as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
  }

  List<String> get voiceOptions {
    if (language == 'hi') {
      return [
        'hi-IN-MadhurNeural',
        'hi-IN-SwaraNeural',
      ];
    }

    if (style == 'expressive') {
      return [
        'en-US-ChristopherNeural',
        'en-US-AriaNeural',
        'en-US-DavisNeural',
      ];
    }

    return [
      'en-US-GuyNeural',
      'en-US-JennyNeural',
      'en-US-AriaNeural',
    ];
  }

  void updateStatus(String message) {
    if (mounted) {
      setState(() => status = message);
    }
  }

  String errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    } catch (_) {}

    return 'Server error ${response.statusCode}: ${response.body}';
  }

  void loadProject(Map<String, dynamic> data) {
    for (final controller in translations.values) {
      controller.dispose();
    }

    translations.clear();

    for (final item in data['segments'] as List) {
      final s = Map<String, dynamic>.from(item as Map);
      final id = s['id'] as int;

      translations[id] = TextEditingController(
        text: (s['translation'] ?? '').toString(),
      );
    }

    setState(() => project = data);
  }

  Future<void> upload() async {
    if (busy) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'mov', 'webm',
        'mp3', 'wav', 'm4a',
      ],
    );

    if (picked == null || picked.files.single.path == null) {
      return;
    }

    setState(() {
      busy = true;
      project = null;
      status = 'Uploading and recognizing speech...';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$server/projects'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          picked.files.single.path!,
        ),
      );

      final streamed = await request.send();
      final uploadResponse = await http.Response.fromStream(streamed);

      if (uploadResponse.statusCode != 200) {
        throw Exception(errorMessage(uploadResponse));
      }

      final uploaded = Map<String, dynamic>.from(
        jsonDecode(uploadResponse.body) as Map,
      );

      updateStatus(
        'Speech recognized. Automatically translating...',
      );

      final translationResponse = await http.post(
        Uri.parse('$server/projects/${uploaded['id']}/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'language': language,
        }),
      );

      if (translationResponse.statusCode != 200) {
        throw Exception(errorMessage(translationResponse));
      }

      final translated = Map<String, dynamic>.from(
        jsonDecode(translationResponse.body) as Map,
      );

      if (!mounted) return;

      loadProject(translated);

      updateStatus(
        'Automatic translation complete. Ready to generate your dub.',
      );
    } catch (e) {
      updateStatus('Error: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> render() async {
    if (busy || project == null) return;

    setState(() {
      busy = true;
      status = 'Generating dubbed voices and video...';
    });

    try {
      final edited = segments.map((s) {
        return {
          ...s,
          'speaker': (s['speaker'] ?? 'Character 1').toString(),
          'translation': translations[s['id']]!.text.trim(),
        };
      }).toList();

      if (edited.any(
        (s) => (s['translation'] as String).isEmpty,
      )) {
        throw Exception(
          'A translation is missing. Please retry the upload.',
        );
      }

      final names = edited
          .map((s) => s['speaker'] as String)
          .toSet()
          .toList();

      final assignedVoices = <String, String>{};

      for (var i = 0; i < names.length; i++) {
        assignedVoices[names[i]] =
            voiceOptions[i % voiceOptions.length];
      }

      final response = await http.post(
        Uri.parse(
          '$server/projects/${project!['id']}/render',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'language': language,
          'style': style,
          'segments': edited,
          'voices': assignedVoices,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(errorMessage(response));
      }

      updateStatus('Downloading your dubbed video...');

      final download = await http.get(
        Uri.parse(
          '$server/projects/${project!['id']}/download',
        ),
      );

      if (download.statusCode != 200) {
        throw Exception(errorMessage(download));
      }

      final directory = await getApplicationDocumentsDirectory();

      final file = File(
        '${directory.path}/AI-Dubbing-Studio-${project!['id']}.mp4',
      );

      await file.writeAsBytes(download.bodyBytes);

      updateStatus('Dubbed video generated successfully!');

      await OpenFilex.open(file.path);
    } catch (e) {
      updateStatus('Error: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Dubbing Studio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.record_voice_over,
            size: 64,
          ),
          const SizedBox(height: 12),

          const Text(
            'Every Character. Every Language.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 24),

          DropdownButtonFormField<String>(
            value: language,
            decoration: const InputDecoration(
              labelText: 'Dub language',
              border: OutlineInputBorder(),
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
            onChanged: busy || project != null
                ? null
                : (value) {
                    setState(() => language = value!);
                  },
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: style,
            decoration: const InputDecoration(
              labelText: 'Voice style',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'natural',
                child: Text('Natural'),
              ),
              DropdownMenuItem(
                value: 'expressive',
                child: Text('Expressive'),
              ),
            ],
            onChanged: busy
                ? null
                : (value) {
                    setState(() => style = value!);
                  },
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: busy ? null : upload,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload video or audio'),
          ),

          if (busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],

          const SizedBox(height: 16),

          Text(status),

          if (project != null) ...[
            const SizedBox(height: 24),

            Text(
              'Detected language: ${project!['source_language']}',
            ),

            const SizedBox(height: 12),

            const Text(
              'Automatically translated dialogue',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),

            const SizedBox(height: 8),

            ...segments.map((s) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s['start']}s – ${s['end']}s',
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Original: ${s['text']}',
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: translations[s['id']],
                        enabled: !busy,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'AI translation (optional editing)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: busy ? null : render,
              icon: const Icon(Icons.movie_creation_outlined),
              label: const Text('Generate dubbed video'),
            ),

            const SizedBox(height: 12),

            const Text(
              'Translations and voices are generated automatically. '
              'You may edit translations before rendering. '
              'The current MVP replaces the original soundtrack.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in translations.values) {
      controller.dispose();
    }

    super.dispose();
  }
}
