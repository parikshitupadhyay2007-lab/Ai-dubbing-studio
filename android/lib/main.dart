import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'screens/otakumind_screen.dart';

const server = String.fromEnvironment('API_URL', defaultValue: 'https://ai-dubbing-studio.onrender.com');
const background = Color(0xFF050509);
const surface = Color(0xFF11111B);
const purple = Color(0xFF9747FF);
const muted = Color(0xFFAAA8BE);

void main() => runApp(const OtakuDub());

class OtakuDub extends StatelessWidget {
  const OtakuDub({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OtakuDub',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.dark, primary: purple, surface: surface),
      appBarTheme: const AppBarTheme(backgroundColor: background, elevation: 0),
      cardTheme: CardThemeData(color: surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF292638)))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF373044))),
      ),
    ),
    home: const OtakuDubShell(),
  );
}

class OtakuDubShell extends StatefulWidget {
  const OtakuDubShell({super.key});
  @override
  State<OtakuDubShell> createState() => _OtakuDubShellState();
}

class _OtakuDubShellState extends State<OtakuDubShell> {
  int tab = 0;
  bool reduceMotion = false;
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      WelcomePage(onStart: () => setState(() => tab = 1), reduceMotion: reduceMotion),
      const Home(),
      const OtakuMindScreen(),
      const VoiceLibraryPage(),
      const ProjectsPage(),
      SettingsPage(reduceMotion: reduceMotion, onChanged: (v) => setState(() => reduceMotion = v)),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          NavigationBar(
            height: 66,
            backgroundColor: surface,
            indicatorColor: purple.withValues(alpha: .22),
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.mic_none_rounded), selectedIcon: Icon(Icons.mic_rounded), label: 'Studio'),
              NavigationDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology_rounded), label: 'Mind'),
              NavigationDestination(icon: Icon(Icons.record_voice_over_outlined), selectedIcon: Icon(Icons.record_voice_over), label: 'Voices'),
              NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library_rounded), label: 'Projects'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, bottom: 3),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('powered by parikshit.co', style: GoogleFonts.cormorantGaramond(fontSize: 14, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, letterSpacing: .4, color: Colors.white54)),
            ),
          ),
        ]),
      ),
    );
  }
}

class WelcomePage extends StatefulWidget {
  final VoidCallback onStart;
  final bool reduceMotion;
  const WelcomePage({super.key, required this.onStart, required this.reduceMotion});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  @override
  void initState() {
    super.initState();
    animation = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }
  @override
  void dispose() { animation.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(padding: const EdgeInsets.all(22), children: [
      const SizedBox(height: 12),
      const BrandHeader(),
      const SizedBox(height: 35),
      AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(offset: Offset(0, widget.reduceMotion ? 0 : -9 * animation.value), child: child),
        child: Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(colors: [Color(0xFF48227D), Color(0xFF191329), background]),
            border: Border.all(color: purple.withValues(alpha: .4)),
          ),
          child: const Stack(children: [
            Positioned(top: 26, right: 26, child: Icon(Icons.auto_awesome, color: Color(0xFFDAC4FF), size: 26)),
            Center(child: Icon(Icons.person_4_rounded, size: 155, color: Color(0xFFD3B5FF))),
            Positioned(left: 25, bottom: 25, child: Icon(Icons.graphic_eq_rounded, color: purple, size: 40)),
          ]),
        ),
      ),
      const SizedBox(height: 35),
      const Text('Every Story\nDeserves a Voice.', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.12)),
      const SizedBox(height: 14),
      const Text('Your AI dubbing universe. Translate dialogue into Hindi or English and bring stories to life.', style: TextStyle(color: muted, fontSize: 14, height: 1.6)),
      const SizedBox(height: 28),
      SizedBox(height: 54, child: FilledButton.icon(onPressed: widget.onStart, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Enter Dubbing Studio'), style: FilledButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white))),
      const SizedBox(height: 28),
    ]),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 47, height: 47, decoration: BoxDecoration(color: purple.withValues(alpha: .16), borderRadius: BorderRadius.circular(15), border: Border.all(color: purple.withValues(alpha: .5))), child: const Icon(Icons.mic_external_on_rounded, color: purple, size: 27)),
    const SizedBox(width: 12),
    const Text.rich(TextSpan(children: [TextSpan(text: 'Otaku', style: TextStyle(color: Colors.white)), TextSpan(text: 'Dub', style: TextStyle(color: purple))]), style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.7)),
    const Spacer(),
    const Icon(Icons.graphic_eq_rounded, color: purple, size: 27),
  ]);
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -.6)),
    const SizedBox(height: 6),
    Text(subtitle, style: const TextStyle(color: muted, fontSize: 13, height: 1.5)),
  ]);
}

class VoiceLibraryPage extends StatelessWidget {
  const VoiceLibraryPage({super.key});
  static const roles = <(String, String, IconData, Color)>[
    ('Hero', 'Confident & energetic', Icons.bolt_rounded, Color(0xFFB58CFF)),
    ('Heroine', 'Expressive & determined', Icons.auto_awesome_rounded, Color(0xFFFF89C8)),
    ('Villain', 'Controlled & dramatic', Icons.dark_mode_rounded, Color(0xFFFF7979)),
    ('Female Villain', 'Elegant & calculating', Icons.visibility_rounded, Color(0xFFC68BFF)),
    ('Mentor', 'Wise & reassuring', Icons.psychology_rounded, Color(0xFF8CCCB9)),
    ('Best Friend', 'Playful & enthusiastic', Icons.sentiment_very_satisfied_rounded, Color(0xFFFFCA7A)),
    ('Young Sidekick', 'Curious & lively', Icons.stars_rounded, Color(0xFF8DBBFF)),
    ('Mysterious Stranger', 'Quiet & enigmatic', Icons.blur_on_rounded, Color(0xFFB4A5E8)),
    ('Background', 'Everyday conversational', Icons.groups_rounded, Color(0xFFB2B2C8)),
    ('Narrator', 'Warm & cinematic', Icons.menu_book_rounded, Color(0xFFD6AEFF)),
  ];
  @override
  Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
    const PageHeading(title: 'Voice Universe', subtitle: 'Explore anime-inspired character voice archetypes.'),
    const SizedBox(height: 20),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: purple.withValues(alpha: .12), borderRadius: BorderRadius.circular(17)), child: const Text('100-profile collection in development. These are category previews, not playable voice samples yet.', style: TextStyle(color: Color(0xFFD8C4FF), fontSize: 12, height: 1.5))),
    const SizedBox(height: 20),
    GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: roles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .91),
      itemBuilder: (context, index) {
        final item = roles[index];
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [item.$4.withValues(alpha: .27), surface]), border: Border.all(color: item.$4.withValues(alpha: .3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Center(child: Icon(item.$3, size: 58, color: item.$4))),
            Text(item.$1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(item.$2, style: const TextStyle(color: muted, fontSize: 11)),
          ]),
        );
      },
    ),
    const SizedBox(height: 20),
  ]));
}

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const PageHeading(title: 'My Projects', subtitle: 'Your dubbing workspace.'),
    const Spacer(),
    Center(child: Column(children: [
      Container(width: 105, height: 105, decoration: BoxDecoration(color: purple.withValues(alpha: .12), shape: BoxShape.circle), child: const Icon(Icons.video_library_outlined, color: purple, size: 48)),
      const SizedBox(height: 20),
      const Text('Your story starts here', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('Persistent project history will appear here once we connect project storage. Current downloads still work from the Studio.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.5)),
    ])),
    const Spacer(),
  ])));
}

class SettingsPage extends StatelessWidget {
  final bool reduceMotion;
  final ValueChanged<bool> onChanged;
  const SettingsPage({super.key, required this.reduceMotion, required this.onChanged});
  @override
  Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(22), children: [
    const PageHeading(title: 'Settings', subtitle: 'Personalise your OtakuDub experience.'),
    const SizedBox(height: 28),
    Card(child: SwitchListTile(title: const Text('Reduce motion'), subtitle: const Text('Disable floating artwork animation', style: TextStyle(color: muted)), secondary: const Icon(Icons.animation_rounded, color: purple), value: reduceMotion, onChanged: onChanged)),
    const SizedBox(height: 12),
    const Card(child: ListTile(leading: Icon(Icons.language_rounded, color: purple), title: Text('Languages'), subtitle: Text('Hindi and English dubbing', style: TextStyle(color: muted)))),
    const SizedBox(height: 12),
    const Card(child: ListTile(leading: Icon(Icons.info_outline_rounded, color: purple), title: Text('About OtakuDub'), subtitle: Text('AI-powered dubbing studio', style: TextStyle(color: muted)))),
    const SizedBox(height: 35),
    Center(child: Text('OTAKUDUB', style: GoogleFonts.cormorantGaramond(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3, color: purple))),
  ]));
}

// =============================================
// EXISTING WORKING STUDIO 鈥� API FLOW PRESERVED
// =============================================

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

  List<Map<String, dynamic>> get segments => ((project?['segments'] ?? []) as List).map((s) => Map<String, dynamic>.from(s as Map)).toList();

  List<String> get voiceOptions {
    if (language == 'hi') return ['hi-IN-MadhurNeural', 'hi-IN-SwaraNeural'];
    if (style == 'expressive') return ['en-US-ChristopherNeural', 'en-US-AriaNeural', 'en-US-DavisNeural'];
    return ['en-US-GuyNeural', 'en-US-JennyNeural', 'en-US-AriaNeural'];
  }

  void updateStatus(String message) {
    if (mounted) setState(() => status = message);
  }

  String errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] != null) return data['detail'].toString();
    } catch (_) {}
    return 'Server error ${response.statusCode}';
  }

  void loadProject(Map<String, dynamic> data) {
    for (final controller in translations.values) { controller.dispose(); }
    translations.clear();
    for (final item in data['segments'] as List) {
      final s = Map<String, dynamic>.from(item as Map);
      final id = s['id'] as int;
      translations[id] = TextEditingController(text: (s['translation'] ?? '').toString());
    }
    setState(() { project = data; completed = false; outputPath = null; });
  }

  Future<void> upload() async {
    if (busy) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp4', 'mkv', 'mov', 'webm', 'mp3', 'wav', 'm4a']);
    if (picked == null || picked.files.single.path == null) return;
    final file = picked.files.single;
    setState(() { busy = true; project = null; completed = false; outputPath = null; selectedFile = file.name; status = 'Uploading and recognizing speech...'; });
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$server/projects'));
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
      final streamed = await request.send();
      final uploadResponse = await http.Response.fromStream(streamed);
      if (uploadResponse.statusCode != 200) throw Exception(errorMessage(uploadResponse));
      final uploaded = Map<String, dynamic>.from(jsonDecode(uploadResponse.body) as Map);
      updateStatus('Speech recognized. Translating dialogue...');
      final translationResponse = await http.post(
        Uri.parse('$server/projects/${uploaded['id']}/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'language': language}),
      );
      if (translationResponse.statusCode != 200) throw Exception(errorMessage(translationResponse));
      final translated = Map<String, dynamic>.from(jsonDecode(translationResponse.body) as Map);
      if (!mounted) return;
      loadProject(translated);
      updateStatus('Translation complete. Your dub is ready to generate.');
    } catch (e) {
      updateStatus('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> render() async {
    if (busy || project == null) return;
    setState(() { busy = true; completed = false; status = 'Generating dubbed voices and video...'; });
    try {
      final edited = segments.map((s) => {
        ...s,
        'speaker': (s['speaker'] ?? 'Character 1').toString(),
        'translation': translations[s['id']]!.text.trim(),
      }).toList();
      if (edited.any((s) => (s['translation'] as String).isEmpty)) throw Exception('A translation is missing. Please review the dialogue.');
      final names = edited.map((s) => s['speaker'] as String).toSet().toList();
      final assignedVoices = <String, String>{};
      for (var i = 0; i < names.length; i++) { assignedVoices[names[i]] = voiceOptions[i % voiceOptions.length]; }
      final response = await http.post(
        Uri.parse('$server/projects/${project!['id']}/render'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'language': language, 'style': style, 'segments': edited, 'voices': assignedVoices}),
      );
      if (response.statusCode != 200) throw Exception(errorMessage(response));
      updateStatus('Downloading your dubbed video...');
      final download = await http.get(Uri.parse('$server/projects/${project!['id']}/download'));
      if (download.statusCode != 200) throw Exception(errorMessage(download));
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/OtakuDub-${project!['id']}.mp4');
      await file.writeAsBytes(download.bodyBytes);
      if (!mounted) return;
      setState(() { completed = true; outputPath = file.path; status = 'Your dubbed video is ready!'; });
      await OpenFilex.open(file.path);
    } catch (e) {
      updateStatus('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF292638))),
    child: child,
  );

  Widget sectionTitle(String title, {String? subtitle}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    if (subtitle != null) ...[const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: muted, fontSize: 13))],
  ]);

  Widget option({required String label, required String value, required String selected, required VoidCallback? onTap}) {
    final active = value == selected;
    return Expanded(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        decoration: BoxDecoration(color: active ? purple.withValues(alpha: .17) : background, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? purple : const Color(0xFF302B3D))),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: active ? Colors.white : muted)),
      ),
    ));
  }

  Widget primaryButton({required String text, required IconData icon, required VoidCallback? onPressed}) => SizedBox(
    width: double.infinity, height: 54,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: FilledButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, disabledBackgroundColor: purple.withValues(alpha: .3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    ),
  );

  Widget hero() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF35205B), Color(0xFF171024), Color(0xFF0C0B13)]), border: Border.all(color: purple.withValues(alpha: .4))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.multitrack_audio_rounded, color: Color(0xFFD5AEFF), size: 38),
      const SizedBox(height: 18),
      const Text('Your Anime.\nYour Language.', style: TextStyle(fontSize: 29, height: 1.13, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      const Text('Upload a clip. Translate the dialogue. Create your own AI dub.', style: TextStyle(color: Color(0xFFD1C5DF), fontSize: 14, height: 1.5)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(30)), child: const Text('JAPANESE  鈥�  HINDI  鈥�  ENGLISH', style: TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.bold))),
    ]),
  );

  Widget configuration() => panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    sectionTitle('Dub settings', subtitle: 'Choose your target language and voice style.'),
    const SizedBox(height: 22),
    const Text('TARGET LANGUAGE', style: TextStyle(fontSize: 11, letterSpacing: 1.3, color: muted, fontWeight: FontWeight.bold)),
    const SizedBox(height: 11),
    Row(children: [
      option(label: '馃嚠馃嚦  Hindi', value: 'hi', selected: language, onTap: busy || project != null ? null : () => setState(() => language = 'hi')),
      const SizedBox(width: 10),
      option(label: '馃嚭馃嚫  English', value: 'en', selected: language, onTap: busy || project != null ? null : () => setState(() => language = 'en')),
    ]),
    const SizedBox(height: 22),
    const Text('VOICE STYLE', style: TextStyle(fontSize: 11, letterSpacing: 1.3, color: muted, fontWeight: FontWeight.bold)),
    const SizedBox(height: 11),
    Row(children: [
      option(label: 'Natural', value: 'natural', selected: style, onTap: busy ? null : () => setState(() => style = 'natural')),
      const SizedBox(width: 10),
      option(label: 'Expressive', value: 'expressive', selected: style, onTap: busy ? null : () => setState(() => style = 'expressive')),
    ]),
  ]));

  Widget uploadPanel() => panel(child: Column(children: [
    Container(width: 66, height: 66, decoration: BoxDecoration(color: purple.withValues(alpha: .14), shape: BoxShape.circle), child: const Icon(Icons.cloud_upload_outlined, size: 33, color: purple)),
    const SizedBox(height: 17),
    const Text('Upload your media', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('Select an anime clip, video or audio file.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
    const SizedBox(height: 8),
    const Text('MP4 鈥� MKV 鈥� MOV 鈥� WEBM 鈥� MP3 鈥� WAV 鈥� M4A', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF807A93), fontSize: 10)),
    if (selectedFile.isNotEmpty) ...[const SizedBox(height: 15), Text(selectedFile, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD5AEFF), fontSize: 12))],
    const SizedBox(height: 22),
    primaryButton(text: 'Choose File & Translate', icon: Icons.add_rounded, onPressed: busy ? null : upload),
  ]));

  Widget statusPanel() {
    final isError = status.startsWith('Error:');
    return panel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (busy) const SizedBox(width: 23, height: 23, child: CircularProgressIndicator(strokeWidth: 2.5, color: purple))
      else Icon(isError ? Icons.error_outline_rounded : completed ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: isError ? Colors.orangeAccent : completed ? Colors.greenAccent : purple),
      const SizedBox(width: 13),
      Expanded(child: Text(status, style: const TextStyle(fontSize: 13, height: 1.5))),
    ]));
  }

  Widget dialoguePanel() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    sectionTitle('Translated dialogue', subtitle: 'Detected language: ${project!['source_language']}'),
    const SizedBox(height: 14),
    ...segments.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.mic_rounded, color: purple, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text((s['speaker'] ?? 'Character 1').toString(), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text('${s['start']}s 鈥� ${s['end']}s', style: const TextStyle(fontSize: 11, color: muted)),
      ]),
      const SizedBox(height: 17),
      const Text('ORIGINAL', style: TextStyle(fontSize: 10, color: muted, letterSpacing: 1.2)),
      const SizedBox(height: 7),
      Text(s['text'].toString(), style: const TextStyle(height: 1.5)),
      const SizedBox(height: 18),
      TextField(controller: translations[s['id']], enabled: !busy, maxLines: 3, decoration: const InputDecoration(labelText: 'AI translation', helperText: 'Optional: edit before dubbing')),
    ])))),
    const SizedBox(height: 12),
    primaryButton(text: 'Generate Dubbed Video', icon: Icons.movie_creation_outlined, onPressed: busy ? null : render),
    const SizedBox(height: 12),
    const Text('Current MVP: voices are assigned from speaker labels. Automatic character identification and soundtrack separation are not yet implemented.', style: TextStyle(color: muted, fontSize: 11, height: 1.5)),
  ]);

  Widget completedPanel() => panel(child: Column(children: [
    const Icon(Icons.check_circle_rounded, size: 62, color: Colors.greenAccent),
    const SizedBox(height: 14),
    const Text('Dubbing Complete!', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('Your OtakuDub video is ready.', style: TextStyle(color: muted)),
    const SizedBox(height: 22),
    primaryButton(text: 'Open Dubbed Video', icon: Icons.play_arrow_rounded, onPressed: outputPath == null ? null : () async { await OpenFilex.open(outputPath!); }),
  ]));

  @override
  Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
    const BrandHeader(),
    const SizedBox(height: 27),
    hero(),
    const SizedBox(height: 26),
    configuration(),
    const SizedBox(height: 17),
    uploadPanel(),
    const SizedBox(height: 17),
    statusPanel(),
    if (busy) ...[const SizedBox(height: 12), const LinearProgressIndicator(color: purple, backgroundColor: surface)],
    if (project != null) ...[const SizedBox(height: 28), dialoguePanel()],
    if (completed) ...[const SizedBox(height: 22), completedPanel()],
    const SizedBox(height: 35),
    const Center(child: Text('OTAKUDUB  鈥�  YOUR ANIME. YOUR LANGUAGE.', style: TextStyle(color: Color(0xFF777184), fontSize: 10, letterSpacing: 1.1))),
    const SizedBox(height: 20),
  ]));

  @override
  void dispose() {
    for (final controller in translations.values) { controller.dispose(); }
    super.dispose();
  }
}
