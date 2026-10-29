import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OtakuDubApp());
}

// The launcher icon's lavender is the signature accent across the new UI.
const lavender = Color(0xFFB9A2F4);
const violet = Color(0xFF9A83D9);
const canvas = Color(0xFF101014);
const surface = Color(0xFF1B1A22);
const softer = Color(0xFF272530);
const subdued = Color(0xFFAAA6B6);
const white = Color(0xFFF8F6FF);

class OtakuDubApp extends StatelessWidget {
  const OtakuDubApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OtakuDub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvas,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: lavender,
            brightness: Brightness.dark,
            primary: lavender,
            surface: surface,
          ),
          appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: white),
          cardTheme: CardThemeData(color: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF18171E),
            indicatorColor: lavender.withValues(alpha: .18),
            labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
        home: const OtakuShell(),
      );
}

class OtakuShell extends StatefulWidget {
  const OtakuShell({super.key});
  @override
  State<OtakuShell> createState() => _OtakuShellState();
}

class _OtakuShellState extends State<OtakuShell> {
  int tab = 0;
  static const labels = ['Discover', 'Studio', 'Projects', 'Departments'];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 18,
          title: Row(children: [
            Container(width: 29, height: 29, decoration: BoxDecoration(color: lavender, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.play_arrow_rounded, color: canvas, size: 24)),
            const SizedBox(width: 9),
            const Text('OTAKUDUB', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 20)),
          ]),
          actions: [
            IconButton(onPressed: () => setState(() => tab = 3), tooltip: 'Department progress', icon: const Icon(Icons.monitor_heart_outlined)),
            const Padding(padding: EdgeInsets.only(right: 16), child: CircleAvatar(radius: 15, backgroundColor: softer, child: Icon(Icons.person_outline, color: lavender, size: 19))),
          ],
        ),
        body: IndexedStack(index: tab, children: const [DiscoverPage(), StudioPage(), ProjectsPage(), DepartmentsPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: lavender), label: 'Discover'),
            NavigationDestination(icon: Icon(Icons.movie_creation_outlined), selectedIcon: Icon(Icons.movie_creation, color: lavender), label: 'Studio'),
            NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library, color: lavender), label: 'Projects'),
            NavigationDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree, color: lavender), label: 'Departments'),
          ],
        ),
      );
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          height: 330,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF4C386E), Color(0xFF211D31), Color(0xFF121116)]),
          ),
          child: Stack(children: [
            const Positioned(right: -34, top: 10, child: Icon(Icons.auto_awesome, size: 225, color: Color(0x558B76B5))),
            const Positioned(right: 16, top: 35, child: Icon(Icons.play_circle_outline_rounded, size: 110, color: Color(0x88D8C9FF))),
            Positioned(left: 22, right: 22, bottom: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BLACKHEART PRESENTS', style: TextStyle(color: lavender, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)),
              const SizedBox(height: 9),
              const Text('Your Anime.\nYour Language.', style: TextStyle(fontSize: 34, height: 1.08, fontWeight: FontWeight.w900, color: white)),
              const SizedBox(height: 12),
              const Text('A new dubbing studio, rebuilt department by department.', style: TextStyle(color: Color(0xFFDDD4EC), fontSize: 13)),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => _notReady(context), icon: const Icon(Icons.play_arrow), label: const Text('EXPLORE THE REBUILD'),
                style: FilledButton.styleFrom(backgroundColor: lavender, foregroundColor: canvas)),
            ])),
          ]),
        ),
        const _SectionTitle(title: 'Built for the next production', subtitle: 'A fresh start for OtakuDub'),
        const SizedBox(height: 12),
        const _FeatureTile(icon: Icons.translate, title: 'Human-sounding adaptations', description: 'Original dialogue and target-language scripts will be reviewed side by side.'),
        const _FeatureTile(icon: Icons.record_voice_over_outlined, title: 'Character-consistent voices', description: 'Casting and performance will be assessed independently.'),
        const _FeatureTile(icon: Icons.fact_check_outlined, title: 'Every department accountable', description: 'Inspect evidence, approvals, issues and handoffs in one place.'),
        const Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Text('POWERED BY BLACKHEART', style: TextStyle(letterSpacing: 2, color: subdued, fontSize: 10))),
      ]);
}

void _notReady(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The new dubbing engines are not installed yet. The UI is ready for departmental development.')));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: subdued, fontSize: 12)),
    ]),
  );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(width: 47, height: 47, decoration: BoxDecoration(color: softer, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: lavender)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 5),
        Text(description, style: const TextStyle(color: subdued, fontSize: 12)),
      ])),
    ]),
  );
}

class StudioPage extends StatelessWidget {
  const StudioPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('DUBBING STUDIO', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
    const SizedBox(height: 5),
    const Text('Build a production from your source video.', style: TextStyle(color: subdued)),
    const SizedBox(height: 23),
    Container(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 22),
      decoration: BoxDecoration(color: surface, border: Border.all(color: violet.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(17)),
      child: Column(children: [
        const Icon(Icons.add_to_queue_rounded, color: lavender, size: 50),
        const SizedBox(height: 14),
        const Text('Start a new dub', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Video import will return with Department 00.', textAlign: TextAlign.center,
          style: TextStyle(color: subdued)),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => _notReady(context), icon: const Icon(Icons.add), label: const Text('IMPORT VIDEO'),
          style: FilledButton.styleFrom(backgroundColor: lavender, foregroundColor: canvas),
        ),
      ]),
    ),
    const SizedBox(height: 22),
    const _FeatureTile(icon: Icons.lock_clock_outlined, title: 'Production currently offline', description: 'The old AI pipeline has been removed. No unfinished department will silently run.'),
  ]);
}

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('MY PROJECTS', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    const Text('New project storage and resume controls will be rebuilt with Production Office.', style: TextStyle(color: subdued)),
    const SizedBox(height: 80),
    Center(child: Column(children: [
      Icon(Icons.video_library_outlined, size: 75, color: lavender.withValues(alpha: .8)),
      const SizedBox(height: 15),
      const Text('Your production library starts here', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      const Text('No projects in the new system yet.', style: TextStyle(color: subdued)),
    ])),
  ]);
}

class DepartmentSpec {
  const DepartmentSpec(this.name, this.purpose, this.artifacts, this.checks);
  final String name, purpose;
  final List<String> artifacts, checks;
}

const departments = <DepartmentSpec>[
  DepartmentSpec('Production Office', 'Intake, media verification, project manifest and checkpoint ownership.',
      ['Source video metadata', 'Validated media manifest', 'Project and run IDs'], ['Readable video/audio', 'Hash and timestamp integrity']),
  DepartmentSpec('Research & Continuity', 'Collect scene context while distinguishing references from verified evidence.',
      ['Scene evidence', 'Continuity notes', 'Reference provenance'], ['Evidence grounding', 'No invented identity']),
  DepartmentSpec('Original Script', 'Extract source speech with precise line-level timing.',
      ['Original dialogue', 'Language and timestamps', 'Uncertain words'], ['Text/audio alignment', 'Coverage and omissions']),
  DepartmentSpec('Translation & Adaptation', 'Preserve meaning and natural conversation in the target language.',
      ['Translated script', 'Dialogue alternatives', 'Terminology notes'], ['Semantic equivalence', 'Natural language and timing']),
  DepartmentSpec('Script Supervision', 'Independently challenge script meaning, consistency and pronunciation.',
      ['Review report', 'Approved revisions', 'Issue history'], ['Source-to-target meaning', 'Continuity and completeness']),
  DepartmentSpec('Casting & Performance Direction', 'Ground recurring speaker identity and select suitable voices.',
      ['Speaker evidence', 'Character/voice map', 'Emotion and delivery cues'], ['Identity continuity', 'Uncertainty rejection']),
  DepartmentSpec('Voice Performance', 'Generate expressive dialogue from approved scripts and casting.',
      ['Line-by-line speech audio', 'Voice/style metadata', 'Synthesis issues'], ['Intelligibility', 'Voice stability and delivery']),
  DepartmentSpec('ADR & Timing', 'Fit approved performances to dialogue windows and visible action.',
      ['Timed takes', 'Alignment decisions', 'Retake requests'], ['No clipped dialogue', 'Sync and duration validity']),
  DepartmentSpec('Sound Post-production', 'Preserve scene ambience, effects and music while mixing the new voices.',
      ['Stem evidence', 'Final mix', 'Mixing measurements'], ['Dialogue audibility', 'No missing soundtrack']),
  DepartmentSpec('Quality Control', 'Evaluate the complete dub independently, including failures at handoffs.',
      ['QC findings', 'Retake decisions', 'Acceptance evidence'], ['End-to-end correctness', 'All prior approvals current']),
  DepartmentSpec('Delivery', 'Package and verify the completed playable video and project records.',
      ['Exported video', 'Export manifest', 'Playback verification'], ['Container/playback integrity', 'No missing or stale assets']),
];

class DepartmentsPage extends StatelessWidget {
  const DepartmentsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('DEPARTMENT TRACKER', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
    const SizedBox(height: 5),
    const Text('Inspect each department’s actual work, independent review and handoff.', style: TextStyle(color: subdued)),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('NEW PIPELINE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text('0 / 11 approved', style: TextStyle(color: lavender, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 13),
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(value: 0, minHeight: 8, backgroundColor: softer, color: lavender)),
        const SizedBox(height: 11),
        const Text('No AI department is implemented or approved yet. Progress will come from verified saved records, not estimated percentages.',
          style: TextStyle(fontSize: 12, color: subdued)),
      ]),
    ),
    const SizedBox(height: 19),
    for (var i = 0; i < departments.length; i++) _DepartmentCard(index: i, spec: departments[i]),
    const SizedBox(height: 12),
  ]);
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.index, required this.spec});
  final int index;
  final DepartmentSpec spec;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Container(width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(color: softer, borderRadius: BorderRadius.circular(8)),
        child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(color: lavender, fontWeight: FontWeight.w900))),
      title: Text(spec.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: const Padding(padding: EdgeInsets.only(top: 4), child: Text('NOT BUILT · 0% VERIFIED', style: TextStyle(color: subdued, fontSize: 10))),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(color: softer),
          Text(spec.purpose, style: const TextStyle(color: subdued, fontSize: 13)),
          const SizedBox(height: 16),
          const _DetailHeader('WORK & ARTIFACTS'),
          for (final item in spec.artifacts) _DetailLine(item),
          const SizedBox(height: 12),
          const _DetailHeader('INDEPENDENT REVIEW'),
          for (final item in spec.checks) _DetailLine(item),
          const SizedBox(height: 13),
          const _DetailHeader('ACTUAL RESULTS'),
          const Text('No output recorded. No original script, translation, audio, or review exists in the replacement pipeline yet.',
            style: TextStyle(color: subdued, fontSize: 12)),
          const SizedBox(height: 12),
          const _DetailHeader('HANDOFF'),
          const Text('Locked until implementation, evidence and independent acceptance pass.',
            style: TextStyle(color: subdued, fontSize: 12)),
        ]))],
    ));
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 7),
    child: Text(title, style: const TextStyle(color: lavender, letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w900)));
}
class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [const Icon(Icons.radio_button_unchecked, size: 13, color: subdued), const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12)))]));
}
