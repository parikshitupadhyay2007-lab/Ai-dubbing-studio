import 'dart:convert';

/// Licensed scene references must be traceable to an actual supplied corpus.
/// This validator intentionally refuses unlicensed or incomplete entries.
class VerifiedAnimeCatalog {
  const VerifiedAnimeCatalog();

  List<Map<String, dynamic>> parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Catalog must be a list');
    final unique = <String>{};
    final entries = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) throw const FormatException('Invalid reference record');
      final entry = Map<String, dynamic>.from(item);
      String required(String key) {
        final value = entry[key];
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('Missing verified catalog field: $key');
        }
        return value;
      }
      final anime = required('anime_id');
      final episode = required('episode_id');
      required('title');
      required('provenance');
      final license = required('redistribution_license').trim().toLowerCase();
      if (const {'unknown', 'none', 'unlicensed', 'tbd', 'pending', 'copyrighted'}.contains(license)) {
        throw const FormatException('Reference usage rights are not established');
      }
      required('source_id');
      final lines = entry['dialogue'];
      if (lines is! List || lines.length < 3 ||
          lines.any((line) => line is! String || line.trim().isEmpty)) {
        throw const FormatException('Catalog needs at least three actual dialogue lines');
      }
      final start = entry['start_seconds'];
      if (start is! num || !start.toDouble().isFinite || start < 0) {
        throw const FormatException('Invalid reference timeline');
      }
      final annotations = entry['speaker_annotations'];
      if (annotations != null) {
        if (annotations is! List) throw const FormatException('Invalid speaker annotations');
        final seen = <String>{};
        for (final rawRow in annotations) {
          if (rawRow is! Map) throw const FormatException('Invalid speaker annotation row');
          final row = Map<String, dynamic>.from(rawRow);
          for (final field in ['track_id', 'character_id', 'reference_id', 'source_hash']) {
            if (row[field] is! String || (row[field] as String).trim().isEmpty) {
              throw FormatException('Missing speaker annotation field: $field');
            }
          }
          if (row['reference_id'] != entry['source_id'] || row['segment_id'] is! int ||
              (row['segment_id'] as int) < 0 || !seen.add('${row['segment_id']}/${row['track_id']}')) {
            throw const FormatException('Inconsistent or duplicate speaker annotation');
          }
        }
      }
      final key = '$anime/$episode/$start';
      if (!unique.add(key)) throw const FormatException('Duplicated reference');
      entries.add(entry);
    }
    return entries;
  }
}
