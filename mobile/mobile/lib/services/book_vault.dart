import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

/// Downloaded library books, readable only inside the app.
///
/// A book's PDF is downloaded into memory, encrypted with AES-256-GCM and written to the app's
/// private support directory (`books/book_<id>.bin`). The key is created on first use and kept in
/// the platform keystore (flutter_secure_storage), so a copied file is useless outside this install
/// and no plain PDF is ever written to disk. The in-app reader decrypts into memory.
/// Signing out deletes the books and the key.
class BookVault {
  BookVault._();

  static const _keyName = 'book_vault_key';
  static const _nonceLength = 12;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<Directory> _dir() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}books');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<File> fileFor(int bookId) async => File('${(await _dir()).path}${Platform.pathSeparator}book_$bookId.bin');

  static Future<bool> has(int bookId) async => (await fileFor(bookId)).existsSync();

  static Future<Uint8List> _key({bool create = true}) async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return base64Decode(existing);
    if (!create) throw const BookVaultException();
    final key = _random(32);
    await _storage.write(key: _keyName, value: base64Encode(key));
    return key;
  }

  static Uint8List _random(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  /// nonce (12 bytes) · ciphertext · GCM tag (16 bytes).
  static Uint8List encrypt(Uint8List plain, Uint8List key) {
    final nonce = _random(_nonceLength);
    final c = GCMBlockCipher(AESEngine())..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    return Uint8List.fromList([...nonce, ...c.process(plain)]);
  }

  static Uint8List decrypt(Uint8List sealed, Uint8List key) {
    if (sealed.length <= _nonceLength + 16) throw const BookVaultException();
    final c = GCMBlockCipher(AESEngine())..init(false, AEADParameters(KeyParameter(key), 128, sealed.sublist(0, _nonceLength), Uint8List(0)));
    try {
      return c.process(sealed.sublist(_nonceLength));
    } on InvalidCipherTextException {
      throw const BookVaultException();
    }
  }

  /// Encrypt and keep a downloaded PDF.
  static Future<void> save(int bookId, Uint8List pdf) async {
    final sealed = encrypt(pdf, await _key());
    final f = await fileFor(bookId);
    final tmp = File('${f.path}.part');
    await tmp.writeAsBytes(sealed, flush: true);
    await tmp.rename(f.path);
  }

  /// The PDF in memory for the reader. A file that cannot be decrypted (key gone) is removed and
  /// [BookVaultException] thrown, so the book is simply downloaded again.
  static Future<Uint8List> read(int bookId) async {
    final f = await fileFor(bookId);
    if (!f.existsSync()) throw const BookVaultException();
    try {
      return decrypt(await f.readAsBytes(), await _key(create: false));
    } on BookVaultException {
      await f.delete();
      rethrow;
    }
  }

  static Future<void> remove(int bookId) async {
    final f = await fileFor(bookId);
    if (f.existsSync()) await f.delete();
  }

  /// Delete every downloaded book and the key (sign-out).
  static Future<void> wipe() async {
    try {
      final dir = await _dir();
      if (dir.existsSync()) await dir.delete(recursive: true);
      // Plain PDFs saved by an earlier build in the documents folder.
      final old = Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}books');
      if (old.existsSync()) await old.delete(recursive: true);
      await _storage.delete(key: _keyName);
    } catch (_) {
      // Best effort: nothing to clean on a fresh install / unsupported platform.
    }
  }
}

class BookVaultException implements Exception {
  const BookVaultException();
}
