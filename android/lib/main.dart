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

const background = Color(0xFF050509);
const surface = Color(0xFF11111B);
const purple = Color(0xFF9747FF);
const muted = Color(0xFFAAA8BE);

void main() => runApp(const OtakuDub());

class OtakuDub extends StatelessWidget {
  const OtakuDub({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OtakuDub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
          primary: purple,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: Color(0xFF292638),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Color(0xFF373044),
            ),
          ),
        ),
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
  bool completed = false;

  String status = 'Ready to create your next dub.';
  String language = 'hi';
  String style = 'natural';
  String selectedFile = '';

  String? outputPath;

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

    return 'Server error ${response.statusCode}';
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

    setState(() {
      project = data;
      completed = false;
      outputPath = null;
    });
  }

  Future<void> upload() async {
    if (busy) return;

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

    if (picked == null ||
        picked.files.single.path == null) {
      return;
    }

    final file = picked.files.single;

    setState(() {
      busy = true;
      project = null;
      completed = false;
      outputPath = null;
      selectedFile = file.name;
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
          file.path!,
        ),
      );

      final streamed = await request.send();

      final uploadResponse =
          await http.Response.fromStream(streamed);

      if (uploadResponse.statusCode != 200) {
        throw Exception(errorMessage(uploadResponse));
      }

      final uploaded = Map<String, dynamic>.from(
        jsonDecode(uploadResponse.body) as Map,
      );

      updateStatus(
        'Speech recognized. Translating dialogue...',
      );

      final translationResponse = await http.post(
        Uri.parse(
          '$server/projects/${uploaded['id']}/translate',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'language': language,
        }),
      );

      if (translationResponse.statusCode != 200) {
        throw Exception(
          errorMessage(translationResponse),
        );
      }

      final translated = Map<String, dynamic>.from(
        jsonDecode(translationResponse.body) as Map,
      );

      if (!mounted) return;

      loadProject(translated);

      updateStatus(
        'Translation complete. Your dub is ready to generate.',
      );
    } catch (e) {
      updateStatus(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
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
      completed = false;
      status = 'Generating dubbed voices and video...';
    });

    try {
      final edited = segments.map((s) {
        return {
          ...s,
          'speaker':
              (s['speaker'] ?? 'Character 1').toString(),
          'translation':
              translations[s['id']]!.text.trim(),
        };
      }).toList();

      if (edited.any(
        (s) => (s['translation'] as String).isEmpty,
      )) {
        throw Exception(
          'A translation is missing. Please review the dialogue.',
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
        headers: {
          'Content-Type': 'application/json',
        },
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

      final directory =
          await getApplicationDocumentsDirectory();

      final file = File(
        '${directory.path}/OtakuDub-${project!['id']}.mp4',
      );

      await file.writeAsBytes(download.bodyBytes);

      if (!mounted) return;

      setState(() {
        completed = true;
        outputPath = file.path;
        status = 'Your dubbed video is ready!';
      });

      await OpenFilex.open(file.path);
    } catch (e) {
      updateStatus(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF292638),
        ),
      ),
      child: child,
    );
  }

  Widget sectionTitle(
    String title, {
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: muted,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget option({
    required String label,
    required String value,
    required String selected,
    required VoidCallback? onTap,
  }) {
    final active = value == selected;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: active
                ? purple.withValues(alpha: 0.17)
                : background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? purple
                  : const Color(0xFF302B3D),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget primaryButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              purple.withValues(alpha: 0.30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget brandHeader() {
    return Row(
      children: [
        Container(
          width: 47,
          height: 47,
          decoration: BoxDecoration(
            color: purple.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: purple.withValues(alpha: 0.5),
            ),
          ),
          child: const Icon(
            Icons.mic_external_on_rounded,
            color: purple,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Otaku',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'Dub',
                style: TextStyle(color: purple),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        const Spacer(),
        const Icon(
          Icons.graphic_eq_rounded,
          color: purple,
          size: 27,
        ),
      ],
    );
  }

  Widget hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF35205B),
            Color(0xFF171024),
            Color(0xFF0C0B13),
          ],
        ),
        border: Border.all(
          color: purple.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.multitrack_audio_rounded,
            color: Color(0xFFD5AEFF),
            size: 38,
          ),
          const SizedBox(height: 18),
          const Text(
            'Your Anime.\nYour Language.',
            style: TextStyle(
              fontSize: 29,
              height: 1.13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Upload a clip. Translate the dialogue. '
            'Create your own AI dub.',
            style: TextStyle(
              color: Color(0xFFD1C5DF),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'JAPANESE  •  HINDI  •  ENGLISH',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget configuration() {
    return panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'Dub settings',
            subtitle: 'Choose your target language and voice style.',
          ),
          const SizedBox(height: 22),
          const Text(
            'TARGET LANGUAGE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.3,
              color: muted,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              option(
                label: '🇮🇳  Hindi',
                value: 'hi',
                selected: language,
                onTap: busy || project != null
                    ? null
                    : () => setState(() => language = 'hi'),
              ),
              const SizedBox(width: 10),
              option(
                label: '🇺🇸  English',
                value: 'en',
                selected: language,
                onTap: busy || project != null
                    ? null
                    : () => setState(() => language = 'en'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'VOICE STYLE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.3,
              color: muted,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              option(
                label: 'Natural',
                value: 'natural',
                selected: style,
                onTap: busy
                    ? null
                    : () => setState(() => style = 'natural'),
              ),
              const SizedBox(width: 10),
              option(
                label: 'Expressive',
                value: 'expressive',
                selected: style,
                onTap: busy
                    ? null
                    : () => setState(() => style = 'expressive'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget uploadPanel() {
    return panel(
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              size: 33,
              color: purple,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'Upload your media',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select an anime clip, video or audio file.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'MP4 • MKV • MOV • WEBM • MP3 • WAV • M4A',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF807A93),
              fontSize: 10,
            ),
          ),
          if (selectedFile.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              selectedFile,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD5AEFF),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 22),
          primaryButton(
            text: 'Choose File & Translate',
            icon: Icons.add_rounded,
            onPressed: busy ? null : upload,
          ),
        ],
      ),
    );
  }

  Widget statusPanel() {
    final isError = status.startsWith('Error:');

    return panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: purple,
              ),
            )
          else
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : completed
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
              color: isError
                  ? Colors.orangeAccent
                  : completed
                      ? Colors.greenAccent
                      : purple,
            ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget dialoguePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'Translated dialogue',
          subtitle:
              'Detected language: ${project!['source_language']}',
        ),
        const SizedBox(height: 14),
        ...segments.map((s) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.mic_rounded,
                        color: purple,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (s['speaker'] ?? 'Character 1').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${s['start']}s – ${s['end']}s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  const Text(
                    'ORIGINAL',
                    style: TextStyle(
                      fontSize: 10,
                      color: muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    s['text'].toString(),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: translations[s['id']],
                    enabled: !busy,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'AI translation',
                      helperText: 'Optional: edit before dubbing',
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        primaryButton(
          text: 'Generate Dubbed Video',
          icon: Icons.movie_creation_outlined,
          onPressed: busy ? null : render,
        ),
        const SizedBox(height: 12),
        const Text(
          'Current MVP: voices are assigned from speaker labels. '
          'Automatic character voice identification and soundtrack '
          'separation are not yet implemented.',
          style: TextStyle(
            color: muted,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget completedPanel() {
    return panel(
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 62,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 14),
          const Text(
            'Dubbing Complete!',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your OtakuDub video is ready.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 22),
          primaryButton(
            text: 'Open Dubbed Video',
            icon: Icons.play_arrow_rounded,
            onPressed: outputPath == null
                ? null
                : () async {
                    await OpenFilex.open(outputPath!);
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            brandHeader(),
            const SizedBox(height: 27),
            hero(),
            const SizedBox(height: 26),
            configuration(),
            const SizedBox(height: 17),
            uploadPanel(),
            const SizedBox(height: 17),
            statusPanel(),
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: purple,
                backgroundColor: surface,
              ),
            ],
            if (project != null) ...[
              const SizedBox(height: 28),
              dialoguePanel(),
            ],
            if (completed) ...[
              const SizedBox(height: 22),
              completedPanel(),
            ],
            const SizedBox(height: 35),
            const Center(
              child: Text(
                'OTAKUDUB  •  YOUR ANIME. YOUR LANGUAGE.',
                style: TextStyle(
                  color: Color(0xFF777184),
                  fontSize: 10,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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

