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
      required('redistribution_license');
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
      final key = '$anime/$episode/$start';
      if (!unique.add(key)) throw const FormatException('Duplicated reference');
      entries.add(entry);
    }
    return entries;
  }
}
