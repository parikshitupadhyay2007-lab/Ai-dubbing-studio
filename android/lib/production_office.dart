import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Immutable approval derived from independently re-reading the stored file.
class IntakeRecord {
  IntakeRecord(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  bool get approved => data['status'] == 'approved';
  Map<String, dynamic> toJson() => data;
}

class ProductionOffice {
  ProductionOffice({Directory? root, this.inspectOverride}) : _root = root;
  final Directory? _root;
  static final Random _random = Random.secure();
  final Future<Map<String, dynamic>> Function(String path)? inspectOverride;
  static const channel = MethodChannel('co.parikshit.otakudub/production_office');
  Future<Directory> get root async => _root ?? Directory('${(await getApplicationDocumentsDirectory()).path}/otakudub_v6');
  Future<Map<String, dynamic>> inspect(String path) async =>
      inspectOverride != null ? inspectOverride!(path) : Map<String, dynamic>.from(
        await channel.invokeMapMethod<String, dynamic>('inspect', {'path': path}) ?? {});

  Future<String> digest(File f) async => (await sha256.bind(f.openRead()).first).toString();

  Future<void> _atomic(File target, String value) async {
    final temp = File('${target.path}.part');
    await temp.writeAsString(value, flush: true);
    await temp.rename(target.path);
  }

  Future<List<IntakeRecord>> all() async {
    final dir = await root;
    if (!await dir.exists()) return [];
    final records = <IntakeRecord>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      try {
        final file = File('${entity.path}/manifest.json');
        if (await file.exists()) records.add(IntakeRecord(Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map)));
      } catch (_) { /* Interrupted or invalid manifests do not become approved projects. */ }
    }
    records.sort((a, b) => b.id.compareTo(a.id));
    return records;
  }

  Future<IntakeRecord> import(String sourcePath, String title, String language) async {
    if (!['hi', 'en'].contains(language)) throw const FormatException('Unsupported target language');
    final source = File(sourcePath);
    if (!await source.exists() || await source.length() == 0) throw const FormatException('Source is missing or empty');
    final base = await root;
    await base.create(recursive: true);
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff).toRadixString(16)}';
    final folder = Directory('${base.path}/$id');
    await folder.create(recursive: false);
    final destination = File('${folder.path}/source.media');
    final manifest = File('${folder.path}/manifest.json');
    final initial = <String, dynamic>{
      'schema': 1, 'department': '00', 'id': id, 'run_id': '$id-00',
      'title': title, 'target_language': language, 'status': 'importing',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'source_path': destination.path,
    };
    await _atomic(manifest, jsonEncode(initial));
    try {
      await source.openRead().pipe(destination.openWrite());
      final size = await destination.length();
      if (size == 0) throw const FormatException('Imported source is empty');
      final sourceHash = await digest(destination);
      final metadata = await inspect(destination.path);
      final evidence = {...initial, 'status': 'pending_review', 'size_bytes': size,
        'sha256': sourceHash, 'media': metadata};
      await _atomic(manifest, jsonEncode(evidence));
      final verdict = await review(evidence);
      final completed = {...evidence, 'status': verdict['passed'] == true ? 'approved' : 'rejected',
        'review': verdict, 'reviewed_at': DateTime.now().toUtc().toIso8601String()};
      await _atomic(manifest, jsonEncode(completed));
      return IntakeRecord(completed);
    } catch (e) {
      await _atomic(manifest, jsonEncode({...initial, 'status': 'rejected', 'error': '$e'}));
      rethrow;
    }
  }

  /// Reviewer must re-open and re-hash the stored source, not trust producer's claims.
  Future<Map<String, dynamic>> review(Map<String, dynamic> evidence) async {
    final errors = <String>[];
    final path = evidence['source_path'];
    if (path is! String || !path.startsWith('${(await root).absolute.path}/')) {
      return {'passed': false, 'errors': ['Invalid project storage path']};
    }
    final file = File(path);
    if (file.absolute.path != File('${(await root).path}/${evidence['id']}/source.media').absolute.path) {
      return {'passed': false, 'errors': ['Source path does not match project ID']};
    }
    if (!await file.exists()) return {'passed': false, 'errors': ['Stored source missing']};
    final actualSize = await file.length();
    final actualHash = await digest(file);
    if (actualSize <= 0 || actualSize != evidence['size_bytes']) errors.add('Source size mismatch');
    if (actualHash != evidence['sha256']) errors.add('Source fingerprint mismatch');
    try {
      final metadata = await inspect(path);
      if (metadata['has_video'] != true || metadata['has_audio'] != true) errors.add('Video and audio streams required');
      final duration = metadata['duration_ms'];
      if (duration is! num || duration <= 0) errors.add('Invalid duration');
      final width = metadata['width'], height = metadata['height'];
      if (width is! num || width <= 0 || height is! num || height <= 0) errors.add('Invalid dimensions');
      if (jsonEncode(metadata) != jsonEncode(evidence['media'])) errors.add('Media evidence changed');
    } catch (e) { errors.add('Independent media inspection failed: $e'); }
    return {'passed': errors.isEmpty, 'errors': errors, 'size_bytes': actualSize, 'sha256': actualHash};
  }

  Future<bool> canHandoff(IntakeRecord record) async {
    if (!record.approved || record.data['review'] is! Map ||
        (record.data['review'] as Map)['passed'] != true) return false;
    if (!RegExp(r'^[0-9]+-[0-9a-f]+
    if (!await file.exists()) return false;
    final saved = Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
    if (jsonEncode(saved) != jsonEncode(record.data)) return false;
    return (await review(saved))['passed'] == true;
  }
}
).hasMatch(record.id)) return false;
    final file = File('${(await root).path}/${record.id}/manifest.json');
    if (!await file.exists()) return false;
    final saved = Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
    if (jsonEncode(saved) != jsonEncode(record.data)) return false;
    return (await review(saved))['passed'] == true;
  }
}
