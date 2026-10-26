import 'dart:io';

/// Basic container sanity check, not a substitute for media decode/playback.
class ExportFileValidator {
  static Future<bool> hasMp4Header(File file) async {
    if (!await file.exists() || await file.length() < 16) return false;
    final bytes = await file.openRead(0, 16).expand((part) => part).toList();
    if (bytes.length < 16) return false;
    final boxSize = (bytes[0] << 24) | (bytes[1] << 16) |
        (bytes[2] << 8) | bytes[3];
    if (boxSize != 1 && boxSize < 16) return false;
    if (String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') return false;
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    return const {'isom', 'iso2', 'iso4', 'iso5', 'iso6', 'mp41', 'mp42',
      'avc1', 'M4V ', 'dash', 'MSNV'}.contains(brand);
  }
}
