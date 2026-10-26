import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/export_file_validator.dart';

void main() {
  test('export validator rejects missing and truncated files', () async {
    final dir = await Directory.systemTemp.createTemp('otakudub-mp4-');
    try {
      final file = File('${dir.path}/video.mp4');
      expect(await ExportFileValidator.hasMp4Header(file), isFalse);
      await file.writeAsBytes([0, 0, 0, 8, 102, 116, 121, 112]);
      expect(await ExportFileValidator.hasMp4Header(file), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('export validator accepts MP4 ftyp and rejects arbitrary payload', () async {
    final dir = await Directory.systemTemp.createTemp('otakudub-mp4-');
    try {
      final file = File('${dir.path}/video.mp4');
      await file.writeAsBytes([0, 0, 0, 16, 102, 116, 121, 112,
        105, 115, 111, 109, 0, 0, 0, 0]);
      expect(await ExportFileValidator.hasMp4Header(file), isTrue);
      await file.writeAsBytes([0, 0, 0, 32, 102, 116, 121, 112,
        105, 115, 111, 109, 0, 0, 0, 0]);
      expect(await ExportFileValidator.hasMp4Header(file), isFalse);
      await file.writeAsBytes([0, 0, 0, 1, 102, 116, 121, 112,
        105, 115, 111, 109, 0, 0, 0, 0]);
      expect(await ExportFileValidator.hasMp4Header(file), isFalse);
      await file.writeAsBytes(List<int>.filled(32, 0));
      expect(await ExportFileValidator.hasMp4Header(file), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
