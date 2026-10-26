import 'dart:typed_data';

final Map<String, Uint8List> _webUploadBytes = {};

/// Registers picked file bytes in memory so they can be read during upload on Web
void registerUploadBytes(String key, Uint8List bytes) {
  _webUploadBytes[key] = bytes;
}

/// Retrieves stored file bytes by key / path
Uint8List? getUploadBytes(String key) {
  return _webUploadBytes[key];
}

/// Clears cached bytes once upload finishes
void clearUploadBytes(String key) {
  _webUploadBytes.remove(key);
}
