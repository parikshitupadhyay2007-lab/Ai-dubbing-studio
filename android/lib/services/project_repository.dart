import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/dub_project.dart';

class ProjectRepository {
  Future<Directory> get root async {
    final docs = await getApplicationDocumentsDirectory();

    final folder = Directory('${docs.path}/otakudub/projects');
    await folder.create(recursive: true);

    return folder;
  }

  Future<Directory> folder(String id) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) {
      throw ArgumentError('Invalid project ID.');
    }

    final base = await root;
    final result = Directory('${base.path}/$id');

    await result.create(recursive: true);
    return result;
  }

  Future<void> save(DubProject project) async {
    final dir = await folder(project.id);
    final destination = File('${dir.path}/project.json');
    final temporary = File('${dir.path}/project.json.tmp');

    await temporary.writeAsString(
      project.encode(),
      flush: true,
    );

    if (await destination.exists()) {
      await destination.delete();
    }

    await temporary.rename(destination.path);
  }

  Future<DubProject> load(String id) async {
    final dir = await folder(id);
    final file = File('${dir.path}/project.json');

    return DubProject.decode(await file.readAsString());
  }

  Future<List<DubProject>> all() async {
    final base = await root;
    final result = <DubProject>[];

    await for (final entity in base.list()) {
      if (entity is! Directory) continue;

      final file = File('${entity.path}/project.json');

      if (!await file.exists()) continue;

      try {
        result.add(
          DubProject.decode(await file.readAsString()),
        );
      } catch (_) {
        // A damaged project should not hide the remaining projects.
      }
    }

    result.sort((a, b) => b.id.compareTo(a.id));
    return result;
  }
}

