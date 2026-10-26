import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/network/api_exception.dart';
import '../core/providers.dart';
import '../models/content.dart';
import '../models/json.dart';
import '../repositories/providers.dart';
import 'preferences_service.dart';
import 'sync_service.dart';

enum DownloadStatus { queued, downloading, done, failed }

class OfflineEntry {
  const OfflineEntry({
    required this.id,
    required this.title,
    required this.status,
    this.progress = 0,
    this.withAudio = false,
    this.sizeBytes = 0,
    this.stale = false,
    this.audioPath,
    this.coverPath,
    this.json,
    this.downloadedAt,
  });

  final int id;
  final String title;
  final DownloadStatus status;
  final double progress;
  final bool withAudio;
  final int sizeBytes;
  final bool stale;
  final String? audioPath;
  final String? coverPath;
  final Json? json;
  final DateTime? downloadedAt;

  bool get isDone => status == DownloadStatus.done;
  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;

  Mezmur? toMezmur() => json == null ? null : Mezmur.fromJson(json!, localAudioPath: audioPath, localCoverPath: coverPath);

  String? get categoryName => asStr(asJson(json?['category'])['name']);

  factory OfflineEntry.fromRow(Map<String, Object?> r) => OfflineEntry(
        id: r['id'] as int,
        title: r['title'] as String,
        status: DownloadStatus.values.byName(r['status'] as String),
        progress: (r['progress'] as num?)?.toDouble() ?? 0,
        withAudio: r['with_audio'] == 1,
        sizeBytes: (r['size_bytes'] as int?) ?? 0,
        stale: r['stale'] == 1,
        audioPath: r['audio_path'] as String?,
        coverPath: r['cover_path'] as String?,
        json: r['json'] == null ? null : asJson(jsonDecode(r['json'] as String)),
        downloadedAt: DateTime.tryParse('${r['downloaded_at']}'),
      );

  OfflineEntry copyWith({DownloadStatus? status, double? progress}) => OfflineEntry(
        id: id,
        title: title,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        withAudio: withAudio,
        sizeBytes: sizeBytes,
        stale: stale,
        audioPath: audioPath,
        coverPath: coverPath,
        json: json,
        downloadedAt: downloadedAt,
      );
}

class WifiOnlyException implements Exception {}

/// Offline Mezmur downloads: lyrics + category (always), cover and audio (optional).
/// Audio is only fetched when the user asks for it or their "download audio" preference allows it.
class DownloadManager extends Notifier<Map<int, OfflineEntry>> {
  late Future<void> _ready;

  @override
  Map<int, OfflineEntry> build() {
    _ready = _load();
    return const {};
  }

  Database get _db => ref.read(localDbProvider).db;

  Future<void> _load() async {
    final rows = await _db.query('offline_mezmurs');
    // Anything interrupted mid-download (app killed) is marked failed so it can be retried.
    state = {
      for (final r in rows)
        r['id'] as int: () {
          final e = OfflineEntry.fromRow(r);
          return e.isActive ? e.copyWith(status: DownloadStatus.failed) : e;
        }(),
    };
  }

  Future<Directory> _dir(String sub) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'offline', sub));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  void _set(OfflineEntry e) => state = {...state, e.id: e};

  OfflineEntry? entry(int id) => state[id];

  Future<void> download(int id, {required String title, required bool withAudio}) async {
    await _ready;
    if (state[id]?.isActive ?? false) return;
    if (withAudio && ref.read(appSettingsProvider).wifiOnly && !await isUnmeteredConnection()) {
      throw WifiOnlyException();
    }
    _set(OfflineEntry(id: id, title: title, status: DownloadStatus.downloading, withAudio: withAudio));
    await _db.insert(
      'offline_mezmurs',
      {'id': id, 'title': title, 'json': '{}', 'with_audio': withAudio ? 1 : 0, 'status': 'downloading'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    try {
      final api = ref.read(apiClientProvider);
      // Records the download server-side and returns the full offline package.
      final json = await api.put<Json>('/downloads/$id', body: {'with_audio': withAudio}, parse: asJson);
      var size = utf8.encode(jsonEncode(json)).length;

      String? coverPath;
      final coverUrl = asStr(json['cover_url']);
      if (coverUrl != null) {
        coverPath = p.join((await _dir('covers')).path, '$id${p.extension(Uri.parse(coverUrl).path)}');
        await api.download(coverUrl, coverPath);
        size += await File(coverPath).length();
      }

      String? audioPath;
      final audio = asJson(json['audio']);
      final audioUrl = asStr(audio['url']);
      if (withAudio && audioUrl != null) {
        audioPath = p.join((await _dir('audio')).path, '$id${p.extension(Uri.parse(audioUrl).path)}');
        await api.download(audioUrl, audioPath, onProgress: (r, t) {
          if (t > 0) _set(state[id]!.copyWith(progress: r / t));
        });
        size += await File(audioPath).length();
      }

      final row = {
        'id': id,
        'title': asStr(json['title']) ?? title,
        'json': jsonEncode(json),
        'content_version': asIntOr(json['content_version'], 1),
        'with_audio': audioPath != null ? 1 : 0,
        'audio_path': audioPath,
        'cover_path': coverPath,
        'size_bytes': size,
        'status': 'done',
        'progress': 1.0,
        'stale': 0,
        'downloaded_at': DateTime.now().toIso8601String(),
      };
      await _db.insert('offline_mezmurs', row, conflictAlgorithm: ConflictAlgorithm.replace);
      _set(OfflineEntry.fromRow(row));
    } catch (e) {
      await _db.update('offline_mezmurs', {'status': 'failed'}, where: 'id = ?', whereArgs: [id]);
      _set((state[id] ?? OfflineEntry(id: id, title: title, status: DownloadStatus.failed)).copyWith(status: DownloadStatus.failed));
      rethrow;
    }
  }

  /// "Download audio" preference (on by default): opening a Mezmur keeps its audio offline too.
  /// Never duplicates (skips done / running entries), obeys "Wi-Fi only" silently, and failed
  /// downloads are retried by [retryFailed] when the connection comes back.
  Future<void> autoDownloadAudio(Mezmur m) async {
    if (!m.hasAudio || !ref.read(preferencesProvider).downloadAudio) return;
    await _ready;
    final e = state[m.id];
    if (e != null && (e.isActive || (e.isDone && e.withAudio))) return;
    try {
      await download(m.id, title: m.title, withAudio: true);
    } catch (_) {
      // Wi-Fi only / offline / server error: left as failed (or untouched) and retried later.
    }
  }

  /// Retry failed audio downloads (called when the phone is back online).
  Future<void> retryFailed() async {
    await _ready;
    if (!ref.read(preferencesProvider).downloadAudio) return;
    for (final e in state.values.where((e) => e.status == DownloadStatus.failed).toList()) {
      try {
        await download(e.id, title: e.title, withAudio: e.withAudio);
      } catch (_) {}
    }
  }

  Future<void> retry(int id) async {
    final e = state[id];
    if (e == null) return;
    await download(id, title: e.title, withAudio: e.withAudio);
  }

  Future<void> remove(int id) async {
    await _ready;
    final e = state[id];
    for (final path in [e?.audioPath, e?.coverPath]) {
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    }
    await _db.delete('offline_mezmurs', where: 'id = ?', whereArgs: [id]);
    state = {...state}..remove(id);
    await ref.read(syncServiceProvider).enqueue(SyncOp.downloadRemove, {'mezmur_id': id});
  }

  Future<void> removeAll() async {
    for (final id in state.keys.toList()) {
      await remove(id);
    }
  }

  /// Download several Mezmurs sequentially (e.g. "download all favorites"). Errors are per item.
  Future<void> downloadAll(List<MezmurSummary> items, {required bool withAudio}) async {
    for (final m in items) {
      final have = state[m.id];
      if (have != null && have.isDone && (have.withAudio || !m.hasAudio)) continue;
      try {
        await download(m.id, title: m.title, withAudio: withAudio && m.hasAudio);
      } on WifiOnlyException {
        rethrow;
      } catch (_) {
        // Marked failed; the user can retry from the downloads screen.
      }
    }
  }

  int get totalBytes => state.values.fold(0, (s, e) => s + e.sizeBytes);

  /// Lyrics are kept offline automatically (no server call, no "download" record). An entry that
  /// already has audio keeps its files; only the text is refreshed when the content changed.
  Future<void> cacheLyrics(Mezmur m) => _storeLyrics([m.raw]);

  bool _syncingLyrics = false;

  /// Pull the lyrics of every published Mezmur (paged) so reading works offline from day one.
  Future<void> syncAllLyrics() async {
    if (_syncingLyrics) return;
    _syncingLyrics = true;
    try {
      await _ready;
      final api = ref.read(apiClientProvider);
      for (var page = 1;; page++) {
        final res = await api.getPage<Json>('/mezmurs/lyrics-pack', (j) => j, page: page, limit: 200);
        await _storeLyrics(res.items);
        if (!res.hasMore) break;
      }
    } on ApiException {
      // Offline — the next start tries again.
    } finally {
      _syncingLyrics = false;
    }
  }

  Future<void> _storeLyrics(List<Json> items) async {
    await _ready;
    final next = {...state};
    await _db.transaction((txn) async {
      for (final j in items) {
        final id = asIntOr(j['id']);
        if (id == 0 || asStr(j['lyrics']) == null) continue;
        final version = asIntOr(j['content_version'], 1);
        final old = next[id];
        if (old != null && old.isDone && asIntOr(old.json?['content_version'], 0) >= version) continue;
        if (old != null && (old.isActive || old.withAudio)) {
          if (old.isActive) continue;
          await txn.update('offline_mezmurs', {'json': jsonEncode(j), 'title': asStr(j['title']) ?? old.title, 'content_version': version}, where: 'id = ?', whereArgs: [id]);
        } else {
          await txn.insert(
            'offline_mezmurs',
            {
              'id': id,
              'title': asStr(j['title']) ?? '',
              'json': jsonEncode(j),
              'content_version': version,
              'with_audio': 0,
              'size_bytes': utf8.encode(jsonEncode(j)).length,
              'status': 'done',
              'progress': 1.0,
              'stale': 0,
              'downloaded_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        final rows = await txn.query('offline_mezmurs', where: 'id = ?', whereArgs: [id]);
        if (rows.isNotEmpty) next[id] = OfflineEntry.fromRow(rows.first);
      }
    });
    state = next;
  }

  /// Offline full-text search over downloaded Mezmurs (used when there is no connection).
  Future<List<Mezmur>> searchOffline(String q) async {
    final like = '%${q.replaceAll('%', '')}%';
    final rows = await _db.query('offline_mezmurs', where: "status = 'done' AND (title LIKE ? OR json LIKE ?)", whereArgs: [like, like], limit: 50);
    return rows.map((r) => OfflineEntry.fromRow(r).toMezmur()).whereType<Mezmur>().toList();
  }

  /// Ask the server which offline copies changed or were withdrawn; refresh or drop them.
  Future<void> refreshStale() async {
    final done = state.values.where((e) => e.isDone && e.json != null).toList();
    if (done.isEmpty) return;
    try {
      final res = await ref.read(contentRepositoryProvider).changes([
        for (final e in done) (id: e.id, version: asIntOr(e.json!['content_version'], 1)),
      ]);
      for (final m in res.updated) {
        final old = state[m.id];
        if (old == null) continue;
        final audioChanged = old.withAudio && asStr(asJson(old.json?['audio'])['url']) != m.audio?.url;
        if (audioChanged) {
          await _db.update('offline_mezmurs', {'stale': 1}, where: 'id = ?', whereArgs: [m.id]);
        }
        await _db.update(
          'offline_mezmurs',
          {'json': jsonEncode(m.raw), 'title': m.title, 'content_version': m.summary.contentVersion},
          where: 'id = ?',
          whereArgs: [m.id],
        );
      }
      for (final id in res.removed) {
        // Withdrawn by the administrators — the offline copy is removed as well.
        final e = state[id];
        for (final path in [e?.audioPath, e?.coverPath]) {
          if (path != null && await File(path).exists()) await File(path).delete();
        }
        await _db.delete('offline_mezmurs', where: 'id = ?', whereArgs: [id]);
      }
      await _load();
    } on ApiException {
      // Offline or server issue — try again next time.
    }
  }
}

final downloadsProvider = NotifierProvider<DownloadManager, Map<int, OfflineEntry>>(DownloadManager.new);
