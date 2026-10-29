import 'package:flutter/material.dart';
import '../models/dub_project.dart';

/// Read-only production ledger. No department is marked passed without a
/// separately persisted, reviewed handoff in the replacement pipeline.
class DepartmentWorkPage extends StatelessWidget {
  const DepartmentWorkPage({super.key, required this.project});
  final DubProject? project;
  static const names = [
    '00 · Production Office', '01 · Research & Continuity',
    '02 · Original Script', '03 · Translation & Adaptation',
    '04 · Script Supervision', '05 · Casting & Performance Direction',
    '06 · Voice Performance', '07 · ADR & Timing',
    '08 · Sound Post-production', '09 · Quality Control', '10 · Delivery',
  ];
  @override
  Widget build(BuildContext context) {
    final p = project;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Department Work', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Independent work, evidence, evaluation and handoff for every department. The replacement AI pipeline is being rebuilt; none of its departments is approved yet.'),
      const SizedBox(height: 18),
      if (p == null) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Import or select a project in Studio to inspect its saved material.')))
      else Card(child: ListTile(title: Text(p.title), subtitle: Text('Target: ${p.targetLanguage.toUpperCase()} · Saved stage: ${p.stage.name}\nExisting scripts below are LEGACY DATA, not new department approvals.'))),
      for (var i = 0; i < names.length; i++)
        Card(child: ExpansionTile(
          key: ValueKey('department_$i'),
          title: Text(names[i]),
          subtitle: const Text('Replacement department: not implemented / not approved'),
          children: [
            const ListTile(title: Text('Producer evidence'), subtitle: Text('Not produced by replacement engine')),
            const ListTile(title: Text('Independent evaluation'), subtitle: Text('Pending · no verified handoff')),
            if (p != null && i == 2) ...[
              const ListTile(title: Text('Saved original script (legacy; unverified)')),
              if (p.segments.isEmpty) const ListTile(subtitle: Text('No transcript saved')),
              for (final s in p.segments) ListTile(
                title: Text('#${s.id} · ${s.start.toStringAsFixed(2)}–${s.end.toStringAsFixed(2)} s'),
                subtitle: SelectableText(s.original.isEmpty ? 'No original dialogue' : s.original)),
            ],
            if (p != null && i == 3) ...[
              const ListTile(title: Text('Saved translated script (legacy; unverified)')),
              if (p.segments.isEmpty) const ListTile(subtitle: Text('No translations saved')),
              for (final s in p.segments) ListTile(
                title: Text('#${s.id} · ${s.start.toStringAsFixed(2)}–${s.end.toStringAsFixed(2)} s'),
                subtitle: SelectableText(s.translation.isEmpty ? 'Translation not available' : s.translation)),
            ],
            if (p != null && i == 5) ...[
              const ListTile(title: Text('Existing speaker/voice assignments (legacy; unverified)')),
              for (final s in p.segments) ListTile(
                title: Text('Line #${s.id}: ${s.speakerId}'),
                subtitle: Text('Voice: ${s.voiceId.isEmpty ? "Unassigned" : s.voiceId} · Acoustic confidence: ${s.speakerConfidence.toStringAsFixed(2)}')),
            ],
          ],
        )),
    ]);
  }
}
