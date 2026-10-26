import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/l10n/l10n.dart';
import '../core/network/api_exception.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../widgets/file_preview.dart';
import 'error_reporting_service.dart';

/// One universal file opening, downloading, caching, and sharing service across the entire platform.
///
/// Features:
/// - Authenticated API downloads, private storage endpoints, public URLs, and local files.
/// - Streaming directly to local storage to support large files without excess memory consumption.
/// - Local cache with offline access: previously downloaded files open immediately even when offline.
/// - In-flight download deduplication: concurrent requests for the same file share one download task.
/// - Path traversal prevention and safe filename sanitization.
/// - Modal progress indicator with cancellation support.
/// - Seamless integration with [openFilePreview] and [SharePlus] for office documents, media, and PDFs.
/// - Integrated diagnostic reporting on download and file-opening failures.
class FileOpeningService {
  FileOpeningService([this._ref]);

  final Ref? _ref;
  final Map<String, Future<File?>> _activeDownloads = <String, Future<File?>>{};

  /// Directory inside app storage dedicated to cached files.
  Future<Directory> _getCacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(base.path, 'file_cache'));
    if (!cacheDir.existsSync()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Sanitizes filenames to eliminate path traversal and invalid characters.
  static String sanitizeFilename(String filename, {String fallback = 'document'}) {
    var clean = filename.trim();
    // Remove query params if present (e.g. file.pdf?token=secret)
    if (clean.contains('?')) {
      final qIndex = clean.indexOf('?');
      final queryPart = clean.substring(qIndex + 1);
      if (queryPart.contains('=') || clean.startsWith('http://') || clean.startsWith('https://')) {
        clean = clean.substring(0, qIndex);
      }
    }
    // Extract basename
    clean = clean.split(RegExp(r'[/\\]')).last;
    // Strip forbidden characters
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (clean.isEmpty || clean == '.' || clean == '..') {
      clean = fallback;
    }
    return clean;
  }

  /// Derives a stable cache key and filename for a given URL or source.
  static String deriveCacheKey(String source) {
    final bytes = utf8.encode(source);
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  /// Resolves the file source into a local file, downloading and caching if needed.
  ///
  /// If [showProgressDialog] is true, presents a cancelable progress dialog.
  Future<File?> acquireFile(
    BuildContext context, {
    required String source,
    String? filename,
    String? mime,
    bool showProgressDialog = true,
    void Function(int received, int total)? onProgress,
  }) async {
    final cleanSource = source.trim();
    if (cleanSource.isEmpty) {
      if (context.mounted) {
        final l = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.isEn ? 'Invalid file link' : 'ትክክለኛ ያልሆነ የፋይል አድራሻ')));
      }
      return null;
    }

    // 1. If it's already an existing local file
    try {
      final localFile = File(cleanSource);
      if (localFile.existsSync()) {
        return localFile;
      }
    } catch (_) {}

    // 2. Prepare safe cached target location
    final cacheDir = await _getCacheDir();
    final key = deriveCacheKey(cleanSource);
    var safeName = sanitizeFilename(filename ?? cleanSource, fallback: 'file_$key');
    if (!safeName.contains('.') && mime != null && mime.trim().isNotEmpty) {
      final ext = switch (mime.trim().toLowerCase()) {
        'application/pdf' => '.pdf',
        'image/png' => '.png',
        'image/jpeg' || 'image/jpg' => '.jpg',
        'image/webp' => '.webp',
        'image/gif' => '.gif',
        'audio/mpeg' || 'audio/mp3' => '.mp3',
        'audio/mp4' || 'audio/m4a' => '.m4a',
        'audio/wav' || 'audio/x-wav' => '.wav',
        'video/mp4' => '.mp4',
        'text/plain' => '.txt',
        'text/csv' => '.csv',
        'application/json' => '.json',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => '.docx',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation' => '.pptx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => '.xlsx',
        _ => '',
      };
      if (ext.isNotEmpty) {
        safeName = '$safeName$ext';
      }
    }
    final targetPath = p.join(cacheDir.path, '${key}_$safeName');
    final targetFile = File(targetPath);
    final partPath = '$targetPath.part';
    final partFile = File(partPath);

    // Verify target path does not escape cacheDir (path traversal defense)
    if (!p.isWithin(cacheDir.path, targetFile.path)) {
      throw StateError('Unsafe file path detected: $targetPath');
    }

    // 3. Check existing cache
    if (targetFile.existsSync() && targetFile.lengthSync() > 0) {
      debugPrint('[FileOpeningService] Cache hit for $cleanSource -> $targetPath');
      return targetFile;
    }

    // 4. In-flight deduplication: if download is already in progress, await it
    if (_activeDownloads.containsKey(key)) {
      debugPrint('[FileOpeningService] Reusing active download task for $key');
      return _activeDownloads[key]!;
    }

    // 5. Download with progress
    final cancelToken = CancelToken();
    ValueNotifier<double>? progressNotifier;
    bool dialogOpen = false;

    if (showProgressDialog && context.mounted) {
      progressNotifier = ValueNotifier<double>(0.0);
      dialogOpen = true;
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DownloadProgressDialog(
          filename: safeName,
          progressNotifier: progressNotifier!,
          onCancel: () {
            cancelToken.cancel('User cancelled download');
            Navigator.of(ctx, rootNavigator: true).pop();
            dialogOpen = false;
          },
        ),
      ));
    }

    final completer = Completer<File?>();
    _activeDownloads[key] = completer.future;

    try {
      final ref = _ref;
      if (ref == null) {
        throw StateError('FileOpeningService was initialized without a Riverpod Ref.');
      }
      final api = ref.read(apiClientProvider);

      await api.download(
        cleanSource,
        partPath,
        cancel: cancelToken,
        onProgress: (received, total) {
          onProgress?.call(received, total);
          if (total > 0 && progressNotifier != null) {
            progressNotifier.value = (received / total).clamp(0.0, 1.0);
          }
        },
      );

      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }

      if (partFile.existsSync() && partFile.lengthSync() > 0) {
        if (targetFile.existsSync()) {
          try {
            targetFile.deleteSync();
          } catch (_) {}
        }
        await partFile.rename(targetPath);
        completer.complete(targetFile);
        return targetFile;
      } else {
        if (partFile.existsSync()) {
          try {
            partFile.deleteSync();
          } catch (_) {}
        }
        throw const ApiException(code: 'EMPTY_FILE', message: 'Downloaded file is empty');
      }
    } catch (e, st) {
      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }

      // Safe cleanup of partial downloaded file
      if (partFile.existsSync()) {
        try {
          partFile.deleteSync();
        } catch (_) {}
      }

      if (cancelToken.isCancelled) {
        debugPrint('[FileOpeningService] Download cancelled by user');
        completer.complete(null);
        return null;
      }

      // Check if we can serve from existing cache as offline fallback
      if (targetFile.existsSync() && targetFile.lengthSync() > 0) {
        if (context.mounted) {
          final l = context.l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.isEn ? 'Offline: Viewing previously downloaded copy' : 'ኢንተርኔት የለም፦ ቀድሞ የወረደውን ቅጂ በማሳየት ላይ')),
          );
        }
        completer.complete(targetFile);
        return targetFile;
      }

      // Record diagnostic error
      final ref = _ref;
      final repId = ref != null
          ? await ref.read(errorReportingServiceProvider).recordError(
              module: 'files',
              screen: 'FileOpeningService',
              operation: 'acquire_file',
              error: e,
              stackTrace: st,
              endpoint: cleanSource,
              customMessage: 'Failed to acquire file: $safeName from $cleanSource',
            )
          : null;

      if (context.mounted) {
        final l = context.l10n;
        final msg = e is ApiException
            ? (e.status == 404
                ? (l.isEn ? 'File not found on server' : 'ፋይሉ በአገልጋዩ ላይ አልተገኘም')
                : (e.status == 401 || e.status == 403
                    ? (l.isEn ? 'Access denied / session expired' : 'ፈቃድ የለዎትም / ክፍለ-ጊዜው አልቋል')
                    : (l.isEn ? 'Network error downloading file' : 'ፋይሉን በማውረድ ላይ ስህተት ተከስቷል')))
            : (l.isEn ? 'Failed to open file ($repId)' : 'ፋይሉን መክፈት አልተቻለም ($repId)');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            action: SnackBarAction(
              label: l.isEn ? 'Details' : 'ዝርዝር',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.isEn ? 'File Error' : 'የፋይል ስህተት'),
                    content: Text('$msg\n\n${l.isEn ? "Diagnostic ID" : "የስህተት መለያ"}: $repId\n\n$e'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.isEn ? 'OK' : 'እሺ'))],
                  ),
                );
              },
            ),
          ),
        );
      }

      completer.complete(null);
      return null;
    } finally {
      _activeDownloads.remove(key);
      progressNotifier?.dispose();
    }
  }

  /// Open any file in the app's unified file preview screen.
  /// Returns `true` only if the file was successfully acquired and opened in the viewer.
  Future<bool> openFile(
    BuildContext context, {
    required String source,
    String? filename,
    String? mime,
  }) async {
    final file = await acquireFile(
      context,
      source: source,
      filename: filename,
      mime: mime,
      showProgressDialog: true,
    );

    if (file != null && context.mounted) {
      final displayName = filename ?? file.uri.pathSegments.last;
      await openFilePreview(
        context,
        file.path,
        name: displayName,
        mime: mime,
      );
      return true;
    }
    return false;
  }

  /// Specific helper for opening and playing audio files through the audio previewer,
  /// preserving audio playback controls and pausing conflicting background players.
  Future<bool> playAudio(
    BuildContext context, {
    required String source,
    String? title,
    String? artist,
  }) async {
    return openFile(
      context,
      source: source,
      filename: title != null ? '$title.mp3' : null,
      mime: 'audio/mpeg',
    );
  }

  /// Shares or opens the file with an external application sheet.
  Future<void> shareOrOpenWith(
    BuildContext context, {
    required String source,
    String? filename,
    String? mime,
  }) async {
    final file = await acquireFile(
      context,
      source: source,
      filename: filename,
      mime: mime,
      showProgressDialog: true,
    );

    if (file != null && context.mounted) {
      final displayName = filename ?? file.uri.pathSegments.last;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mime, name: displayName)],
          subject: displayName,
        ),
      );
    }
  }

  /// Safely cleans up the local cache directory.
  Future<void> clearCache() async {
    try {
      final dir = await _getCacheDir();
      if (dir.existsSync()) {
        for (final entity in dir.listSync()) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[FileOpeningService] Cache clean error: $e');
    }
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog({
    required this.filename,
    required this.progressNotifier,
    required this.onCancel,
  });

  final String filename;
  final ValueNotifier<double> progressNotifier;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.downloading_rounded, color: AppColors.maroon, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.isEn ? 'Downloading file...' : 'ፋይሉን በማውረድ ላይ...',
                    style: context.serif(16, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.sans(13, color: context.palette.muted),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (ctx, progress, _) {
                return Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: context.palette.fill,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        progress > 0 ? '${(progress * 100).toInt()}%' : (l.isEn ? 'Connecting...' : 'በመገናኘት ላይ...'),
                        style: context.sans(11, color: context.palette.muted),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: Text(l.isEn ? 'Cancel' : 'ይቅር'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final fileOpeningServiceProvider = Provider<FileOpeningService>((ref) {
  return FileOpeningService(ref);
});
