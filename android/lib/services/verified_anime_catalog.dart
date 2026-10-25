import 'dart:convert';

/// Rejects incomplete, untraceable or structurally inconsistent scene records.
/// Validation is not an independent legal determination of usage rights.
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
      final sourceId = required('source_id');
      final lines = entry['dialogue'];
      if (lines is! List || lines.length < 3 ||
          lines.any((line) => line is! String || line.trim().isEmpty)) {
        throw const FormatException('Catalog needs at least three actual dialogue lines');
      }
      final start = entry['start_seconds'];
      if (start is! num || !start.toDouble().isFinite || start < 0) {
        throw const FormatException('Invalid reference timeline');
      }
      final season = entry['season'];
      if (season != null && (season is! int || season < 0)) {
        throw const FormatException('Invalid anime season');
      }
      final end = entry['end_seconds'];
      if (end != null && (end is! num || !end.toDouble().isFinite || end <= start)) {
        throw const FormatException('Invalid scene end timestamp');
      }
      final hashes = entry['frame_hashes'];
      if (hashes != null && (hashes is! List || hashes.any((h) =>
          h is! String || !RegExp(r'^[0-9a-fA-F]{16}$').hasMatch(h)))) {
        throw const FormatException('Invalid visual reference hash');
      }
      final timeline = entry['timeline'];
      if (timeline != null) {
        if (timeline is! List || timeline.isEmpty) {
          throw const FormatException('Invalid scene timeline');
        }
        var previous = start.toDouble();
        for (final rawLine in timeline) {
          if (rawLine is! Map) throw const FormatException('Invalid timeline row');
          final row = Map<String, dynamic>.from(rawLine);
          final from = row['start_seconds'];
          final until = row['end_seconds'];
          if (from is! num || until is! num || !from.toDouble().isFinite ||
              !until.toDouble().isFinite || from < previous || until <= from ||
              (end is num && until > end)) {
            throw const FormatException('Invalid or unordered timeline interval');
          }
          for (final field in ['dialogue', 'speaker_id', 'source_id']) {
            if (row[field] is! String || (row[field] as String).trim().isEmpty) {
              throw FormatException('Missing verified timeline field: $field');
            }
          }
          if (row['source_id'] != sourceId || !lines.contains(row['dialogue'])) {
            throw const FormatException('Timeline provenance or dialogue mismatch');
          }
          final expression = row['expression'];
          if (expression != null && (expression is! Map ||
              expression['source_id'] != sourceId ||
              expression['delivery'] is! String ||
              (expression['delivery'] as String).trim().isEmpty)) {
            throw const FormatException('Unverified expression annotation');
          }
          previous = until.toDouble();
        }
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
          if (row['reference_id'] != sourceId || row['segment_id'] is! int ||
              (row['segment_id'] as int) < 0 ||
              !seen.add("${row['segment_id']}/${row['track_id']}")) {
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
