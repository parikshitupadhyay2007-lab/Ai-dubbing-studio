import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'verified_anime_catalog.dart';

/// Bundled records are distributable; local developer records never enter APK.
class AnimeReferenceStore {
  const AnimeReferenceStore();

  Future<List<Map<String, dynamic>>> load() async {
    final bundled = const VerifiedAnimeCatalog().parse(
      await rootBundle.loadString('assets/anime_scene_catalog.json'));
    final support = await getApplicationSupportDirectory();
    final privateFile = File('${support.path}/otakudub/private_anime_scene_catalog.json');
    if (!await privateFile.exists()) return bundled;
    final local = const VerifiedAnimeCatalog().parse(await privateFile.readAsString());
    final known = <String>{};
    final combined = <Map<String, dynamic>>[];
    for (final row in [...bundled, ...local]) {
      final key = '${row['anime_id']}/${row['episode_id']}/${row['start_seconds']}';
      if (!known.add(key)) throw const FormatException('Duplicate bundled/private anime reference');
      combined.add(row);
    }
    return combined;
  }
}
